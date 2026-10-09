class_name FormaArena
extends Node

signal changed
signal sound_requested(cue: String)

const SIZE = Vector2(3600, 2800)
const NAMES = ["Nyx", "Orion", "Íris", "Atlas", "Lume", "Kael", "Vega", "Solis", "Flora", "Aster", "Rune", "Nox", "Lyra", "Oberon", "Elara", "Thorn"]
const UPGRADES = [
	{"title": "Poder primordial", "subtitle": "OFENSIVA", "body": "+20 de dano por segundo nos ataques básicos.", "kind": "power"},
	{"title": "Coração de pedra", "subtitle": "VITALIDADE", "body": "+35 de vida máxima e cura completa.", "kind": "health"},
	{"title": "Passos de vento", "subtitle": "MOBILIDADE", "body": "+12% de velocidade de movimento.", "kind": "speed"},
	{"title": "Ímã de essência", "subtitle": "EXPANSÃO", "body": "+55 px de alcance de coleta.", "kind": "magnet"},
	{"title": "Seiva eterna", "subtitle": "REGENERAÇÃO", "body": "Recupera 2,5 pontos de vida por segundo.", "kind": "regen"},
]

var networked: bool = false
var room_label: String = ""
var cooperative: bool = false
var rival_count: int = 16
var difficulty: int = 1
var threat: float = 1.0
var director_timer: float = 0.0
var rng = RandomNumberGenerator.new()
var actors: Array[FormaActor] = []
var orbs: Array[FormaOrb] = []
var shots: Array[FormaShot] = []
var effects: Array[FormaEffect] = []
var hazards: Array[FormaHazard] = []
var player: FormaActor
var mode: String = "menu"
var selected_class: int = 0
var elapsed: float = 0.0
var kills: int:
	get: return player.kills if player != null else 0
	set(value):
		if player != null: player.kills = value
var collected: int:
	get: return player.collected if player != null else 0
	set(value):
		if player != null: player.collected = value
var next_level_mass: float:
	get: return player.next_level_mass if player != null else 55.0
	set(value):
		if player != null: player.next_level_mass = value
var upgrade_options: Array[int]:
	get: return player.upgrade_options if player != null else []
	set(value):
		if player != null: player.upgrade_options = value
var pending_upgrades: int:
	get: return player.pending_upgrades if player != null else 0
	set(value):
		if player != null: player.pending_upgrades = value
var boss_spawned: bool = false
var boss: FormaActor
var boss_bag: Array[int] = []
var last_boss_kind: int = -1
var next_boss_at: float = 120.0
var encounters: int = 0
var boss_kills: int:
	get: return player.boss_kills if player != null else 0
	set(value):
		if player != null: player.boss_kills = value
var best_boss_kills: int = 0
var mouse_move: bool = false
var auto_attack: bool = false
var move_input: Vector2 = Vector2.ZERO
var aim_point: Vector2 = Vector2.ZERO
var attack_held: bool = false
var spawn_timer: float = 0.0
var notice: String = ""
var notice_time: float = 0.0
# "neutral", "progress" (gold) or "boss" (the live boss color).
var notice_tone: String = "neutral"
var next_id: int = 0
var best_mass: int = 0
var best_kills: int = 0
var last_attacker: String:
	get: return player.last_attacker if player != null else ""
	set(value):
		if player != null: player.last_attacker = value

func _ready() -> void:
	rng.randomize()
	load_record()

func new_run(kind: int) -> void:
	actors.clear()
	orbs.clear()
	shots.clear()
	effects.clear()
	hazards.clear()
	boss_bag.clear()
	last_boss_kind = -1
	next_boss_at = rng.randf_range(90, 150)
	encounters = 0
	boss_kills = 0
	selected_class = kind
	elapsed = 0
	threat = 1.0
	director_timer = 0.0
	kills = 0
	collected = 0
	spawn_timer = 0
	next_level_mass = 55
	pending_upgrades = 0
	boss_spawned = false
	boss = null
	next_id = 0
	attack_held = false
	move_input = Vector2.ZERO
	player = add_actor(kind, SIZE / 2.0, "Você", true)
	player.shield_timer = 3.0
	aim_point = player.pos + Vector2.RIGHT * 100
	for i in range(600):
		add_orb(random_point(), rng.randf_range(1.4, 3.4))
	# A small, readable trail gives every class a safe first level.
	for i in range(20):
		add_orb(player.pos + Vector2.from_angle(i * 0.9) * (65 + i * 10), 3.0)
	for i in range(rival_count):
		spawn_rival()
	mode = "playing"
	announce("Absorva essência. Cresça. Encontre seu poder.")
	changed.emit()

