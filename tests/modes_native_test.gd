extends Node

var mp
var failures = 0
var hashes = {}

func check(ok, label):
	print("MODE_CHECK host=", HOST, " ", label, "=", ok)
	if not ok:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func check_files():
	for path in hashes:
		check(File.new().get_md5(path) == hashes[path], "save unchanged: " + path)

func run():
	yield(get_tree().create_timer(6), "timeout")
	mp = Global.get_node("Multiplayer")
	mp.Voice.test_capture = true
	Global.save_game()
	Global._backup()
	Global.STOCKS.save_stocks()
	for path in ["user://savegame.save", "user://backup.save", "user://stocks.save", "user://stock_backup.save"]:
		hashes[path] = File.new().get_md5(path)
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
		check(mp.players.size() == 1, "Host starts alone")
		mp.CounterOp.host_apply_mode("counter_op")
		check(mp.hostSettings.gameMode == "cruelty", "Counter-Op cannot start alone")
		mp.CounterOp.host_apply_mode("deathmatch")
		check(mp.hostSettings.gameMode == "cruelty", "Deathmatch cannot start alone")
		var solo_modes = get_tree().get_nodes_in_group("MultiplayerMenu")[0].get_node("CenterContainer/TabContainer/Modes")
		solo_modes._refresh_mode_availability()
		check(solo_modes.mode_list.is_item_disabled(1) and solo_modes.mode_list.is_item_disabled(2), "Solo mode choices disabled")
	else:
		mp.join_to_server("127.0.0.1", PORT)
	while mp.players.size() < 2:
		yield(get_tree().create_timer(0.1), "timeout")
	if HOST:
		yield(get_tree().create_timer(1), "timeout")
		var menu = get_tree().get_nodes_in_group("MultiplayerMenu")[0]
		menu.enable_menu()
		var tabs = menu.get_node("CenterContainer/TabContainer")
		tabs.current_tab = tabs.get_node("VC").get_index()
		yield(get_tree().create_timer(0.3), "timeout")
		check(tabs.get_current_tab_control() == tabs.get_node("VC"), "VC remains selected")
		tabs.current_tab = tabs.get_node("Player").get_index()
		yield(get_tree().create_timer(0.3), "timeout")
		check(tabs.get_current_tab_control() == tabs.get_node("Player"), "Can leave VC for Player")
		menu.enable_menu()
		check(tabs.get_current_tab_control() == tabs.get_node("Main"), "Opening menu starts on Main")
		menu.get_node("ErrorHandler").hide()
		menu._cruelty_settings_pressed()
		yield(get_tree().create_timer(0.3), "timeout")
		check(menu.cruelty_settings_tab.get_parent() != tabs, "Cruelty top header hidden")
		check(not menu.has_node("DeathmatchSettings"), "Empty Deathmatch settings removed")
		var implants = tabs.get_node("Implants")
		implants.update()
		menu._sync_implant_tab()
		menu._close_mode_settings()
		tabs.current_tab = implants.get_index()
		check(tabs.get_current_tab_control() == implants, "Implants tab selectable")
		print("MENU_BOUNDS tabs=", tabs.rect_size, " minimum=", tabs.get_combined_minimum_size(), " center=", menu.get_node("CenterContainer").rect_size)
		check(tabs.rect_size == Vector2(661, 549), "Menu keeps original size")
		var grid = implants.implant_scroll.get_node("ImplantGrid")
		check(grid.get_child_count() == implants.displayed.size() and implants.implant_scroll.scroll_vertical_enabled, "Implants use scrolling icon grid")
		yield(get_tree(), "idle_frame")
		check(implants.implant_scroll.rect_size.x <= 340 and implants.controls.rect_size.x >= 280, "Implant grid fits five columns and rules get remaining width")
		var bottom_save = implants.controls.get_node("Button")
		var ban_button = implants.controls.get_node("Button3")
		var allow_button = implants.controls.get_node("Button4")
		check(bottom_save.rect_position.y + bottom_save.rect_size.y >= implants.controls.rect_size.y - 4 and ban_button.rect_position.y > implants.controls.rect_size.y - 110 and allow_button.rect_position.y > ban_button.rect_position.y, "Implant save and bulk actions sit at bottom")
		check(tabs.get_node("Player/Save").rect_position.y == tabs.get_node("Host/Save").rect_position.y, "Player save matches Host bottom position")
		check(abs(grid.get_child(1).rect_position.x - grid.get_child(0).rect_position.x - 64) < 1 and abs(grid.get_child(5).rect_position.y - grid.get_child(0).rect_position.y - 64) < 1, "Implant squares touch")
		implants.hover_implant(0)
		check(Global.menu.hover_info.get_node("Name").text.begins_with(implants.displayed[0]), "Implant hover shows name")
		implants.hide_implant_hover()
		yield(get_tree(), "idle_frame")
		var implant_capture = get_viewport().get_texture().get_data()
		implant_capture.flip_y()
		implant_capture.save_png("E:/Cruelty/Online/dist/implants-menu.png")
		tabs.current_tab = tabs.get_node("Modes").get_index()
		menu._cruelty_settings_pressed()
		implants.allow_all()
		implants.toggle_implant(0)
		check(mp.is_implant_banned(implants.displayed[0]), "Implant ban applied")
		check(implants.implant_buttons[0].modulate == Color(1, 0.2, 0.2), "Banned icon turns red")
		implants.toggle_implant(0)
		check(not mp.is_implant_banned(implants.displayed[0]), "Banned implant can be allowed again")
		check(implants.implant_buttons[0].modulate == Color.white, "Allowed icon turns white")
		implants.ban_all()
		check(mp.hostSettings.bannedImplants.size() == implants.displayed.size(), "Ban all implants")
		implants.controls.get_node("LineEdit").text = "Native test"
		implants.save_preset()
		var saved_preset = implants.preset_picker.get_selected()
		check(saved_preset > 0, "Saved preset appears in dropdown")
		implants.allow_all()
		implants.load_preset(saved_preset)
		check(mp.hostSettings.bannedImplants.size() == implants.displayed.size(), "Implant preset restored")
		implants.delete_preset()
		check(not mp.config.implantPresets.has("Native test"), "Preset can be deleted")
		implants.delete_preset()
		implants.controls.get_node("LineEdit").text = "A very long preset name that should never change the menu width"
		implants.save_preset()
		yield(get_tree(), "idle_frame")
		check(tabs.get_combined_minimum_size().x == 661 and tabs.rect_size.x == 661, "Implant and preset clicks keep menu width")
		implants.delete_preset()
		var original_head = Global.implants.head_implant
		for implant in Global.implants.IMPLANTS:
			if implant.head and implant.i_name in implants.displayed:
				Global.implants.head_implant = implant
				break
		mp.enforce_implant_bans()
		var equipment = Global.menu.get_node("Character_Menu/Character_Container")
		var money_before = Global.money
		equipment._on_implant_pressed(0)
		check(Global.money == money_before and Global.implants.head_implant == Global.implants.empty_implant, "Normal equipment menu rejects banned implants")
		check(Global.implants.head_implant == Global.implants.empty_implant, "Banned equipped implant removed")
		implants.allow_all()
		Global.implants.head_implant = original_head
		menu.rect_scale = Vector2(0.8, 0.8)
		menu._sync_cruelty_settings_tab()
		menu._layout_mode_panels()
		var button = menu.cruelty_bottom_tab
		var center = button.get_global_transform().xform(button.rect_size * 0.5)
		var local = tabs.get_global_transform().affine_inverse().xform(center)
		check(abs(local.x - tabs.rect_size.x * 0.5) < 1 and local.y > tabs.rect_size.y and local.y < tabs.rect_size.y + button.rect_size.y, "bottom tab centered outside border")
		menu._cruelty_settings_pressed()
		menu.rect_scale = Vector2.ONE
		menu._sync_cruelty_settings_tab()
		menu._layout_mode_panels()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		var cruelty_save = menu.cruelty_settings_tab.get_node("Save")
		check(cruelty_save.rect_position.y + cruelty_save.rect_size.y >= menu.cruelty_settings_tab.rect_size.y - 4, "Cruelty save sits at bottom")
		var capture = get_viewport().get_texture().get_data()
		capture.flip_y()
		capture.save_png("E:/Cruelty/Online/dist/cruelty-settings.png")
		menu.counterop_settings_tab.get_node("VBoxContainer/Lives/LivesEdit").value = 3
		check(mp.config.reviveLives == 3 and menu.cruelty_settings_tab.get_node("VBoxContainer/Lives/LivesEdit").value == 3, "Counter-Op controls update Cruelty storage")
		menu.counterop_settings_tab.get_node("VBoxContainer/ReviveTimer/ReviveEdit").value = 7
		implants.toggle_implant(0)
		mp.CounterOp.host_apply_mode("counter_op")
		check(mp.hostSettings.reviveLives == 3 and mp.hostSettings.helpTimer == 7, "Counter-Op applies shared revive settings")
		check(Global.menu._counterop_level_locked(0) and not Global.menu._counterop_level_locked(1), "Counter-Op locks CSHQ, not Pharmakokinetics")
	while not Global.campaign_save.active:
		yield(get_tree().create_timer(0.1), "timeout")
	if not HOST:
		var client_menu = get_tree().get_nodes_in_group("MultiplayerMenu")[0]
		client_menu.enable_menu()
		check(not client_menu.implants_tab_shown, "Client has no Implants tab")
		var client_tabs = client_menu.get_node("CenterContainer/TabContainer")
		client_tabs.current_tab = client_tabs.get_node("VC").get_index()
		yield(get_tree().create_timer(0.3), "timeout")
		check(client_tabs.get_current_tab_control() == client_tabs.get_node("VC"), "Client VC remains selected")
		client_tabs.current_tab = client_tabs.get_node("Main").get_index()
		yield(get_tree().create_timer(0.3), "timeout")
		check(client_tabs.get_current_tab_control() == client_tabs.get_node("Main"), "Client can leave VC for Main")
	check(mp.hostSettings.bannedImplants.size() == 1, "Implant rules synchronized")
	if not HOST:
		var implant_panel = get_tree().get_nodes_in_group("MultiplayerMenu")[0].get_node("CenterContainer/TabContainer/Implants")
		implant_panel.update()
		check(not implant_panel.can_edit(), "Client implant rules read only")
		implant_panel.allow_all()
		check(mp.hostSettings.bannedImplants.size() == 1, "Client cannot clear host bans")
	var original_campaign = Global.campaign_save.campaign.duplicate(true)
	var original_implants = Global.implants.purchased_implants.duplicate(true)
	var original_money = Global.money
	var original_owned = Global.STOCKS.stocks[0].owned
	Global.LEVELS_UNLOCKED += 1
	Global.LEVEL_TIMES_RAW[1] = 1234
	Global.DEAD_CIVS.append("mode-test")
	Global.ending_3 = not Global.ending_3
	Global.consecutive_deaths += 9
	Global.implants.purchased_implants[0] = not Global.implants.purchased_implants[0]
	Global.money += 987654
	Global.STOCKS.stocks[0].owned += 987
	Global.WEAPONS_UNLOCKED[0] = not Global.WEAPONS_UNLOCKED[0]
	Global.save_game()
	Global._backup()
	Global.STOCKS.save_stocks()
	check_files()
	if HOST:
		yield(get_tree().create_timer(2), "timeout")
		mp.CounterOp.host_apply_mode("cruelty")
	while Global.campaign_save.active:
		yield(get_tree().create_timer(0.1), "timeout")
	check(Global.money == original_money and Global.STOCKS.stocks[0].owned == original_owned, "Counter-Op restores campaign and stocks")
	for key in original_campaign:
		if key != "play_time":
			check(var2bytes(Global.get(key)) == var2bytes(original_campaign[key]), "restores " + key)
	check(Global.implants.purchased_implants == original_implants, "restores implants")
	if HOST:
		yield(get_tree().create_timer(1), "timeout")
		var menu = get_tree().get_nodes_in_group("MultiplayerMenu")[0]
		menu.cruelty_settings_tab.get_node("VBoxContainer/SaveProgress/TickEdit").pressed = false
		menu.save_host()
		check(Global.campaign_save.active, "Cruelty saving can be disabled")
		var saved_money = Global.money
		Global.money += 42
		Global.save_game()
		check_files()
		menu.cruelty_settings_tab.get_node("VBoxContainer/SaveProgress/TickEdit").pressed = true
		menu.save_host()
		check(not Global.campaign_save.active and Global.money == saved_money, "re-enabling saving discards temporary progress")
		mp.CounterOp.host_apply_mode("deathmatch")
		Global.CURRENT_LEVEL = 1
		mp.game_init(Global.LEVELS[1])
	while Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(3), "timeout")
	check(mp.Deathmatch.is_active(), "Deathmatch active")
	check(Global.objectives == 0, "no mission targets")
	check(not mp.has_revives_remaining(mp.NetworkBridge.get_id()), "revives blocked")
	check(mp.NetworkBridge.damage_allowed(1, 2), "friendly fire setting cannot prevent damage")
	var remote = null
	for avatar in mp.Players.get_children():
		if int(avatar.name) != mp.NetworkBridge.get_id():
			remote = avatar
	check(Global.player.global_transform.origin.distance_to(remote.global_transform.origin) > 5, "players spread across map")
	var indicator = remote.get_node("Puppet/PlayerModel/Armature/Skeleton/Head/PlayerIndicator")
	check(indicator.material_override == load("res://Materials/See_Through_Red.tres"), "original red target material")
	var old_position = Global.player.global_transform.origin
	var old_health = Global.player.health
	if HOST:
		var exit_area = find_exit(Global.current_scene)
		check(exit_area != null, "map exit found")
		Global.player.global_transform.origin = exit_area.global_transform.origin
		old_position = Global.player.global_transform.origin
		yield(get_tree().create_timer(0.5), "timeout")
		check(Global.player.global_transform.origin.distance_to(old_position) > 5 and Global.player.health == old_health, "exit relocation preserves health")
	else:
		yield(get_tree().create_timer(2), "timeout")
		Global.player.suicide()
	while not mp.Flow.result_active:
		yield(get_tree().create_timer(0.1), "timeout")
	check(mp.Flow.result_won == HOST, "winner and loser see separate results")
	check_files()
	var previous_scene = Global.current_scene.get_instance_id()
	if HOST:
		check(not indicator.visible, "dead target hidden")
		yield(get_tree().create_timer(1), "timeout")
		mp.Flow.restart_mission()
	while mp.Flow.result_active or get_tree().paused or Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.get_instance_id() == previous_scene or not mp.player_scene_loaded:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(2), "timeout")
	check(mp.died_players.empty(), "restart clears deaths")
	if HOST:
		yield(get_tree().create_timer(2), "timeout")
		Global.player.instadie()
	while not mp.Flow.result_active:
		yield(get_tree().create_timer(0.1), "timeout")
	check(mp.Flow.result_won != HOST, "client can win and host can lose")
	check(not Global.menu.get_node("Level_End_Grid/Level_Info_Vbox/Next_Level").visible, "no campaign next mission reward")
	check_files()
	yield(get_tree().create_timer(1), "timeout")
	mp.leave_server()
	check(not Global.campaign_save.active and Global.money == original_money, "leaving restores campaign")
	if HOST:
		var menu = get_tree().get_nodes_in_group("MultiplayerMenu")[0]
		menu._sync_implant_tab()
		check(not menu.implants_tab_shown, "Implants tab hidden outside lobby")
		menu._sync_cruelty_settings_tab()
		menu._sync_counterop_settings_tab()
		check(not menu.cruelty_bottom_tab.visible and not menu.counterop_bottom_tab.visible and mp.hostSettings.gameMode == "cruelty", "leaving hides mode tabs and restores Cruelty")
	print("MODE_TEST_RESULT failures=", failures)
	get_tree().quit(1 if failures else 0)

func find_exit(node):
	if node.has_method("_collect_exit_peers"):
		return node
	for child in node.get_children():
		var found = find_exit(child)
		if found != null:
			return found
	return null
