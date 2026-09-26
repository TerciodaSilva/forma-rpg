class_name FormaLayout
extends RefCounted

static func padding(size: Vector2) -> float:
	return 12.0 if size.x < 700 or size.y < 550 else 24.0

static func health(size: Vector2) -> Rect2:
	var p = padding(size)
	return Rect2(p, p, minf(300, size.x - p * 2 - 100), 86)

static func skills(size: Vector2) -> Rect2:
	var p = padding(size)
	var width = minf(510, size.x - p * 2)
	return Rect2(p, size.y - p - 62, width, 62)

static func upgrades(size: Vector2, collapsed: bool = false) -> Rect2:
	var p = padding(size)
	var height = 40.0 if collapsed else (174.0 if size.y < 500 else 204.0)
	var width = minf(296, size.x - p * 2)
	if size.x < 800 and size.y < 650:
		width = minf(width, maxf(224, size.x * 0.38))
	if size.x < 600 and size.y < 650:
		width = size.x - p * 2
		if not collapsed: height = 106
	var bottom = size.y - p
	# Narrow screens stack the upgrade panel above the action bar.
	if size.x < 950: bottom = skills(size).position.y - 10
	return Rect2(size.x - p - width, bottom - height, width, height)

static func modal(size: Vector2, preferred: Vector2) -> Rect2:
	var p = padding(size)
	var dimensions = preferred.min(size - Vector2.ONE * p * 2)
	return Rect2((size - dimensions) / 2, dimensions)

static func class_cards(size: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var p = padding(size)
	var compact = size.x < 720
	var top = 84.0 if size.y < 500 else (150.0 if size.y < 650 else 230.0)
	var bottom = size.y - p - (208 if compact else 216)
	var height = clampf(bottom - top, 80, 290)
	if compact:
		result.append(Rect2(p, top, size.x - p * 2, height))
	else:
		var width = (size.x - p * 2 - 48) / 5
		for index in range(5):
			result.append(Rect2(p + index * (width + 12), top, width, height))
	return result

static func menu_name(size: Vector2) -> Rect2:
	var p = padding(size)
	return Rect2(p, class_cards(size)[0].end.y + 10, size.x - p * 2, 40)