func add_actor(kind: int, point: Vector2, title: String, human: bool = false) -> FormaActor:
	var actor = FormaActor.new()
	actor.setup(next_id, kind, point, title, human)
	next_id += 1
	actors.append(actor)
	return actor

func random_point() -> Vector2:
	return Vector2(rng.randf_range(80, SIZE.x - 80), rng.randf_range(80, SIZE.y - 80))

func spawn_rival() -> void:
	var point = random_point()
	for attempt in range(20):
		if safe_spawn(point):
			break
		point = random_point()
	var rival = add_actor(rng.randi_range(0, 4), point, NAMES[rng.randi_range(0, NAMES.size() - 1)])
	rival.mass = rng.randf_range(15, 75)
	FormaDirector.equip_rival(self, rival)
	# Rival levels follow the same gradual curve as the director. Using mass / 65
	# made a late elite reach hundreds of levels and deal instant-kill damage.
	rival.level = 1 + int(sqrt(rival.mass / 40.0))
	rival.max_hp += rival.level * rival.growth()
	rival.hp = rival.max_hp
	rival.skill_timer = rng.randf_range(3, 10)

func add_orb(point: Vector2, amount: float) -> void:
	if orbs.size() >= 900:
		return
	orbs.append(FormaOrb.new(point.clamp(Vector2.ONE * 30, SIZE - Vector2.ONE * 30), amount, rng.randi_range(0, 4)))

func step(delta: float) -> void:
	if mode != "playing":
		return
	elapsed += delta
	FormaDirector.tick(self, delta)
	notice_time = maxf(0, notice_time - delta)
	for actor in actors:
		if not actor.alive:
			continue
		actor.attack_timer = maxf(0, actor.attack_timer - delta)
		actor.skill_timer = maxf(0, actor.skill_timer - delta)
		actor.shield_skill_timer = maxf(0, actor.shield_skill_timer - delta)
		actor.shield_skill_cooldown = maxf(0, actor.shield_skill_cooldown - delta)
		actor.dash_cooldown = maxf(0, actor.dash_cooldown - delta)
		actor.shield_timer = maxf(0, actor.shield_timer - delta)
		actor.slow_timer = maxf(0, actor.slow_timer - delta)
		actor.flash = maxf(0, actor.flash - delta)
		actor.phoenix_cooldown = maxf(0, actor.phoenix_cooldown - delta)
		actor.stun_timer = maxf(0, actor.stun_timer - delta)
		update_status(actor, delta)
		if not actor.alive:
			continue
		actor.hp = minf(actor.max_hp, actor.hp + (actor.regeneration + (0.65 if actor.class_id == 4 else 0.15)) * delta)
		if actor.is_player:
			move_human(actor, delta)
		elif actor.is_boss:
			FormaBossCombat.tick(self, actor, delta)
		else:
			move_bot(actor, delta)
		actor.pos = actor.pos.clamp(Vector2.ONE * actor.radius(), SIZE - Vector2.ONE * actor.radius())
	collect_orbs(delta)
	update_shots(delta)
	if mode != "playing":
		return
	update_effects(delta)
	if mode != "playing":
		return
	update_hazards(delta)
	if mode != "playing":
		return
	resolve_contacts(delta)
	actors = actors.filter(func(a: FormaActor) -> bool: return a.alive or a.is_player)
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = 1.0
		for i in range(mini(18, 620 - orbs.size())):
			add_orb(random_point(), rng.randf_range(1.4, 3.4))
		if actors.filter(func(a: FormaActor) -> bool: return not a.is_boss and not a.is_player).size() < rival_count:
			spawn_rival()
	if mode == "playing" and not boss_spawned and (elapsed >= next_boss_at or (encounters == 0 and FormaDirector.leading_mass(self) >= 500)):
		spawn_boss()

