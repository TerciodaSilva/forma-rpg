class_name FormaInterface
extends Node2D

# HUD, menu and overlays, drawn from the FORMA design system: palette.gd tokens,
# FormaType styles and the six HUD zones in FormaLayout.

const P = preload("res://scripts/palette.gd")
const D = preload("res://scripts/paint.gd")
const T = preload("res://scripts/type.gd")
const DIFFICULTY = ["Normal", "Intenso", "Cataclismo"]
const HINTS = [["WASD", "mover"], ["Q", "habilidade"], ["R", "escudo"], ["Espaço", "esquiva"], ["F", "autoataque"]]
const TRANSPARENT = Color(0, 0, 0, 0)
var arena: FormaArena
var clock: float = 0
var buttons: Dictionary = {}
var help_open: bool = false
var muted: bool = false
var bestiary_open: bool = false
var selected_boss: int = 0
var help_scroll: float = 0
var bestiary_scroll: float = 0
var help_scroll_max: float = 0
var bestiary_scroll_max: float = 0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func screen_size() -> Vector2:
	return get_viewport_rect().size

func action_at(point: Vector2) -> String:
	var keys = buttons.keys()
	keys.reverse()
	for action in keys:
		var rect: Rect2 = buttons[action]
		if rect.has_point(point): return action
	return ""

# ---------- Text ----------

func text(value: String, point: Vector2, style: String = "body", color: Color = P.TEXT) -> void:
	D.styled(self, value, point, style, color)

func text_center(value: String, point: Vector2, style: String = "body", color: Color = P.TEXT) -> void:
	D.styled_center(self, value, point, style, color)

func text_right(value: String, point: Vector2, style: String = "body", color: Color = P.TEXT) -> void:
	D.styled_right(self, value, point, style, color)

func ellipsized(value: String, width: float, style: String) -> String:
	var result = value
	while result.length() > 1 and T.width(result, style) > width:
		result = result.left(result.length() - 2) + "…"
	return result

func fitted(value: String, point: Vector2, width: float, style: String = "body", color: Color = P.TEXT) -> void:
	text(ellipsized(value, width, style), point, style, color)

func lines_for(value: String, width: float, style: String) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in value.split("\n"):
		var line = ""
		for word in paragraph.split(" "):
			var candidate = word if line.is_empty() else line + " " + word
			if not line.is_empty() and T.width(candidate, style) > width:
				lines.append(line)
				line = word
			else: line = candidate
		lines.append(line)
	return lines

# Wraps inside rect and returns the height used.
func wrapped(value: String, rect: Rect2, style: String = "body", color: Color = P.TEXT, centered: bool = false) -> float:
	var line_height = T.line_height(style)
	var y = rect.position.y
	for line in lines_for(value, rect.size.x, style):
		if y + line_height > rect.end.y + 0.5: break
		if centered: text_center(line, Vector2(rect.get_center().x, y), style, color)
		else: text(line, Vector2(rect.position.x, y), style, color)
		y += line_height
	return y - rect.position.y

func clock_text() -> String:
	return "%02d:%02d" % [int(arena.elapsed) / 60, int(arena.elapsed) % 60]

# ---------- Controls ----------

# Primary: accent fill and on-accent text. Secondary: raised fill, strong border.
# A key cap after the label shows the shortcut.
func button(action: String, value: String, rect: Rect2, primary: bool = false, accent: Color = P.GOLD, key: String = "") -> void:
	buttons[action] = rect
	var hovered = rect.has_point(get_global_mouse_position())
	var fill = accent if primary else P.RAISED
	if hovered: fill = fill.lightened(0.10)
	D.panel(self, rect, fill, accent if primary or hovered else P.LINE_STRONG, P.RADIUS_SM)
	var style = "subhead" if primary else "strong"
	var key_width = 0.0 if key == "" else maxf(20.0, T.width(key, "label") + 10) + P.SPACE_2
	var label = ellipsized(value, rect.size.x - 24 - key_width, style)
	var x = rect.get_center().x - (T.width(label, style) + key_width) / 2
	var size = T.size(style)
	var color = P.ON_ACCENT if primary else P.TEXT
	text(label, Vector2(x, rect.get_center().y - size * 0.64), style, color)
	if key != "":
		var key_point = Vector2(x + T.width(label, style) + P.SPACE_2, rect.get_center().y - 10)
		if primary: D.keycap(self, key, key_point, P.ON_ACCENT, Color(P.ON_ACCENT, 0.45), TRANSPARENT)
		else: D.keycap(self, key, key_point)

