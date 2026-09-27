class_name FormaInterface
extends Node2D

const P = preload("res://scripts/palette.gd")
const D = preload("res://scripts/paint.gd")
var arena: FormaArena
var clock: float = 0
var buttons: Dictionary = {}
var help_open: bool = false
var muted: bool = false
var bestiary_open: bool = false
var selected_boss: int = 0
var upgrades_collapsed: bool = false
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

func label(value: String, x: float, y: float, size: int = 18, color: Color = P.TEXT) -> void:
	D.text(self, value, Vector2(x, y), size, color)

func center(value: String, x: float, y: float, size: int = 18, color: Color = P.TEXT) -> void:
	D.centered(self, value, Vector2(x, y), size, color)

func fitted(value: String, point: Vector2, width: float, size: int = 16, color: Color = P.TEXT) -> void:
	var text = value
	var font = D.HEADING if size >= 22 else D.FONT
	while text.length() > 1 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		text = text.left(text.length() - 2) + "…"
	D.text(self, text, point, size, color)

func wrapped(value: String, rect: Rect2, size: int = 16, color: Color = P.TEXT) -> void:
	var y = rect.position.y
	for paragraph in value.split("\n"):
		var line = ""
		for word in paragraph.split(" "):
			var candidate = word if line.is_empty() else line + " " + word
			if not line.is_empty() and D.FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x:
				if y + size > rect.end.y: return
				label(line, rect.position.x, y, size, color)
				y += size + 6
				line = word
			else: line = candidate
		if y + size > rect.end.y: return
		label(line, rect.position.x, y, size, color)
		y += size + 6

func button(action: String, value: String, rect: Rect2, primary: bool = false, accent: Color = P.GOLD, font_size: int = 16) -> void:
	buttons[action] = rect
	var hovered = rect.has_point(get_global_mouse_position())
	var fill = accent if primary else P.RAISED
	if hovered: fill = fill.lightened(0.10)
	D.panel(self, rect, fill, accent if primary or hovered else P.LINE, 8)
	center(value, rect.get_center().x, rect.get_center().y - font_size * 0.65, font_size, P.BG if primary else P.TEXT)

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
	D.outline(self, D.polygon(point + Vector2(14, 17), 15, 6), P.GOLD, 1.5)
	draw_colored_polygon(D.polygon(point + Vector2(14, 17), 7, 3), P.GOLD)
	label("F O R M A", point.x + 40, point.y, 25)

func draw_menu() -> void:
	var size = screen_size()
	var p = FormaLayout.padding(size)
	var compact = size.x < 720
	var short_screen = size.y < 650
	draw_brand(Vector2(p, p))
	if size.x >= 600: label("MULTIPLAYER  /  SALAS AUTOMÁTICAS", size.x - p - 312, p + 8, 13, P.MUTED)
	if size.y < 500:
		label("Escolha sua essência", p, 53, 16, P.GOLD)
	else:
		var title_y = 65.0 if short_screen else 92.0
		label("Pequenas formas.", p, title_y, 28 if compact or short_screen else 44)
		label("Grandes lendas.", p, title_y + (34 if compact or short_screen else 52), 28 if compact or short_screen else 44, P.GOLD)
		if not short_screen:
			label("Escolha sua essência. Entre na arena.", p, title_y + (78 if compact else 109), 16, P.MUTED)
	var cards = FormaLayout.class_cards(size)
	if compact:
		draw_class_card(arena.selected_class, cards[0])
		button("menu_previous", "‹", Rect2(cards[0].position + Vector2(12, 12), Vector2(40, 36)))
		button("menu_next", "›", Rect2(cards[0].end.x - 52, cards[0].position.y + 12, 40, 36))
	else:
		for i in range(5): draw_class_card(i, cards[i])
	var footer_y = maxf(cards[0].end.y + 62, size.y - p - (144 if compact else 150))
	var accent: Color = P.CLASSES[arena.selected_class]
	button("start", "Jogar online  →", Rect2(p, footer_y, size.x - p * 2, 46), true, accent)
	if compact:
		button("settings", "Servidor / Ajustes", Rect2(p, footer_y + 56, size.x - p * 2, 40))
		var width = (size.x - p * 2 - 16) / 3
		button("bestiary", "Bestiário", Rect2(p, footer_y + 106, width, 36), false, P.GOLD, 14)
		button("help", "Como jogar", Rect2(p + width + 8, footer_y + 106, width, 36), false, P.GOLD, 14)
		button("mute", "Som: " + ("off" if muted else "on"), Rect2(p + (width + 8) * 2, footer_y + 106, width, 36), false, P.GOLD, 14)
	else:
		var width = (size.x - p * 2 - 36) / 4
		button("settings", "Servidor / Ajustes", Rect2(p, footer_y + 56, width, 40), false, P.GOLD, 14)
		button("bestiary", "Bestiário  [B]", Rect2(p + width + 12, footer_y + 56, width, 40))
		button("help", "Como jogar", Rect2(p + (width + 12) * 2, footer_y + 56, width, 40))
		button("mute", "Som: " + ("off" if muted else "on"), Rect2(p + (width + 12) * 3, footer_y + 56, width, 40))
		label("Recordes · essência %d  /  chefes %d" % [arena.best_mass, arena.best_boss_kills], p, footer_y + 112, 14, P.MUTED)

