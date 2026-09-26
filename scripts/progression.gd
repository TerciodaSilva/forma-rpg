class_name FormaProgression
extends RefCounted

# Cost from the current level to the next. First level remains accessible;
# quadratic costs increasingly outweigh the farm advantage at high levels.
static func cost(level: int) -> float:
	var n = float(maxi(1, level) - 1)
	return 35.0 + 22.0 * n + 7.0 * n * n

static func progress(actor: FormaActor) -> float:
	var needed = cost(actor.level)
	return clampf(1.0 - (actor.next_level_mass - actor.mass) / needed, 0.0, 1.0)
