extends Node

func _ready():
	call_deferred("run")

func run():
	yield(get_tree().create_timer(1.0), "timeout")
	var manager = Global.get_node("AchievementGoals")
	var preview = Global.get_node("AchievementPreview")
	var menu = Global.get_node("Menu")
	manager.unlocked.clear()
	manager.mastery.erase("2")
	Global.implants.head_implant = Global.implants.empty_implant
	Global.implants.arm_implant = Global.implants.empty_implant
	Global.implants.leg_implant = Global.implants.empty_implant
	Global.implants.torso_implant = Global.implants.empty_implant
	Global.level_time_raw = Global.LEVEL_RANK_S[2] + 1
	Global.hope_discarded = false
	Global.punishment_mode = false
	Global.chaos_mode = false
	Global.stock_mode = false
	var money_before = Global.money
	manager.record_mission_win(2)
	print("MASTERY_TEST first=", manager.unlocked.has("steam_paradise"), " progress=", manager.mastery_for(2), " reward=", Global.money - money_before)
	Global.level_time_raw = 1
	Global.hope_discarded = true
	Global.punishment_mode = true
	Global.chaos_mode = true
	for implant in Global.implants.IMPLANTS:
		if implant.i_name == "Extravagant Suit":
			Global.implants.torso_implant = implant
			break
	manager.record_mission_win(2)
	print("MASTERY_TEST complete=", manager.unlocked.has("mastery_paradise"), " progress=", manager.mastery_for(2), " reward=", Global.money - money_before, " queued=", preview.pending_achievements.size())
	var old_active = Global.campaign_save.active
	Global.campaign_save.active = true
	var guard_money = Global.money
	manager.record_mission_win(3)
	print("MASTERY_TEST other_mode_guard=", not manager.unlocked.has("steam_sin_space_engineering") and Global.money == guard_money)
	Global.campaign_save.active = old_active
	menu._on_Goals_Button_Pressed(menu.START, menu.menu[menu.START].get_child(7))
	yield(get_tree().create_timer(0.5), "timeout")
	var goals = menu.goals_screen
	print("MASTERY_TEST categories=", goals.category_ids, " count=", goals.category_count_label.text, " scroll=", goals.list_scroll.get_v_scrollbar().visible)
	var list_image = get_viewport().get_texture().get_data()
	list_image.flip_y()
	list_image.save_png("E:/Cruelty/Online/dist/goals-list-new.png")
	goals._on_header_nav_pressed()
	yield(get_tree().create_timer(0.1), "timeout")
	var categories_image = get_viewport().get_texture().get_data()
	categories_image.flip_y()
	categories_image.save_png("E:/Cruelty/Online/dist/goals-categories-new.png")
	goals._on_header_nav_pressed()
	goals._open_mastery(2)
	print("MASTERY_TEST mastery_view=", goals.mastery_panel.visible, " back=", goals.header_nav_button.text)
	yield(get_tree().create_timer(0.1), "timeout")
	var mastery_image = get_viewport().get_texture().get_data()
	mastery_image.flip_y()
	mastery_image.save_png("E:/Cruelty/Online/dist/goals-mastery-new.png")
	goals._on_header_nav_pressed()
	print("MASTERY_TEST mastery_back=", goals.list_scroll.visible)
	yield(get_tree().create_timer(9.0), "timeout")
	print("MASTERY_TEST second_notification=", preview.showing_achievement, " title=", preview.screen.achievement.get("id", ""), " sound=", preview.cash_ding.playing)
	yield(get_tree().create_timer(9.0), "timeout")
	print("MASTERY_TEST queue_drained=", preview.pending_achievements.empty(), " hidden=", not preview.output.visible)
	get_tree().quit()