func draw_class_card(index: int, rect: Rect2) -> void:
	var data = FormaClasses.DATA[index]
	var color: Color = P.CLASSES[index]
	var selected = arena.selected_class == index
	buttons["class_%d" % index] = rect
	D.panel(self, rect, P.PANEL.lerp(color, 0.075 if selected else 0.012), color if selected else P.LINE, 12)
	var small = rect.size.y < 210
	D.sigil(self, rect.position + Vector2(rect.size.x / 2, 25 if rect.size.y < 110 else (42 if small else 65)), 16 if rect.size.y < 110 else (23 if small else 34), index, clock, selected, -PI / 2)
	center(data.name, rect.get_center().x, rect.position.y + (48 if rect.size.y < 110 else (79 if small else 118)), 20 if rect.size.x < 170 else 25)
	if rect.size.y >= 250:
		wrapped(data.description, Rect2(rect.position + Vector2(12, 169), Vector2(rect.size.x - 24, 60)), 14, P.MUTED)
	if rect.size.y < 140: return
	fitted(data.skill, rect.position + Vector2(12, rect.size.y - 32), rect.size.x - 24, 13, color)

func draw_hud() -> void:
	var actor = arena.player
	if actor == null: return
	var size = screen_size()
	var p = FormaLayout.padding(size)
	var rect = FormaLayout.health(size)
	var color = actor.tint()
	D.panel(self, rect, Color(P.PANEL, 0.94), P.LINE)
	fitted("%s · Nv. %d" % [FormaClasses.DATA[actor.class_id].name, actor.level], rect.position + Vector2(12, 9), rect.size.x - 24, 17, color)
	label("%d / %d PV" % [maxi(0, int(actor.hp)), int(actor.max_hp)], rect.position.x + 12, rect.position.y + 34, 12, P.TEXT)
	D.bar(self, Rect2(rect.position + Vector2(12, 56), Vector2(rect.size.x - 24, 6)), actor.hp / actor.max_hp, color)
	D.bar(self, Rect2(rect.position + Vector2(12, 71), Vector2(rect.size.x - 24, 3)), level_progress(), P.GOLD)
	button("pause", "Pausa", Rect2(size.x - p - 44, p, 44, 40), false, P.GOLD, 12)
	button("mute", "Som" if not muted else "Mudo", Rect2(size.x - p - 94, p, 44, 40), false, P.GOLD, 12)
	var summary_width = minf(300, size.x - p * 2)
	D.panel(self, Rect2(p, rect.end.y + 8, summary_width, 47), Color(P.PANEL, 0.9), P.LINE, 8)
	label("AMEAÇA %.1f · %s" % [arena.threat, ["NORMAL", "INTENSO", "CATACLISMO"][arena.difficulty]], p + 12, rect.end.y + 14, 12, P.GOLD)
	label("Éter %d  ·  Próximo nível: +%d" % [int(actor.mass), maxi(0, ceili(actor.next_level_mass - actor.mass))], p + 12, rect.end.y + 34, 12, P.TEXT)
	if size.x >= 850:
		center("O NEXO · %02d:%02d · %s" % [int(arena.elapsed) / 60, int(arena.elapsed) % 60, arena.room_label if arena.networked else "SOLO"], size.x / 2, p + 10, 14, P.MUTED)
	if size.x >= 1100 and size.y >= 600:
		draw_leaderboard(Rect2(size.x - p - 232, p + 54, 232, 200))
		draw_boons(Rect2(p, rect.end.y + 67, 300, 88))
		draw_status(Rect2(p, rect.end.y + 163, 300, 88))
	else:
		draw_status(Rect2(p, rect.end.y + 67, summary_width, 88))
		if size.y >= 600:
			button("bestiary", "Dons %d/10  [B]" % actor.boons.size(), Rect2(p, rect.end.y + 163, 145, 34), false, P.GOLD, 13)
	var bar = FormaLayout.skills(size)
	var slot_width = (bar.size.x - 16) / 3
	var data = FormaClasses.DATA[actor.class_id]
	draw_skill_slot(Rect2(bar.position, Vector2(slot_width, bar.size.y)), "CLIQUE", data.attack, 0, color)
	draw_skill_slot(Rect2(bar.position + Vector2(slot_width + 8, 0), Vector2(slot_width, bar.size.y)), "Q · %d/10" % FormaSpells.tier(actor.level), FormaSpells.title(actor), actor.skill_timer, color)
	draw_skill_slot(Rect2(bar.position + Vector2((slot_width + 8) * 2, 0), Vector2(slot_width, bar.size.y)), "R", "Escudo", maxf(actor.shield_skill_timer, actor.shield_skill_cooldown), P.GOLD)
	draw_skill_slot(Rect2(bar.position + Vector2((slot_width + 8) * 3, 0), Vector2(slot_width, bar.size.y)), "ESPAÇO", "Esquiva", actor.dash_cooldown, P.TEXT)
	if size.x >= 700 and size.y >= 520:
		label("WASD mover · Q habilidade · Espaço esquiva · F autoataque", p, bar.position.y - 24, 12, P.MUTED)
	if size.x >= 950 and size.y >= 600:
		draw_minimap(Rect2(size.x - p - 172, size.y - p - 144, 172, 144))
	if arena.boss != null and arena.boss.alive:
		var width = minf(340, size.x - p * 2)
		var x = (size.x - width) / 2
		var y = p + 55 if size.x >= 1000 else rect.end.y + 110
		fitted(arena.boss.label + " · encontro %d" % arena.encounters, Vector2(x, y), width, 14, arena.boss.tint())
		D.bar(self, Rect2(x, y + 24, width, 5), arena.boss.hp / arena.boss.max_hp, arena.boss.tint())
	elif arena.notice_time > 0 and size.x >= 1100:
		fitted(arena.notice, Vector2(340 + p, p + 60), size.x - 640 - p * 2, 13, P.GOLD)
	if actor.hp / actor.max_hp < 0.3 and arena.mode == "playing":
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(P.DANGER, 0.25 + sin(clock * 5) * 0.1), false, 3)