func icon_button(action: String, kind: String, rect: Rect2) -> void:
	buttons[action] = rect
	var hovered = rect.has_point(get_global_mouse_position())
	D.panel(self, rect, P.RAISED.lightened(0.10) if hovered else Color(P.RAISED, P.PANEL_SOLID_ALPHA), P.GOLD if hovered else P.LINE_STRONG, P.RADIUS_SM)
	D.icon(self, kind, rect.get_center(), P.TEXT)

func scrim() -> void:
	buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, screen_size()), P.SCRIM)

# ---------- Frame ----------

func _draw() -> void:
	buttons.clear()
	if arena == null: return
	if arena.mode == "menu": draw_menu()
	else:
		draw_hud()
		match arena.mode:
			"paused": draw_pause()
			"lost": draw_result()
	if bestiary_open: draw_bestiary()
	if help_open: draw_help()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not action_at(get_global_mouse_position()).is_empty() else Input.CURSOR_ARROW)

func draw_brand(point: Vector2) -> void:
	D.outline(self, D.polygon(point + Vector2(16, 19), 16, 6), P.GOLD, P.STROKE_CONTROL)
	draw_colored_polygon(D.polygon(point + Vector2(16, 21), 8, 3), P.GOLD)
	draw_circle(point + Vector2(16, 23), 2.2, P.BG)
	text("Forma", point + Vector2(44, -1), "wordmark")
	text("Reinos de Éter", point + Vector2(45, 25), "label", P.MUTED)

# ---------- Menu ----------

func draw_menu() -> void:
	var size = screen_size()
	var p = FormaLayout.padding(size)
	var compact = size.x < 720
	var short_screen = size.y < 650
	draw_brand(Vector2(p, p))
	if size.x >= 760: text_right("Multiplayer · salas automáticas", Vector2(size.x - p, p + 12), "label", P.MUTED)
	if size.y >= 500:
		var style = "title" if compact or short_screen else "display"
		var top = (66.0 if short_screen else 92.0) + FormaLayout.menu_offset(size)
		text("Pequenas formas.", Vector2(p, top), style)
		text("Grandes lendas.", Vector2(p, top + T.line_height(style)), style, P.GOLD)
		if not short_screen:
			text("Escolha sua essência. Entre na arena.", Vector2(p, top + T.line_height(style) * 2 + 6), "body", P.MUTED)
	var cards = FormaLayout.class_cards(size)
	if compact:
		draw_class_card(arena.selected_class, cards[0], true)
		icon_button("menu_previous", "prev", Rect2(cards[0].position + Vector2(12, 12), Vector2(40, 40)))
		icon_button("menu_next", "next", Rect2(cards[0].end.x - 52, cards[0].position.y + 12, 40, 40))
	else:
		for i in range(5): draw_class_card(i, cards[i])
	var footer = FormaLayout.menu_footer(size)
	var width = size.x - p * 2
	button("start", "Jogar online", Rect2(p, footer, width, 46), true, P.CLASSES[arena.selected_class], "Enter")
	var sound = "Som desligado" if muted else "Som ligado"
	if compact:
		button("settings", "Servidor e ajustes", Rect2(p, footer + 56, width, 40))
		var third = (width - 16) / 3
		button("bestiary", "Bestiário", Rect2(p, footer + 106, third, 36))
		button("help", "Como jogar", Rect2(p + third + 8, footer + 106, third, 36))
		button("mute", "Som" if not muted else "Mudo", Rect2(p + (third + 8) * 2, footer + 106, third, 36))
	else:
		var quarter = (width - 36) / 4
		button("settings", "Servidor e ajustes", Rect2(p, footer + 56, quarter, 40))
		button("bestiary", "Bestiário", Rect2(p + quarter + 12, footer + 56, quarter, 40), false, P.GOLD, "B")
		button("help", "Como jogar", Rect2(p + (quarter + 12) * 2, footer + 56, quarter, 40), false, P.GOLD, "H")
		button("mute", sound, Rect2(p + (quarter + 12) * 3, footer + 56, quarter, 40), false, P.GOLD, "M")
		var records_y = size.y - p - 18
		if records_y > footer + 108:
			text("Recordes · essência %s · chefes %d" % [T.integer(arena.best_mass), arena.best_boss_kills], Vector2(p, records_y), "body-sm", P.MUTED)