func safe_spawn(point: Vector2) -> bool:
	for actor in actors:
		if actor.is_player and actor.alive and point.distance_to(actor.pos) < 680:
			return false
	return true

func move_human(actor: FormaActor, delta: float) -> void:
	if actor.stun_timer > 0:
		return
	var direction = actor.input_direction if networked else move_input.limit_length()
	var aim = actor.input_aim if networked else aim_point
	if not networked and mouse_move and direction.length() < 0.1:
		var offset = aim - actor.pos
		direction = offset.normalized() * clampf((offset.length() - 25) / 100, 0, 1)
	if actor.pos.distance_to(aim) > 5:
		actor.aim = actor.pos.direction_to(aim)
	if actor.dash_timer > 0:
		actor.dash_timer -= delta
		actor.pos += actor.velocity * delta
	else:
		actor.velocity = direction * actor.speed()
		actor.pos += actor.velocity * delta
	if actor.input_attack if networked else (attack_held or auto_attack):
		attack(actor)

func allies(first: FormaActor, second: FormaActor) -> bool:
	return cooperative and first != null and second != null and first.is_player and second.is_player

func move_bot(actor: FormaActor, delta: float) -> void:
	if actor.stun_timer > 0:
		return
	actor.think_timer -= delta
	var target: FormaActor = null
	var distance: float = 900.0 if actor.elite else 450.0
	for other in actors:
		if other == actor or not other.alive or allies(actor, other):
			continue
		var d = actor.pos.distance_to(other.pos)
		if d < distance:
			target = other
			distance = d
	if target != null:
		actor.aim = actor.pos.direction_to(target.pos)
		var retreat = target.mass > actor.mass * 1.35 or actor.hp < actor.max_hp * 0.3
		if actor.elite:
			retreat = actor.hp < actor.max_hp * 0.18
		var range_limit: float = FormaClasses.DATA[actor.class_id].range
		if retreat:
			actor.destination = actor.pos - actor.aim * 300
		elif range_limit > 200 and distance < 235:
			actor.destination = actor.pos - actor.aim * 60 + actor.aim.orthogonal() * 85
		else:
			actor.destination = target.pos
		if distance < range_limit + target.radius():
			attack(actor)
		if distance < (270 if actor.class_id != 3 else 500) and elapsed > 10:
			use_skill(actor)
	elif actor.think_timer <= 0:
		actor.think_timer = rng.randf_range(0.4, 1.0)
		var nearest: float = INF
		for orb in orbs:
			var d = actor.pos.distance_squared_to(orb.pos)
			if d < nearest:
				nearest = d
				actor.destination = orb.pos
	if actor.dash_timer > 0:
		actor.dash_timer -= delta
		actor.pos += actor.velocity * delta
	else:
		actor.velocity = actor.pos.direction_to(actor.destination) * actor.speed() * (0.98 if actor.elite else 0.80)
		if actor.pos.distance_to(actor.destination) > 8:
			actor.pos += actor.velocity * delta

func collect_orbs(delta: float) -> void:
	for i in range(orbs.size() - 1, -1, -1):
		var orb = orbs[i]
		for actor in actors:
			if not actor.alive or actor.is_boss:
				continue
			var distance = actor.pos.distance_to(orb.pos)
			var bonus = actor.pickup_bonus + (140 if FormaBosses.Kind.VOID in actor.boons else 0)
			if distance < actor.radius() + 50 + bonus:
				orb.pos = orb.pos.move_toward(actor.pos, (150 + bonus * 2) * delta)
			if distance < actor.radius() + 5:
				gain_mass(actor, orb.value)
				orbs.remove_at(i)
				if actor.is_player:
					actor.collected += 1
					sound_requested.emit("collect")
				break