func level_progress() -> float:
	return FormaProgression.progress(arena.player)

func draw_leaderboard(rect: Rect2) -> void:
	D.panel(self, rect, Color(P.PANEL, 0.92), P.LINE)
	label("DOMÍNIO DA ARENA", rect.position.x + 12, rect.position.y + 12, 12, P.MUTED)
	var ranked = arena.leaderboard()
	for i in range(mini(5, ranked.size())):
		var actor = ranked[i]
		var pos = rect.position + Vector2(12, 39 + i * 27)
		fitted("%d. %s" % [i + 1, actor.label], pos, 147, 14, P.GOLD if actor == arena.player else P.TEXT)
		label(str(int(actor.mass)), rect.end.x - 58, pos.y, 12, P.MUTED)
	label("%d vivos · %d chefes seus" % [ranked.size(), arena.boss_kills], rect.position.x + 12, rect.end.y - 24, 12, P.MUTED)

func draw_boons(rect: Rect2) -> void:
	D.panel(self, rect, Color(P.PANEL, 0.92), P.LINE)
	label("DONS DESTA VIDA · %d/10" % arena.player.boons.size(), rect.position.x + 12, rect.position.y + 10, 12, P.GOLD)
	button("bestiary", "B", Rect2(rect.end.x - 40, rect.position.y + 6, 30, 26), false, P.GOLD, 12)
	for i in range(10):
		var slot = Rect2(rect.position + Vector2(12 + i * 27.6, 42), Vector2(24, 30))
		D.panel(self, slot, P.RAISED, FormaBosses.DATA[i].color if i in arena.player.boons else P.LINE, 4)
		if i in arena.player.boons: FormaBossArt.creature(self, slot.get_center(), 8, i, clock)
		buttons["inspect_boss_%d" % i] = slot

