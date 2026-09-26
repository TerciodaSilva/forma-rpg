class_name FormaNetwork
extends Node

signal status_changed(message: String)
signal entered
const PROTOCOL = 3
const SNAPSHOT_INTERVAL = 1.0 / 20.0
var arena: FormaArena
var active: bool = false
var hosting: bool = false
var dedicated: bool = false
var capacity: int = 10
var rooms: Dictionary = {}
var peer_rooms: Dictionary = {}
var next_room_id: int = 1
var room_id: int = 0
var human_count: int = 0
var nickname: String = "Viajante"
var selected_class: int = 0
var status: String = ""
var peers: Dictionary = {}
var last_input: Dictionary = {}
var pending_peers: Dictionary = {}
var peer: WebSocketMultiplayerPeer
var snapshot_timer: float = 0.0
var input_timer: float = 0.0
var connection_time: float = 0.0
var local_pause: bool = false
var last_snapshot: float = 0.0

func _ready() -> void:
	# All traffic is client/server; rooms must not relay peer-to-peer packets.
	multiplayer.server_relay = false
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): close("Não foi possível conectar ao servidor."))
	multiplayer.server_disconnected.connect(func(): close("O servidor encerrou a sala."))
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.peer_connected.connect(func(id: int):
		if hosting: pending_peers[id] = Time.get_ticks_msec())

func report(message: String) -> void:
	status = message
	status_changed.emit(message)

func host(port: int, slots: int, headless: bool = false) -> Error:
	if OS.has_feature("web"):
		report("No navegador, entre em uma sala de um servidor FORMA.")
		return ERR_UNAVAILABLE
	close()
	peer = WebSocketMultiplayerPeer.new()
	peer.outbound_buffer_size = 1048576
	var error = peer.create_server(port, "*")
	if error != OK:
		report("Não foi possível abrir a porta %d (erro %d)." % [port, error])
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	hosting = true
	dedicated = headless
	capacity = clampi(slots, 2, 10)
	arena.rival_count = capacity - (0 if dedicated else 1)
	arena.networked = true
	arena.new_run(arena.selected_class)
	arena.player.peer_id = 1
	arena.player.label = nickname.left(16)
	if dedicated:
		arena.actors.erase(arena.player)
		arena.player.alive = false
	else:
		peers[1] = arena.player.id
	rooms[1] = arena
	next_room_id = 2
	if not dedicated: peer_rooms[1] = 1
	refill_room(1)
	report("Salas automáticas abertas · porta %d · até %d jogadores" % [port, capacity])
	entered.emit()
	return OK

func join_room(url: String, title: String, kind: int) -> Error:
	close()
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		report("Use um endereço ws:// ou wss://.")
		return ERR_INVALID_PARAMETER
	nickname = title.strip_edges().left(16)
	selected_class = clampi(kind, 0, 4)
	peer = WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = 2097152
	var error = peer.create_client(url)
	if error != OK:
		report("Endereço inválido ou servidor indisponível.")
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	connection_time = 0
	last_snapshot = 0
	report("Conectando à sala…")
	return OK

func close(message: String = "") -> void:
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	active = false
	hosting = false
	dedicated = false
	for room in rooms.values():
		if room != arena: room.queue_free()
	rooms.clear()
	peer_rooms.clear()
	room_id = 0
	human_count = 0
	peers.clear()
	pending_peers.clear()
	last_input.clear()
	local_pause = false
	arena.networked = false
	arena.attack_held = false
	arena.mode = "menu"
	if not message.is_empty():
		report(message)

func _connected() -> void:
	register_player.rpc_id(1, PROTOCOL, nickname, selected_class)

