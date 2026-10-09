class_name FormaWorldView
extends Node2D

const P = preload("res://scripts/palette.gd")
const D = preload("res://scripts/paint.gd")
var arena: FormaArena
var camera: Vector2 = FormaArena.SIZE / 2
var zoom: float = 1.0
var clock: float = 0

func _process(delta: float) -> void:
	clock += delta
	if arena != null and arena.player != null:
		camera = camera.lerp(arena.player.pos, 1.0 - exp(-delta * 8))
		zoom = lerpf(zoom, clampf(1.05 - arena.player.mass / 2000.0, 0.67, 1.0), 1.0 - exp(-delta * 3))
	queue_redraw()

func screen_size() -> Vector2:
	return get_viewport_rect().size

func view_zoom() -> float:
	# Preserve a useful arena view even on narrow or short screens.
	return zoom * clampf(minf(screen_size().x / 1000.0, screen_size().y / 650.0), 0.42, 1.5)

func screen_to_world(point: Vector2) -> Vector2:
	return (point - screen_size() / 2) / view_zoom() + camera

func world_to_screen(point: Vector2) -> Vector2:
	return (point - camera) * view_zoom() + screen_size() / 2

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size()), P.BG)
	if arena == null or arena.mode == "menu":
		draw_menu_background()
		return
	draw_set_transform(screen_size() / 2 - camera * view_zoom(), 0, Vector2.ONE * view_zoom())
	draw_floor()
	for field in arena.hazards:
		draw_hazard(field)
	for orb in arena.orbs:
		if not visible_point(orb.pos, 20):
			continue
		var color: Color = P.CLASSES[orb.tint]
		var size = clampf(2.5 + orb.value * 0.5, 3.5, 9.0)
		D.glow(self, orb.pos, size * 1.6, color)
		draw_colored_polygon(D.polygon(orb.pos, size, 4, clock * 0.25), Color(color, 0.85))
	for effect in arena.effects:
		if effect.kind == "grove":
			draw_effect(effect)
	for actor in arena.actors:
		if actor.alive and visible_point(actor.pos, actor.radius() + 60):
			draw_actor(actor)
	for shot in arena.shots:
		var color: Color = FormaBosses.DATA[shot.boss_kind].color if shot.boss_kind >= 0 else P.CLASSES[shot.class_id]
		draw_line(shot.pos - shot.velocity.normalized() * 21, shot.pos, Color(color, 0.3), shot.radius * 1.5, true)
		D.glow(self, shot.pos, shot.radius, color, 2)
		if shot.boss_kind >= 0:
			D.outline(self, D.polygon(shot.pos, shot.radius, 3 + shot.boss_kind % 4, shot.velocity.angle() + clock), color, 2)
		elif shot.class_id == 3:
			draw_line(shot.pos - shot.velocity.normalized() * 14, shot.pos, color, 3, true)
		else:
			draw_circle(shot.pos, shot.radius, color)
	for effect in arena.effects:
		if effect.kind != "grove":
			draw_effect(effect)
	draw_set_transform(Vector2.ZERO)
	if arena.boss != null and arena.boss.alive:
		var boss_point = world_to_screen(arena.boss.pos)
		if not Rect2(Vector2.ZERO, screen_size()).grow(-90).has_point(boss_point):
			var direction = (screen_size() / 2).direction_to(boss_point)
			var marker = screen_size() / 2 + direction * maxf(60, minf(screen_size().x, screen_size().y) * 0.35)
			FormaBossArt.creature(self, marker, 20, arena.boss.boss_kind, clock)
			D.styled_center(self, "%s · %d m" % [arena.boss.label, int(arena.player.pos.distance_to(arena.boss.pos) / 10)], marker + Vector2(0, 32), "body-sm", arena.boss.tint())

func visible_point(point: Vector2, extra: float) -> bool:
	return Rect2(camera - screen_size() / view_zoom() / 2, screen_size() / view_zoom()).grow(extra).has_point(point)

func draw_menu_background() -> void:
	for x in range(32, int(screen_size().x), 48):
		for y in range(20, int(screen_size().y), 48):
			draw_circle(Vector2(x, y), 1, Color(P.LINE, P.GRID_ALPHA))
	D.glow(self, Vector2(screen_size().x * 0.82, 170), 120, P.GOLD, 0.65)
	for i in range(4):
		D.outline(self, D.polygon(Vector2(screen_size().x * 0.85, 150), 80 + i * 36, 6, clock * 0.025 + i * 0.14), Color(P.GOLD, 0.055 + i * 0.014), 1)

