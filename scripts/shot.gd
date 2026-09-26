class_name FormaShot
extends RefCounted
var pos: Vector2
var velocity: Vector2
var damage: float
var ttl: float
var owner_id: int
var class_id: int
var radius: float = 7.0
var boss_kind: int = -1
var status: String = ""
var homing: float = 0.0
var target_id: int = -1

var pierce: int = 0
var hit_ids: Array[int] = []
var burning: bool = false