@rpc("any_peer", "call_remote", "reliable")
func register_player(version: int, title: String, kind: int) -> void:
	if not hosting:
		return
	var id = multiplayer.get_remote_sender_id()
	if peers.has(id):
		return
	if version != PROTOCOL or kind < 0 or kind > 4:
		rejected.rpc_id(id, "Versão incompatível ou classe inválida.")
		return
	var assigned_room = find_room()
	peer_rooms[id] = assigned_room
	refill_room(assigned_room)
	var actor = spawn_human(id, title, kind)
	peers[id] = actor.id
	pending_peers.erase(id)
	last_input[id] = Time.get_ticks_msec()
	report("%d jogadores em %d salas" % [peers.size(), rooms.size()])

@rpc("authority", "call_remote", "reliable")
func rejected(message: String) -> void:
	close(message)

func spawn_human(id: int, title: String, kind: int) -> FormaActor:
	var room = room_for(id)
	# Prefer the largest gap between all combatants, including bots and bosses.
	var point = room.random_point()
	var best_clearance = -INF
	for attempt in range(64):
		var candidate = room.random_point()
		var clearance = INF
		for other in room.actors:
			if other.alive:
				clearance = minf(clearance, candidate.distance_to(other.pos) - other.radius())
		if clearance > best_clearance:
			best_clearance = clearance
			point = candidate
		if clearance >= 700: break
	var actor = room.add_actor(kind, point, title.strip_edges().left(16) if not title.strip_edges().is_empty() else "Viajante", true)
	actor.peer_id = id
	actor.shield_timer = 4.0
	actor.input_aim = point + Vector2.RIGHT * 100
	# Late arrivals start with some mass, never another player's boons.
	room.gain_mass(actor, minf(250, room.elapsed * 0.5))
	return actor

func _disconnected(id: int) -> void:
	pending_peers.erase(id)
	last_input.erase(id)
	if not hosting or not peers.has(id): return
	var number = int(peer_rooms[id])
	var room = room_for(id)
	var actor = room.actor_by_id(peers[id])
	if actor != null:
		remove_combatant(room, actor)
	peers.erase(id)
	peer_rooms.erase(id)
	if occupants(number) == 0:
		if number != 1:
			rooms.erase(number)
			room.queue_free()
		else:
			room.rival_count = capacity
			room.new_run(room.selected_class)
			room.actors.erase(room.player)
			room.player.alive = false
	else:
		refill_room(number)
	report("%d jogadores em %d salas" % [peers.size(), rooms.size()])

func occupants(number: int) -> int:
	return peer_rooms.values().count(number)

func room_for(id: int) -> FormaArena:
	return rooms.get(peer_rooms.get(id, 1), arena)

func find_room() -> int:
	# Fill an occupied room before opening or reusing an empty one.
	for number in rooms:
		if occupants(number) > 0 and occupants(number) < capacity: return number
	for number in rooms:
		if occupants(number) == 0: return number
	var room = arena.get_script().new() as FormaArena
	room.networked = true
	room.rival_count = capacity
	room.difficulty = arena.difficulty
	add_child(room)
	room.new_run(0)
	room.actors.erase(room.player)
	room.player.alive = false
	var number = next_room_id
	next_room_id += 1
	rooms[number] = room
	return number

func remove_combatant(room: FormaArena, actor: FormaActor) -> void:
	FormaBoonSystem.clear(actor)
	room.actors.erase(actor)
	room.shots = room.shots.filter(func(shot: FormaShot) -> bool: return shot.owner_id != actor.id)
	room.effects = room.effects.filter(func(effect: FormaEffect) -> bool: return effect.owner_id != actor.id)
	room.hazards = room.hazards.filter(func(hazard: FormaHazard) -> bool: return hazard.owner_id != actor.id)

func refill_room(number: int) -> void:
	var room: FormaArena = rooms[number]
	room.rival_count = capacity - occupants(number)
	room.room_label = "SALA %d · %d humanos + %d bots" % [number, occupants(number), room.rival_count]
	var bots = room.actors.filter(func(actor: FormaActor) -> bool: return not actor.is_player and not actor.is_boss)
	while bots.size() > room.rival_count:
		remove_combatant(room, bots.pop_back())
	while bots.size() < room.rival_count:
		room.spawn_rival()
		bots.append(room.actors.back())

