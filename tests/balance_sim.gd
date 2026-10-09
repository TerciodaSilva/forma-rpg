extends SceneTree

# Headless balance report. Not part of the smoke suite: it measures, it does not assert.
#   Godot --headless --path . -s res://tests/balance_sim.gd -- [--only=curves,duels,runs] [--levels=1,10,30,60] [--reps=12] [--runs=6] [--minutes=10]

class SimArena extends "res://tests/test_arena.gd":
	# Cautious human proxy: farms, fights what it can beat, kites what it cannot,
	# and uses dodge and shield when hurt. Bots keep their normal AI.
	func move_human(actor: FormaActor, delta: float) -> void:
		if actor.stun_timer > 0:
			return
		var reach: float = FormaClasses.DATA[actor.class_id].range
		var danger = Vector2.ZERO
		var prey: FormaActor = null
		var prey_distance: float = INF
		var nearest: FormaActor = null
		var nearest_distance: float = INF
		for other in actors:
			if other == actor or not other.alive:
				continue
			var d = actor.pos.distance_to(other.pos)
			if d < nearest_distance:
				nearest = other
				nearest_distance = d
			var scary = other.mass > actor.mass * 1.3 or actor.hp < actor.max_hp * 0.45 or (other.elite and actor.hp < actor.max_hp * 0.8)
			if other.is_boss:
				scary = d < 260 or actor.hp < actor.max_hp * 0.6
			if scary and d < 430:
				danger += other.pos.direction_to(actor.pos) * (430.0 - d)
			elif not scary and d < prey_distance and d < 650:
				prey = other
				prey_distance = d
		var direction = Vector2.ZERO
		if danger.length() > 1:
			direction = danger.normalized()
			if actor.hp < actor.max_hp * 0.55:
				dash(actor, direction)
			if actor.hp < actor.max_hp * 0.3:
				use_shield(actor)
		elif prey != null:
			var toward = actor.pos.direction_to(prey.pos)
			if prey_distance > reach * 0.85 + prey.radius():
				direction = toward
			elif reach > 200 and prey_distance < 260:
				direction = -toward
			else:
				direction = toward.orthogonal() * 0.6
		else:
			var best: float = INF
			for orb in orbs:
				var d = actor.pos.distance_squared_to(orb.pos)
				if d < best:
					best = d
					direction = actor.pos.direction_to(orb.pos)
		var target = prey if prey != null else nearest
		if target != null:
			actor.aim = actor.pos.direction_to(target.pos)
			var gap = actor.pos.distance_to(target.pos)
			if gap < reach + target.radius():
				attack(actor)
			if gap < (300 if actor.class_id != 3 else 520) and (target == prey or actor.class_id in [1, 4]):
				use_skill(actor)
		if actor.dash_timer > 0:
			actor.dash_timer -= delta
		else:
			actor.velocity = direction * actor.speed()
		actor.pos += actor.velocity * delta

	var death_cause: String = ""

	func defeat(actor: FormaActor, source: FormaActor, absorbed: bool = false) -> void:
		if actor.is_player and actor.alive:
			if absorbed: death_cause = "absorvido"
			elif source == null: death_cause = "status"
			elif source.is_boss: death_cause = "chefe"
			elif source.elite: death_cause = "elite"
			else: death_cause = "rival"
		super.defeat(actor, source, absorbed)

var args: Dictionary = {}

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts = arg.trim_prefix("--").split("=")
		args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var only = args.get("only", "duels,runs,curves")
	if "curves" in only: curves()
	if "duels" in only:
		for level in str(args.get("levels", "1,10,30,60")).split(","):
			duels(int(level))
	if "runs" in only: runs(int(args.get("runs", 6)), float(args.get("minutes", 10)))
	quit()

func make_arena(seed: int) -> FormaArena:
	var arena = SimArena.new()
	root.add_child(arena)
	arena.rng.seed = seed
	return arena

func curves() -> void:
	print("\n== Spell damage per cast (first hit of main effect) ==")
	print("tier | mage nova | knight charge | archer arrow | druid grove/s | strength")
	for rank in [0, 1, 3, 5, 7, 10]:
		var strength = FormaSpells.power(rank)
		print("%4d | %9.1f | %13.1f | %12.1f | %13.1f | %.2f" % [rank, 65 * strength, 58 * strength, 25 * strength, 14 * strength, strength])

