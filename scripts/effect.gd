class_name FormaEffect
extends RefCounted
var pos: Vector2
var velocity: Vector2 = Vector2.ZERO
var ttl: float = 0.6
var duration: float = 0.6
var radius: float = 30.0
var color: Color = FormaPalette.GOLD
var kind: String = "ring"
var label: String = ""
var owner_id: int = -1
# Who a floating number belongs to: damage the local player takes reads as danger.
var target_id: int = -1

var damage: float = 17.0
var healing: float = 12.0
var status: String = ""
var rooted: bool = false
var pulses: int = 0
var pulse_timer: float = 0.65
