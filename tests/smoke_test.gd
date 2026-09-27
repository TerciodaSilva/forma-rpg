extends Node

var checks: int = 0
var failures: Array[String] = []
var arena: FormaArena

func _ready() -> void:
	arena = preload("res://tests/test_arena.gd").new()
	add_child(arena)
	arena.rng.seed = 42
	test_responsive_layout()
	test_progressive_cost()
	test_director()
	test_classes()
	test_shield_skill()
	test_spell_evolutions()
	test_absorption()
	test_progression()
	test_lifecycle()
	test_boss_roster()
	test_boss_attacks()
	test_boon_effects()
	test_boon_ownership()
	test_endless_encounters()
	test_bestiary_controls()
	if not "--quick" in OS.get_cmdline_user_args():
		test_simulation()
	await get_tree().process_frame
	print("FORMA: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func clean_run(kind: int) -> FormaActor:
	arena.new_run(kind)
	arena.actors = [arena.player]
	arena.orbs.clear()
	arena.player.shield_timer = 0
	var enemy = arena.add_actor(2, arena.player.pos + Vector2(80, 0), "Alvo")
	enemy.max_hp = 1000
	enemy.hp = 1000
	enemy.mass = 15
	arena.player.aim = Vector2.RIGHT
	return enemy

func test_classes() -> void:
	for kind in range(5):
		var enemy = clean_run(kind)
		var player = arena.player
		check(player.class_id == kind and player.max_hp == FormaClasses.DATA[kind].hp, "Class setup %d" % kind)
		arena.attack(player)
		if kind in [1, 2]:
			check(enemy.hp < 1000, "Melee attack %d" % kind)
		else:
			check(arena.shots.size() == 1, "Projectile spawned %d" % kind)
			arena.update_shots(0.2)
			check(enemy.hp < 1000, "Swept projectile hit %d" % kind)
		var shot_count = arena.shots.size()
		var hp_before = enemy.hp
		arena.attack(player)
		check(arena.shots.size() == shot_count and enemy.hp == hp_before, "Attack cooldown %d" % kind)
		player.hp = player.max_hp * 0.5
		check(arena.use_skill(player), "Skill activates %d" % kind)
		check(not arena.use_skill(player), "Skill cooldown %d" % kind)
		match kind:
			0: check(enemy.hp < hp_before, "Mage nova damages")
			1:
				check(player.hp > player.max_hp * 0.5, "Paladin heals")
				var hp = player.hp
				arena.hurt(player, 500, enemy)
				check(player.hp == hp, "Paladin shield blocks damage")
			2: check(enemy.hp < hp_before and player.dash_timer > 0, "Knight charge damages and moves")
			3: check(arena.shots.size() >= 7, "Archer seven arrow fan")
			4:
				arena.update_effects(0.1)
				check(player.hp > player.max_hp * 0.5 and enemy.hp < hp_before and enemy.slow_timer > 0, "Druid grove heals, damages, slows")

func test_shield_skill() -> void:
	for kind in range(5):
		var enemy = clean_run(kind)
		var player = arena.player
		player.shield_skill_cooldown = 0
		player.aim = Vector2.RIGHT
		var enemy_hp = enemy.hp
		var shot_count = arena.shots.size()
		check(arena.use_shield(player), "Shield activates for class %d" % kind)
		check(player.shield_skill_timer > 0 and player.shield_timer > 0, "Shield grants brief invulnerability %d" % kind)
		var hp = player.hp
		arena.hurt(player, 999, enemy, false)
		check(player.hp == hp, "Shield blocks damage %d" % kind)
		arena.attack(player)
		check(enemy.hp == enemy_hp and arena.shots.size() == shot_count, "Shield blocks attacks %d" % kind)
		check(not arena.use_skill(player), "Shield blocks offensive skill %d" % kind)
		arena.step(1.6)
		check(player.shield_skill_timer == 0 and not arena.use_shield(player), "Shield cooldown starts after protection %d" % kind)

func test_absorption() -> void:
	var enemy = clean_run(0)
	var player = arena.player
	player.hp = player.max_hp
	player.mass = 20
	arena.hurt(player, 10, enemy, false)
	var small_damage = player.max_hp - player.hp
	player.hp = player.max_hp
	player.mass = 400
	arena.hurt(player, 10, enemy, false)
	var large_damage = player.max_hp - player.hp
	check(large_damage < small_damage, "Larger characters take less damage")
	player.mass = 100
	enemy.mass = 60
	check(not arena.can_absorb(player, enemy), "Healthy near-size rival resists absorption")
	enemy.hp = 200
	check(arena.can_absorb(player, enemy), "Weakened smaller rival can be absorbed")
	enemy.shield_timer = 1
	check(not arena.can_absorb(player, enemy), "Shield prevents absorption")
	enemy.shield_timer = 0
	enemy.mass = 30
	enemy.hp = 1000
	check(arena.can_absorb(player, enemy), "Large size advantage absorbs healthy rival")
	player.mass = 30
	enemy.mass = 90
	player.hp = player.max_hp
	check(not arena.can_absorb(enemy, player), "Healthy player cannot be instantly absorbed")
	player.hp = player.max_hp * 0.2
	check(not arena.can_absorb(enemy, player), "New player is protected from early absorption")
	arena.elapsed = 60
	player.mass = 100
	enemy.mass = 190
	check(arena.can_absorb(enemy, player) == false, "Wounded player needs a stronger size advantage")
	enemy.mass = 201
	check(arena.can_absorb(enemy, player), "Critically wounded developed player can be absorbed")
	player.hp = player.max_hp
	player.mass = 100
	enemy.mass = 30
	enemy.pos = player.pos
	arena.resolve_contacts(0.016)
	check(not enemy.alive and arena.kills == 1 and player.mass > 100, "Absorption grants mass and kill")

func test_progression() -> void:
	clean_run(4)
	var radius_before = arena.player.radius()
	var speed_before = arena.player.speed()
	arena.add_orb(arena.player.pos, 40)
	arena.collect_orbs(0.1)
	check(arena.collected == 1 and arena.player.mass == 60, "Orb collects and adds mass")
	check(arena.player.radius() > radius_before and (arena.player.speed() < speed_before or arena.player.speed_multiplier > 1.0), "Growth increases radius and preserves speed balance")
	check(arena.player.level == 2 and arena.pending_upgrades == 0 and arena.upgrade_options.is_empty(), "Level milestone applies an automatic upgrade")
	check(arena.player.damage_bonus > 0 or arena.player.max_hp > FormaClasses.DATA[arena.player.class_id].hp or arena.player.speed_multiplier > 1.0 or arena.player.pickup_bonus > 0 or arena.player.regeneration > 0, "Automatic upgrade changes a visible stat")
	var elapsed = arena.elapsed
	arena.actors = [arena.player] # Isolate input from enemy knockback.
	var position_before = arena.player.pos
	arena.move_input = Vector2.RIGHT
	arena.attack_held = true
	arena.player.shield_timer = 10
	arena.step(0.05)
	check(arena.elapsed > elapsed and arena.mode == "playing", "Automatic upgrade does not pause simulation")
	check(arena.player.pos.x > position_before.x and arena.player.attack_timer > 0, "Movement and attacks remain active after automatic upgrade")
	check(arena.use_skill(arena.player), "Skills remain available after automatic upgrade")
	arena.dash()
	check(arena.player.dash_cooldown > 0, "Dash remains available after automatic upgrade")
	for i in range(5):
		arena.mode = "playing"
		arena.apply_upgrade(arena.player, i)
	check(arena.player.damage_bonus >= 10 and arena.player.max_hp > 130 and arena.player.speed_multiplier > 1 and arena.player.pickup_bonus >= 55 and arena.player.regeneration >= 2.5, "All five upgrades affect stats")

func test_lifecycle() -> void:
	var enemy = clean_run(0)
	arena.toggle_pause()
	arena.step(1)
	check(arena.mode == "paused" and arena.elapsed == 0, "Pause freezes simulation")
	arena.toggle_pause()
	arena.dash()
	check(arena.player.dash_timer > 0 and arena.player.dash_cooldown > 0, "Dodge activates with cooldown")
	arena.player.shield_timer = 0
	arena.hurt(arena.player, 999, enemy)
	check(arena.mode == "lost" and not arena.player.alive, "Death opens defeat screen")
	arena.new_run(3)
	check(arena.mode == "playing" and arena.kills == 0 and arena.player.alive and arena.player.class_id == 3, "Restart resets run")
	arena.spawn_boss(0)
	check(arena.boss.is_boss and not arena.can_absorb(arena.player, arena.boss), "Boss spawns and cannot be absorbed")
	arena.hurt(arena.boss, 9999, arena.player)
	check(arena.mode == "playing" and arena.boss_kills == 1 and 0 in arena.player.boons, "Boss defeat grants boon and continues run")

func test_simulation() -> void:
	arena.new_run(3)
	arena.player.shield_timer = 9999
	arena.auto_attack = true
	for frame in range(5400):
		arena.move_input = Vector2.from_angle(frame * 0.004)
		arena.aim_point = arena.player.pos + arena.move_input * 300
		arena.step(1.0 / 30.0)
	check(arena.elapsed > 179, "Three minute simulation completes")
	check(arena.encounters >= 1 and (arena.boss_spawned or arena.next_boss_at > arena.elapsed), "Timed boss spawns or has been defeated with another encounter scheduled")
	check(arena.actors.size() >= 2 and arena.actors.size() <= arena.rival_count + 2, "Rival population stays bounded while dead rivals await respawn")
	check(arena.orbs.size() <= 900 and arena.shots.size() < 180 and arena.effects.size() < 150, "Transient entities stay bounded")
	check(arena.player.pos.is_finite() and arena.player.hp > 0, "Simulation values remain valid")

func test_boss_roster() -> void:
	arena.new_run(0)
	check(FormaBosses.DATA.size() == 10, "Ten mystical bosses")
	var previous = -1
	for cycle in range(3):
		var seen: Array[int] = []
		for i in range(10):
			var kind = arena.draw_boss_kind()
			check(kind not in seen and kind != previous, "Random roster no repeat within cycle or at boundary")
			seen.append(kind)
			previous = kind
		check(seen.size() == 10, "Full roster available each cycle")

func test_boss_attacks() -> void:
	for kind in range(10):
		clean_run(0)
		arena.actors = [arena.player]
		arena.player.hp = 10000
		arena.player.max_hp = 10000
		arena.spawn_boss(kind)
		var boss = arena.boss
		boss.pos = arena.player.pos + Vector2(300, 0)
		FormaBossCombat.basic(arena, boss, arena.player)
		check(not arena.shots.is_empty() or not arena.hazards.is_empty(), "Boss basic attack %d" % kind)
		for shot in arena.shots:
			check(shot.boss_kind == kind and shot.owner_id == boss.id and shot.damage > 0, "Boss projectile attribution %d" % kind)
		if kind == FormaBosses.Kind.NECROMANCER:
			check(arena.shots.all(func(shot: FormaShot) -> bool: return shot.homing > 0), "Necromancer souls home")
		arena.hazards.clear()
		FormaBossCombat.special(arena, boss, arena.player)
		check(not arena.hazards.is_empty(), "Boss unique special creates telegraph %d" % kind)
		var field = arena.hazards[0]
		arena.hazards = [field]
		arena.player.pos = field.pos
		var hp = arena.player.hp
		arena.update_hazards(0.1)
		check(arena.player.hp == hp, "Telegraph grants time to dodge %d" % kind)
		arena.update_hazards(1.7)
		check(arena.player.hp < hp, "Boss special deals damage after warning %d" % kind)
		arena.hazards.clear()
		arena.shots.clear()
		boss.shield_timer = 0
		arena.hurt(boss, boss.max_hp * 10, arena.player)
		if kind == FormaBosses.Kind.PHOENIX:
			check(boss.alive and boss.boss_reborn and arena.boss_kills == 0, "Phoenix has one rebirth before reward")
			boss.shield_timer = 0
			arena.hurt(boss, boss.max_hp * 10, arena.player)
		check(not boss.alive and kind in arena.player.boons and arena.mode == "playing", "Each boss grants its own boon without ending run %d" % kind)
		check(arena.hazards.is_empty(), "Boss death cleans hazards %d" % kind)

func test_boon_effects() -> void:
	var enemy = clean_run(0)
	var player = arena.player
	FormaBoonSystem.grant(player, FormaBosses.Kind.VOID)
	enemy.pos = player.pos + Vector2(220, 0)
	var distance = player.pos.distance_to(enemy.pos)
	arena.use_skill(player)
	check(player.pos.distance_to(enemy.pos) < distance, "Void boon pulls after skill")
	arena.orbs.clear()
	arena.add_orb(player.pos - Vector2(180, 0), 2)
	var orb_before = arena.orbs[0].pos
	arena.collect_orbs(0.1)
	check(arena.orbs[0].pos.distance_to(player.pos) < orb_before.distance_to(player.pos), "Void boon expands pickup")
	FormaBoonSystem.grant(player, FormaBosses.Kind.DRAGON)
	arena.hurt(enemy, 10, player)
	var hp = enemy.hp
	arena.update_status(enemy, 1)
	check(enemy.burn_timer > 0 and enemy.hp < hp, "Dragon boon burns over time")
	FormaBoonSystem.grant(player, FormaBosses.Kind.NECROMANCER)
	player.hp = 40
	arena.hurt(enemy, 10, player)
	check(is_equal_approx(player.hp, 41.2), "Necromancer boon lifesteals actual damage")
	FormaBoonSystem.grant(player, FormaBosses.Kind.HYDRA)
	arena.shots.clear()
	player.attack_count = 0
	for i in range(3):
		player.attack_timer = 0
		arena.attack(player)
	check(arena.shots.size() == 5, "Hydra boon adds exactly two shots every third attack")
	FormaBoonSystem.grant(player, FormaBosses.Kind.GOLEM)
	hp = player.hp
	arena.hurt(player, 10, enemy)
	check(hp - player.hp < 7.8 and hp - player.hp > 0, "Golem boon reduces incoming damage")
	FormaBoonSystem.grant(player, FormaBosses.Kind.KRAKEN)
	arena.hurt(enemy, 1, player)
	check(enemy.slow_timer >= 1.5, "Kraken boon slows on hit")
	FormaBoonSystem.grant(player, FormaBosses.Kind.BASILISK)
	player.boon_hits = 0
	for i in range(4):
		arena.hurt(enemy, 1, player)
	check(enemy.stun_timer > 0 and enemy.speed() == 0, "Basilisk boon petrifies fourth hit")
	FormaBoonSystem.grant(player, FormaBosses.Kind.UNICORN)
	player.skill_timer = 0
	hp = player.hp
	arena.use_skill(player)
	check(player.hp > hp and player.shield_timer >= 1.2, "Unicorn boon heals and shields after skill")
	FormaBoonSystem.grant(player, FormaBosses.Kind.DJINN)
	arena.shots.clear()
	player.skill_timer = 0
	arena.use_skill(player)
	check(arena.shots.size() == 8, "Djinn boon adds eight bolts to skill")
	FormaBoonSystem.grant(player, FormaBosses.Kind.PHOENIX)
	player.shield_timer = 0
	arena.hurt(player, 999, enemy)
	check(player.alive and player.phoenix_cooldown == 60 and player.hp > 0, "Phoenix boon prevents lethal hit")
	player.shield_timer = 0
	arena.hurt(player, 999, enemy)
	check(not player.alive and player.boons.is_empty() and enemy.boons.is_empty(), "Phoenix cooldown permits death and all boons expire without transfer")

func test_boon_ownership() -> void:
	var rival = clean_run(1)
	arena.spawn_boss(6)
	var boss = arena.boss
	arena.hurt(boss, 9999, rival)
	check(6 in rival.boons and arena.player.boons.is_empty() and arena.boss_kills == 0, "AI final blow owns boon exclusively")
	arena.defeat(rival, arena.player, true)
	check(rival.boons.is_empty() and arena.player.boons.is_empty(), "Absorbing boon holder never inherits boon")
	var fresh = arena.add_actor(1, Vector2(300, 300), "Renascido")
	check(fresh.boons.is_empty(), "New actor has no inherited boons")
	check(not FormaBoonSystem.grant(rival, 0), "Dead actor cannot acquire boon")
	FormaBoonSystem.grant(arena.player, 2)
	arena.player.hp = arena.player.max_hp * 0.2
	var hp = arena.player.hp
	check(not FormaBoonSystem.grant(arena.player, 2) and arena.player.boons.size() == 1 and arena.player.hp > hp, "Duplicate boon heals without stacking")
	arena.new_run(1)
	check(arena.player.boons.is_empty() and arena.boss_kills == 0 and arena.hazards.is_empty(), "Restart clears boons and encounter state")

func test_endless_encounters() -> void:
	arena.new_run(2)
	arena.player.shield_timer = 99999
	for encounter in range(30):
		arena.actors = [arena.player]
		arena.orbs.clear()
		arena.shots.clear()
		arena.effects.clear()
		arena.pending_upgrades = 0
		arena.mode = "playing"
		arena.elapsed = arena.next_boss_at + 0.01
		arena.step(0.01)
		check(arena.boss != null and arena.boss.alive, "Endless scheduled spawn %d" % encounter)
		var boss = arena.boss
		boss.boss_reborn = true
		arena.hurt(boss, boss.max_hp * 10, arena.player)
		check(arena.mode == "playing" and arena.next_boss_at > arena.elapsed and not arena.boss_spawned, "Endless encounter schedules next without victory %d" % encounter)
	check(arena.encounters == 30 and arena.boss_kills == 30 and arena.player.boons.size() == 10, "Three complete cycles, ten unique boons, game continues")
	check(arena.player.radius() <= 120, "Endless mass cannot outgrow arena collision bounds")

func test_bestiary_controls() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	add_child(game)
	game.audio.muted = true
	game.arena.new_run(0)
	game.handle_action("bestiary")
	check(game.ui.bestiary_open and game.arena.mode == "paused", "Bestiary pauses active combat")
	game.handle_action("close_bestiary")
	check(not game.ui.bestiary_open and game.arena.mode == "playing", "Closing bestiary resumes combat")
	game.handle_action("pause")
	game.handle_action("inspect_boss_9")
	check(game.ui.selected_boss == 9 and game.ui.bestiary_open, "Boon slot opens matching boss details")
	game.handle_action("close_bestiary")
	check(game.arena.mode == "paused", "Bestiary preserves manual pause")
	game.free()

func test_director() -> void:
	arena.new_run(0)
	var initial = FormaDirector.target_threat(arena)
	arena.player.mass = 3000
	arena.player.level = 20
	arena.player.damage_multiplier = 3
	check(FormaDirector.target_threat(arena) > initial + 2, "Farm and upgrades increase threat")
	var previous = arena.threat
	FormaDirector.tick(arena, 1.0)
	check(arena.threat <= previous + 0.071, "Threat rises gradually after a large farm lead")
	arena.elapsed = 1800
	var late = FormaDirector.target_threat(arena)
	arena.elapsed = 3600
	check(FormaDirector.target_threat(arena) > late, "Threat keeps increasing after thirty minutes")
	arena.threat = 8
	arena.spawn_rival()
	var rival = arena.actors.back()
	check(rival.mass > 500 and rival.damage_multiplier > 1.8, "Late reinforcements scale beyond the old cap")
	var hp = rival.hp * 0.3
	rival.hp = hp
	FormaDirector.tick(arena, 0.1)
	check(rival.hp == hp, "Director does not heal injured rivals")
	arena.spawn_boss(0)
	check(arena.boss.max_hp > float(FormaBosses.DATA[0].hp) * 3, "Boss scales with developed player power")
	check(arena.boss.damage_multiplier > 2, "Boss damage continues to scale")
	arena.new_run(0)
	check(arena.threat == 1 and arena.elapsed == 0, "New run resets director")
	arena.networked = true
	var remote = arena.add_actor(1, Vector2(100, 100), "Remote", true)
	arena.gain_mass(remote, 60)
	check(remote.pending_upgrades == 0 and remote.upgrade_options.is_empty() and (remote.damage_bonus > 0 or remote.max_hp > FormaClasses.DATA[remote.class_id].hp or remote.speed_multiplier > 1.0 or remote.pickup_bonus > 0 or remote.regeneration > 0), "Human progression applies upgrades independently")
	arena.networked = false

func test_progressive_cost() -> void:
	check(FormaProgression.cost(1) == 35, "First level remains accessible")
	var previous = 0.0
	var previous_increase = 0.0
	for level in range(1, 41):
		var cost = FormaProgression.cost(level)
		check(cost > previous, "Each level costs more than the previous %d" % level)
		if level > 2:
			check(cost - previous > previous_increase, "Level costs accelerate %d" % level)
		previous_increase = cost - previous
		previous = cost
	arena.new_run(0)
	arena.gain_mass(arena.player, 35)
	check(arena.player.level == 2 and arena.next_level_mass == 119, "New threshold uses progressive cost")
	check(is_zero_approx(FormaProgression.progress(arena.player)), "XP bar starts at zero on exact level boundary")
	arena.gain_mass(arena.player, 64)
	check(arena.player.level == 3 and arena.pending_upgrades == 0, "Large farm applies every upgrade automatically")
	check(arena.upgrade_options.is_empty(), "Automatic upgrades leave no choices to select")

func test_responsive_layout() -> void:
	for size in [Vector2(640, 400), Vector2(390, 550), Vector2(320, 480), Vector2(390, 844), Vector2(844, 390), Vector2(768, 1024), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]:
		var screen = Rect2(Vector2.ZERO, size)
		var upgrade = FormaLayout.upgrades(size)
		var skills = FormaLayout.skills(size)
		for rect in [FormaLayout.health(size), upgrade, skills, FormaLayout.upgrades(size, true)]:
			check(screen.encloses(rect), "HUD fits screen %s" % size)
		check(not upgrade.intersects(skills), "Upgrade choices do not cover action bar %s" % size)
		check(not upgrade.has_point(size / 2), "Upgrade panel keeps arena center clear %s" % size)
		for rect in FormaLayout.class_cards(size):
			check(screen.encloses(rect), "Class selection fits screen %s" % size)

func test_spell_evolutions() -> void:
	for kind in range(5):
		check(FormaSpells.NAMES[kind].size() == 10, "Ten magic evolutions per class")
		for rank in range(1, 11):
			var target = clean_run(kind)
			var actor = arena.player
			actor.level = rank * 10
			actor.hp = actor.max_hp * 0.1
			target.max_hp = 100000
			target.hp = 100000
			check(FormaSpells.tier(actor.level - 1) == rank - 1 and FormaSpells.tier(actor.level) == rank, "Magic unlocks exactly at level %d" % actor.level)
			check(FormaSpells.title(actor) == FormaSpells.NAMES[kind][rank - 1], "Evolved magic name matches class and level")
			check(arena.use_skill(actor), "Every evolved magic casts")
			check(actor.skill_timer > 0 and not arena.use_skill(actor), "Evolved magic obeys cooldown")
			if kind in [0, 2]: check(target.hp < 100000, "Evolved area/charge deals actual damage")
			if kind == 1: check(actor.hp > actor.max_hp * 0.4 and actor.shield_timer > 2.5, "Evolved paladin heals and shields")
			if kind == 3:
				check(arena.shots.size() >= 7 + rank * 2, "Archer creates stronger volleys")
				if rank >= 2: check(arena.shots[0].pierce > 0, "Evolved arrows pierce")
				if rank >= 4: check(arena.shots[0].homing > 0, "Evolved arrows seek a real target")
			if kind == 4:
				arena.update_effects(0.1)
				check(target.hp < 100000 and actor.hp > actor.max_hp * 0.1, "Evolved grove damages and heals")
				if rank >= 3: check(target.poison_timer > 0, "Evolved grove applies poison")
			arena.update_effects(0.7)
			arena.update_shots(0.12)
		var actor = arena.player
		actor.level = 100
		var final_title = FormaSpells.title(actor)
		for level in [101, 150, 1000]:
			actor.level = level
			check(FormaSpells.tier(level) == 10 and FormaSpells.title(actor) == final_title, "Final magic remains after level 100")
	# A piercing projectile may hit each target only once, then expires at its limit.
	clean_run(3)
	arena.actors = [arena.player]
	var targets: Array[FormaActor] = []
	for index in range(3):
		var target = arena.add_actor(0, arena.player.pos + Vector2(100 + index * 100, 0), "Piercing target")
		target.hp = 1000
		target.max_hp = 1000
		targets.append(target)
	var shot = arena.fire_shot(arena.player, Vector2.RIGHT, 10)
	shot.pierce = 1
	arena.update_shots(0.5)
	check(targets[0].hp < 1000 and targets[1].hp < 1000 and targets[2].hp == 1000, "Piercing hits exactly the permitted number of distinct targets")
	var target = clean_run(0)
	arena.player.level = 100
	target.hp = 100000
	target.max_hp = 100000
	arena.use_skill(arena.player)
	var before = target.hp
	arena.update_effects(0.7)
	check(target.hp < before, "Final mage magic emits a delayed damaging echo")
	arena.player.alive = false
	arena.update_effects(0.7)
	check(not arena.effects.any(func(effect: FormaEffect) -> bool: return effect.owner_id == arena.player.id), "Caster death removes lingering magic")
