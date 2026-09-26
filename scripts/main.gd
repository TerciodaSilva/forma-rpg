extends Node2D

var network: FormaNetwork
var settings: FormaSettingsPanel
var arena: FormaArena
var world: FormaWorldView
var ui: FormaInterface
var bestiary_resume: bool = false
var audio: FormaAudio

func _ready() -> void:
	add_child(FormaDisplay.new())
	configure_inputs()
	arena = FormaArena.new()
	add_child(arena)
	world = FormaWorldView.new()
	world.arena = arena
	add_child(world)
	ui = FormaInterface.new()
	ui.arena = arena
	add_child(ui)
	audio = FormaAudio.new()
	add_child(audio)
	arena.sound_requested.connect(audio.play)
	network = FormaNetwork.new()
	network.name = "Network"
	network.arena = arena
	add_child(network)
	settings = FormaSettingsPanel.new()
	settings.network = network
	settings.arena = arena
	add_child(settings)
	settings.menu_name.text_submitted.connect(func(_value: String): handle_action("start"))
	network.entered.connect(func():
		if arena.player != null: world.camera = arena.player.pos)
	if "--server" in OS.get_cmdline_user_args():
		var server_port = 9080
		var server_slots = 10
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--port="): server_port = clampi(int(arg.trim_prefix("--port=")), 1024, 65535)
			if arg.begins_with("--players="): server_slots = clampi(int(arg.trim_prefix("--players=")), 2, 10)
			if arg.begins_with("--difficulty="): arena.difficulty = clampi(int(arg.trim_prefix("--difficulty=")), 0, 2)
		var error = network.host(server_port, server_slots, true)
		if error != OK: get_tree().quit(1)
		else: print("FORMA_SERVER_READY port=%d" % server_port)
		world.hide()
		ui.hide()
	get_window().focus_exited.connect(on_focus_lost)
	if "--preview-arena" in OS.get_cmdline_user_args():
		arena.new_run(0)
		arena.mode = "paused"
		world.camera = arena.player.pos
		arena.mode = "playing"
	if "--capture-menu" in OS.get_cmdline_user_args():
		capture.call_deferred("menu")
	elif "--capture-arena" in OS.get_cmdline_user_args():
		arena.new_run(0)
		for i in range(5):
			arena.actors[i + 1].pos = arena.player.pos + Vector2.from_angle(i * 1.4) * (250 + i * 45)
		world.camera = arena.player.pos
		capture.call_deferred("arena")
	elif "--capture-upgrade" in OS.get_cmdline_user_args():
		arena.new_run(3)
		arena.gain_mass(arena.player, 40)
		arena.show_upgrade()
		capture.call_deferred("upgrade")
	elif "--capture-bestiary" in OS.get_cmdline_user_args():
		ui.bestiary_open = true
		capture.call_deferred("bestiary")
	elif "--capture-boss" in OS.get_cmdline_user_args():
		arena.new_run(0)
		arena.spawn_boss(1)
		arena.boss.pos = arena.player.pos + Vector2(240, -80)
		FormaBossCombat.special(arena, arena.boss, arena.player)
		world.camera = arena.player.pos
		capture.call_deferred("boss")
	elif "--capture-help" in OS.get_cmdline_user_args():
		ui.help_open = true
		capture.call_deferred("help")

func configure_inputs() -> void:
	var actions = {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN]}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in actions[action]:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:
	settings.menu_obscured = ui.help_open or ui.bestiary_open
	arena.move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	arena.aim_point = world.screen_to_world(get_global_mouse_position())
	if network.active:
		var blocked = arena.mode != "playing" or ui.bestiary_open or ui.help_open or settings.is_open()
		var direction = arena.move_input
		if arena.mouse_move and direction.length() < 0.1 and arena.player != null:
			var offset = arena.aim_point - arena.player.pos
			direction = offset.normalized() * clampf((offset.length() - 25) / 100, 0, 1)
		network.tick(delta, Vector2.ZERO if blocked else direction, arena.aim_point, not blocked and (arena.attack_held or arena.auto_attack))
	else:
		arena.step(delta)

