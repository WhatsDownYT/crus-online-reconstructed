extends Node

var failures = 0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6), "timeout")
	var screen = null
	if is_instance_valid(Global.menu):
		screen = Global.menu.get_node_or_null("StatisticsScreen")
	print("STATS_CHECK host=", HOST, " screen_exists=", screen != null)
	if screen == null:
		failures += 1
	else:
		screen.open()
		yield(get_tree().create_timer(2), "timeout")
		var screenshot = get_viewport().get_texture().get_data()
		screenshot.flip_y()
		screenshot.save_png("user://statistics_preview.png")
		Global.menu._set_res(1920, 1080)
		Global.menu.rect_scale = Vector2(1.5, 1.5)
		yield(get_tree().create_timer(0.5), "timeout")
		var large_screenshot = get_viewport().get_texture().get_data()
		large_screenshot.flip_y()
		large_screenshot.save_png("user://statistics_preview_1920.png")
		print("STATS_CHECK host=", HOST, " visible=", screen.visible, " preview=", screen.preview_model != null, " camera_inside_tree=", screen.preview_camera.is_inside_tree())
		if not screen.visible or screen.preview_model == null or not screen.preview_camera.is_inside_tree():
			failures += 1
		var original_name = screen.name_edit.text
		var original_outfit = screen.selected_outfit_index
		var mask = screen.preview_mask_viewport.get_texture().get_data()
		mask.lock()
		var background_alpha = mask.get_pixel(20, 20).a
		var body_pixel = Vector2(-1, -1)
		for y in range(100, mask.get_height() - 100, 8):
			for x in range(100, mask.get_width() - 100, 8):
				if mask.get_pixel(x, y).a > 0.5:
					body_pixel = Vector2(x, y)
					break
			if body_pixel.x >= 0:
				break
		mask.unlock()
		print("STATS_CHECK host=", HOST, " mask_background=", background_alpha, " mask_body=", body_pixel)
		if body_pixel.x < 0 or background_alpha > 0.5:
			failures += 1
		else:
			var click = InputEventMouseButton.new()
			click.button_index = BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(10, 10)
			screen._on_preview_input(click)
			if screen.selected_outfit_index != original_outfit:
				failures += 1
			click.position = body_pixel * screen.preview_display.rect_size / screen.preview_mask_viewport.size
			screen._on_preview_input(click)
		var outlined = screen.preview_mask_display.material.get_shader_param("selected") and screen.selected_outfit_index == (original_outfit + 1) % screen.OUTFITS.size()
		yield(get_tree().create_timer(0.2), "timeout")
		var outlined_screenshot = get_viewport().get_texture().get_data()
		outlined_screenshot.flip_y()
		outlined_screenshot.save_png("user://statistics_selected.png")
		screen._on_preview_exited()
		if screen.preview_mask_display.material.get_shader_param("selected"):
			failures += 1
		var cycled = screen.selected_outfit_index == (original_outfit + 1) % screen.OUTFITS.size() and Global.get_node("Multiplayer").playerInfo.skinPath == screen.OUTFITS[screen.selected_outfit_index].path
		screen.name_edit.text = "Statistics Test"
		screen._save_profile()
		var renamed = Global.get_node("Multiplayer").playerInfo.nickname == "Statistics Test"
		var online_menu = get_tree().get_nodes_in_group("MultiplayerMenu")[0]
		var nickname_hidden = not online_menu.get_node("CenterContainer/TabContainer/Player/VBoxContainer/Nickname").visible
		var outfit_hidden = not online_menu.get_node("CenterContainer/TabContainer/Player/VBoxContainer/Skin").visible
		online_menu.save_player()
		var name_preserved = Global.get_node("Multiplayer").playerInfo.nickname == "Statistics Test"
		print("STATS_CHECK host=", HOST, " outlined=", outlined, " cycled=", cycled, " renamed=", renamed, " online_fields_hidden=", nickname_hidden and outfit_hidden, " name_preserved=", name_preserved)
		if not outlined or not cycled or not renamed or not nickname_hidden or not outfit_hidden or not name_preserved:
			failures += 1
		screen.selected_outfit_index = original_outfit
		screen.name_edit.text = original_name
		screen._save_profile()
	var goals = Global.get_node_or_null("AchievementGoals")
	if goals != null:
		goals.discovered.erase("chaos")
		Global.ending_3 = true
		goals.evaluate_progress()
		Global.ending_3 = false
		var chaos_discovered = goals.discovered.get("chaos", false) and goals.known_condition("chaos")
		print("STATS_CHECK host=", HOST, " chaos_discovered_without_win=", chaos_discovered)
		if not chaos_discovered:
			failures += 1
	else:
		failures += 1
	var online_stats = Global.get_node_or_null("Multiplayer/OnlineStats")
	if online_stats == null:
		failures += 1
	else:
		var original_online = online_stats.values.duplicate(true)
		online_stats.record_result("deathmatch", true)
		online_stats.record_result("counter_operative", false)
		online_stats.credit_kill(null)
		var saved_online = online_stats.store.load_data("stats.save")
		var online_recorded = online_stats.values.deathmatch_wins == original_online.deathmatch_wins + 1 and online_stats.values.counter_op_losses == original_online.counter_op_losses + 1 and online_stats.values.player_kills == original_online.player_kills + 1 and saved_online.deathmatch_wins == online_stats.values.deathmatch_wins and saved_online.counter_op_losses == online_stats.values.counter_op_losses and saved_online.player_kills == online_stats.values.player_kills
		print("STATS_CHECK host=", HOST, " online_recorded=", online_recorded)
		if not online_recorded:
			failures += 1
		online_stats.values = original_online
		online_stats._save()
	print("STATS_RESULT host=", HOST, " failures=", failures)
	get_tree().quit(1 if failures else 0)