func gain_mass(actor: FormaActor, amount: float) -> void:
	var gained = amount
	if not actor.is_player:
		# Stop bots from snowballing far beyond the strongest human. Existing mass
		# is preserved; only future farming is limited by the catch-up ceiling.
		var leader = FormaDirector.leading_mass(self)
		var ceiling = leader * 1.25 + 40.0
		gained = minf(gained, maxf(0.0, ceiling - actor.mass))
	actor.mass += gained
	if not actor.is_player:
		return
	while actor.mass >= actor.next_level_mass:
		actor.level += 1
		actor.max_hp += actor.growth()
		actor.hp = minf(actor.max_hp, actor.hp + 25)
		actor.next_level_mass += FormaProgression.cost(actor.level)
		apply_random_upgrade(actor)

func attack(actor: FormaActor) -> void:
	if actor.attack_timer > 0 or actor.shield_skill_timer > 0 or not actor.alive or actor.stun_timer > 0 or actor.is_boss:
		return
	actor.attack_timer = FormaClasses.DATA[actor.class_id].rate
	if actor.is_player:
		sound_requested.emit("attack")
	if actor.class_id == 1 or actor.class_id == 2:
		var reach: float = float(FormaClasses.DATA[actor.class_id].range) + actor.radius() * 0.35
		add_effect(actor.pos + actor.aim * reach * 0.45, reach * 0.65, FormaPalette.CLASSES[actor.class_id], "slash", 0.22)
		for other in actors:
			if other == actor or not other.alive or allies(actor, other):
				continue
			var toward = other.pos - actor.pos
			if toward.length() < reach + other.radius() and actor.aim.dot(toward.normalized()) > 0.1:
				hurt(other, actor.damage(), actor)
				other.pos += actor.aim * 16
	else:
		fire_shot(actor, actor.aim, actor.damage())
	FormaBoonSystem.on_attack(self, actor)

func fire_shot(actor: FormaActor, direction: Vector2, damage_amount: float) -> FormaShot:
	if shots.size() >= 400:
		return null
	var shot = FormaShot.new()
	shot.pos = actor.pos + direction * (actor.radius() + 9)
	shot.velocity = direction * (720 if actor.class_id == 3 else 460)
	shot.ttl = float(FormaClasses.DATA[actor.class_id].range) / shot.velocity.length()
	shot.damage = damage_amount
	shot.owner_id = actor.id
	shot.class_id = actor.class_id
	shot.radius = 4.5 if actor.class_id == 3 else 8
	shots.append(shot)
	return shot

func use_skill(actor: FormaActor) -> bool:
	if mode != "playing" or actor.skill_timer > 0 or actor.shield_skill_timer > 0 or not actor.alive or actor.stun_timer > 0 or actor.is_boss:
		return false
	if actor.is_player:
		sound_requested.emit("skill")
	FormaSpells.cast(self, actor)
	FormaBoonSystem.on_skill(self, actor)
	return true

func use_shield(actor: FormaActor) -> bool:
	if mode != "playing" or actor.shield_skill_cooldown > 0 or not actor.alive or actor.stun_timer > 0 or actor.is_boss:
		return false
	actor.shield_skill_timer = 1.5
	actor.shield_skill_cooldown = 6.0
	actor.shield_timer = maxf(actor.shield_timer, actor.shield_skill_timer)
	add_effect(actor.pos, actor.radius() + 24, actor.tint(), "ring", actor.shield_skill_timer)
	if actor.is_player:
		sound_requested.emit("skill")
	return true

func dash(actor: FormaActor = null, direction: Vector2 = Vector2.ZERO) -> void:
	if actor == null:
		actor = player
		direction = move_input
	if mode != "playing" or actor.dash_cooldown > 0 or actor.stun_timer > 0:
		return
	actor.dash_cooldown = 4.0
	actor.dash_timer = 0.18
	actor.shield_timer = maxf(actor.shield_timer, 0.24)
	actor.velocity = (direction.normalized() if direction.length() > 0.1 else actor.aim) * 820
	add_effect(actor.pos, actor.radius() + 15, FormaPalette.CLASSES[actor.class_id], "ring", 0.35)
	sound_requested.emit("dash")

