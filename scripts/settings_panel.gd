class_name FormaSettingsPanel
extends CanvasLayer

signal closed
var network: FormaNetwork
var arena: FormaArena
var scroll: ScrollContainer
var box: VBoxContainer
var root: Control
var menu_obscured: bool = false
var menu_name: LineEdit
var nickname: LineEdit
var address: LineEdit
var port: SpinBox
var slots: SpinBox
var bots: OptionButton
var difficulty: OptionButton
var message: Label

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var theme = Theme.new()
	theme.default_font = preload("res://assets/body_font.tres")
	theme.default_font_size = 19
	for type in ["Label", "Button", "LineEdit", "OptionButton", "SpinBox"]:
		theme.set_color("font_color", type, FormaPalette.TEXT)
		theme.set_color("font_hover_color", type, FormaPalette.GOLD)
		theme.set_color("font_focus_color", type, FormaPalette.GOLD)
		if type == "Label": continue
		for state in ["normal", "hover", "pressed", "focus", "read_only"]:
			var style = StyleBoxFlat.new()
			style.bg_color = FormaPalette.RAISED
			style.border_color = FormaPalette.GOLD if state in ["hover", "focus"] else FormaPalette.LINE
			style.set_border_width_all(1)
			style.set_corner_radius_all(7)
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			theme.set_stylebox(state, type, style)
	root.theme = theme
	var backdrop = ColorRect.new()
	backdrop.color = Color(FormaPalette.BG, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	get_viewport().size_changed.connect(resize_panel)
	resize_panel()
	add_label(box, "CONFIGURAÇÃO DA ARENA", FormaPalette.GOLD)
	add_label(box, "Multiplayer · todos contra todos")
	add_label(box, "Até 10 participantes · bots preenchem as vagas", FormaPalette.MUTED)
	nickname = LineEdit.new()
	nickname.placeholder_text = "Seu nome"
	nickname.text = "Viajante"
	nickname.max_length = 16
	box.add_child(nickname)
	add_label(box, "Servidor de salas automáticas", FormaPalette.MUTED)
	address = LineEdit.new()
	address.text = default_address()
	address.placeholder_text = "wss://seu-servidor.exemplo"
	box.add_child(address)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	add_label(row, "Porta")
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = 9080
	row.add_child(port)
	add_label(row, "Vagas")
	slots = SpinBox.new()
	slots.min_value = 2
	slots.max_value = 10
	slots.value = 10
	row.add_child(slots)
	add_label(box, "Regras para o servidor que você criar", FormaPalette.MUTED)
	difficulty = OptionButton.new()
	for title in ["Desafio crescente · Normal", "Desafio crescente · Intenso", "Desafio crescente · Cataclismo"]:
		difficulty.add_item(title)
	difficulty.select(arena.difficulty)
	box.add_child(difficulty)
	bots = OptionButton.new()
	bots.add_item("Bots automáticos nas vagas livres", 0)
	bots.select(0)
	bots.disabled = true
	box.add_child(bots)
	add_button(box, "Jogar · encontrar sala", func():
		apply_settings()
		network.join_room(address.text.strip_edges(), nickname.text, arena.selected_class))
	var host_button = add_button(box, "Criar sala neste computador", func():
		apply_settings()
		network.nickname = nickname.text
		network.host(int(port.value), int(slots.value)))
	host_button.disabled = OS.has_feature("web")
	if OS.has_feature("web"):
		add_label(box, "O servidor cria salas e troca bots por jogadores automaticamente.", FormaPalette.MUTED)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 50
	message.add_theme_color_override("font_color", FormaPalette.GOLD)
	box.add_child(message)
	add_button(box, "Aplicar e voltar", func():
		if network.active and not arena.networked: network.close()
		apply_settings()
		hide_panel())
	network.status_changed.connect(func(text: String):
		message.text = text
		if not network.active: show_panel())
	network.entered.connect(hide_panel)
	load_settings()
	menu_name = LineEdit.new()
	menu_name.theme = theme
	menu_name.placeholder_text = "Nome do personagem"
	menu_name.tooltip_text = "Nome do seu personagem · até 16 caracteres"
	menu_name.max_length = 16
	menu_name.text = nickname.text
	menu_name.text_changed.connect(func(value: String): nickname.text = value)
	nickname.text_changed.connect(func(value: String): menu_name.text = value)
	add_child(menu_name)
	root.hide()

func add_label(parent: Control, text: String, color: Color = FormaPalette.TEXT) -> void:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if parent is HBoxContainer else Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func apply_settings() -> void:
	arena.difficulty = difficulty.selected
	arena.rival_count = 9
	var config = ConfigFile.new()
	config.set_value("settings", "version", 3)
	config.set_value("settings", "nickname", nickname.text)
	config.set_value("settings", "address", address.text)
	config.set_value("settings", "port", port.value)
	config.set_value("settings", "slots", slots.value)
	config.set_value("settings", "difficulty", difficulty.selected)
	config.set_value("settings", "bots", bots.selected)
	config.save("user://forma_settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://forma_settings.cfg") != OK: return
	nickname.text = str(config.get_value("settings", "nickname", "Viajante")).left(16)
	address.text = str(config.get_value("settings", "address", default_address()))
	port.value = clampf(float(config.get_value("settings", "port", 9080)), 1024, 65535)
	slots.value = clampf(float(config.get_value("settings", "slots", 10)), 2, 10) if int(config.get_value("settings", "version", 0)) >= 3 else 10
	difficulty.select(clampi(int(config.get_value("settings", "difficulty", 1)), 0, 2))
	bots.select(0)
	arena.difficulty = difficulty.selected
	arena.rival_count = 9

func resize_panel() -> void:
	var size = get_viewport().get_visible_rect().size
	var width = minf(600, size.x - 32)
	scroll.position = Vector2((size.x - width) / 2, 24)
	scroll.size = Vector2(width, size.y - 48)

func show_panel() -> void:
	root.show()
	message.text = network.status

func hide_panel() -> void:
	root.hide()
	closed.emit()

func is_open() -> bool:
	return root.visible

func _process(_delta: float) -> void:
	if menu_name == null: return
	menu_name.visible = arena.mode == "menu" and not root.visible and not network.active and not menu_obscured
	var rect = FormaLayout.menu_name(get_viewport().get_visible_rect().size)
	menu_name.position = rect.position
	menu_name.size = rect.size

func start_match() -> void:
	if network.active: return
	menu_name.release_focus()
	nickname.text = menu_name.text.strip_edges()
	if nickname.text.is_empty(): nickname.text = "Viajante"
	menu_name.text = nickname.text
	apply_settings()
	show_panel()
	network.join_room(address.text.strip_edges(), nickname.text, arena.selected_class)

func default_address() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.hostname + ':9080'"))
	return "ws://127.0.0.1:9080"
