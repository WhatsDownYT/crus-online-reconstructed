extends Node

func _ready():
	call_deferred("inspect_startup")

func inspect_startup():
	yield(get_tree().create_timer(1.0), "timeout")
	var menu = Global.get_node_or_null("Menu")
	print("GOALS_STARTUP menu=", menu != null)
	if menu != null:
		print("GOALS_STARTUP goals=", is_instance_valid(menu.goals_screen))
		menu._on_Goals_Button_Pressed(menu.START, menu.menu[menu.START].get_child(7))
		yield(get_tree().create_timer(2.0), "timeout")
		print("GOALS_STARTUP opened=", menu.goals_screen.visible)
		var goals = menu.goals_screen
		print("GOALS_STARTUP achievements=", goals.goals.size())
		var loaded_icons = 0
		for achievement in goals.goals:
			if goals._texture(str(achievement.get("icon", ""))) != null:
				loaded_icons += 1
		print("GOALS_STARTUP loaded_icons=", loaded_icons)
		print("GOALS_STARTUP bounds=", goals.input_overlay.rect_position, " size=", goals.input_overlay.rect_size)
		print("GOALS_STARTUP nav_polygon=", goals._category_nav_polygon())
		print("GOALS_STARTUP civilians_and_shooter=", goals.scene_phone_holder.get_parent().has_node("Activator"))
		var arrays = goals.scene_phone.mesh.surface_get_arrays(1)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		for i in range(vertices.size()):
			var position = goals.scene_camera.unproject_position(goals.scene_phone.global_transform.xform(vertices[i]))
			print("GOALS_VERTEX ", i, " uv=", uvs[i], " screen=", position)
		var image = get_viewport().get_texture().get_data()
		image.flip_y()
		print("GOALS_STARTUP screenshot=", image.save_png("E:/Cruelty/Online/dist/goals-current.png"))
		var polygon = goals._category_nav_polygon()
		var center = (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
		var click = InputEventMouseButton.new()
		click.button_index = BUTTON_LEFT
		click.pressed = true
		click.position = center - goals.input_overlay.rect_position
		goals._on_input_overlay_gui_input(click)
		click.pressed = false
		goals._on_input_overlay_gui_input(click)
		print("GOALS_STARTUP category_open=", goals.category_menu.visible)
	get_tree().quit()