func setup_duelist(arena: FormaArena, kind: int, level: int, point: Vector2) -> FormaActor:
	var actor = arena.add_actor(kind, point, FormaClasses.DATA[kind].name)
	actor.level = level
	actor.mass = 20 + level * 25
	actor.max_hp += (level - 1) * actor.growth()
	# Equal, deterministic upgrade budget: one of each kind per five levels.
	for i in range(level - 1):
		arena.apply_upgrade(actor, i % FormaArena.UPGRADES.size())
	actor.hp = actor.max_hp
	actor.skill_timer = 0
	return actor

func duels(level: int) -> void:
	var wins = []
	for a in range(5):
		wins.append([0, 0, 0, 0, 0])
	var reps = int(args.get("reps", 12))
	var total_time = 0.0
	var fights = 0
	for a in range(5):
		for b in range(5):
			if a == b:
				continue
			for rep in range(reps):
				var arena = make_arena(1000 + a * 100 + b * 10 + rep)
				arena.new_run(0)
				arena.actors.clear()
				arena.orbs.clear()
				arena.rival_count = 0
				arena.next_boss_at = INF
				arena.elapsed = 30
				var center = FormaArena.SIZE / 2
				var offset = Vector2.from_angle(rep * 0.7) * 380
				var first = setup_duelist(arena, a, level, center - offset)
				var second = setup_duelist(arena, b, level, center + offset)
				var t = 0.0
				while t < 75 and first.alive and second.alive:
					arena.step(1.0 / 20.0)
					t += 1.0 / 20.0
				total_time += t
				fights += 1
				var score_a = first.hp / first.max_hp if first.alive else 0.0
				var score_b = second.hp / second.max_hp if second.alive else 0.0
				if score_a > score_b:
					wins[a][b] += 1
				arena.free()
	print("\n== Duels at level %d (row win rate vs column, %d fights each, avg %.1f s) ==" % [level, reps, total_time / fights])
	var header = "           "
	for b in range(5):
		header += "%10s" % FormaClasses.DATA[b].name.left(9)
	print(header + "   TOTAL")
	for a in range(5):
		var line = "%-11s" % FormaClasses.DATA[a].name
		var total = 0
		for b in range(5):
			if a == b:
				line += "%10s" % "-"
				continue
			# Each pairing is played from both sides; merge them.
			var won = wins[a][b] + (reps - wins[b][a])
			total += won
			line += "%9d%%" % int(100.0 * won / (2 * reps))
		print(line + "%7d%%" % int(100.0 * total / (8 * reps)))

func runs(count: int, minutes: float) -> void:
	print("\n== Solo runs, AI-driven player, %d seeds x %.0f min (Intenso) ==" % [count, minutes])
	print("class      | survived | avg death | avg lvl | avg mass | kills | boss | threat | deaths by")
	for kind in range(5):
		var deaths = []
		var levels = 0.0
		var masses = 0.0
		var kills = 0.0
		var bosses = 0.0
		var threats = 0.0
		var survived = 0
		var causes = {}
		for seed in range(count):
			var arena = make_arena(seed * 7 + kind)
			arena.new_run(kind)
			var limit = minutes * 60.0
			while arena.mode == "playing" and arena.elapsed < limit:
				arena.step(1.0 / 20.0)
			if arena.player.alive:
				survived += 1
			else:
				deaths.append(arena.elapsed)
				causes[arena.death_cause] = causes.get(arena.death_cause, 0) + 1
			levels += arena.player.level
			masses += arena.player.mass
			kills += arena.player.kills
			bosses += arena.player.boss_kills
			threats += arena.threat
			arena.free()
		var avg_death = "-"
		if not deaths.is_empty():
			avg_death = "%.0f s" % (deaths.reduce(func(s, v): return s + v, 0.0) / deaths.size())
		print("%-10s | %4d/%-3d | %9s | %7.1f | %8.0f | %5.1f | %4.1f | %6.2f | %s" % [FormaClasses.DATA[kind].name, survived, count, avg_death, levels / count, masses / count, kills / count, bosses / count, threats / count, causes])
