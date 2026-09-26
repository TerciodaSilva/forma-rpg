class_name FormaHazard
extends RefCounted

var pos: Vector2 = Vector2.ZERO
var end: Vector2 = Vector2.ZERO
var radius: float = 80.0
var owner_id: int = -1
var boss_kind: int = 0
var shape: String = "circle"
var status: String = ""
var warning: float = 1.0
var warning_duration: float = 1.0
var active_time: float = 0.3
var duration: float = 0.3
var damage: float = 20.0
var continuous: bool = false
var hit_ids: Array[int] = []
var pull: float = 0.0

func contains(point: Vector2, body_radius: float) -> bool:
	if shape == "line":
		return Geometry2D.get_closest_point_to_segment(point, pos, end).distance_to(point) <= radius + body_radius
	return pos.distance_to(point) <= radius + body_radius
