class_name FormaActor
extends RefCounted

var peer_id: int = 0
var next_level_mass: float = 55.0
var pending_upgrades: int = 0
var upgrade_options: Array[int] = []
var kills: int = 0
var collected: int = 0
var boss_kills: int = 0
var last_attacker: String = ""
var elite: bool = false
var threat_tier: float = 1.0
var input_direction: Vector2 = Vector2.ZERO
var input_aim: Vector2 = Vector2.RIGHT
var input_attack: bool = false
var id: int = 0
var class_id: int = 0
var label: String = ""
var pos: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var mass: float = 20.0
var hp: float = 100.0
var max_hp: float = 100.0
var attack_timer: float = 0.0
var skill_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0
var shield_timer: float = 0.0
var slow_timer: float = 0.0
var flash: float = 0.0
var think_timer: float = 0.0
var destination: Vector2 = Vector2.ZERO
var level: int = 1
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var pickup_bonus: float = 0.0
var regeneration: float = 0.0
var is_player: bool = false
var is_boss: bool = false
var alive: bool = true
var boss_kind: int = -1
var boss_phase: int = 0
var boss_reborn: bool = false
var boons: Array[int] = []
var attack_count: int = 0
var boon_hits: int = 0
var phoenix_cooldown: float = 0.0
var stun_timer: float = 0.0
var burn_timer: float = 0.0
var burn_source: int = -1
var poison_timer: float = 0.0
var poison_source: int = -1

func radius() -> float:
	return minf(120.0, 16.0 + sqrt(mass) * 2.15)

func speed() -> float:
	if stun_timer > 0:
		return 0.0
	if is_boss:
		return float(FormaBosses.DATA[boss_kind].speed) * (0.6 if slow_timer > 0 else 1.0)
	var base: float = FormaClasses.DATA[class_id].speed
	return maxf(110.0, base - (radius() - 25.0) * 0.62) * speed_multiplier * (0.48 if slow_timer > 0 else 1.0)

func damage() -> float:
	return float(FormaClasses.DATA[class_id].damage) * (1.0 + (level - 1) * 0.09) * damage_multiplier

func setup(new_id: int, kind: int, point: Vector2, title: String, player: bool = false) -> void:
	id = new_id
	class_id = kind
	pos = point
	destination = point
	label = title
	is_player = player
	max_hp = FormaClasses.DATA[kind].hp
	hp = max_hp

func tint() -> Color:
	return FormaBosses.DATA[boss_kind].color if is_boss else FormaPalette.CLASSES[class_id]
