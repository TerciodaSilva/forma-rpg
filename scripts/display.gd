class_name FormaDisplay
extends Node

var density: float = 1.0
var elapsed: float = 0.0

func _ready() -> void:
	get_window().size_changed.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.5:
		elapsed = 0
		refresh()

func refresh() -> void:
	if DisplayServer.get_name() == "headless": return
	var window = get_window()
	var pixel_ratio = DisplayServer.screen_get_scale()
	if OS.has_feature("web"):
		pixel_ratio = float(JavaScriptBridge.eval("window.devicePixelRatio || 1"))
	density = maxf(1.0, pixel_ratio)
	var logical = Vector2i(Vector2(window.size) / density)
	if logical.x <= 0 or logical.y <= 0: return
	# Canvas items render directly at the physical framebuffer resolution.
	# The logical canvas follows CSS/window dimensions; no fixed-ratio letterbox.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	if window.content_scale_size != logical:
		window.content_scale_size = logical
