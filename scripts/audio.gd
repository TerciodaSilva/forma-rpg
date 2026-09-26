class_name FormaAudio
extends Node

var muted: bool = false
var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var last_collect: int = 0

func _ready() -> void:
	for cue in ["collect", "attack", "skill", "hit", "dash", "kill", "level", "click"]:
		streams[cue] = load("res://assets/" + cue + ".wav")
	for i in range(10):
		var player = AudioStreamPlayer.new()
		player.volume_db = -15
		add_child(player)
		players.append(player)

func play(cue: String) -> void:
	if muted or not streams.has(cue):
		return
	if cue == "collect":
		if Time.get_ticks_msec() - last_collect < 90:
			return
		last_collect = Time.get_ticks_msec()
	for player in players:
		if not player.playing:
			player.stream = streams[cue]
			player.volume_db = -23 if cue == "attack" or cue == "collect" else -15
			player.play()
			return

func toggle_mute() -> void:
	muted = not muted
	if muted:
		for player in players:
			player.stop()