func update_shots(delta: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot = shots[i]
		if shot.ttl <= 0:
			shots.remove_at(i)
			continue
		var previous = shot.pos
		var target = actor_by_id(shot.target_id) if shot.homing > 0 else null
		if target != null and target.alive:
			var direction = shot.velocity.normalized().slerp(shot.pos.direction_to(target.pos), minf(1, shot.homing * delta))
			shot.velocity = direction * shot.velocity.length()
		shot.pos += shot.velocity * delta
		shot.ttl -= delta
		for actor in actors:
			if not actor.alive or actor.id == shot.owner_id or actor.id in shot.hit_ids or allies(actor, actor_by_id(shot.owner_id)):
				continue
			var closest = Geometry2D.get_closest_point_to_segment(actor.pos, previous, shot.pos)
			if closest.distance_to(actor.pos) < actor.radius() + shot.radius:
				hurt(actor, shot.damage, actor_by_id(shot.owner_id))
				if shot.class_id == 4 and shot.boss_kind < 0:
					# Short enough that the Druid's cadence does not chain a permanent slow.
					actor.slow_timer = maxf(actor.slow_timer, 0.5)
				apply_status(actor, shot.status, shot.owner_id)
				if shot.burning: apply_status(actor, "burn", shot.owner_id)
				shot.hit_ids.append(actor.id)
				var color: Color = FormaBosses.DATA[shot.boss_kind].color if shot.boss_kind >= 0 else FormaPalette.CLASSES[shot.class_id]
				add_effect(shot.pos, 23, color, "ring", 0.25)
				if shot.pierce > 0:
					shot.pierce -= 1
				else:
					shot.ttl = 0
					break
		if shot.ttl <= 0:
			shots.remove_at(i)
		if mode != "playing":
			return

func apply_status(actor: FormaActor, status: String, source_id: int) -> void:
	if not actor.alive or actor.shield_timer > 0:
		return
	match status:
		"burn":
			actor.burn_timer = 3
			actor.burn_source = source_id
		"poison":
			actor.poison_timer = 4
			actor.poison_source = source_id
		"slow": actor.slow_timer = maxf(actor.slow_timer, 1.5)
		"stun": actor.stun_timer = maxf(actor.stun_timer, 0.3 if actor.is_boss else 0.7)

func update_status(actor: FormaActor, delta: float) -> void:
	if actor.burn_timer > 0:
		var tick_time = minf(delta, actor.burn_timer)
		actor.burn_timer = maxf(0, actor.burn_timer - delta)
		hurt(actor, 6 * tick_time, actor_by_id(actor.burn_source), false)
	if actor.poison_timer > 0 and actor.alive:
		var tick_time = minf(delta, actor.poison_timer)
		actor.poison_timer = maxf(0, actor.poison_timer - delta)
		hurt(actor, 4 * tick_time, actor_by_id(actor.poison_source), false)

func update_hazards(delta: float) -> void:
	for field in hazards.duplicate():
		var owner = actor_by_id(field.owner_id)
		if owner == null or not owner.alive:
			hazards.erase(field)
			continue
		var active_delta = delta
		if field.warning > 0:
			active_delta = maxf(0, delta - field.warning)
			field.warning = maxf(0, field.warning - delta)
			if active_delta <= 0:
				continue
		active_delta = minf(active_delta, field.active_time)
		field.active_time -= active_delta
		for actor in actors:
			if actor.id == field.owner_id or not actor.alive or actor.is_boss or not field.contains(actor.pos, actor.radius() * 0.7):
				continue
			if not field.continuous and actor.id in field.hit_ids:
				continue
			if not field.continuous:
				field.hit_ids.append(actor.id)
			hurt(actor, field.damage * (active_delta if field.continuous else 1.0), owner, not field.continuous)
			apply_status(actor, field.status, field.owner_id)
			if field.pull > 0 and actor.alive and actor.shield_timer <= 0:
				actor.pos = actor.pos.move_toward(field.pos, field.pull * active_delta)
		if field.active_time <= 0:
			hazards.erase(field)
		if mode != "playing":
			return

func update_effects(delta: float) -> void:
	# Snapshot: damage can append new floating text effects.
	for effect in effects.duplicate():
		effect.ttl -= delta
		effect.pos += effect.velocity * delta
		var owner = actor_by_id(effect.owner_id)
		if effect.owner_id >= 0 and (owner == null or not owner.alive):
			effects.erase(effect)
			continue
		if effect.pulses > 0:
			effect.pulse_timer -= delta
			if effect.pulse_timer <= 0:
				effect.pulse_timer += 0.65
				effect.pulses -= 1
				FormaSpells.burst(self, owner, effect.pos, effect.radius, effect.damage)
				if owner.pos.distance_to(effect.pos) <= effect.radius:
					owner.hp = minf(owner.max_hp, owner.hp + effect.healing)
		if effect.kind == "grove":
			effect.pulse_timer -= delta
			var root_tick = effect.pulse_timer <= 0
			if root_tick: effect.pulse_timer = 1.5
			for actor in actors:
				if not actor.alive or actor.pos.distance_to(effect.pos) > effect.radius + actor.radius():
					continue
				if actor.id == effect.owner_id:
					actor.hp = minf(actor.max_hp, actor.hp + effect.healing * delta)
				elif not allies(actor, owner):
					actor.slow_timer = 0.3
					hurt(actor, effect.damage * delta, owner, false)
					apply_status(actor, effect.status, effect.owner_id)
					if effect.rooted and root_tick: apply_status(actor, "stun", effect.owner_id)
		if effect.ttl <= 0:
			effects.erase(effect)

func resolve_contacts(delta: float) -> void:
	for i in range(actors.size()):
		var first = actors[i]
		if not first.alive:
			continue
		for j in range(i + 1, actors.size()):
			var second = actors[j]
			if not second.alive:
				continue
			var distance = first.pos.distance_to(second.pos)
			if distance > first.radius() + second.radius():
				continue
			var big = first if first.mass >= second.mass else second
			var small = second if big == first else first
			if can_absorb(big, small) and distance < big.radius():
				defeat(small, big, true)
				if not first.alive:
					break
			else:
				var normal = first.pos.direction_to(second.pos)
				if normal == Vector2.ZERO:
					normal = Vector2.RIGHT
				var overlap = first.radius() + second.radius() - distance
				first.pos -= normal * overlap * delta * 3
				second.pos += normal * overlap * delta * 3

func can_absorb(big: FormaActor, small: FormaActor) -> bool:
	if allies(big, small) or big.is_boss or small.is_boss or small.shield_timer > 0:
		return false
	# New players need time to learn the arena before size differences become
	# lethal. A player must survive the first minute, reach 100 mass, and be
	# critically wounded before a rival can absorb them.
	if small.is_player:
		if elapsed < 60.0 or small.mass < 100.0 or small.hp >= small.max_hp * 0.25:
			return false
		return big.mass > small.mass * 2.0
	return big.mass > small.mass * 1.45 and (small.hp < small.max_hp * 0.45 or big.mass > small.mass * 2.2)

# Frontline classes must close the distance under fire: Paladin takes 18% less
# damage and Knight 12% less.
func class_reduction(actor: FormaActor) -> float:
	if actor.is_boss:
		return 1.0
	return 0.82 if actor.class_id == 1 else (0.88 if actor.class_id == 2 else 1.0)

func hurt(actor: FormaActor, amount: float, source: FormaActor, show_number: bool = true) -> void:
	if not actor.alive or actor.shield_timer > 0 or allies(actor, source):
		return
	var capped_amount = amount
	if actor.is_player and not actor.is_boss:
		# A single projectile or elite strike may not delete a player's full life.
		# Repeated hits remain dangerous, but every hit leaves room to react.
		capped_amount = minf(capped_amount, actor.max_hp * 0.45)
	var size_reduction = 1.0
	if not actor.is_boss:
		# Growth now also improves durability. The visible radius is used so the
		# mitigation follows the character's actual size, with a 45% floor.
		size_reduction = clampf(1.0 - maxf(0.0, actor.radius() - 25.0) * 0.008, 0.55, 1.0)
	var reduction = size_reduction * class_reduction(actor) * (0.78 if FormaBosses.Kind.GOLEM in actor.boons else 1.0)
	var actual_damage = minf(actor.hp, capped_amount * reduction)
	actor.hp -= capped_amount * reduction
	FormaBoonSystem.on_hit(self, actor, source, actual_damage, show_number)
	actor.flash = 0.12
	if show_number:
		var effect = add_effect(actor.pos - Vector2(0, actor.radius()), 1, FormaPalette.TEXT, "text", 0.7)
		effect.label = str(int(capped_amount))
		effect.target_id = actor.id
		effect.velocity = Vector2(0, -45)
	if actor.is_player and show_number:
		sound_requested.emit("hit")
	if actor.hp <= 0:
		if actor.is_boss and actor.boss_kind == FormaBosses.Kind.PHOENIX and not actor.boss_reborn:
			actor.boss_reborn = true
			actor.hp = actor.max_hp * 0.35
			actor.shield_timer = 1.6
			FormaBossCombat.hazard(self, actor, actor.pos, 230, 35, 1.6, 0.5, Vector2.INF, "burn")
			announce("A Fênix renasceu das cinzas", 4, "boss")
			return
		if FormaBoonSystem.prevent_death(self, actor):
			return
		defeat(actor, source)

func defeat(actor: FormaActor, source: FormaActor, absorbed: bool = false) -> void:
	if not actor.alive:
		return
	actor.alive = false
	# Only mass is loot. Boons are owned by this life and are never copied.
	FormaBoonSystem.clear(actor)
	add_effect(actor.pos, actor.radius() * 2.0, actor.tint(), "nova", 0.8)
	if source != null and source.alive:
		gain_mass(source, kill_loot(source, actor, absorbed))
		if source.is_player and not actor.is_boss:
			source.kills += 1
			announce(("Absorvido · " if absorbed else "Rival derrotado · ") + actor.label)
			sound_requested.emit("kill")
	for i in range(12):
		add_orb(actor.pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 70), minf(actor.mass * 0.035, 30.0))
	if actor.is_player:
		actor.last_attacker = source.label if source != null else "a arena"
		actor.upgrade_options.clear()
		actor.pending_upgrades = 0
		if not networked:
			finish()
	elif actor.is_boss:
		boss_spawned = false
		boss = null
		next_boss_at = elapsed + rng.randf_range(35, 65) / minf(2.2, sqrt(threat))
		hazards = hazards.filter(func(h: FormaHazard) -> bool: return h.owner_id != actor.id)
		# Mark, rather than erase, shots because defeat may run inside their update.
		for shot in shots:
			if shot.owner_id == actor.id:
				shot.ttl = 0
		if source != null and source.alive and not source.is_boss:
			var earned = FormaBoonSystem.grant(source, actor.boss_kind)
			if source.is_player:
				source.boss_kills += 1
				save_record()
			var reward: String = FormaBosses.DATA[actor.boss_kind].boon
			announce("%s conquistou %s%s" % [source.label, reward, "" if earned else " · cura de 30% (já possui)"], 7, "progress")
			sound_requested.emit("level")
		changed.emit()

