extends Node

var multiplayer_node
var failures = 0

func check(condition, message):
	print("VOICE_READY_CHECK ", message, " = ", condition)
	if not condition:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6.0), "timeout")
	multiplayer_node = Global.get_node("Multiplayer")
	var saved_player = Global.player
	var simulated_player = Node.new()
	add_child(simulated_player)
	Global.player = simulated_player
	Global.menu.in_game = true
	multiplayer_node.Voice.settings.enabled = true
	var offline_meter = multiplayer_node.Voice.meter_layer.get_child(0)
	offline_meter._process(0.05)
	check(not offline_meter.visible, "voice meter hidden in singleplayer")
	Global.menu.in_game = false
	Global.player = saved_player
	simulated_player.queue_free()
	multiplayer_node.Voice.test_capture = true
	if HOST:
		multiplayer_node.config.hostPort = PORT
		multiplayer_node.host_server()
	else:
		multiplayer_node.join_to_server("127.0.0.1", PORT)
	var deadline = OS.get_ticks_msec() + 30000
	while multiplayer_node.players.size() < 2 and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.1), "timeout")
	check(multiplayer_node.players.size() == 2, "two players connected")
	if multiplayer_node.players.size() < 2:
		finish()
		return
	Global.menu.open_online_destination(true)
	yield(get_tree().create_timer(2.0), "timeout")
	var overlay = multiplayer_node.CounterOp
	check(is_instance_valid(overlay.ready_count), "ready counter exists")
	if HOST and is_instance_valid(overlay.ready_count):
		var return_button = Global.menu.menu[Global.menu.LEVEL_SELECT].get_child(0)
		check(overlay.ready_count.rect_position == return_button.rect_position + Vector2(Global.menu.button_size.x, (Global.menu.button_size.y - overlay.ready_count.rect_size.y) / 2), "ready counter sits right of Return")
		check(overlay.ready_count.text.begins_with("Ready: "), "ready counter uses compact label")
		var start_button = Global.menu.menu[Global.menu.LEVEL_SELECT].get_child(7)
		start_button.disabled = true
		start_button.texture_disabled = start_button.texture_normal
		start_button.modulate = Color(1, 0.2, 0.2)
		Global.menu._apply_competitive_start_gate()
		check(start_button.texture_disabled == Global.menu.BUTTON_TEXTURES_D[0] and start_button.modulate == Color.white, "Start uses neutral disabled art outside level select")
	if not HOST:
		check(not Global.menu.campaign_label.visible, "client campaign title hidden")
		var start_button = null
		for button in Global.menu.menu[Global.menu.LEVEL_SELECT].get_children():
			if button is TextureButton and button.has_meta("menu_button_type") and button.get_meta("menu_button_type") == Global.menu.B_MISSION_START:
				start_button = button
				break
		if start_button != null:
			check(overlay.ready_button.rect_position == start_button.rect_position, "client Ready matches Start")
	if HOST:
		multiplayer_node.goto_scene_host(Global.LEVELS[1])
	deadline = OS.get_ticks_msec() + 60000
	while (Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not multiplayer_node.player_scene_loaded or get_tree().paused) and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.1), "timeout")
	check(multiplayer_node.player_scene_loaded and Global.menu.in_game, "mission loaded")
	if not multiplayer_node.player_scene_loaded:
		finish()
		return
	multiplayer_node.Voice.settings.enabled = true
	var meter = multiplayer_node.Voice.meter_layer.get_child(0)
	for index in range(112):
		multiplayer_node.Voice.input_peak = pow(float(index % 28) / 27.0, 2.0) * 0.25
		yield(get_tree().create_timer(0.025), "timeout")
	yield(get_tree(), "idle_frame")
	check(meter.visible, "voice meter visible in mission")
	check(meter.rect_position.x > get_viewport().size.x * 0.45 and meter.rect_position.y > get_viewport().size.y * 0.7, "voice meter at bottom right")
	check(meter.rect_size.x >= 300 and meter.rect_size.y >= 58, "voice meter enlarged")
	for peer in multiplayer_node.players:
		if peer == multiplayer_node.NetworkBridge.get_id():
			continue
		var remote_puppet = multiplayer_node.players[peer].get("puppet")
		if not is_instance_valid(remote_puppet):
			continue
		var original_golem = remote_puppet.implant_state.get("golem_exosystem", false)
		remote_puppet.implant_state["golem_exosystem"] = false
		Global.player._play_sound(peer, "FootStep")
		var remote_step = remote_puppet.get_node_or_null("Puppet/PlayerModel/SFX/FootStep")
		check(is_instance_valid(remote_step) and remote_step.stream == Global.player.playerWalkSound, "other players keep their normal footsteps")
		remote_puppet.implant_state["golem_exosystem"] = true
		Global.player._play_sound(peer, "FootStep")
		check(remote_step.stream == Global.player.orbWalkSound, "Golem footsteps follow the wearer")
		remote_puppet.implant_state["golem_exosystem"] = original_golem
		break
	var pause_menu = multiplayer_node.get_node("Menu")
	check(pause_menu.has_node("Settings"), "online pause has a Settings square")
	check(pause_menu.get_node("Stats").get_stylebox("panel") == load("res://MOD_CONTENT/CruS Online/redpanel.tres"), "online pause Stats uses the dark red panel")
	pause_menu.show_menu()
	pause_menu.open_settings()
	yield(get_tree().create_timer(0.3), "timeout")
	check(Global.menu.online_pause_settings and Global.menu.get_node("Settings").visible, "online pause opens game Settings")
	var settings_return = Global.menu.go_back(Global.menu.SETTINGS, Global.menu.menu[Global.menu.SETTINGS].get_child(0))
	if settings_return is GDScriptFunctionState:
		yield(settings_return, "completed")
	check(pause_menu.visible and not Global.menu.online_pause_settings and not Global.menu.visible, "Settings returns to online pause")
	pause_menu.hide_menu()
	if HOST:
		var capture = get_viewport().get_texture().get_data()
		capture.flip_y()
		check(capture.save_png("E:/Cruelty/Online/dist/voice-meter-in-game.png") == OK, "voice meter screenshot saved")
	finish()

func finish():
	print("VOICE_READY_TEST_RESULT failures=", failures)
	get_tree().quit(1 if failures else 0)
