class_name FormaOrb
extends RefCounted
var pos: Vector2
var value: float
var tint: int
func _init(point: Vector2 = Vector2.ZERO, amount: float = 2.0, color_id: int = 0) -> void:
	pos = point
	value = amount
	tint = color_id