# Reinforcements enter scaled to the leader's mass, so uncapped kill loot fed an
# exponential snowball. A kill is worth at most half of the killer's current
# level (a full level when absorbing); farming and fights stay the main sources.
func kill_loot(source: FormaActor, victim: FormaActor, absorbed: bool) -> float:
	var share = victim.mass * (0.65 if absorbed else 0.35)
	return minf(share, FormaProgression.cost(source.level) * (1.0 if absorbed else 0.5))

func add_effect(point: Vector2, size: float, color: Color, kind: String, duration: float) -> FormaEffect:
	var effect = FormaEffect.new()
	effect.pos = point
	effect.radius = size
	effect.color = color
	effect.kind = kind
	effect.duration = duration
	effect.ttl = duration
	effects.append(effect)
	if effects.size() > 360:
		effects.pop_front()
	return effect

func actor_by_id(id: int) -> FormaActor:
	for actor in actors:
		if actor.id == id:
			return actor
	return null

func spawn_boss(forced_kind: int = -1) -> void:
	if boss != null and boss.alive:
		return
	var kind = forced_kind if forced_kind >= 0 and forced_kind < FormaBosses.DATA.size() else draw_boss_kind()
	var data = FormaBosses.DATA[kind]
	boss_spawned = true
	var point = random_point()
	for attempt in range(30):
		if safe_spawn(point):
			break
		point = random_point()
	boss = add_actor(0, point, data.name)
	boss.is_boss = true
	boss.boss_kind = kind
	boss.mass = 520 + encounters * 25
	boss.max_hp = float(data.hp) * (1.0 + encounters * 0.12)
	boss.hp = boss.max_hp
	boss.damage_multiplier = 1.0 + encounters * 0.045
	FormaDirector.equip_boss(self, boss)
	boss.level = 5
	boss.attack_timer = 2
	boss.skill_timer = 5
	encounters += 1
	announce("%s despertou · encontro %d!" % [data.name, encounters], 7, "boss")
	sound_requested.emit("skill")