func draw_class_card(index: int, rect: Rect2, single: bool = false) -> void:
	var data = FormaClasses.DATA[index]
	var color: Color = P.CLASSES[index]
	var selected = arena.selected_class == index
	buttons["class_%d" % index] = rect
	var hovered = rect.has_point(get_global_mouse_position())
	var border = color if selected else (P.LINE_STRONG if hovered else P.LINE)
	D.panel(self, rect, P.PANEL.lerp(color, 0.075) if selected else P.PANEL, border, P.RADIUS_MD, 2 if selected else 1)
	var tiny = rect.size.y < 110
	var small = rect.size.y < 230
	if not tiny and not single:
		D.keycap(self, str(index + 1), rect.position + Vector2(12, 12))
		if selected and rect.size.x >= 170: text_right("Selecionada", Vector2(rect.end.x - 12, rect.position.y + 15), "label", color)
	var radius = 16.0 if tiny else (22.0 if small else 34.0)
	var sigil_y = rect.position.y + (26.0 if tiny else (48.0 if small else 86.0))
	D.sigil(self, Vector2(rect.get_center().x, sigil_y), radius, index, clock, selected, -PI / 2)
	var name_style = "subhead" if rect.size.x < 170 or tiny else "heading"
	var y = sigil_y + radius + (6.0 if tiny else 14.0)
	text_center(data.name, Vector2(rect.get_center().x, y), name_style)
	if tiny: return
	y += T.line_height(name_style) + 2
	text_center(ellipsized(data.role, rect.size.x - 24, "label"), Vector2(rect.get_center().x, y), "label", color)
	y += 24
	var has_skill_line = rect.size.y >= 150
	var skill_top = rect.end.y - 40
	if rect.size.y >= 250:
		wrapped(data.description, Rect2(rect.position.x + 14, y, rect.size.x - 28, skill_top - y - 8), "body-sm", P.MUTED, true)
	if not has_skill_line: return
	D.hairline(self, Vector2(rect.position.x + 12, skill_top), Vector2(rect.end.x - 12, skill_top))
	var key_width = D.keycap(self, "Q", Vector2(rect.position.x + 12, skill_top + 10))
	fitted(data.skill, Vector2(rect.position.x + 12 + key_width + 8, skill_top + 11), rect.size.x - key_width - 32, "body-sm", color)

# ---------- HUD ----------

func draw_hud() -> void:
	var actor = arena.player
	if actor == null: return
	var size = screen_size()
	var zones = FormaLayout.zones(size)
	draw_vitals(zones.vitals)
	draw_system(zones.system)
	draw_session(zones.session)
	if FormaLayout.build_expanded(size): draw_build(zones.build)
	else: button("bestiary", "Dons %d/10" % actor.boons.size(), zones.build, false, P.GOLD, "B")
	if zones.has("standing"): draw_leaderboard(zones.standing)
	draw_skillbar(zones.skills)
	if zones.has("map"): draw_minimap(zones.map)
	if FormaLayout.wide(size) and arena.elapsed < 30 and arena.mode == "playing": draw_hints(zones.skills)
	if actor.hp / actor.max_hp < 0.3 and arena.mode == "playing":
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(P.DANGER, 0.25 + sin(clock * 5) * 0.1), false, 3)