func tick(delta: float, direction: Vector2, aim: Vector2, attack: bool) -> void:
	if not active: return
	connection_time += delta
	if not hosting:
		if last_snapshot == 0 and connection_time > 12:
			close("Tempo de conexão esgotado. Verifique o endereço e a porta.")
			return
		if last_snapshot > 0 and Time.get_ticks_msec() - last_snapshot > 10000:
			close("Conexão com a sala interrompida.")
			return
	if hosting:
		for id in pending_peers.keys():
			if Time.get_ticks_msec() - pending_peers[id] > 10000:
				peer.disconnect_peer(id)
				pending_peers.erase(id)
		for id in last_input:
			if Time.get_ticks_msec() - last_input[id] > 1000:
				var idle = room_for(id).actor_by_id(peers.get(id, -1))
				if idle != null:
					idle.input_direction = Vector2.ZERO
					idle.input_attack = false
		if not dedicated and arena.player != null:
			set_input(1, direction, aim, attack)
		for number in rooms:
			var room: FormaArena = rooms[number]
			room.mode = "playing"
			if occupants(number) > 0:
				room.step(delta)
				refill_room(number)
		snapshot_timer -= delta
		if snapshot_timer <= 0:
			snapshot_timer = SNAPSHOT_INTERVAL
			broadcast()
		if not dedicated: update_local_mode()
	elif peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		input_timer -= delta
		if input_timer <= 0:
			input_timer = 1.0 / 30.0
			submit_input.rpc_id(1, direction, aim, attack)

func set_input(id: int, direction: Vector2, aim: Vector2, attack: bool) -> void:
	var actor = room_for(id).actor_by_id(peers.get(id, -1))
	if actor == null or not actor.alive or not direction.is_finite() or not aim.is_finite(): return
	actor.input_direction = direction.limit_length()
	actor.input_aim = aim.clamp(Vector2(-2000, -2000), FormaArena.SIZE + Vector2(2000, 2000))
	actor.input_attack = attack
	last_input[id] = Time.get_ticks_msec()

@rpc("any_peer", "call_remote", "unreliable")
func submit_input(direction: Vector2, aim: Vector2, attack: bool) -> void:
	if hosting: set_input(multiplayer.get_remote_sender_id(), direction, aim, attack)

func command(action: String, value: int = 0) -> void:
	if hosting: apply_command(1, action, value)
	elif active and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		submit_command.rpc_id(1, action, value)

@rpc("any_peer", "call_remote", "reliable")
func submit_command(action: String, value: int) -> void:
	if hosting: apply_command(multiplayer.get_remote_sender_id(), action, value)

func apply_command(id: int, action: String, value: int) -> void:
	var room = room_for(id)
	var actor = room_for(id).actor_by_id(peers.get(id, -1))
	if actor == null: return
	if action == "respawn" and not actor.alive:
		room.actors.erase(actor)
		var replacement = spawn_human(id, actor.label, actor.class_id)
		peers[id] = replacement.id
		if id == 1:
			room.player = replacement
			entered.emit()
		return
	if not actor.alive: return
	var previous = room.mode
	room.mode = "playing"
	match action:
		"skill": room.use_skill(actor)
		"dash": room.dash(actor, actor.input_direction)
		"upgrade": room.choose_upgrade(value, actor)
	room.mode = previous

func pack_entity(entity: RefCounted) -> Dictionary:
	var data: Dictionary = {}
	for property in entity.get_script().get_script_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			data[property.name] = entity.get(property.name)
	return data

func pack_list(entities: Array) -> Array:
	var result: Array = []
	for entity in entities: result.append(pack_entity(entity))
	return result

func broadcast() -> void:
	if peers.size() <= (0 if dedicated else 1): return
	for number in rooms:
		if occupants(number) > 0: broadcast_room(number)

