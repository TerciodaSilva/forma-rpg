class_name FormaBoonSystem
extends RefCounted

static func grant(actor: FormaActor, kind: int) -> bool:
	if not actor.alive or actor.is_boss or kind < 0 or kind >= FormaBosses.DATA.size():
		return false
	if kind in actor.boons:
		actor.hp = minf(actor.max_hp, actor.hp + actor.max_hp * 0.3)
		return false
	actor.boons.append(kind)
	return true

static func on_attack(arena: FormaArena, actor: FormaActor) -> void:
	actor.attack_count += 1
	if FormaBosses.Kind.HYDRA in actor.boons and actor.attack_count % 3 == 0:
		for side in [-1, 1]:
			var shot = arena.fire_shot(actor, actor.aim.rotated(side * 0.24), actor.damage() * 0.6)
			if shot != null:
				shot.ttl = 1.3
				shot.boss_kind = FormaBosses.Kind.HYDRA

static func on_hit(arena: FormaArena, target: FormaActor, source: FormaActor, actual_damage: float, direct: bool) -> void:
	if source == null or not source.alive or source.is_boss or source == target:
		return
	if FormaBosses.Kind.NECROMANCER in source.boons:
		source.hp = minf(source.max_hp, source.hp + actual_damage * 0.12)
	if not direct:
		return
	if FormaBosses.Kind.DRAGON in source.boons:
		arena.apply_status(target, "burn", source.id)
	if FormaBosses.Kind.KRAKEN in source.boons:
		arena.apply_status(target, "slow", source.id)
	if FormaBosses.Kind.BASILISK in source.boons:
		source.boon_hits += 1
		if source.boon_hits % 4 == 0:
			arena.apply_status(target, "stun", source.id)

static func on_skill(arena: FormaArena, actor: FormaActor) -> void:
	if FormaBosses.Kind.VOID in actor.boons:
		arena.add_effect(actor.pos, 380, FormaPalette.MAGE, "nova", 0.5)
		for other in arena.actors:
			if other != actor and other.alive and other.pos.distance_to(actor.pos) < 380 + other.radius():
				other.pos = other.pos.move_toward(actor.pos, 180)
				other.slow_timer = maxf(other.slow_timer, 1)
	if FormaBosses.Kind.UNICORN in actor.boons:
		actor.hp = minf(actor.max_hp, actor.hp + actor.max_hp * 0.08)
		actor.shield_timer = maxf(actor.shield_timer, 1.2)
	if FormaBosses.Kind.DJINN in actor.boons:
		for i in range(8):
			var shot = arena.fire_shot(actor, Vector2.from_angle(i * TAU / 8), actor.damage() * 0.7)
			if shot != null:
				shot.ttl = 1.4
				shot.boss_kind = FormaBosses.Kind.DJINN

static func prevent_death(arena: FormaArena, actor: FormaActor) -> bool:
	if FormaBosses.Kind.PHOENIX not in actor.boons or actor.phoenix_cooldown > 0:
		return false
	actor.hp = actor.max_hp * 0.25
	actor.phoenix_cooldown = 60
	actor.shield_timer = 2
	arena.add_effect(actor.pos, actor.radius() * 2, FormaPalette.GOLD, "nova", 0.9)
	if actor.is_player:
		arena.announce("Cinza imortal impediu o golpe fatal. Recarga: 60 s.")
	return true

static func clear(actor: FormaActor) -> void:
	actor.boons.clear()
	actor.phoenix_cooldown = 0
	actor.attack_count = 0
	actor.boon_hits = 0
