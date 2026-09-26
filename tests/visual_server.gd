extends Node

# Isolated manual browser QA room. Never exports, never touches real records.
# Connect to ws://127.0.0.1:19081; grants pending upgrades without hostile bots.
var game: Node
var prepared: Dictionary = {}

func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	# Match the production root path used by the browser's multiplayer API.
	get_tree().root.add_child.call_deferred(game)
	setup.call_deferred()

func setup() -> void:
	game.arena.rival_count = 0
	game.network.host(19081, 4, true)
	game.set_process_input(false)
	print("FORMA_VISUAL_QA_READY port=19081")

func _process(_delta: float) -> void:
	if game == null or game.network == null: return
	for actor in game.arena.actors:
		if actor.is_player and not prepared.has(actor.id):
			prepared[actor.id] = true
			actor.pos = FormaArena.SIZE / 2
			actor.shield_timer = 3600
			game.arena.gain_mass(actor, 200)
	game.arena.next_boss_at = game.arena.elapsed + 300
