class_name FormaPaint
extends RefCounted

const P = preload("res://scripts/palette.gd")

# Draws text in a named FormaType style. `point` is the top-left of the line box.
static func styled(canvas: CanvasItem, value: String, point: Vector2, style: String = "body", color: Color = P.TEXT) -> void:
	var size = FormaType.size(style)
	canvas.draw_string(FormaType.font(style), point + Vector2(0, size), FormaType.cased(style, value), HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func styled_center(canvas: CanvasItem, value: String, point: Vector2, style: String = "body", color: Color = P.TEXT) -> void:
	styled(canvas, value, point - Vector2(FormaType.width(value, style) / 2, 0), style, color)

static func styled_right(canvas: CanvasItem, value: String, point: Vector2, style: String = "body", color: Color = P.TEXT) -> void:
	styled(canvas, value, point - Vector2(FormaType.width(value, style), 0), style, color)

# Surfaces by role: "hud" over live play, "control" for panels holding controls,
# "modal" for overlay bodies, "raised" for rows and slots inside a panel.
static func surface(canvas: CanvasItem, rect: Rect2, role: String = "hud", border: Color = P.LINE, border_width: float = P.STROKE_HAIRLINE) -> void:
	var fill: Color = P.PANEL
	var radius = P.RADIUS_MD
	match role:
		"hud": fill = Color(P.PANEL, P.PANEL_ALPHA)
		"control": fill = Color(P.PANEL, P.PANEL_SOLID_ALPHA)
		"raised":
			fill = P.RAISED
			radius = P.RADIUS_SM
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(round(border_width)))
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	canvas.draw_style_box(style, rect)

# A key cap chip; returns its width so callers can place text after it.
static func keycap(canvas: CanvasItem, key: String, point: Vector2, color: Color = P.MUTED, border: Color = P.LINE_STRONG, fill: Color = P.BG) -> float:
	var width = maxf(20.0, FormaType.width(key, "label") + P.SPACE_2 + 2)
	var rect = Rect2(point, Vector2(width, 20))
	panel(canvas, rect, fill, border, P.RADIUS_XS)
	styled_center(canvas, key, Vector2(rect.get_center().x, point.y + 3), "label", color)
	return width

# Drawn glyphs on a 16px grid, single color.
static func icon(canvas: CanvasItem, kind: String, center: Vector2, color: Color) -> void:
	var o = center - Vector2(8, 8)
	var w = P.STROKE_CONTROL
	match kind:
		"pause":
			canvas.draw_line(o + Vector2(5.5, 3.5), o + Vector2(5.5, 12.5), color, w + 0.5, true)
			canvas.draw_line(o + Vector2(10.5, 3.5), o + Vector2(10.5, 12.5), color, w + 0.5, true)
		"sound", "muted":
			outline(canvas, PackedVector2Array([o + Vector2(2.5, 6), o + Vector2(5, 6), o + Vector2(8.5, 3), o + Vector2(8.5, 13), o + Vector2(5, 10), o + Vector2(2.5, 10)]), color, w)
			if kind == "sound":
				canvas.draw_arc(o + Vector2(8, 8), 3.5, -PI / 3, PI / 3, 12, color, w, true)
				canvas.draw_arc(o + Vector2(8, 8), 6.3, -PI / 3, PI / 3, 16, color, w, true)
			else:
				canvas.draw_line(o + Vector2(11, 6), o + Vector2(15, 10), color, w, true)
				canvas.draw_line(o + Vector2(15, 6), o + Vector2(11, 10), color, w, true)
		"close":
			canvas.draw_line(o + Vector2(4, 4), o + Vector2(12, 12), color, w, true)
			canvas.draw_line(o + Vector2(12, 4), o + Vector2(4, 12), color, w, true)
		"prev":
			canvas.draw_polyline(PackedVector2Array([o + Vector2(10, 3.5), o + Vector2(5.5, 8), o + Vector2(10, 12.5)]), color, w, true)
		"next":
			canvas.draw_polyline(PackedVector2Array([o + Vector2(6, 3.5), o + Vector2(10.5, 8), o + Vector2(6, 12.5)]), color, w, true)

static func hairline(canvas: CanvasItem, from: Vector2, to: Vector2) -> void:
	canvas.draw_line(from, to, P.LINE, P.STROKE_HAIRLINE)

static func panel(canvas: CanvasItem, rect: Rect2, fill: Color = P.PANEL, border: Color = P.LINE, radius: int = 12, border_width: int = 1) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
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