func draw_vitals(rect: Rect2) -> void:
	var actor = arena.player
	var fraction = clampf(actor.hp / actor.max_hp, 0, 1)
	var health_color = P.health(fraction)
	D.surface(self, rect, "hud")
	var x = rect.position.x + 12
	var right = rect.end.x - 12
	var inner = right - x
	var y = rect.position.y + 12
	D.sigil(self, Vector2(x + 10, y + 12), 10, actor.class_id, clock, false, -PI / 2)
	var level = "Nível %d" % actor.level
	fitted(FormaClasses.DATA[actor.class_id].name, Vector2(x + 28, y), inner - 36 - T.width(level, "label"), "subhead", actor.tint())
	text_right(level, Vector2(right, y + 6), "label", P.GOLD)
	y += 30
	text("%s / %s PV" % [T.integer(maxf(0, actor.hp)), T.integer(actor.max_hp)], Vector2(x, y), "body-sm", health_color)
	text_right("Éter " + T.integer(actor.mass), Vector2(right, y), "body-sm", P.MUTED)
	y += 22
	D.bar(self, Rect2(x, y, inner, 6), fraction, health_color)
	y += 12
	D.bar(self, Rect2(x, y, inner, 3), FormaProgression.progress(actor), P.XP)
	y += 12
	var threat = "Ameaça %s · %s" % [T.decimal(arena.threat), DIFFICULTY[arena.difficulty]]
	text(threat, Vector2(x, y + 2), "label", P.MUTED)
	var needed = "+%s para o nível %d" % [T.integer(maxi(0, ceili(actor.next_level_mass - actor.mass))), actor.level + 1]
	if T.width(threat, "label") + T.width(needed, "body-sm") + 16 <= inner:
		text_right(needed, Vector2(right, y), "body-sm", P.MUTED)

func draw_system(rect: Rect2) -> void:
	icon_button("mute", "muted" if muted else "sound", Rect2(rect.position, Vector2(40, 40)))
	icon_button("pause", "pause", Rect2(rect.position + Vector2(48, 0), Vector2(40, 40)))

func draw_session(rect: Rect2) -> void:
	var wide = FormaLayout.wide(screen_size())
	var boss_alive = arena.boss != null and arena.boss.alive
	var notice = arena.notice_time > 0 and not arena.notice.is_empty()
	var room = arena.room_label if arena.networked else "Solo"
	var line = "O Nexo · %s · %s" % [clock_text(), room] if rect.size.x >= 300 else "O Nexo · %s" % clock_text()
	if wide:
		var y = rect.position.y + 6
		text_center(line, Vector2(rect.get_center().x, y), "label", P.MUTED)
		y += 24
		if boss_alive:
			draw_boss_banner(Rect2(rect.position.x, y, rect.size.x, 56))
			y += 64
		if notice: draw_notice(rect.get_center().x, y, maxf(rect.size.x, 520))
		return
	# Compact: one item, anchored to the bottom of the zone, above the action bar.
	var bottom = rect.end.y
	if boss_alive:
		draw_boss_banner(Rect2(rect.position.x, bottom - 56, rect.size.x, 56))
		bottom -= 64
	elif notice:
		draw_notice(rect.get_center().x, bottom - 32, rect.size.x)
		bottom -= 40
	text_center(line, Vector2(rect.get_center().x, bottom - 16), "label", P.MUTED)

func draw_boss_banner(rect: Rect2) -> void:
	var boss = arena.boss
	var data = FormaBosses.DATA[boss.boss_kind]
	var encounter = "Encontro %02d" % arena.encounters
	fitted(boss.label, rect.position, rect.size.x - T.width(encounter, "label") - 12, "subhead", boss.tint())
	text_right(encounter, Vector2(rect.end.x, rect.position.y + 6), "label", P.MUTED)
	D.bar(self, Rect2(rect.position.x, rect.position.y + 28, rect.size.x, 6), boss.hp / boss.max_hp, P.HP)
	fitted("Dom em jogo · %s" % data.boon, Vector2(rect.position.x, rect.position.y + 38), rect.size.x, "body-sm", P.MUTED)