func broadcast_room(number: int) -> void:
	var room: FormaArena = rooms[number]
	var state = {
		"room_id": number, "human_count": occupants(number), "capacity": capacity,
		"actors": pack_list(room.actors), "orbs": pack_list(room.orbs),
		"shots": pack_list(room.shots), "hazards": pack_list(room.hazards), "effects": pack_list(room.effects),
		"elapsed": room.elapsed, "threat": room.threat, "encounters": room.encounters,
		"difficulty": room.difficulty, "rival_count": room.rival_count,
		"next_boss_at": room.next_boss_at, "notice": room.notice, "notice_time": room.notice_time,
	}
	var payload = var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE)
	for id in peers:
		if id != 1 and peer_rooms[id] == number and peer.get_peer(id).get_ready_state() == WebSocketPeer.STATE_OPEN:
			receive_snapshot.rpc_id(id, peers[id], payload)

func unpack_entity(entity: RefCounted, data: Dictionary) -> void:
	for property in entity.get_script().get_script_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and data.has(property.name):
			entity.set(property.name, data[property.name])

@rpc("authority", "call_remote", "unreliable")
func receive_snapshot(actor_id: int, payload: PackedByteArray) -> void:
	if hosting or not active: return
	var state: Variant = bytes_to_var(payload.decompress_dynamic(4194304, FileAccess.COMPRESSION_DEFLATE))
	if not state is Dictionary: return
	room_id = int(state.room_id)
	human_count = int(state.human_count)
	capacity = int(state.capacity)
	arena.room_label = "SALA %d · %d humanos + %d bots" % [room_id, human_count, capacity - human_count]
	var previous_player = arena.player
	var first = not arena.networked
	arena.networked = true
	last_snapshot = Time.get_ticks_msec()
	arena.actors.clear()
	arena.boss = null
	for data in state.actors:
		var actor = FormaActor.new()
		unpack_entity(actor, data)
		arena.actors.append(actor)
		if actor.id == actor_id: arena.player = actor
		if actor.is_boss and actor.alive: arena.boss = actor
	arena.boss_spawned = arena.boss != null
	arena.orbs.clear()
	for data in state.orbs:
		var orb = FormaOrb.new()
		unpack_entity(orb, data)
		arena.orbs.append(orb)
	arena.shots.clear()
	for data in state.shots:
		var shot = FormaShot.new()
		unpack_entity(shot, data)
		arena.shots.append(shot)
	arena.hazards.clear()
	for data in state.hazards:
		var hazard = FormaHazard.new()
		unpack_entity(hazard, data)
		arena.hazards.append(hazard)
	arena.effects.clear()
	for data in state.effects:
		var effect = FormaEffect.new()
		unpack_entity(effect, data)
		arena.effects.append(effect)
	for key in ["elapsed", "threat", "encounters", "next_boss_at", "notice", "notice_time", "difficulty", "rival_count"]:
		arena.set(key, state[key])
	update_local_mode()
	if not first and previous_player != null and arena.player != null:
		if arena.player.hp < previous_player.hp: arena.sound_requested.emit("hit")
		if arena.player.attack_timer > previous_player.attack_timer: arena.sound_requested.emit("attack")
		if arena.player.skill_timer > previous_player.skill_timer: arena.sound_requested.emit("skill")
		if arena.player.dash_cooldown > previous_player.dash_cooldown: arena.sound_requested.emit("dash")
		if arena.player.level > previous_player.level: arena.sound_requested.emit("level")
	if first or (previous_player != null and arena.player != null and previous_player.id != arena.player.id):
		report("Conectado · sala automática · todos contra todos")
		entered.emit()

func update_local_mode() -> void:
	if arena.player == null: return
	if not arena.player.alive: arena.mode = "lost"
	elif local_pause: arena.mode = "paused"
	else: arena.mode = "playing"