func draw_boss_kind() -> int:
	if boss_bag.is_empty():
		for kind in range(FormaBosses.DATA.size()):
			boss_bag.append(kind)
	var index = rng.randi_range(0, boss_bag.size() - 1)
	if boss_bag.size() > 1 and boss_bag[index] == last_boss_kind:
		index = (index + 1) % boss_bag.size()
	last_boss_kind = boss_bag.pop_at(index)
	return last_boss_kind

func apply_random_upgrade(actor: FormaActor) -> void:
	if actor == null or not actor.alive:
		return
	apply_upgrade(actor, rng.randi_range(0, UPGRADES.size() - 1))

func apply_upgrade(actor: FormaActor, option: int) -> void:
	if actor == null or not actor.alive or option < 0 or option >= UPGRADES.size():
		return
	match UPGRADES[option].kind:
		"power": actor.damage_bonus += 10.0
		"health":
			actor.max_hp += 35
			actor.hp = actor.max_hp
		"speed": actor.speed_multiplier += 0.12
		"magnet": actor.pickup_bonus += 55
		"regen": actor.regeneration += 2.5
	actor.pending_upgrades = 0
	actor.upgrade_options.clear()
	if actor.is_player:
		announce("Melhoria automática · %s" % UPGRADES[option].title, 3.5, "progress")
		sound_requested.emit("level")
	changed.emit()

