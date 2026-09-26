extends Node

var failures: Array[String] = []
var checks: int = 0
var networks: Array[FormaNetwork] = []
var branches: Array[Node] = []
var simulate: bool = true

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func instance_branch(title: String) -> FormaNetwork:
	var branch = Node.new()
	branch.name = title
	add_child(branch)
	branches.append(branch)
	var api = SceneMultiplayer.new()
	get_tree().set_multiplayer(api, branch.get_path())
	var arena = preload("res://tests/test_arena.gd").new()
	arena.name = "Arena"
	branch.add_child(arena)
	arena.rival_count = 0
	var network = FormaNetwork.new()
	network.name = "Network"
	network.arena = arena
	branch.add_child(network)
	networks.append(network)
	return network

func _ready() -> void:
	var host = instance_branch("Server")
	var one = instance_branch("ClientOne")
	var two = instance_branch("ClientTwo")
	check(host.host(19080, 10, true) == OK, "Server binds WebSocket")
	await get_tree().create_timer(0.1).timeout
	check(host.arena.elapsed == 0, "Empty dedicated room waits for players")
	check(one.join_room("ws://127.0.0.1:19080", "Um", 0) == OK, "Client one opens")
	check(two.join_room("ws://127.0.0.1:19080", "Dois", 3) == OK, "Client two opens")
	await get_tree().create_timer(2).timeout
	check(host.peers.size() == 2, "Two independent clients registered")
	check(one.arena.networked and two.arena.networked, "Both receive snapshots")
	if one.arena.player == null or two.arena.player == null:
		failures.append("Missing player snapshot")
		finish()
		return
	check(one.arena.player.id != two.arena.player.id, "Each client owns a different actor")
	check(one.arena.player.class_id == 0 and two.arena.player.class_id == 3, "Selected classes synchronized")
	check(one.arena.player.label == "Um" and two.arena.player.label == "Dois", "Character names synchronized")
	check(host.arena.rival_count == 8 and host.arena.actors.size() == 10, "Two humans replace bots in a ten-seat room")
	var a = host.arena.actor_by_id(one.arena.player.id)
	var b = host.arena.actor_by_id(two.arena.player.id)
	var original = a.pos
	one.submit_input.rpc_id(1, Vector2(999, 0), original + Vector2(100, 0), false)
	await get_tree().create_timer(0.12).timeout
	check(a.input_direction.length() <= 1.0, "Server clamps movement input")
	check(a.pos.x > original.x, "Remote movement reaches server")
	one.command("skill")
	await get_tree().create_timer(0.12).timeout
	check(a.skill_timer > 0, "Remote skill executes authoritatively")
	host.arena.gain_mass(a, 45)
	await get_tree().create_timer(0.12).timeout
	check(one.arena.mode == "playing" and one.arena.pending_upgrades > 0 and two.arena.mode == "playing", "Upgrade recipient remains in live play")
	var move_before = a.pos
	one.submit_input.rpc_id(1, Vector2.LEFT, a.pos + Vector2.LEFT * 100, true)
	await get_tree().create_timer(0.12).timeout
	check(a.pos.x < move_before.x and a.attack_timer > 0, "Remote movement and attacks continue with pending upgrade")
	var time_before = host.arena.elapsed
	one.command("upgrade", 0)
	await get_tree().create_timer(0.12).timeout
	check(a.pending_upgrades == 0 and host.arena.elapsed > time_before, "Upgrade validates on live server")
	a.shield_timer = 0
	b.shield_timer = 0
	var hp = b.hp
	host.arena.hurt(b, 10, a)
	check(b.hp < hp, "Competitive humans damage each other")
	FormaBoonSystem.grant(a, FormaBosses.Kind.DRAGON)
	host.arena.defeat(a, b)
	await get_tree().create_timer(0.12).timeout
	check(one.arena.mode == "lost" and two.arena.mode == "playing", "One death does not end the room")
	check(a.boons.is_empty() and b.boons.is_empty(), "Death removes boons without transfer")
	one.command("respawn")
	await get_tree().create_timer(0.2).timeout
	check(one.arena.player.alive and one.arena.player.id != a.id, "Remote respawn creates a new life")
	check(one.arena.player.boons.is_empty(), "Respawn starts without boons")
	var extra: Array[FormaNetwork] = []
	for index in range(10):
		var client = instance_branch("Extra%d" % index)
		extra.append(client)
		client.join_room("ws://127.0.0.1:19080", "Rival%d" % index, index % 5)
	await get_tree().create_timer(1.0).timeout
	check(host.peers.size() == 12 and host.rooms.size() == 2, "Twelve clients automatically create two rooms")
	check(host.occupants(1) == 10 and host.occupants(2) == 2, "Matchmaking fills ten-seat room before opening another")
	for number in host.rooms:
		var room: FormaArena = host.rooms[number]
		check(room.actors.filter(func(actor: FormaActor) -> bool: return not actor.is_boss).size() == 10, "Room keeps exactly ten participants")
		check(room.rival_count == 10 - host.occupants(number), "Bots fill only vacant seats")
	var isolated = extra[9]
	check(isolated.room_id == 2 and isolated.human_count == 2, "Room metadata reaches second-room client")
	check(not isolated.arena.actors.any(func(actor: FormaActor) -> bool: return actor.label == "Um"), "Snapshots never leak players from another room")
	var remote_id = isolated.multiplayer.get_unique_id()
	var remote_room = host.room_for(remote_id)
	var remote_actor = remote_room.actor_by_id(host.peers[remote_id])
	remote_actor.level = 100
	remote_actor.skill_timer = 0
	isolated.command("skill")
	await get_tree().create_timer(0.15).timeout
	check(remote_actor.skill_timer > 0 and isolated.arena.player.level == 100, "Level-100 magic executes and syncs in second room")
	var first_room_time = host.arena.elapsed
	check(remote_room != host.arena and remote_room.elapsed < first_room_time, "Each room has independent simulation time")
	two.close()
	await get_tree().create_timer(0.15).timeout
	check(host.occupants(1) == 9 and host.arena.rival_count == 1, "Leaving human is immediately replaced by a bot")
	two.join_room("ws://127.0.0.1:19080", "Dois", 3)
	for attempt in range(30):
		if two.room_id == 1: break
		await get_tree().create_timer(0.1).timeout
	check(two.room_id == 1 and host.arena.rival_count == 0, "Reconnect uses vacant seat before creating room")
	for client in extra: client.close()
	two.close()
	one.close()
	await get_tree().create_timer(0.25).timeout
	check(host.peers.is_empty() and host.rooms.size() == 1 and host.arena.elapsed == 0 and host.arena.threat == 1, "Empty extra rooms are destroyed; base room resets")
	one.join_room("ws://127.0.0.1:19080", "Um", 0)
	await get_tree().create_timer(0.2).timeout
	host.close()
	await get_tree().create_timer(0.15).timeout
	check(not one.active and one.arena.mode == "menu", "Host shutdown returns client to menu")
	finish()

func _physics_process(delta: float) -> void:
	if not simulate: return
	for network in networks:
		# Clients are controlled explicitly in the assertions above.
		if network.hosting: network.tick(delta, Vector2.ZERO, Vector2.ZERO, false)

func finish() -> void:
	simulate = false
	for network in networks: network.close()
	print("FORMA NETWORK: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)