func draw_minimap(rect: Rect2) -> void:
	D.panel(self, rect, Color(P.PANEL, 0.94), P.LINE)
	var map_rect = Rect2(rect.position + Vector2(10, 10), rect.size - Vector2(20, 30))
	for actor in arena.actors:
		if actor.alive:
			draw_circle(map_rect.position + actor.pos / FormaArena.SIZE * map_rect.size, 3 if actor == arena.player else 2, P.TEXT if actor == arena.player else actor.tint())
	label("O NEXO", rect.position.x + 10, rect.end.y - 20, 10, P.MUTED)

func draw_skill_slot(rect: Rect2, key: String, title: String, cooldown: float, color: Color) -> void:
	D.panel(self, rect, Color(P.PANEL, 0.96), P.LINE)
	label(key, rect.position.x + 10, rect.position.y + 8, 11, P.MUTED)
	if cooldown > 0: label("%.1fs" % cooldown, rect.end.x - 44, rect.position.y + 8, 11, P.TEXT)
	fitted(title, rect.position + Vector2(10, 30), rect.size.x - 20, 14, color if cooldown <= 0 else P.MUTED)
	if cooldown > 0:
		var maximum: float = 4 if key == "ESPAÇO" else (6 if key == "R" else FormaClasses.DATA[arena.player.class_id].cooldown)
		D.bar(self, Rect2(rect.position + Vector2(10, 54), Vector2(rect.size.x - 20, 2)), 1 - cooldown / maximum, color)

func draw_status(rect: Rect2) -> void:
	var actor = arena.player
	if actor == null: return
	D.panel(self, rect, Color(P.PANEL, 0.92), P.LINE, 8)
	label("MELHORIAS AUTOMÁTICAS", rect.position.x + 12, rect.position.y + 10, 11, P.GOLD)
	label("Dano +%d · Vida máx %d" % [int(actor.damage_bonus), int(actor.max_hp)], rect.position.x + 12, rect.position.y + 31, 11, P.TEXT)
	label("Veloc. +%d%% · Coleta +%d px" % [int(round((actor.speed_multiplier - 1.0) * 100.0)), int(actor.pickup_bonus)], rect.position.x + 12, rect.position.y + 50, 11, P.TEXT)
	label("Regeneração +%.1f PV/s" % actor.regeneration, rect.position.x + 12, rect.position.y + 69, 11, P.TEXT)

func draw_upgrades() -> void:
	var rect = FormaLayout.upgrades(screen_size(), upgrades_collapsed)
	D.panel(self, rect, Color(P.PANEL, 0.96), P.GOLD, 10)
	label("EVOLUIR · %d pendente%s" % [arena.pending_upgrades, "s" if arena.pending_upgrades != 1 else ""], rect.position.x + 12, rect.position.y + 10, 13, P.GOLD)
	button("toggle_upgrades", "+" if upgrades_collapsed else "−", Rect2(rect.end.x - 38, rect.position.y + 6, 30, 28), false, P.GOLD, 16)
	if upgrades_collapsed: return
	if screen_size().x < 600 and screen_size().y < 650:
		var summaries = ["+10 dano", "+35 PV + cura", "+12% veloc.", "+55 coleta", "+2,5 PV/s"]
		var width = (rect.size.x - 24) / 3
		for i in range(arena.upgrade_options.size()):
			var option = arena.upgrade_options[i]
			var cell = Rect2(rect.position + Vector2(8 + i * (width + 4), 40), Vector2(width, 58))
			buttons["upgrade_%d" % i] = cell
			D.panel(self, cell, P.RAISED, P.LINE, 6)
			label(str(i + 1), cell.position.x + 6, cell.position.y + 3, 13, P.GOLD)
			fitted(FormaArena.UPGRADES[option].subtitle, cell.position + Vector2(6, 20), cell.size.x - 12, 10)
			fitted(summaries[option], cell.position + Vector2(6, 37), cell.size.x - 12, 11, P.MUTED)
		return
	var row_height = 38.0 if screen_size().y < 500 else 46.0
	var descriptions = ["+10 de dano básico", "+35 PV e cura completa", "+12% de velocidade", "+55 px de coleta", "+2,5 PV por segundo"]
	for i in range(arena.upgrade_options.size()):
		var option = arena.upgrade_options[i]
		var row = Rect2(rect.position + Vector2(8, 40 + i * (row_height + 4)), Vector2(rect.size.x - 16, row_height))
		buttons["upgrade_%d" % i] = row
		var hovered = row.has_point(get_global_mouse_position())
		D.panel(self, row, P.RAISED, P.GOLD if hovered else P.LINE, 6)
		label(str(i + 1), row.position.x + 9, row.position.y + 9, 18, P.GOLD)
		label(FormaArena.UPGRADES[option].title, row.position.x + 34, row.position.y + 3, 14, P.TEXT)
		label(descriptions[option], row.position.x + 34, row.position.y + 22, 11, P.MUTED)
	# No scrim, no simulation mode change, no input capture beyond each button.