func draw_floor() -> void:
	draw_rect(Rect2(Vector2.ZERO, FormaArena.SIZE), P.FLOOR)
	var start_x = maxi(0, int((camera.x - (screen_size().x / 2 + 80) / view_zoom()) / 80) * 80)
	var end_x = mini(int(FormaArena.SIZE.x), int(camera.x + (screen_size().x / 2 + 80) / view_zoom()))
	var start_y = maxi(0, int((camera.y - (screen_size().y / 2 + 80) / view_zoom()) / 80) * 80)
	var end_y = mini(int(FormaArena.SIZE.y), int(camera.y + (screen_size().y / 2 + 80) / view_zoom()))
	for x in range(start_x, end_x + 80, 80):
		for y in range(start_y, end_y + 80, 80):
			var point = Vector2(x, y)
			draw_line(point - Vector2(3, 0), point + Vector2(3, 0), Color(P.LINE, P.GRID_ALPHA), 1)
			draw_line(point - Vector2(0, 3), point + Vector2(0, 3), Color(P.LINE, P.GRID_ALPHA), 1)
	var landmarks = [Vector2(800, 700), Vector2(2800, 700), Vector2(1800, 1400), Vector2(800, 2200), Vector2(2800, 2200)]
	for i in range(landmarks.size()):
		var point: Vector2 = landmarks[i]
		if not visible_point(point, 350):
			continue
		var color: Color = P.CLASSES[i]
		D.glow(self, point, 170, color, 0.45)
		draw_arc(point, 260, 0, TAU, 96, Color(color, 0.09), 1, true)
		draw_arc(point, 245, 0, TAU, 96, Color(color, 0.045), 1, true)
		D.outline(self, D.polygon(point, 160, 6, PI / 6), Color(color, 0.1), 1)
		for j in range(6):
			var rune = point + Vector2.from_angle(j * TAU / 6) * 260
			D.outline(self, D.polygon(rune, 7, 4), Color(color, 0.2), 1)
		D.styled_center(self, ["Arquivo arcano", "Círculo solar", "O Nexo", "Jardim ancestral", "Ruínas do vento"][i], point + Vector2(0, 185), "label", Color(color, P.LANDMARK_ALPHA))
	draw_rect(Rect2(Vector2(15, 15), FormaArena.SIZE - Vector2(30, 30)), Color(P.DANGER, 0.4), false, 3)
	draw_rect(Rect2(Vector2(30, 30), FormaArena.SIZE - Vector2(60, 60)), Color(P.DANGER, 0.08), false, 15)

func draw_actor(actor: FormaActor) -> void:
	var radius = actor.radius()
	var color = actor.tint()
	if actor.is_player:
		draw_arc(actor.pos, radius + 23, 0, TAU, 64, Color(color, 0.1), 1, true)
		var pointer = actor.pos + actor.aim * (radius + 28)
		draw_colored_polygon(D.polygon(pointer, 4.5, 3, actor.aim.angle() + PI / 2), color)
	if actor.is_boss:
		FormaBossArt.creature(self, actor.pos, radius, actor.boss_kind, clock)
		draw_arc(actor.pos, radius, 0, TAU, 64, Color(color, 0.13), 1, true)
		if actor.attack_timer < 0.65:
			draw_arc(actor.pos, radius + 27, 0, TAU * (1.0 - actor.attack_timer / 0.65), 48, Color(color, 0.6), 2, true)
	else:
		D.sigil(self, actor.pos, radius, actor.class_id, clock, actor.is_player, actor.aim.angle())
	for i in range(actor.boons.size()):
		var boon_color: Color = FormaBosses.DATA[actor.boons[i]].color
		var orbit = actor.pos + Vector2.from_angle(clock * 0.3 + i * TAU / actor.boons.size()) * (radius + 18)
		draw_colored_polygon(D.polygon(orbit, 4, 4), boon_color)
	draw_status_rings(actor, radius)
	if actor.flash > 0:
		draw_circle(actor.pos, radius * 0.75, Color(P.WHITE, actor.flash * 3))
	draw_nameplate(actor, radius, color)

# One shape and one color per state, on distinct radii so they can stack.
func draw_status_rings(actor: FormaActor, radius: float) -> void:
	if actor.burn_timer > 0:
		draw_arc(actor.pos, radius + 6, clock * 3, clock * 3 + PI * 1.5, 32, P.BURN, 2, true)
	if actor.poison_timer > 0:
		D.outline(self, D.polygon(actor.pos, radius + 7, 6, clock * 0.1), P.POISON, 2)
	if actor.slow_timer > 0:
		D.outline(self, D.polygon(actor.pos, radius + 9, 5, clock * 0.3), P.CHILL, P.STROKE_CONTROL)
	if actor.stun_timer > 0:
		for i in range(3):
			draw_colored_polygon(D.polygon(actor.pos + Vector2.from_angle(clock * 2 + i * TAU / 3) * (radius + 9), 4, 4), P.STUN)
	if actor.shield_timer > 0:
		draw_arc(actor.pos, radius + 8, 0, TAU, 64, Color(P.SHIELD, 0.55 + sin(clock * 8) * 0.15), P.STROKE_RING, true)

