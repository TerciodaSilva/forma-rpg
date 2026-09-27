class_name FormaSpells
extends RefCounted

const DAMAGE_SCALE: float = 0.35

# Ten automatic evolutions, at levels 10, 20, ... 100; the initial skill is tier 0.
const NAMES = [
	["Nova ampliada", "Pulso astral", "Ignição arcana", "Estilhaços estelares", "Gravidade zero", "Eco da supernova", "Prisão cósmica", "Tempestade astral", "Colapso dimensional", "Big Bang"],
	["Luz restauradora", "Égide radiante", "Julgamento", "Martelos sagrados", "Purificação", "Círculo de luz", "Sentença divina", "Aurora imortal", "Trono solar", "Apoteose"],
	["Investida brutal", "Rastro de aço", "Impacto sísmico", "Lâminas do vendaval", "Armadura de guerra", "Ruptura", "Marcha do titã", "Tempestade de aço", "Golpe do destino", "Fim dos reinos"],
	["Rajada de cristal", "Flechas penetrantes", "Caçada glacial", "Mira astral", "Flechas incendiárias", "Chuva de estrelas", "Caçada infinita", "Horizonte de flechas", "Eclipse de cristal", "Mil sóis"],
	["Bosque desperto", "Raízes profundas", "Esporos venenosos", "Coroa de espinhos", "Seiva da vida", "Floresta ancestral", "Prisão selvagem", "Fúria da natureza", "Mundo verde", "Árvore da eternidade"],
]
const FEATURES = [
	["Nova maior e mais forte", "Recarga reduzida", "Nova incendeia os alvos", "Projéteis em todas as direções", "Atrai os alvos para a explosão", "Nova ecoa após o impacto", "Atordoa os alvos", "Estilhaços perseguem inimigos", "Dois ecos de destruição", "Nova máxima e três ecos"],
	["Cura ampliada", "Escudo mais duradouro", "Explosão de luz causa dano", "Martelos irradiam ao redor", "Remove queimadura, veneno e lentidão", "Aura cura e fere por pulsos", "Julgamento atordoa", "Martelos perseguem inimigos", "Aura de luz prolongada", "Cura total e julgamento supremo"],
	["Investida mais longa e forte", "Corredor de impacto ampliado", "Impacto causa lentidão", "Lâminas irradiam no destino", "Proteção durante toda a investida", "Explosão no fim do trajeto", "Impacto atordoa", "Lâminas atravessam inimigos", "Explosão ecoa no destino", "Investida colossal com três ecos"],
	["Mais flechas e dano", "Flechas atravessam um alvo", "Aplica lentidão", "Flechas perseguem alvos", "Adiciona queimadura", "Dobra a rajada", "Atravessa mais inimigos", "Rajada adicional em todas as direções", "Projéteis maiores e mais rápidos", "Rajada tripla e chuva circular"],
	["Bosque maior e mais forte", "Bosque dura mais", "Envenena inimigos no bosque", "Dispara espinhos ao redor", "Regeneração ampliada", "Cria um segundo bosque", "Raízes atordoam periodicamente", "Espinhos perseguem inimigos", "Cria um terceiro bosque", "Floresta máxima e espinhos penetrantes"],
]

static func tier(level: int) -> int:
	return clampi(level / 10, 0, 10)

static func title(actor: FormaActor) -> String:
	var rank = tier(actor.level)
	return FormaClasses.DATA[actor.class_id].skill if rank == 0 else NAMES[actor.class_id][rank - 1]

static func description(kind: int) -> String:
	var text = "MAGIAS · %s\nA habilidade Q evolui automaticamente a cada 10 níveis. A forma do nível 100 permanece nos níveis seguintes.\n" % FormaClasses.DATA[kind].name
	for index in range(10):
		text += "\nNv. %d · %s — %s." % [(index + 1) * 10, NAMES[kind][index], FEATURES[kind][index]]
	return text

static func power(rank: int) -> float:
	return 1.0 + rank * 0.32 + rank * rank * 0.055

