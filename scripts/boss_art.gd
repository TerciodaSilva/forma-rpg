class_name FormaBossArt
extends RefCounted

const D = preload("res://scripts/paint.gd")
const P = preload("res://scripts/palette.gd")

static func part(canvas: CanvasItem, point: Vector2, radius: float, sides: int, color: Color, angle: float = 0) -> void:
	var vertices = D.polygon(point, radius, sides, angle)
	canvas.draw_colored_polygon(vertices, color.darkened(0.8))
	D.outline(canvas, vertices, color, 1.8)

static func eye(canvas: CanvasItem, point: Vector2, size: float, color: Color) -> void:
	canvas.draw_circle(point, size * 2, Color(color, 0.1))
	canvas.draw_circle(point, size, color)

static func creature(canvas: CanvasItem, point: Vector2, radius: float, kind: int, time: float) -> void:
	var color: Color = FormaBosses.DATA[kind].color
	var s = radius / 70.0
	var wave = sin(time * 2) * 5 * s
	D.glow(canvas, point, radius, color, 1.4)
	match kind:
		FormaBosses.Kind.VOID:
			for i in range(3):
				D.outline(canvas, D.polygon(point, radius * (1.0 + i * 0.19), 3 + i, time * (0.15 if i % 2 else -0.2)), Color(color, 0.7 - i * 0.18), 2)
			canvas.draw_circle(point, radius * 0.57, P.BG)
			canvas.draw_arc(point, radius * 0.59, 0, TAU, 64, color, 3, true)
			for i in range(5):
				part(canvas, point + Vector2.from_angle(time * 0.4 + i * TAU / 5) * radius * 1.2, 8 * s, 4, color)
			eye(canvas, point, 7 * s, P.WHITE)
		FormaBosses.Kind.DRAGON:
			for side in [-1, 1]:
				var wing = PackedVector2Array([point + Vector2(side * 24, 5) * s, point + Vector2(side * 115, -72 + wave) * s, point + Vector2(side * 96, 26) * s, point + Vector2(side * 50, 2) * s])
				canvas.draw_colored_polygon(wing, color.darkened(0.85))
				D.outline(canvas, wing, color, 2)
				canvas.draw_line(wing[0], wing[2], Color(color, 0.55), 1.3, true)
				part(canvas, point + Vector2(side * 25, -50) * s, 24 * s, 3, color, side * 0.4)
			part(canvas, point + Vector2(0, 15) * s, 48 * s, 6, color)
			part(canvas, point + Vector2(0, -34) * s, 36 * s, 5, color, PI)
			part(canvas, point + Vector2(0, 75) * s, 28 * s, 3, color, PI)
			for side in [-1, 1]:
				eye(canvas, point + Vector2(side * 12, -40) * s, 4 * s, P.GOLD)
		FormaBosses.Kind.NECROMANCER:
			part(canvas, point + Vector2(0, 25) * s, 64 * s, 3, color)
			part(canvas, point + Vector2(0, -28) * s, 34 * s, 6, color)
			canvas.draw_line(point + Vector2(65, -60) * s, point + Vector2(65, 75) * s, color, 3, true)
			part(canvas, point + Vector2(65, -67) * s, 20 * s, 4, color)
			for side in [-1, 1]:
				eye(canvas, point + Vector2(side * 12, -30) * s, 5 * s, color)
				part(canvas, point + Vector2(side * 20, 15) * s, 12 * s, 4, color)
			for i in range(3):
				var soul = point + Vector2(-76 + i * 10, -48 + i * 44 + sin(time * 2 + i) * 7) * s
				eye(canvas, soul, 6 * s, color)
				canvas.draw_arc(soul, 12 * s, 0, PI * 1.5, 16, Color(color, 0.4), 1, true)
		FormaBosses.Kind.HYDRA:
			part(canvas, point + Vector2(0, 34) * s, 56 * s, 6, color)
			for i in range(3):
				var head = point + Vector2((i - 1) * 60, -48 + sin(time * 1.8 + i) * 7) * s
				canvas.draw_line(point + Vector2((i - 1) * 22, 30) * s, head, color.darkened(0.6), 19 * s, true)
				canvas.draw_line(point + Vector2((i - 1) * 22, 30) * s, head, color, 2, true)
				part(canvas, head, 28 * s, 5, color, PI)
				for side in [-1, 1]:
					eye(canvas, head + Vector2(side * 9, -4) * s, 3 * s, P.GOLD)
		FormaBosses.Kind.PHOENIX:
			for side in [-1, 1]:
				for i in range(4):
					var feather = point + Vector2(side * (32 + i * 21), -20 + i * 10 + wave) * s
					part(canvas, feather, (42 - i * 4) * s, 3, color, side * (-0.6 - i * 0.12))
			for i in range(3):
				part(canvas, point + Vector2((i - 1) * 20, 64) * s, 37 * s, 3, color, PI + (i - 1) * 0.25)
			part(canvas, point, 37 * s, 4, color)
			part(canvas, point + Vector2(0, -42) * s, 22 * s, 3, color)
			eye(canvas, point + Vector2(0, -39) * s, 4 * s, P.WHITE)
		FormaBosses.Kind.GOLEM:
			for side in [-1, 1]:
				part(canvas, point + Vector2(side * 62, -10 + wave * 0.3) * s, 32 * s, 4, color, PI / 4)
				part(canvas, point + Vector2(side * 75, 37) * s, 25 * s, 6, color)
				part(canvas, point + Vector2(side * 27, 66) * s, 25 * s, 4, color, PI / 4)
			part(canvas, point, 55 * s, 6, color)
			part(canvas, point + Vector2(0, -59) * s, 28 * s, 4, color, PI / 4)
			part(canvas, point, 19 * s, 4, P.MAGE)
			for side in [-1, 1]:
				eye(canvas, point + Vector2(side * 10, -60) * s, 3 * s, P.MAGE)
		FormaBosses.Kind.KRAKEN:
			for i in range(8):
				var angle = i * TAU / 8
				var previous = point + Vector2.from_angle(angle) * 30 * s
				for j in range(3):
					var segment = point + Vector2.from_angle(angle + sin(time * 1.8 + i + j) * 0.22) * (52 + j * 23) * s
					canvas.draw_line(previous, segment, color.darkened(0.6), (15 - j * 3) * s, true)
					part(canvas, segment, (12 - j * 2) * s, 4, color, angle)
					previous = segment
			part(canvas, point, 44 * s, 8, color)
			for side in [-1, 1]:
				eye(canvas, point + Vector2(side * 15, -6) * s, 6 * s, P.GOLD)
		FormaBosses.Kind.BASILISK:
			for i in range(7, -1, -1):
				var segment = point + Vector2(sin(time * 1.5 + i * 0.7) * 32, i * 15 - 24) * s
				part(canvas, segment, (32 - i * 2.5) * s, 4, color, PI / 4)
			part(canvas, point + Vector2(0, -48) * s, 43 * s, 3, color, PI)
			for side in [-1, 1]:
				part(canvas, point + Vector2(side * 30, -68) * s, 18 * s, 3, color, side * 0.2)
				eye(canvas, point + Vector2(side * 15, -54) * s, 5 * s, P.GOLD)
		FormaBosses.Kind.UNICORN:
			part(canvas, point + Vector2(-5, 15) * s, 47 * s, 6, color, PI / 6)
			for i in range(3):
				part(canvas, point + Vector2(-55 - i * 9, 4 + i * 11) * s, 20 * s, 3, P.MAGE, -PI / 2)
			for side in [-1, 1]:
				canvas.draw_line(point + Vector2(side * 27, 40) * s, point + Vector2(side * 39, 79) * s, color, 5 * s, true)
			part(canvas, point + Vector2(28, -28) * s, 33 * s, 4, color, 0.35)
			part(canvas, point + Vector2(42, -70) * s, 30 * s, 3, P.WHITE, 0.25)
			eye(canvas, point + Vector2(38, -34) * s, 4 * s, P.MAGE)
			canvas.draw_arc(point, 95 * s, time * 0.3, time * 0.3 + PI, 40, Color(color, 0.4), 1, true)
		FormaBosses.Kind.DJINN:
			for i in range(5):
				var center = point + Vector2(sin(time * 2 + i) * i * 3, 30 + i * 12) * s
				canvas.draw_arc(center, (40 - i * 7) * s, time + i, time + i + PI * 1.6, 30, Color(color, 0.8 - i * 0.1), 2, true)
			part(canvas, point + Vector2(0, -5) * s, 46 * s, 4, color)
			part(canvas, point + Vector2(0, -54) * s, 25 * s, 6, color)
			for side in [-1, 1]:
				part(canvas, point + Vector2(side * 67, 3 + wave) * s, 18 * s, 4, color)
				canvas.draw_line(point + Vector2(side * 25, -15) * s, point + Vector2(side * 67, 3 + wave) * s, color, 2, true)
				eye(canvas, point + Vector2(side * 8, -55) * s, 3 * s, P.WHITE)
