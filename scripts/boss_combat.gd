class_name FormaBossCombat
extends RefCounted

static func tick(arena: FormaArena, boss: FormaActor, delta: float) -> void:
	if boss.stun_timer > 0:
		return
	var target: FormaActor = null
	var nearest: float = INF
	for actor in arena.actors:
		if actor == boss or not actor.alive or actor.is_boss:
			continue
		var distance = boss.pos.distance_to(actor.pos)
		if distance < nearest:
			nearest = distance
			target = actor
	if target == null:
		return
	boss.aim = boss.pos.direction_to(target.pos)
	var movement = boss.aim if nearest > 300 else boss.aim.orthogonal() * 0.5
	boss.pos += movement * boss.speed() * delta
	if nearest > 950:
		return
	if boss.attack_timer <= 0:
		basic(arena, boss, target)
		boss.attack_timer = float(FormaBosses.DATA[boss.boss_kind].rate) / minf(1.65, 1 + (boss.threat_tier - 1) * 0.06)
	if boss.skill_timer <= 0:
		special(arena, boss, target)
		boss.skill_timer = float(FormaBosses.DATA[boss.boss_kind].skill_rate) / minf(1.6, 1 + (boss.threat_tier - 1) * 0.05)

static func projectile(arena: FormaArena, boss: FormaActor, direction: Vector2, speed: float, damage: float, status: String = "", target_id: int = -1, origin: Vector2 = Vector2.INF) -> void:
	if arena.shots.size() >= 400:
		return
	var shot = FormaShot.new()
	shot.pos = boss.pos + direction * (boss.radius() + 12) if origin == Vector2.INF else origin
	shot.velocity = direction * speed
	shot.ttl = 3.0
	shot.damage = damage * boss.damage_multiplier
	shot.owner_id = boss.id
	shot.class_id = 0
	shot.boss_kind = boss.boss_kind
	shot.radius = 9
	shot.status = status
	shot.target_id = target_id
	shot.homing = 1.5 if target_id >= 0 else 0
	arena.shots.append(shot)

static func hazard(arena: FormaArena, boss: FormaActor, pos: Vector2, radius: float, damage: float, warning: float = 1.0, duration: float = 0.35, end: Vector2 = Vector2.INF, status: String = "", continuous: bool = false, pull: float = 0.0) -> FormaHazard:
	var field = FormaHazard.new()
	field.owner_id = boss.id
	field.boss_kind = boss.boss_kind
	field.pos = pos
	field.radius = radius
	field.damage = damage * boss.damage_multiplier
	field.warning = warning
	field.warning_duration = warning
	field.active_time = duration
	field.duration = duration
	field.status = status
	field.continuous = continuous
	field.pull = pull
	if end != Vector2.INF:
		field.end = end
		field.shape = "line"
	if arena.hazards.size() < 64:
		arena.hazards.append(field)
	return field

static func basic(arena: FormaArena, boss: FormaActor, target: FormaActor) -> void:
	var aim = boss.pos.direction_to(target.pos)
	boss.boss_phase += 1
	match boss.boss_kind:
		FormaBosses.Kind.VOID:
			for i in range(10):
				projectile(arena, boss, Vector2.from_angle(i * TAU / 10 + boss.boss_phase * 0.22), 245, 15)
		FormaBosses.Kind.DRAGON:
			for i in range(5):
				projectile(arena, boss, aim.rotated((i - 2) * 0.15), 340 + i * 15, 17, "burn")
		FormaBosses.Kind.NECROMANCER:
			for i in range(3):
				projectile(arena, boss, aim.rotated((i - 1) * 0.65), 210, 19, "", target.id)
		FormaBosses.Kind.HYDRA:
			for i in range(3):
				var origin = boss.pos + Vector2((i - 1) * 58, -55)
				for j in range(2):
					projectile(arena, boss, origin.direction_to(target.pos).rotated((j - 0.5) * 0.12), 300 + i * 35, 13, "poison", -1, origin)
		FormaBosses.Kind.PHOENIX:
			for i in range(12):
				projectile(arena, boss, Vector2.from_angle(i * TAU / 12 + boss.boss_phase * 0.4), 260 + i % 3 * 45, 13, "burn")
		FormaBosses.Kind.GOLEM:
			hazard(arena, boss, target.pos, 110, 38, 1.2)
		FormaBosses.Kind.KRAKEN:
			for i in range(3):
				var direction = aim.rotated((i - 1) * 0.42)
				hazard(arena, boss, boss.pos + direction * 60, 19, 27, 1.0 + i * 0.15, 0.45, boss.pos + direction * 650, "slow")
		FormaBosses.Kind.BASILISK:
			for i in range(2):
				projectile(arena, boss, aim.rotated((i - 0.5) * 0.17), 420, 17, "poison")
		FormaBosses.Kind.UNICORN:
			hazard(arena, boss, boss.pos + aim * 60, 24, 34, 1.15, 0.45, boss.pos + aim * 880)
		FormaBosses.Kind.DJINN:
			for i in range(3):
				var point = target.pos + target.velocity.limit_length(150) * i * 0.35
				hazard(arena, boss, point, 65, 24, 0.85 + i * 0.35, 0.25)

