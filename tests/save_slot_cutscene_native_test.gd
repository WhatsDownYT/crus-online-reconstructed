extends Node

var failures = 0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func _read(path):
	var file = File.new()
	if file.open(path, File.READ) != OK:
		return {}
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	return parsed.result if parsed.error == OK and parsed.result is Dictionary else {}

func run():
	yield(get_tree().create_timer(6), "timeout")
	var source = OS.get_environment("APPDATA").replace("\\", "/") + "/Godot/app_userdata/Cruelty Squad/"
	var campaign = _read(source + "savegame.save")
	var stock = _read(source + "stocks.save")
	var saved_goals = _read(source + "crus_online_goals.save")
	var entries = _read("res://MOD_CONTENT/CruS Online/achievements/achievements.json")
	var goals = Global.get_node_or_null("AchievementGoals")
	var screen = Global.menu.get_node_or_null("StatisticsScreen")
	var selector = load("res://MOD_CONTENT/CruS Online/SaveSlotSelector.gd").new()
	if campaign.empty() or goals == null or screen == null:
		failures += 1
	else:
		Global.WEAPONS_UNLOCKED = campaign.get("weapons_unlocked", [])
		Global.implants.purchased_implants = campaign.get("implants_unlocked", [])
		Global.DEAD_CIVS = campaign.get("dead_npcs", [])
		Global.STOCKS.FISH_FOUND = stock.get("fish_found", [])
		Global.STOCKS.ORGANS_FOUND = stock.get("org_found", [])
		goals.unlocked.clear()
		for id in saved_goals.get("unlocked", []):
			goals.unlocked[str(id)] = true
		goals.mastery = saved_goals.get("mastery", {})
		var expected = screen._completion_percentage(goals)
		var actual = selector._completion_percentage(campaign, stock, saved_goals, entries)
		print("SLOT_CUTSCENE_CHECK completion_stats=", expected, " completion_slot=", actual)
		if abs(expected - actual) > 0.0001:
			failures += 1
	selector.free()
	if screen._format_time(46185871) != "12:49:45":
		failures += 1
	var extensions = Global.get_node("Multiplayer/ExtensionCompatibility")
	print("SLOT_CUTSCENE_CHECK campaigns=", extensions.campaigns.size(), " levels=", Global.LEVELS.size())
	if extensions.campaigns.size() < 2 or Global.LEVELS.size() < 24:
		failures += 1
	else:
		var first = extensions.campaigns.back().indices[0]
		var second = extensions.campaigns.back().indices[1]
		extensions.completed_stages.clear()
		if not load(Global.LEVELS[first]) is PackedScene:
			failures += 1
		if not extensions.stage_unlocked(first) or extensions.stage_unlocked(second):
			failures += 1
		extensions.record_campaign_win(first)
		if not extensions.stage_unlocked(second):
			failures += 1
	var game_menu = Global.menu
	var level_menu = game_menu.menu[game_menu.LEVEL_SELECT]
	var online_button = level_menu.get_child(6)
	var goals_button = level_menu.get_child(7)
	var statistics_button = level_menu.get_child(8)
	var online_position = game_menu._level_select_position(online_button)
	var goals_position = game_menu._level_select_position(goals_button)
	var statistics_position = game_menu._level_select_position(statistics_button)
	print("SLOT_CUTSCENE_CHECK menu_top=", online_position, ",", goals_position, ",", statistics_position)
	if goals_position - online_position != Vector2(64, 0) or statistics_position - goals_position != Vector2(64, 0):
		failures += 1
	if game_menu.campaign_pages.size() < 2 or game_menu.campaign_pages[0].name != "Cruelty Squad" or game_menu.campaign_pages[1].name != "Placeholder":
		failures += 1
	var campaign_offer = false
	for group in Global.get_node("Multiplayer/LobbyContent").manifest.groups:
		if group.kind == "campaigns" and group.folder == "Placeholder" and group.files.size() == 16:
			campaign_offer = true
	print("SLOT_CUTSCENE_CHECK campaign_offer=", campaign_offer)
	if not campaign_offer:
		failures += 1
	Global.skip_intro = false
	Global.goto_scene("res://Cutscenes/Cutscene1.tscn")
	var elapsed = 0.0
	while elapsed < 35.0 and (not is_instance_valid(Global.current_scene) or Global.current_scene.filename != "res://Cutscenes/Cutscene1.tscn"):
		yield(get_tree().create_timer(0.25), "timeout")
		elapsed += 0.25
	if not is_instance_valid(Global.current_scene) or Global.current_scene.filename != "res://Cutscenes/Cutscene1.tscn":
		failures += 1
	else:
		var scene = Global.current_scene
		var shooter = scene.get_node_or_null("Activator/Office_MG/Body")
		if shooter == null:
			failures += 1
		else:
			scene.current_scene = 9
			yield(get_tree().create_timer(1), "timeout")
			var civilian = scene.get_node_or_null("Activator/Civilian")
			var civilian_body = civilian.get_node_or_null("Body") if civilian != null else null
			if civilian_body != null:
				var civilian_target = civilian_body.get_near_player()
				print("SLOT_CUTSCENE_CHECK civilian_visible=", civilian.visible, " civilian_target=", civilian_target.player == Global.player, " civilian_physics=", civilian_body.is_physics_processing())
				if not civilian.visible or civilian_target.player != Global.player or not civilian_body.is_physics_processing():
					failures += 1
			else:
				failures += 1
			var target = shooter.get_near_player(shooter)
			var initial_position = shooter.global_transform.origin
			var initial_ticks = shooter.anim_counter
			yield(get_tree().create_timer(3), "timeout")
			var moved = initial_position.distance_to(shooter.global_transform.origin)
			var ticked = shooter.anim_counter - initial_ticks
			print("SLOT_CUTSCENE_CHECK shooter_target=", target.player == Global.player, " movement=", moved, " ai_ticks=", ticked, " physics=", shooter.is_physics_processing())
			if target.player != Global.player or ticked < 10 or moved < 0.1:
				failures += 1
	Global.goto_scene("res://Menu/Main_Menu.tscn")
	elapsed = 0.0
	while elapsed < 20.0 and (not is_instance_valid(Global.current_scene) or Global.current_scene.filename != "res://Menu/Main_Menu.tscn"):
		yield(get_tree().create_timer(0.25), "timeout")
		elapsed += 0.25
	if not is_instance_valid(Global.current_scene) or Global.current_scene.filename != "res://Menu/Main_Menu.tscn":
		failures += 1
	else:
		Global.menu._on_Start_Button_Pressed(Global.menu.START, Global.menu.menu[Global.menu.START].get_child(0))
		yield(get_tree().create_timer(2), "timeout")
		var menu_open = Global.menu.active_menus.back() == Global.menu.menu[Global.menu.LEVEL_SELECT]
		var current_page = Global.menu.campaign_label.text
		print("SLOT_CUTSCENE_CHECK level_menu_open=", menu_open, " campaign_label=", current_page)
		if not menu_open or current_page != "Cruelty Squad":
			failures += 1
		Global.menu._on_Next_Levels_Button_Pressed(Global.menu.LEVEL_SELECT, null)
		if Global.menu.campaign_label.text != "Placeholder":
			failures += 1
	print("SLOT_CUTSCENE_TEST_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
