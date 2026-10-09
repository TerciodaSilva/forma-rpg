class_name FormaLayout
extends RefCounted

# HUD zones of the FORMA design system. Each zone holds one panel or cluster,
# pinned to an edge; the center of the screen stays clear.

const VITALS_HEIGHT = 112.0
const BUILD_HEIGHT = 224.0
const STANDING_HEIGHT = 190.0
const SESSION_WIDTH = 340.0
const SESSION_HEIGHT = 128.0
const SESSION_COMPACT_HEIGHT = 96.0
const SKILLS_WIDTH = 560.0
const SLOT_HEIGHT = 62.0

static func padding(size: Vector2) -> float:
	return 12.0 if size.x < 700 or size.y < 550 else 24.0

static func wide(size: Vector2) -> bool:
	return size.x >= 1000

static func health(size: Vector2) -> Rect2:
	var p = padding(size)
	return Rect2(p, p, minf(300, size.x - p * 2 - 96), VITALS_HEIGHT)

static func system(size: Vector2) -> Rect2:
	var p = padding(size)
	return Rect2(size.x - p - 88, p, 88, 40)

static func skills(size: Vector2) -> Rect2:
	var p = padding(size)
	var width = minf(SKILLS_WIDTH, size.x - p * 2)
	if size.x < 700: width = size.x - p * 2
	return Rect2((size.x - width) / 2, size.y - p - SLOT_HEIGHT, width, SLOT_HEIGHT)

static func build_expanded(size: Vector2) -> bool:
	return size.x >= 700 and size.y >= 600

static func build(size: Vector2) -> Rect2:
	var top = health(size).end.y + 8
	if build_expanded(size):
		return Rect2(health(size).position.x, top, 300, BUILD_HEIGHT)
	return Rect2(health(size).position.x, top, 140, 32)

# Room line, boss banner and notice. Top center on wide screens; above the
# action bar otherwise, so it never collides with the vitals panel.
static func session(size: Vector2) -> Rect2:
	var p = padding(size)
	var width = minf(SESSION_WIDTH, size.x - p * 2)
	if wide(size):
		return Rect2((size.x - width) / 2, p, width, SESSION_HEIGHT)
	return Rect2((size.x - width) / 2, skills(size).position.y - 8 - SESSION_COMPACT_HEIGHT, width, SESSION_COMPACT_HEIGHT)

static func standing_visible(size: Vector2) -> bool:
	return size.x >= 1100 and size.y >= 600

static func standing(size: Vector2) -> Rect2:
	var p = padding(size)
	return Rect2(size.x - p - 232, system(size).end.y + 8, 232, STANDING_HEIGHT)

static func map_visible(size: Vector2) -> bool:
	return wide(size) and size.y >= 600

static func minimap(size: Vector2) -> Rect2:
	var p = padding(size)
	return Rect2(size.x - p - 172, size.y - p - 144, 172, 144)

# Every visible zone by name; tests check that none overlap.
static func zones(size: Vector2) -> Dictionary:
	var result = {"vitals": health(size), "system": system(size), "skills": skills(size), "build": build(size), "session": session(size)}
	if standing_visible(size): result["standing"] = standing(size)
	if map_visible(size): result["map"] = minimap(size)
	return result

static func modal(size: Vector2, preferred: Vector2) -> Rect2:
	var p = padding(size)
	var dimensions = preferred.min(size - Vector2.ONE * p * 2)
	return Rect2((size - dimensions) / 2, dimensions)

# Tall screens move the hero and cards down so the menu does not leave a void
# under the footer.
static func menu_offset(size: Vector2) -> float:
	return clampf((size.y - 820) / 2, 0, 90)

static func class_cards(size: Vector2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var p = padding(size)
	var compact = size.x < 720
	var top = (84.0 if size.y < 500 else (150.0 if size.y < 650 else 230.0)) + menu_offset(size)
	var bottom = size.y - p - (208 if compact else 216)
	var height = clampf(bottom - top, 80, 300)
	if compact:
		result.append(Rect2(p, top, size.x - p * 2, height))
	else:
		var width = (size.x - p * 2 - 48) / 5
		for index in range(5):
			result.append(Rect2(p + index * (width + 12), top, width, height))
	return result

static func menu_name(size: Vector2) -> Rect2:
	var p = padding(size)
	return Rect2(p, class_cards(size)[0].end.y + 12, size.x - p * 2, 40)

# Primary action and secondary row follow the name field.
static func menu_footer(size: Vector2) -> float:
	return menu_name(size).end.y + 12