func _input(event: InputEvent) -> void:
	if settings.is_open() or (event is InputEventKey and settings.menu_name.visible and settings.menu_name.has_focus()):
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			ui.scroll_details(-63 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 63)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				arena.attack_held = false
				return
			var action = ui.action_at(get_global_mouse_position())
			if not action.is_empty():
				handle_action(action)
			elif arena.mode == "playing" and not ui.help_open:
				arena.attack_held = true
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and arena.mode == "playing" and not ui.help_open:
			player_command("skill")
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_M:
		handle_action("mute")
		return
	if key == KEY_F11:
		var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if key == KEY_B and not ui.help_open:
		handle_action("close_bestiary" if ui.bestiary_open else "bestiary")
		return
	if ui.bestiary_open:
		if key in [KEY_UP, KEY_DOWN]:
			ui.scroll_details(-63 if key == KEY_UP else 63)
		elif key == KEY_ESCAPE:
			handle_action("close_bestiary")
		elif key == KEY_LEFT or key == KEY_RIGHT:
			ui.selected_boss = posmod(ui.selected_boss + (-1 if key == KEY_LEFT else 1), 10)
			ui.bestiary_scroll = 0
		return
	if ui.help_open:
		if key in [KEY_UP, KEY_DOWN]:
			ui.scroll_details(-63 if key == KEY_UP else 63)
		elif key == KEY_ESCAPE or key == KEY_ENTER:
			handle_action("close_help")
		return
	match arena.mode:
		"menu":
			if key >= KEY_1 and key <= KEY_5:
				handle_action("class_%d" % (key - KEY_1))
			elif key == KEY_ENTER:
				handle_action("start")
			elif key == KEY_H:
				handle_action("help")
		"playing":
			if key >= KEY_1 and key <= KEY_3 and arena.pending_upgrades > 0:
				player_command("upgrade", key - KEY_1)
				return
			match key:
				KEY_Q: player_command("skill")
				KEY_SPACE: player_command("dash")
				KEY_ESCAPE: handle_action("pause")
				KEY_E: arena.mouse_move = not arena.mouse_move
				KEY_F: arena.auto_attack = not arena.auto_attack
		"paused":
			if key == KEY_ESCAPE:
				handle_action("resume")
		"lost":
			if key == KEY_ENTER:
				handle_action("restart")
			elif key == KEY_ESCAPE:
				handle_action("menu")

func handle_action(action: String) -> void:
	audio.play("click")
	if action.begins_with("boss_card_"):
		ui.selected_boss = int(action.trim_prefix("boss_card_"))
		ui.bestiary_scroll = 0
	elif action.begins_with("inspect_boss_"):
		ui.selected_boss = int(action.trim_prefix("inspect_boss_"))
		handle_action("bestiary")
	elif action.begins_with("class_"):
		arena.selected_class = int(action.trim_prefix("class_"))
	elif action.begins_with("upgrade_"):
		player_command("upgrade", int(action.trim_prefix("upgrade_")))
	else:
		match action:
			"toggle_upgrades":
				ui.upgrades_collapsed = not ui.upgrades_collapsed
			"menu_next":
				arena.selected_class = (arena.selected_class + 1) % 5
			"menu_previous":
				arena.selected_class = posmod(arena.selected_class - 1, 5)
			"boss_next":
				ui.selected_boss = (ui.selected_boss + 1) % 10
				ui.bestiary_scroll = 0
			"boss_previous":
				ui.selected_boss = posmod(ui.selected_boss - 1, 10)
				ui.bestiary_scroll = 0
			"settings":
				settings.show_panel()
			"start", "restart":
				if network.active:
					network.command("respawn")
					return
				settings.start_match()
			"pause", "resume":
				arena.attack_held = false
				if network.active:
					network.local_pause = not network.local_pause
					network.update_local_mode()
				else:
					arena.toggle_pause()
			"menu":
				if network.active: network.close()
				else: arena.save_record()
				arena.mode = "menu"
			"bestiary":
				bestiary_resume = arena.mode == "playing"
				if bestiary_resume:
					if network.active: network.local_pause = true
					arena.mode = "paused"
				arena.attack_held = false
				ui.bestiary_open = true
			"close_bestiary":
				ui.bestiary_open = false
				if bestiary_resume:
					if network.active: network.local_pause = false
					arena.mode = "playing"
				bestiary_resume = false
			"help": ui.help_open = true
			"close_help": ui.help_open = false
			"mute":
				audio.toggle_mute()
				ui.muted = audio.muted
	ui.queue_redraw()

func player_command(action: String, value: int = 0) -> void:
	if network.active:
		network.command(action, value)
	else:
		match action:
			"skill": arena.use_skill(arena.player)
			"dash": arena.dash()
			"upgrade": arena.choose_upgrade(value)

func on_focus_lost() -> void:
	if network.active:
		arena.attack_held = false
		if not network.dedicated and arena.mode == "playing":
			network.local_pause = true
			network.update_local_mode()
		return
	var capturing = false
	for argument in OS.get_cmdline_user_args():
		capturing = capturing or argument.begins_with("--capture-")
	if arena.mode == "playing" and not capturing:
		arena.mode = "paused"
		arena.attack_held = false

func capture(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screenshot = get_viewport().get_texture().get_image()
	screenshot.save_png("res://artifacts/" + name + ".png")
	get_tree().quit()
