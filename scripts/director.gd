class_name FormaDirector
extends RefCounted

# The director equips reinforcements, never refills a wounded enemy mid-fight.
static func leading_mass(arena: FormaArena) -> float:
	var mass = 20.0
	for actor in arena.actors:
		if actor.is_player and actor.alive:
			mass = maxf(mass, actor.mass)
	return mass

static func target_threat(arena: FormaArena) -> float:
	var power = 0.0
	for actor in arena.actors:
		if actor.is_player and actor.alive:
			power = maxf(power, (actor.level - 1) * 0.10 + maxf(0, actor.damage_multiplier - 1) * 0.65 + actor.boons.size() * 0.22)
	var farm = log(1.0 + maxf(0, leading_mass(arena) - 150) / 180.0) * 0.65
	return (1.0 + arena.elapsed / 210.0 + farm + power) * [1.0, 1.2, 1.5][arena.difficulty]

static func tick(arena: FormaArena, delta: float) -> void:
	# At most +0.07 threat/sec: a large loot pickup cannot instantly spike difficulty.
	arena.threat = move_toward(arena.threat, maxf(arena.threat, target_threat(arena)), delta * 0.07)
	arena.director_timer -= delta
	if arena.director_timer > 0:
		return
	arena.director_timer = 18.0
	# Rivals continue leveling from their own farm, even before they are replaced.
	for rival in arena.actors:
		if rival.is_player or rival.is_boss or not rival.alive:
			continue
		var level = 1 + int(sqrt(rival.mass / 40.0))
		if level > rival.level:
			rival.max_hp += (level - rival.level) * 8
			rival.level = level
	if arena.elapsed > 60 and arena.threat > 2:
		arena.announce("Ameaça %.1f · reforços mais fortes entram na arena" % arena.threat)

static func equip_rival(arena: FormaArena, rival: FormaActor) -> void:
	var pressure = maxf(0, arena.threat - 1)
	rival.elite = arena.elapsed > 45 and arena.rng.randf() < minf(0.5, pressure * 0.12)
	rival.threat_tier = arena.threat
	var farm_share = 0.8 if rival.elite else arena.rng.randf_range(0.18, 0.42)
	rival.mass += pressure * 28 + leading_mass(arena) * farm_share * minf(1, arena.elapsed / 90.0)
	rival.max_hp *= 1.0 + pressure * (0.65 if rival.elite else 0.3)
	rival.damage_multiplier = 1.0 + pressure * (0.24 if rival.elite else 0.14)
	rival.speed_multiplier = 1.0 + minf(0.28, pressure * 0.025)
	if rival.elite:
		rival.label = "Elite " + rival.label
		rival.shield_timer = 2.5

static func equip_boss(arena: FormaArena, boss: FormaActor) -> void:
	var humans = 0
	var peak_damage = 1.0
	for actor in arena.actors:
		if actor.is_player and actor.alive:
			humans += 1
			peak_damage = maxf(peak_damage, actor.damage_multiplier * (1 + (actor.level - 1) * 0.09))
	boss.threat_tier = arena.threat
	boss.max_hp *= (1 + (arena.threat - 1) * 0.4) * maxf(1, peak_damage * 0.6) * (1 + maxf(0, humans - 1) * 0.45)
	boss.hp = boss.max_hp
	boss.damage_multiplier *= 1 + (arena.threat - 1) * 0.18