func draw_notice(center_x: float, y: float, max_width: float) -> void:
	var fade = clampf(arena.notice_time / 0.3, 0, 1)
	var label = ellipsized(arena.notice, max_width - 44, "body-sm")
	var width = T.width(label, "body-sm") + 44
	var rect = Rect2(center_x - width / 2, y, width, 32)
	var tone: Color = P.MUTED
	var border: Color = P.LINE
	match arena.notice_tone:
		"progress": tone = P.GOLD
		"boss":
			tone = arena.boss.tint() if arena.boss != null and arena.boss.alive else P.DANGER
			border = tone
	D.panel(self, rect, Color(P.PANEL, P.PANEL_ALPHA * fade), Color(border, fade), 16)
	draw_circle(rect.position + Vector2(17, 16), 3, Color(tone, fade))
	text(label, rect.position + Vector2(28, 7), "body-sm", Color(P.TEXT, fade))

func draw_build(rect: Rect2) -> void:
	var actor = arena.player
	D.surface(self, rect, "hud")
	var x = rect.position.x + 12
	var right = rect.end.x - 12
	var y = rect.position.y + 12
	text("Dons desta vida · %d/10" % actor.boons.size(), Vector2(x, y + 2), "label", P.GOLD)
	var key_point = Vector2(right - 20, y - 2)
	buttons["bestiary"] = Rect2(key_point - Vector2(4, 4), Vector2(28, 28))
	D.keycap(self, "B", key_point)
	y += 26
	for i in range(10):
		var slot = Rect2(x + i * 28, y, 24, 30)
		var owned = i in actor.boons
		D.panel(self, slot, P.RAISED, FormaBosses.DATA[i].color if owned else P.LINE, P.RADIUS_XS)
		if owned: FormaBossArt.creature(self, slot.get_center(), 8, i, clock)
		buttons["inspect_boss_%d" % i] = slot
	y += 42
	D.hairline(self, Vector2(x, y), Vector2(right, y))
	y += 12
	text("Melhorias automáticas", Vector2(x, y), "label", P.MUTED)
	y += 22
	var rows = [
		["Dano", "+%d por golpe" % int(actor.bonus_damage())],
		["Vida máx", T.integer(actor.max_hp)],
		["Velocidade", "+%d%%" % int(round((actor.speed_multiplier - 1.0) * 100.0))],
		["Coleta", "+%d px" % int(actor.pickup_bonus)],
		["Regeneração", "+%s PV/s" % T.decimal(actor.regeneration)],
	]
	for row in rows:
		text(row[0], Vector2(x, y + 3), "label", P.MUTED)
		text_right(row[1], Vector2(right, y), "body-sm")
		y += 20

func draw_leaderboard(rect: Rect2) -> void:
	D.surface(self, rect, "hud")
	var x = rect.position.x + 12
	var right = rect.end.x - 12
	var y = rect.position.y + 12
	text("Domínio da arena", Vector2(x, y), "label", P.MUTED)
	y += 24
	var ranked = arena.leaderboard()
	var rows: Array = []
	for i in range(mini(5, ranked.size())): rows.append(i)
	var own = ranked.find(arena.player)
	if own >= 5: rows[4] = own
	for index in rows:
		var actor: FormaActor = ranked[index]
		var you = actor == arena.player
		if you and index >= 5: D.hairline(self, Vector2(x, y - 3), Vector2(right, y - 3))
		if you: D.panel(self, Rect2(x - 6, y - 2, right - x + 12, 22), P.RAISED, P.RAISED, P.RADIUS_XS)
		text_right(str(index + 1), Vector2(x + 14, y), "body-sm", P.MUTED)
		draw_circle(Vector2(x + 26, y + 9), 3, actor.tint())
		var mass = T.integer(actor.mass)
		var tagged = you and actor.label != "Você"
		var name_width = right - x - 40 - T.width(mass, "body-sm") - (34 if tagged else 0)
		var shown = ellipsized(actor.label, name_width, "body-sm")
		text(shown, Vector2(x + 36, y), "body-sm")
		if tagged: text("Você", Vector2(x + 42 + T.width(shown, "body-sm"), y + 3), "label", P.GOLD)
		text_right(mass, Vector2(right, y), "body-sm", P.MUTED)
		y += 22
	text("%d vivos · %d chefes seus" % [ranked.size(), arena.boss_kills], Vector2(x, rect.end.y - 30), "body-sm", P.MUTED)

