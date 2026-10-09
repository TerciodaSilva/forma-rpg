class_name FormaPalette
extends RefCounted

# Color tokens of the FORMA design system (theme "Éter").
# Gold is reserved for the brand and progression; class colors identify;
# semantic colors report what is happening.

# Surfaces
const BG = Color("081015")
const FLOOR = Color("0b1318")
const PANEL = Color("101c23")
const RAISED = Color("172730")
const SCRIM = Color("081015f0")
const LINE = Color("2a3c43")
const LINE_STRONG = Color("5e757c")

# Text
const TEXT = Color("efece2")
const MUTED = Color("8fa3ab")
const ON_ACCENT = Color("081015")

# Brand and progression
const GOLD = Color("ecc986")
const GOLD_SOFT = Color("ecc9861f")
const XP = GOLD

# Classes
const MAGE = Color("b4a0ff")
const PALADIN = Color("f0ce88")
const KNIGHT = Color("ef8f83")
const ARCHER = Color("85cbe7")
const DRUID = Color("90d7ae")
const CLASSES = [MAGE, PALADIN, KNIGHT, ARCHER, DRUID]

# Semantic
const HP = TEXT
const DANGER = Color("ec777f")
const HEAL = DRUID
const SHIELD = Color("bfe3ff")
const BURN = Color("ff9b54")
const POISON = Color("b5e36b")
const CHILL = Color("9cc4ff")
const STUN = Color("fff0a8")
const WHITE = Color("ffffff")

# Opacity
const PANEL_ALPHA = 0.92
const PANEL_SOLID_ALPHA = 0.96
const GRID_ALPHA = 0.42
const LANDMARK_ALPHA = 0.28

# Spacing, radius and stroke, in logical pixels.
const SPACE_1 = 4.0
const SPACE_2 = 8.0
const SPACE_3 = 12.0
const SPACE_4 = 16.0
const SPACE_6 = 24.0
const SPACE_8 = 32.0
const RADIUS_XS = 4
const RADIUS_SM = 8
const RADIUS_MD = 12
const STROKE_HAIRLINE = 1.0
const STROKE_CONTROL = 1.5
const STROKE_FOCUS = 2.0
const STROKE_RING = 2.5

# Health is never class-colored, so a Paladin's HP bar cannot read as XP.
static func health(fraction: float) -> Color:
	return DANGER if fraction < 0.3 else HP
