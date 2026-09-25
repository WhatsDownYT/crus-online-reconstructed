extends Node

var failures = 0

func check(ok, label):
	print("MODE_CHECK host=", HOST, " ", label, "=", ok)
	if not ok:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6), "timeout")
	var mp = Global.get_node("Multiplayer")
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
		check(mp.players.size() == 1, "Host starts alone")
		mp.CounterOp.host_apply_mode("counter_op")
		check(mp.hostSettings.gameMode == "cruelty", "Counter-Op blocked for solo host")
		mp.CounterOp.host_apply_mode("deathmatch")
		check(mp.hostSettings.gameMode == "cruelty", "Deathmatch blocked for solo host")
		var menu = get_tree().get_nodes_in_group("MultiplayerMenu")[0]
		menu.enable_menu()
		var tabs = menu.get_node("CenterContainer/TabContainer")
		var modes = tabs.get_node("Modes")
		modes._refresh_mode_availability()
		check(not modes.mode_list.is_item_disabled(1) and not modes.mode_list.is_item_disabled(2), "Solo mode choices selectable")
		modes.mode_list.select(1)
		modes._gamemode_select(1)
		check(modes.gamemodeSelected == 1 and modes.play_button.disabled, "Solo Deathmatch selected but Play disabled")
		modes.mode_list.select(2)
		modes._gamemode_select(2)
		check(modes.gamemodeSelected == 2 and modes.play_button.disabled, "Solo Counter-Op selected but Play disabled")
		var implants = tabs.get_node("Implants")
		implants.update()
		menu._sync_implant_tab()
		tabs.current_tab = implants.get_index()
		yield(get_tree(), "idle_frame")
		check(implants.implant_scroll.rect_size.x <= 340 and implants.controls.rect_size.x >= 280, "Implant panel width")
		var controls = implants.controls
		check(controls.get_node("Button").get_index() == controls.get_node("DeletePreset").get_index() + 1, "Preset save follows Delete preset")
		check(controls.get_node("Button3").rect_position.y > controls.rect_size.y - 110 and controls.get_node("Button4").rect_position.y > controls.get_node("Button3").rect_position.y, "Ban and allow at bottom")
		check(tabs.get_node("Player/Save").rect_position.y == tabs.get_node("Host/Save").rect_position.y, "Player save at bottom")
		tabs.current_tab = tabs.get_node("Player").get_index()
		yield(get_tree(), "idle_frame")
		check(tabs.get_node("Player/Save").rect_size.y <= 30, "Player save normal height")
		tabs.current_tab = tabs.get_node("Modes").get_index()
		menu._cruelty_settings_pressed()
		yield(get_tree(), "idle_frame")
		var panel = menu.cruelty_settings_tab
		check(panel.get_node("Save").rect_position.y + panel.get_node("Save").rect_size.y >= panel.rect_size.y - 4, "Cruelty save at bottom")
		check(tabs.rect_size == Vector2(661, 549), "Menu size unchanged")
		check(Global.menu._counterop_restricted_path("res://Levels/Training_Level.tscn"), "CSHQ restricted")
		check(not Global.menu._counterop_restricted_path("res://Levels/Level1.tscn"), "Pharmakokinetics allowed")
	else:
		yield(get_tree().create_timer(5), "timeout")
		mp.join_to_server("127.0.0.1", PORT)
	for _attempt in range(100):
		if mp.players.size() >= 2:
			break
		yield(get_tree().create_timer(0.1), "timeout")
	if HOST:
		check(mp.players.size() >= 2, "Second player joined")
		var modes = get_tree().get_nodes_in_group("MultiplayerMenu")[0].get_node("CenterContainer/TabContainer/Modes")
		modes._refresh_mode_availability()
		check(not modes.play_button.disabled and modes.gamemodeSelected == 2, "Selected Counter-Op Play enabled with two players")
		mp.CounterOp.host_apply_mode("counter_op")
		check(mp.hostSettings.gameMode == "counter_op", "Counter-Op selectable with two players")
	print("MODE_TEST_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