func draw_skillbar(bar: Rect2) -> void:
	var actor = arena.player
	var color = actor.tint()
	var data = FormaClasses.DATA[actor.class_id]
	var gap = P.SPACE_2
	var width = (bar.size.x - gap * 3) / 4
	var slots = [
		["Clique", data.attack, 0.0, 1.0, color, ""],
		["Q", FormaSpells.title(actor), actor.skill_timer, float(data.cooldown), color, "%d/10" % FormaSpells.tier(actor.level)],
		["R", "Escudo", maxf(actor.shield_skill_timer, actor.shield_skill_cooldown), 6.0, P.SHIELD, ""],
		["Espaço", "Esquiva", actor.dash_cooldown, 4.0, P.TEXT, ""],
	]
	for i in range(4):
		var slot = slots[i]
		draw_skill_slot(Rect2(bar.position.x + i * (width + gap), bar.position.y, width, bar.size.y), slot[0], slot[1], slot[2], slot[3], slot[4], slot[5])

func draw_skill_slot(rect: Rect2, key: String, title: String, cooldown: float, maximum: float, accent: Color, tier: String) -> void:
	D.panel(self, rect, Color(P.PANEL, P.PANEL_SOLID_ALPHA), P.LINE, P.RADIUS_SM)
	var x = rect.position.x + 10
	var key_width = D.keycap(self, key, Vector2(x, rect.position.y + 8))
	if not tier.is_empty() and rect.size.x >= 110: text(tier, Vector2(x + key_width + 6, rect.position.y + 11), "label", P.MUTED)
	# Ready reads from the colored name; only a cooldown needs a figure.
	if cooldown > 0 and rect.size.x >= 100:
		text_right("%s s" % T.decimal(cooldown), Vector2(rect.end.x - 10, rect.position.y + 11), "label", P.TEXT)
	fitted(title, Vector2(x, rect.position.y + 32), rect.size.x - 20, "strong", accent if cooldown <= 0 else P.MUTED)
	if cooldown > 0:
		D.bar(self, Rect2(x, rect.end.y - 7, rect.size.x - 20, 2), 1 - cooldown / maximum, accent)

func draw_hints(bar: Rect2) -> void:
	var total = 0.0
	for hint in HINTS:
		total += maxf(20.0, T.width(hint[0], "label") + 10) + 6 + T.width(hint[1], "body-sm") + 16
	var x = bar.get_center().x - (total - 16) / 2
	var y = bar.position.y - 30
	for hint in HINTS:
		x += D.keycap(self, hint[0], Vector2(x, y)) + 6
		text(hint[1], Vector2(x, y + 1), "body-sm", P.MUTED)
		x += T.width(hint[1], "body-sm") + 16

func draw_minimap(rect: Rect2) -> void:
	D.surface(self, rect, "hud")
	var well = Rect2(rect.position + Vector2(8, 8), rect.size - Vector2(16, 34))
	D.panel(self, well, P.BG, P.LINE, P.RADIUS_XS)
	for actor in arena.actors:
		if not actor.alive or actor == arena.player: continue
		var point = well.position + actor.pos / FormaArena.SIZE * well.size
		draw_circle(point, 5 if actor.is_boss else 2, actor.tint())
	if arena.player != null and arena.player.alive:
		var point = well.position + arena.player.pos / FormaArena.SIZE * well.size
		draw_arc(point, 5, 0, TAU, 24, P.TEXT, 1, true)
		draw_circle(point, 3, P.TEXT)
	text("O Nexo", Vector2(rect.position.x + 8, rect.end.y - 22), "label", P.MUTED)
	text_right("%s × %s" % [T.integer(FormaArena.SIZE.x), T.integer(FormaArena.SIZE.y)], Vector2(rect.end.x - 8, rect.end.y - 22), "label", P.MUTED)

# ---------- Overlays ----------

func modal_header(rect: Rect2, eyebrow: String, title: String, y: float) -> float:
	text_center(eyebrow, Vector2(rect.get_center().x, y), "label", P.MUTED)
	y += 22
	text_center(title, Vector2(rect.get_center().x, y), "title")
	return y + T.line_height("title") + 8

