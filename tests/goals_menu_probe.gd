extends Node

func _ready():
	call_deferred("capture")

func capture():
	yield(get_tree().create_timer(1.0), "timeout")
	var menu = Global.get_node_or_null("Menu")
	if menu == null:
		print("GOALS_PROBE menu_missing")
		get_tree().quit()
		return
	print("GOALS_PROBE button=", menu.menu[menu.START].get_child(7).name)
	menu._on_Goals_Button_Pressed(menu.START, menu.menu[menu.START].get_child(7))
	yield(get_tree().create_timer(0.5), "timeout")
	print("GOALS_PROBE open=", menu.goals_screen.visible, " return=", menu.menu[menu.GOALS].get_child(0).visible)
	var image = get_viewport().get_texture().get_data()
	image.flip_y()
	print("GOALS_PROBE screenshot=", image.save_png("E:/Cruelty/Online/dist/goals-menu.png"))
	menu._on_Return_Button_Pressed(menu.GOALS, menu.menu[menu.GOALS].get_child(0))
	yield(get_tree().create_timer(0.5), "timeout")
	print("GOALS_PROBE closed=", not menu.goals_screen.visible)
	var preview = Global.get_node_or_null("AchievementPreview")
	var sample = preview.achievements["steam_pharmakokinetiks"].duplicate()
	sample.name = "A LONG ACHIEVEMENT NAME THAT WRAPS ACROSS LINES"
	preview.screen.set_achievement(sample)
	yield(get_tree().create_timer(0.1), "timeout")
	var art = preview.screen_viewport.get_texture().get_data()
	art.flip_y()
	print("GOALS_PROBE wrapped=", art.save_png("E:/Cruelty/Online/dist/achievement-wrapped.png"))
	get_tree().quit()