static func special(arena: FormaArena, boss: FormaActor, target: FormaActor) -> void:
	var aim = boss.pos.direction_to(target.pos)
	if arena.player.pos.distance_to(boss.pos) < 900:
		arena.sound_requested.emit("skill")
	match boss.boss_kind:
		FormaBosses.Kind.VOID:
			hazard(arena, boss, target.pos, 185, 13, 1.3, 3.0, Vector2.INF, "slow", true, 90)
		FormaBosses.Kind.DRAGON:
			for i in range(4):
				hazard(arena, boss, boss.pos + aim * (140 + i * 120), 70, 14, 0.9 + i * 0.22, 3.5, Vector2.INF, "burn", true)
		FormaBosses.Kind.NECROMANCER:
			for i in range(5):
				var point = target.pos + Vector2.from_angle(i * TAU / 5) * 135
				hazard(arena, boss, point, 68, 31, 1.2 + i * 0.08, 0.5, Vector2.INF, "slow")
		FormaBosses.Kind.HYDRA:
			for i in range(3):
				var point = target.pos + Vector2.from_angle(i * TAU / 3) * 125
				hazard(arena, boss, point, 95, 10, 1.1, 4.0, Vector2.INF, "poison", true)
		FormaBosses.Kind.PHOENIX:
			hazard(arena, boss, boss.pos, 250, 40, 1.6, 0.6, Vector2.INF, "burn")
		FormaBosses.Kind.GOLEM:
			boss.shield_timer = 1.8
			for i in range(4):
				var direction = Vector2.from_angle(i * PI / 2 + aim.angle())
				hazard(arena, boss, boss.pos, 30, 36, 1.3, 0.5, boss.pos + direction * 570)
		FormaBosses.Kind.KRAKEN:
			hazard(arena, boss, target.pos, 180, 12, 1.2, 3.2, Vector2.INF, "slow", true)
		FormaBosses.Kind.BASILISK:
			# Two marked lanes leave a safe gap beside the gaze.
			for i in range(2):
				var origin = boss.pos + aim.orthogonal() * (i * 90 - 45)
				hazard(arena, boss, origin, 24, 22, 1.4, 0.4, origin + aim * 720, "stun")
		FormaBosses.Kind.UNICORN:
			for i in range(6):
				var point = target.pos + Vector2.from_angle(i * TAU / 6) * 160
				hazard(arena, boss, point, 65, 29, 1.1 + i * 0.13, 0.4)
		FormaBosses.Kind.DJINN:
			var old_pos = boss.pos
			boss.pos = (target.pos - aim * 260 + aim.orthogonal() * 200).clamp(Vector2.ONE * 140, FormaArena.SIZE - Vector2.ONE * 140)
			arena.add_effect(old_pos, 95, boss.tint(), "nova", 0.5)
			hazard(arena, boss, boss.pos, 145, 32, 1.1, 0.35)
			for i in range(8):
				projectile(arena, boss, Vector2.from_angle(i * TAU / 8), 210, 11, "slow")