func draw_pause() -> void:
	scrim()
	var rect = FormaLayout.modal(screen_size(), Vector2(460, 330))
	D.surface(self, rect, "modal")
	var y = modal_header(rect, "Pausa", "Um instante de calma.", rect.position.y + 20)
	var body = "A sala continua ativa. Sua forma permanece vulnerável na arena." if arena.networked else "Sua jornada espera por você."
	y += wrapped(body, Rect2(rect.position.x + 24, y, rect.size.x - 48, 44), "body", P.MUTED, true) + 16
	var row = Rect2(rect.position.x + 16, y, rect.size.x - 32, 46)
	button("resume", "Continuar", row, true, P.GOLD, "Esc")
	button("help", "Controles e regras", Rect2(row.position + Vector2(0, 56), Vector2(row.size.x, 40)), false, P.GOLD, "H")
	button("menu", "Sair da partida", Rect2(row.position + Vector2(0, 106), Vector2(row.size.x, 40)))

func draw_result() -> void:
	scrim()
	var actor = arena.player
	var rect = FormaLayout.modal(screen_size(), Vector2(520, 440))
	D.surface(self, rect, "modal")
	var y = rect.position.y + 20
	if rect.size.y >= 420:
		D.sigil(self, Vector2(rect.get_center().x, y + 26), 22, actor.class_id, clock, false, -PI / 2)
		y += 62
	y = modal_header(rect, "Fim desta vida", "A essência permanece.", y)
	y += wrapped("Derrotado por %s. Seus dons desta vida se dissiparam." % arena.last_attacker, Rect2(rect.position.x + 24, y, rect.size.x - 48, 44), "body", P.MUTED, true) + 12
	D.hairline(self, Vector2(rect.position.x + 16, y), Vector2(rect.end.x - 16, y))
	y += 14
	var titles = ["Essência", "Nível", "Derrotados"]
	var values = [T.integer(actor.mass), str(actor.level), str(arena.kills)]
	var column = (rect.size.x - 32) / 3
	for i in range(3):
		var center_x = rect.position.x + 16 + column * (i + 0.5)
		text_center(titles[i], Vector2(center_x, y), "label", P.MUTED)
		text_center(values[i], Vector2(center_x, y + 18), "stat")
	y += 64
	D.hairline(self, Vector2(rect.position.x + 16, y), Vector2(rect.end.x - 16, y))
	y += 16
	var row = Rect2(rect.position.x + 16, y, rect.size.x - 32, 46)
	button("restart", "Jogar novamente", row, true, actor.tint(), "Enter")
	button("menu", "Escolher outra classe", Rect2(row.position + Vector2(0, 56), Vector2(row.size.x, 40)), false, P.GOLD, "Esc")

func draw_help() -> void:
	scrim()
	var rect = FormaLayout.modal(screen_size(), Vector2(720, 620))
	D.surface(self, rect, "modal")
	var p = rect.position
	text("Guia do viajante", p + Vector2(16, 18), "label", P.MUTED)
	text("Como jogar", p + Vector2(16, 36), "title")
	icon_button("close_help", "close", Rect2(rect.end.x - 56, p.y + 16, 40, 40))
	var help = "WASD / setas · mover\nMouse · mirar   Clique · atacar\nQ / clique direito · habilidade da classe\nR · escudo (1,5 s, sem atacar)\nEspaço · esquiva\nE · mover pelo mouse   F · autoataque\nB · bestiário   Esc · pausa   M · som\n\nColete essência para evoluir. Cada nível custa mais que o anterior, e as melhorias são aplicadas automaticamente no painel de evolução.\n\nChefes concedem dons a quem dá o golpe final. Morrer elimina os dons. Escudos impedem absorção. No multiplayer, os menus não pausam a sala.\n\nSalas automáticas: até 10 participantes, com vagas preenchidas por bots.\n\n"
	help += FormaSpells.description(arena.player.class_id if arena.mode != "menu" and arena.player != null else arena.selected_class)
	help_scroll_max = scrollable(help, Rect2(p + Vector2(16, 84), rect.size - Vector2(32, 166)), help_scroll)
	if help_scroll_max > 0: text("Role ou use as setas para ler mais", Vector2(p.x + 16, rect.end.y - 80), "body-sm", P.MUTED)
	button("close_help", "Entendi", Rect2(p.x + 16, rect.end.y - 62, rect.size.x - 32, 46), true, P.GOLD, "Esc")