func scrim() -> void:
	buttons.clear()
	draw_rect(Rect2(Vector2.ZERO, screen_size()), Color(P.BG, 0.94))

func draw_pause() -> void:
	scrim()
	var rect = FormaLayout.modal(screen_size(), Vector2(520, 350))
	center("Um instante de calma.", rect.get_center().x, rect.position.y + 15, 25)
	wrapped("A sala continua ativa. Sua forma permanece na arena." if arena.networked else "Sua jornada espera por você.", Rect2(rect.position + Vector2(16, 66), Vector2(rect.size.x - 32, 70)), 16, P.MUTED)
	var width = minf(330, rect.size.x - 16)
	var x = rect.get_center().x - width / 2
	button("resume", "Continuar  [Esc]", Rect2(x, rect.position.y + 146, width, 46), true)
	button("help", "Controles e regras", Rect2(x, rect.position.y + 204, width, 42))
	button("menu", "Sair da partida", Rect2(x, rect.position.y + 258, width, 42))

func draw_result() -> void:
	scrim()
	var rect = FormaLayout.modal(screen_size(), Vector2(640, 420))
	var y = rect.position.y
	center("A essência permanece.", rect.get_center().x, y + 10, 27)
	wrapped("Derrotado por %s. Seus dons desta vida se dissiparam." % arena.last_attacker, Rect2(rect.position + Vector2(12, 60), Vector2(rect.size.x - 24, 65)), 16, P.MUTED)
	var titles = ["ESSÊNCIA", "NÍVEL", "DERROTADOS"]
	var values = [str(int(arena.player.mass)), str(arena.player.level), str(arena.kills)]
	var col = rect.size.x / 3
	for i in range(3):
		var x = rect.position.x + i * col
		center(titles[i], x + col / 2, y + 143, 11, P.MUTED)
		center(values[i], x + col / 2, y + 166, 28, arena.player.tint())
	var width = minf(340, rect.size.x - 16)
	var x = rect.get_center().x - width / 2
	button("restart", "Jogar novamente  [Enter]", Rect2(x, y + 245, width, 46), true, arena.player.tint())
	button("menu", "Escolher outra classe", Rect2(x, y + 303, width, 42))

