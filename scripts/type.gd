class_name FormaType
extends RefCounted

# Type styles of the FORMA design system. Callers pick a style by role;
# size, weight, tracking and casing come from here.

const OUTFIT = preload("res://assets/Outfit.ttf")
const WEIGHT_TAG = 2003265652 # OpenType "wght"

const STYLES = {
	"display": {"size": 44, "line": 48, "weight": 600},
	"title": {"size": 28, "line": 34, "weight": 560},
	"heading": {"size": 22, "line": 28, "weight": 560},
	"subhead": {"size": 17, "line": 24, "weight": 560},
	"body": {"size": 15, "line": 22, "weight": 420},
	"body-sm": {"size": 13, "line": 18, "weight": 420},
	"label": {"size": 11, "line": 14, "weight": 600, "tracking": 1, "upper": true},
	"stat": {"size": 28, "line": 32, "weight": 600},
	"float": {"size": 18, "line": 20, "weight": 680},
	# Code-side variants: body at button weight, and the tracked wordmark.
	"strong": {"size": 15, "line": 22, "weight": 560},
	"wordmark": {"size": 22, "line": 28, "weight": 560, "tracking": 5, "upper": true},
}

static var _fonts: Dictionary = {}

static func font(style: String) -> Font:
	if not _fonts.has(style):
		var data: Dictionary = STYLES[style]
		var variation = FontVariation.new()
		variation.base_font = OUTFIT
		variation.variation_opentype = {WEIGHT_TAG: float(data.weight)}
		variation.spacing_glyph = int(data.get("tracking", 0))
		_fonts[style] = variation
	return _fonts[style]

static func size(style: String) -> int:
	return int(STYLES[style].size)

static func line_height(style: String) -> float:
	return float(STYLES[style].line)

static func cased(style: String, value: String) -> String:
	return value.to_upper() if STYLES[style].get("upper", false) else value

static func width(value: String, style: String) -> float:
	return font(style).get_string_size(cased(style, value), HORIZONTAL_ALIGNMENT_LEFT, -1, size(style)).x

# Brazilian number formatting: 4.605 and 2,5.
static func integer(value: float) -> String:
	var digits = str(absi(int(value)))
	var grouped = ""
	while digits.length() > 3:
		grouped = "." + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped

static func decimal(value: float, places: int = 1) -> String:
	return (("%." + str(places) + "f") % value).replace(".", ",")