func draw_bestiary() -> void:
	scrim()
	var rect = FormaLayout.modal(screen_size(), Vector2(1040, 720))
	D.surface(self, rect, "modal")
	var narrow = rect.size.x < 700 or rect.size.y < 550
	var p = rect.position
	text("Bestiário infinito", p + Vector2(16, 18), "label", P.MUTED)
	text("Os dez ancestrais", p + Vector2(16, 36), "title")
	icon_button("close_bestiary", "close", Rect2(rect.end.x - 56, p.y + 16, 40, 40))
	var columns = 5
	var gap = P.SPACE_2
	var card_width = (rect.size.x - 32 - gap * (columns - 1)) / columns
	var card_height = 52.0 if narrow else 124.0
	var owned: Array = arena.player.boons if arena.player != null and arena.mode != "menu" else []
	for i in range(10):
		var card = Rect2(p + Vector2(16 + i % columns * (card_width + gap), 84 + i / columns * (card_height + gap)), Vector2(card_width, card_height))
		var data = FormaBosses.DATA[i]
		var color: Color = data.color
		var selected = i == selected_boss
		buttons["boss_card_%d" % i] = card
		D.panel(self, card, P.RAISED if selected else P.PANEL, color if selected else P.LINE, P.RADIUS_MD, 2 if selected else 1)
		if i in owned: draw_colored_polygon(D.polygon(card.position + Vector2(card.size.x - 14, 14), 4, 4), P.GOLD)
		if narrow:
			FormaBossArt.creature(self, card.get_center(), 12, i, clock)
			continue
		FormaBossArt.creature(self, card.position + Vector2(card.size.x / 2, 46), 20, i, clock)
		text_center(ellipsized(data.name, card.size.x - 16, "strong"), Vector2(card.get_center().x, card.end.y - 46), "strong")
		text_center(ellipsized(data.boon, card.size.x - 16, "label"), Vector2(card.get_center().x, card.end.y - 22), "label", color)
	var top = p.y + 84 + (card_height + gap) * 2 + 12
	var chosen = FormaBosses.DATA[selected_boss]
	text(chosen.name, Vector2(p.x + 16, top), "heading", chosen.color)
	text(chosen.title, Vector2(p.x + 16, top + 30), "label", P.MUTED)
	var details = "Ataques · %s / %s\n\nDom · %s\n%s\n\nSó o golpe final recebe o dom. Se você já o possui, recupera 30%% da vida. Dons desaparecem ao morrer." % [chosen.attack, chosen.skill, chosen.boon, chosen.description.replace("\n", " ")]
	bestiary_scroll_max = scrollable(details, Rect2(p.x + 16, top + 54, rect.size.x - 32, rect.end.y - top - 132), bestiary_scroll)
	if bestiary_scroll_max > 0: text("Role ou use as setas para ler mais", Vector2(p.x + 16, rect.end.y - 80), "body-sm", P.MUTED)
	var half = (rect.size.x - 40) / 2
	button("boss_previous", "Anterior", Rect2(p.x + 16, rect.end.y - 56, half, 40), false, P.GOLD, "←")
	button("boss_next", "Próximo", Rect2(p.x + 24 + half, rect.end.y - 56, half, 40), false, P.GOLD, "→")

func scroll_details(amount: float) -> void:
	if help_open: help_scroll = clampf(help_scroll + amount, 0, help_scroll_max)
	elif bestiary_open: bestiary_scroll = clampf(bestiary_scroll + amount, 0, bestiary_scroll_max)
	queue_redraw()

func scrollable(value: String, rect: Rect2, offset: float) -> float:
	var lines = lines_for(value, rect.size.x, "body")
	var line_height = T.line_height("body")
	var maximum = maxf(0, lines.size() * line_height - rect.size.y)
	var scroll = minf(offset, maximum)
	for index in range(lines.size()):
		var y = rect.position.y + index * line_height - scroll
		if y >= rect.position.y and y + line_height <= rect.end.y + 0.5:
			text(lines[index], Vector2(rect.position.x, y), "body")
	return maximum