func announce(message: String, duration: float = 4.0, tone: String = "neutral") -> void:
	notice = message
	notice_time = duration
	notice_tone = tone

func finish() -> void:
	mode = "lost"
	save_record()
	changed.emit()

func save_record() -> void:
	if networked:
		return
	if player != null:
		best_mass = maxi(best_mass, int(player.mass))
		best_kills = maxi(best_kills, kills)
		best_boss_kills = maxi(best_boss_kills, boss_kills)
	var config = ConfigFile.new()
	config.set_value("records", "mass", best_mass)
	config.set_value("records", "kills", best_kills)
	config.set_value("records", "boss_kills", best_boss_kills)
	config.save("user://forma_records.cfg")

func load_record() -> void:
	var config = ConfigFile.new()
	if config.load("user://forma_records.cfg") == OK:
		best_mass = int(config.get_value("records", "mass", 0))
		best_kills = int(config.get_value("records", "kills", 0))
		best_boss_kills = int(config.get_value("records", "boss_kills", 0))

func leaderboard() -> Array[FormaActor]:
	var result: Array[FormaActor] = actors.filter(func(actor: FormaActor) -> bool: return actor.alive)
	result.sort_custom(func(a: FormaActor, b: FormaActor) -> bool: return a.mass > b.mass)
	return result

func toggle_pause() -> void:
	if mode == "playing":
		mode = "paused"
	elif mode == "paused":
		mode = "playing"
	changed.emit()