func draw_help() -> void:
	scrim()
	var rect = FormaLayout.modal(screen_size(), Vector2(720, 620))
	var p = rect.position
	label("GUIA DO VIAJANTE", p.x + 12, p.y + 6, 13, P.GOLD)
	var text = "WASD / Setas · Mover\nMouse / clique · Mirar e atacar\nQ / clique direito · Habilidade\nR · Escudo (1,5 s, sem atacar)\nEspaço · Esquiva\nMelhorias · Aplicadas automaticamente\nE / F · Mover pelo mouse / autoataque\nB · Bestiário   Esc · Pausa   M · Som\n\nColete essência para evoluir. Cada próximo nível custa mais. As melhorias são aplicadas automaticamente e aparecem no painel de status.\n\nChefes concedem dons ao golpe final. Morrer elimina os dons. Escudos impedem absorção. No multiplayer, os menus não pausam a sala."
	text += "\n\nSalas automáticas: até 10 participantes, com preenchimento equilibrado de vagas.\n\n" + FormaSpells.description(arena.player.class_id if arena.mode != "menu" and arena.player != null else arena.selected_class)
	help_scroll_max = scrollable(text, Rect2(p + Vector2(12, 40), rect.size - Vector2(24, 122)), help_scroll)
	if help_scroll_max > 0: label("Role ou use as setas para ler mais", p.x + 12, rect.end.y - 69, 12, P.MUTED)
	button("close_help", "Entendi  [Esc]", Rect2(p.x + 12, rect.end.y - 46, rect.size.x - 24, 40), true)

func draw_bestiary() -> void:
	scrim()
	var rect = FormaLayout.modal(screen_size(), Vector2(1040, 720))
	var narrow = rect.size.x < 700
	var p = rect.position
	label("BESTIÁRIO INFINITO", p.x + 12, p.y + 8, 18, P.GOLD)
	button("close_bestiary", "Fechar", Rect2(rect.end.x - 84, p.y + 4, 76, 34), false, P.GOLD, 14)
	var columns = 5
	var card_width = (rect.size.x - 24 - 24) / columns
	var card_height = 44.0 if narrow or rect.size.y < 550 else 96.0
	for i in range(10):
		var card = Rect2(p + Vector2(12 + i % columns * (card_width + 6), 53 + i / columns * (card_height + 6)), Vector2(card_width, card_height))
		var color: Color = FormaBosses.DATA[i].color
		buttons["boss_card_%d" % i] = card
		D.panel(self, card, P.RAISED if i == selected_boss else P.PANEL, color if i == selected_boss else P.LINE, 6)
		FormaBossArt.creature(self, card.get_center() - Vector2(0, 9 if card_height > 60 else 0), 18 if card_height > 60 else 12, i, clock)
		if card_height > 60: fitted(FormaBosses.DATA[i].name, card.position + Vector2(6, 70), card.size.x - 12, 12)
	var top = p.y + 65 + (card_height + 6) * 2
	var chosen = FormaBosses.DATA[selected_boss]
	label(chosen.name, p.x + 12, top, 24, chosen.color)
	var details = "Ataques: %s / %s\n\nDOM · %s\n%s\n\nO golpe final recebe o dom. Já possui? Cura de 30%%. Dons desaparecem ao morrer." % [chosen.attack, chosen.skill, chosen.boon, chosen.description]
	bestiary_scroll_max = scrollable(details, Rect2(p.x + 12, top + 44, rect.size.x - 24, rect.end.y - top - 118), bestiary_scroll)
	if bestiary_scroll_max > 0: label("Role ou use as setas para ler mais", p.x + 12, rect.end.y - 69, 12, P.MUTED)
	button("boss_previous", "‹ Anterior", Rect2(p.x + 12, rect.end.y - 44, (rect.size.x - 32) / 2, 38))
	button("boss_next", "Próximo ›", Rect2(rect.get_center().x + 4, rect.end.y - 44, (rect.size.x - 32) / 2, 38))

func scroll_details(amount: float) -> void:
	if help_open: help_scroll = clampf(help_scroll + amount, 0, help_scroll_max)
	elif bestiary_open: bestiary_scroll = clampf(bestiary_scroll + amount, 0, bestiary_scroll_max)
	queue_redraw()

func scrollable(value: String, rect: Rect2, offset: float) -> float:
	var lines: Array[String] = []
	for paragraph in value.split("\n"):
		var line = ""
		for word in paragraph.split(" "):
			var candidate = word if line.is_empty() else line + " " + word
			if not line.is_empty() and D.FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > rect.size.x:
				lines.append(line)
				line = word
			else: line = candidate
		lines.append(line)
	var maximum = maxf(0, lines.size() * 21 - rect.size.y)
	var scroll = minf(offset, maximum)
	for index in range(lines.size()):
		var y = rect.position.y + index * 21 - scroll
		if y >= rect.position.y and y + 18 <= rect.end.y:
			label(lines[index], rect.position.x, y, 15, P.TEXT)
	return maximum
