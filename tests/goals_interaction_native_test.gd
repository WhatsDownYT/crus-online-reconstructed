extends Node

func _ready():
	call_deferred("run")

func run():
	yield(get_tree().create_timer(1.0), "timeout")
	var menu = Global.get_node("Menu")
	menu._on_Goals_Button_Pressed(menu.START, menu.menu[menu.START].get_child(7))
	yield(get_tree().create_timer(0.4), "timeout")
	var goals = menu.goals_screen
	var manager = Global.get_node("AchievementGoals")
	print("GOALS_INTERACTION count=", goals.filter_count_label.text, " category_width=", goals.category_buttons["all"].rect_size.x, " static_removed=", not goals.scene_phone_holder.get_parent().has_node("AudioStreamPlayer3D"))
	goals._on_header_nav_pressed()
	yield(get_tree().create_timer(0.1), "timeout")
	var category_image = get_viewport().get_texture().get_data()
	category_image.flip_y()
	category_image.save_png("E:/Cruelty/Online/dist/goals-categories-final.png")
	goals._on_header_nav_pressed()
	goals.tap_player.stop()
	var outside = InputEventMouseButton.new()
	outside.button_index = BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(20, 20)
	goals._input(outside)
	print("GOALS_INTERACTION outside_tap=", goals.tap_player.playing)
	var phone_point = goals._ui_point_to_scene(Vector2(100, 220))
	var inside = InputEventMouseButton.new()
	inside.button_index = BUTTON_LEFT
	inside.pressed = true
	inside.position = phone_point
	goals._input(inside)
	print("GOALS_INTERACTION inside_tap=", goals.tap_player.playing)
	var wheel = InputEventMouseButton.new()
	wheel.button_index = BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = phone_point
	var before = goals.list_scroll.scroll_vertical
	goals._input(wheel)
	var after = goals.list_scroll.scroll_vertical
	goals._on_input_overlay_gui_input(wheel)
	print("GOALS_INTERACTION wheel_before=", before, " after=", after, " duplicate=", goals.list_scroll.scroll_vertical != after, " drag=", goals.drag_active)
	var level = 2
	var time_before = Global.LEVEL_TIMES_RAW[level]
	var hell_before = Global.HELL_TIMES_RAW[level]
	Global.LEVEL_TIMES_RAW[level] = 99999999
	Global.HELL_TIMES_RAW[level] = 99999999
	manager.unlocked.erase("steam_paradise")
	var campaign_entry = null
	for goal in goals.goals:
		if goal.get("id", "") == "steam_paradise":
			campaign_entry = goal
			break
	var sample = VBoxContainer.new()
	goals.add_child(sample)
	goals._add_card(sample, campaign_entry, goals.card_width, goals.ming_body, goals.game_body)
	var hidden_button = false
	for child in sample.get_child(0).get_children():
		if child is Button and child.text == "MASTERY":
			hidden_button = true
	Global.LEVEL_TIMES_RAW[level] = 10
	goals._add_card(sample, campaign_entry, goals.card_width, goals.ming_body, goals.game_body)
	var revealed_button = false
	var mastery_count = ""
	for child in sample.get_child(1).get_children():
		if child is Button and child.text == "MASTERY":
			revealed_button = child.get_color("font_color_hover") == Color(1, 0, 0.68)
		if child is Label and child.text.ends_with(" / 6"):
			mastery_count = child.text
	print("GOALS_INTERACTION mastery_hidden=", not hidden_button, " mastery_revealed=", revealed_button, " mastery_count=", mastery_count)
	Global.LEVEL_TIMES_RAW[level] = time_before
	Global.HELL_TIMES_RAW[level] = hell_before
	manager.mastery.clear()
	manager.discovered.clear()
	Global.hell_discovered = false
	Global.chaos_mode = false
	Global.implants.torso_implant = Global.implants.empty_implant
	Global.implants.purchased_implants.erase("Extravagant Suit")
	print("GOALS_INTERACTION condition_masks=", not manager.known_condition("hope_eradicated") and not manager.known_condition("chaos") and not manager.known_condition("extravagance"))
	manager.unlocked["steam_paradise"] = true
	manager._save_progress()
	manager.clear_progress()
	print("GOALS_INTERACTION clear=", manager.unlocked.empty() and manager.mastery.empty() and not File.new().file_exists(manager.SAVE_PATH))
	get_tree().quit()
