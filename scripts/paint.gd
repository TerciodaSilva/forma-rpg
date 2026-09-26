class_name FormaPaint
extends RefCounted

const FONT = preload("res://assets/body_font.tres")
const HEADING = preload("res://assets/heading_font.tres")
const P = preload("res://scripts/palette.gd")

static func text(canvas: CanvasItem, value: String, point: Vector2, size: int = 18, color: Color = P.TEXT) -> void:
	canvas.draw_string(HEADING if size >= 22 else FONT, point + Vector2(0, size), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func centered(canvas: CanvasItem, value: String, point: Vector2, size: int = 18, color: Color = P.TEXT) -> void:
	var font = HEADING if size >= 22 else FONT
	var width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(canvas, value, point - Vector2(width / 2, 0), size, color)

static func panel(canvas: CanvasItem, rect: Rect2, fill: Color = P.PANEL, border: Color = P.LINE, radius: int = 12) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	canvas.draw_style_box(style, rect)

static func polygon(point: Vector2, radius: float, sides: int, angle: float = 0.0) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(sides):
		points.append(point + Vector2.from_angle(angle + TAU * i / sides - PI / 2) * radius)
	return points

static func outline(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	var closed = points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, color, width, true)

static func glow(canvas: CanvasItem, point: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	for i in range(4, 0, -1):
		canvas.draw_circle(point, radius * (1 + i * 0.27), Color(color, 0.018 * strength))

static func sigil(canvas: CanvasItem, point: Vector2, radius: float, kind: int, time: float, highlighted: bool = false, facing: float = 0.0) -> void:
	var color: Color = P.CLASSES[kind]
	var sides: int = FormaClasses.DATA[kind].shape
	glow(canvas, point, radius, color, 2 if highlighted else 1)
	var rotation = 0.0
	if kind == 2:
		rotation = PI / 4
	elif kind == 3:
		rotation = facing + PI / 2
	var points = polygon(point, radius, sides, rotation)
	canvas.draw_colored_polygon(points, color.darkened(0.78))
	outline(canvas, points, color, 2.3)
	outline(canvas, polygon(point, radius * 0.79, sides, rotation), Color(color, 0.32), 1)
	match kind:
		0:
			canvas.draw_circle(point + Vector2(0, 3), radius * 0.19, color)
			canvas.draw_arc(point, radius * 0.42, time, time + PI * 1.5, 32, color, 1.4, true)
		1:
			canvas.draw_line(point - Vector2(radius * 0.34, 0), point + Vector2(radius * 0.34, 0), color, 3, true)
			canvas.draw_line(point - Vector2(0, radius * 0.34), point + Vector2(0, radius * 0.34), color, 3, true)
		2:
			outline(canvas, polygon(point, radius * 0.31, 4), color, 2)
			canvas.draw_line(point + Vector2(-radius * 0.25, radius * 0.25), point + Vector2(radius * 0.25, -radius * 0.25), color, 2, true)
		3:
			var direction = Vector2.from_angle(facing)
			canvas.draw_line(point - direction * radius * 0.28, point + direction * radius * 0.31, color, 2, true)
		4:
			for i in range(3):
				outline(canvas, polygon(point + Vector2.from_angle(i * TAU / 3 + time * 0.15) * radius * 0.17, radius * 0.2, 4), color, 1.5)
	if highlighted:
		canvas.draw_arc(point, radius + 12, time * 0.22, time * 0.22 + PI * 1.3, 64, Color(color, 0.5), 1, true)
		for i in range(3):
			var dot = point + Vector2.from_angle(time * 0.22 + i * TAU / 3) * (radius + 12)
			canvas.draw_circle(dot, 2.5, color)

static func bar(canvas: CanvasItem, rect: Rect2, value: float, color: Color) -> void:
	panel(canvas, rect, P.RAISED, P.RAISED, int(rect.size.y / 2))
	if value > 0:
		var filled = Rect2(rect.position, Vector2(maxf(rect.size.y, rect.size.x * clampf(value, 0, 1)), rect.size.y))
		panel(canvas, filled, color, color, int(rect.size.y / 2))