func draw_nameplate(actor: FormaActor, radius: float, color: Color) -> void:
	var fraction = clampf(actor.hp / actor.max_hp, 0, 1)
	var shown = actor.label.trim_prefix("Elite ") if actor.elite else actor.label
	var top = actor.pos + Vector2(0, -radius - (65 if actor.is_boss else 42))
	var name_color = color if actor.is_player or actor.is_boss else P.TEXT
	if actor.elite:
		# The elite marker is a form as well as a color: danger sits close to knight.
		var chip_width = FormaType.width("Elite", "label") + 10
		var total = chip_width + 6 + FormaType.width(shown, "body")
		var chip = Rect2(top + Vector2(-total / 2, 2), Vector2(chip_width, 18))
		D.panel(self, chip, Color(P.BG, 0.6), P.DANGER, P.RADIUS_XS)
		D.styled_center(self, "Elite", Vector2(chip.get_center().x, chip.position.y + 2), "label", P.DANGER)
		D.styled(self, shown, Vector2(chip.end.x + 6, top.y), "body", name_color)
	else:
		D.styled_center(self, shown, top, "body", name_color)
	D.bar(self, Rect2(actor.pos + Vector2(-25, -radius - 16), Vector2(50, 4)), fraction, P.health(fraction))
	if not actor.is_boss:
		D.styled_center(self, FormaType.integer(actor.mass), actor.pos + Vector2(0, radius + 10), "body-sm", P.MUTED)

func draw_hazard(field: FormaHazard) -> void:
	var color: Color = FormaBosses.DATA[field.boss_kind].color
	var warning = field.warning > 0
	var intensity = 0.16 + (1.0 - field.warning / field.warning_duration) * 0.16 if warning else 0.7
	if field.shape == "line":
		var normal = field.pos.direction_to(field.end).orthogonal() * field.radius
		var corners = PackedVector2Array([field.pos + normal, field.end + normal, field.end - normal, field.pos - normal])
		draw_colored_polygon(corners, Color(color, intensity * 0.3))
		D.outline(self, corners, Color(color, intensity + 0.25), 1.5)
		if not warning:
			draw_line(field.pos, field.end, color, 4, true)
	else:
		draw_circle(field.pos, field.radius, Color(color, intensity * 0.2))
		D.outline(self, D.polygon(field.pos, field.radius, 32, clock * 0.04), Color(color, intensity + 0.3), 2)
		if warning:
			draw_arc(field.pos, field.radius * 0.9, -PI / 2, -PI / 2 + TAU * (1 - field.warning / field.warning_duration), 48, color, 2, true)
		else:
			D.outline(self, D.polygon(field.pos, field.radius * (0.3 + fmod(clock, 0.8)), 6, clock), Color(color, 0.25), 2)
	if warning:
		D.styled_center(self, "!", field.pos - Vector2(0, 17), "title", color)

func draw_effect(effect: FormaEffect) -> void:
	var progress = 1.0 - effect.ttl / effect.duration
	var color = Color(effect.color, 1.0 - progress)
	match effect.kind:
		"ring", "nova", "slash":
			var radius = effect.radius * (0.3 + progress * 0.7)
			draw_arc(effect.pos, radius, 0, TAU, 64, color, 2.5, true)
			if effect.kind != "ring":
				draw_circle(effect.pos, radius, Color(color, (1 - progress) * 0.07))
				for i in range(8):
					var direction = Vector2.from_angle(i * TAU / 8)
					draw_line(effect.pos + direction * radius * 0.75, effect.pos + direction * radius, color, 2, true)
		"text":
			# Damage the local player takes reads as danger; everything else as text.
			var taken = arena.player != null and effect.target_id == arena.player.id
			D.styled_center(self, ("−" + effect.label) if taken else effect.label, effect.pos, "float", Color(P.DANGER, 1.0 - progress) if taken else color)
		"grove":
			draw_circle(effect.pos, effect.radius, Color(effect.color, 0.055))
			D.outline(self, D.polygon(effect.pos, effect.radius, 12, clock * 0.07), Color(effect.color, 0.5), 1.5)
			for i in range(7):
				D.outline(self, D.polygon(effect.pos + Vector2.from_angle(i * TAU / 7) * effect.radius * 0.7, 13, 3, clock), Color(effect.color, 0.4), 1)