static func cast(arena: FormaArena, actor: FormaActor) -> void:
	var rank = tier(actor.level)
	# Ultimates should create space and pressure without deleting a full-health rival.
	# Healing, shielding and control remain unchanged; only spell damage is reduced.
	var strength = power(rank) * actor.damage_multiplier * DAMAGE_SCALE
	var color = actor.tint()
	actor.skill_timer = FormaClasses.DATA[actor.class_id].cooldown * (1.0 - rank * 0.025)
	match actor.class_id:
		0:
			var radius = 240.0 + rank * 26
			burst(arena, actor, actor.pos, radius, 65 * strength, "burn" if rank >= 3 else "", rank >= 7, rank >= 5)
			if rank >= 4: radial(arena, actor, actor.pos, 6 + rank, 15 * strength, rank)
			if rank >= 6: echo(arena, actor, actor.pos, radius, 28 * strength, 3 if rank == 10 else (2 if rank >= 9 else 1))
		1:
			actor.hp = minf(actor.max_hp, actor.hp + actor.max_hp * (0.35 + rank * 0.065))
			actor.shield_timer = maxf(actor.shield_timer, 2.5 + rank * 0.18)
			arena.add_effect(actor.pos, actor.radius() + 35 + rank * 10, color, "ring", 0.7)
			if rank >= 3: burst(arena, actor, actor.pos, 150 + rank * 22, 24 * strength, "", rank >= 7)
			if rank >= 4: radial(arena, actor, actor.pos, 4 + rank, 12 * strength, rank)
			if rank >= 5:
				actor.burn_timer = 0
				actor.poison_timer = 0
				actor.slow_timer = 0
			if rank >= 6: echo(arena, actor, actor.pos, 160 + rank * 16, 12 * strength, 5 if rank >= 9 else 3, actor.max_hp * 0.025)
		2:
			var reach = 315.0 + rank * 27
			actor.dash_timer = 0.3
			actor.velocity = actor.aim * reach / actor.dash_timer
			actor.shield_timer = maxf(actor.shield_timer, 0.4 + (rank * 0.05 if rank >= 5 else 0))
			var destination = (actor.pos + actor.aim * reach).clamp(Vector2.ONE * actor.radius(), FormaArena.SIZE - Vector2.ONE * actor.radius())
			for other in arena.actors.duplicate():
				if other == actor or not other.alive or arena.allies(actor, other): continue
				var closest = Geometry2D.get_closest_point_to_segment(other.pos, actor.pos, destination)
				if closest.distance_to(other.pos) < actor.radius() + other.radius() + rank * 7:
					arena.hurt(other, 58 * strength, actor)
					if rank >= 3: arena.apply_status(other, "stun" if rank >= 7 else "slow", actor.id)
			arena.add_effect(actor.pos, 90 + rank * 12, color, "slash", 0.4)
			if rank >= 4: radial(arena, actor, destination, 4 + rank, 12 * strength, rank)
			if rank >= 6: burst(arena, actor, destination, 100 + rank * 12, 22 * strength)
			if rank >= 9: echo(arena, actor, destination, 110 + rank * 12, 18 * strength, 3 if rank == 10 else 1)
		3:
			var count = 7 + rank * 2
			var volleys = 3 if rank == 10 else (2 if rank >= 6 else 1)
			for volley in range(volleys):
				for index in range(count):
					var angle = (index - (count - 1) / 2.0) * (0.14 if rank == 0 else 0.075)
					var shot = arena.fire_shot(actor, actor.aim.rotated(angle), 25 * strength)
					if shot == null: continue
					shot.velocity *= 1.0 + volley * 0.2 + rank * 0.035
					shot.ttl *= 1 + rank * 0.055
					shot.radius += rank * 0.45
					shot.pierce = (2 if rank >= 7 else 1) if rank >= 2 else 0
					shot.status = "slow" if rank >= 3 else ""
					shot.burning = rank >= 5
					if rank >= 4: guide(arena, actor, shot, 1.2 + rank * 0.08)
			if rank >= 8: radial(arena, actor, actor.pos, 12 + rank, 16 * strength, rank)
		4:
			var count = 3 if rank >= 9 else (2 if rank >= 6 else 1)
			for index in range(count):
				var point = actor.pos if index == 0 else actor.pos + actor.aim.rotated((index - 1) * PI) * (180 + rank * 12)
				var field = arena.add_effect(point, 185 + rank * 19, color, "grove", 4 + rank * 0.28)
				field.owner_id = actor.id
				field.damage = 17 * strength
				field.healing = 12 * (1 + rank * 0.24 + (0.6 if rank >= 5 else 0))
				field.status = "poison" if rank >= 3 else ""
				field.rooted = rank >= 7
			if rank >= 4: radial(arena, actor, actor.pos, 6 + rank, 13 * strength, rank)

static func burst(arena: FormaArena, actor: FormaActor, point: Vector2, radius: float, damage: float, status: String = "", stun: bool = false, pull: bool = false) -> void:
	arena.add_effect(point, radius, actor.tint(), "nova", 0.6)
	for other in arena.actors.duplicate():
		if other == actor or not other.alive or arena.allies(actor, other) or point.distance_to(other.pos) >= radius + other.radius(): continue
		arena.hurt(other, damage, actor)
		arena.apply_status(other, status, actor.id)
		if stun: arena.apply_status(other, "stun", actor.id)
		if other.alive and other.shield_timer <= 0:
			if pull: other.pos = other.pos.move_toward(point, 100)
			else: other.pos += point.direction_to(other.pos) * 90

static func echo(arena: FormaArena, actor: FormaActor, point: Vector2, radius: float, damage: float, count: int, healing: float = 0) -> void:
	var field = arena.add_effect(point, radius, actor.tint(), "ring", count * 0.65 + 0.1)
	field.owner_id = actor.id
	field.pulses = count
	field.pulse_timer = 0.65
	field.damage = damage
	field.healing = healing

static func radial(arena: FormaArena, actor: FormaActor, point: Vector2, count: int, damage: float, rank: int) -> void:
	for index in range(count):
		var shot = arena.fire_shot(actor, Vector2.from_angle(index * TAU / count), damage)
		if shot == null: continue
		shot.pos += point - actor.pos
		shot.ttl = 1.1 + rank * 0.045
		shot.pierce = 1 if rank >= 8 else 0
		if rank >= 8: guide(arena, actor, shot, 1.5)

static func guide(arena: FormaArena, actor: FormaActor, shot: FormaShot, amount: float) -> void:
	var distance = 1200.0
	for other in arena.actors:
		if other == actor or not other.alive or arena.allies(actor, other): continue
		var gap = shot.pos.distance_to(other.pos)
		if gap < distance:
			distance = gap
			shot.target_id = other.id
			shot.homing = amount
