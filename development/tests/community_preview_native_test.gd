extends Node

func _ready():
	call_deferred("run")

func run():
	yield(get_tree().create_timer(12), "timeout")
	Global.select_save_slot(1)
	Global.goto_scene("res://Menu/Main_Menu.tscn")
	while Global.loader != null:
		yield(get_tree(), "idle_frame")
	yield(get_tree().create_timer(0.5), "timeout")
	Global.menu._hide_online_navigation()
	Global.menu.in_game = false
	Global.menu.show()
	Global.menu.news_panel.come()
	yield(get_tree(), "idle_frame")
	yield(VisualServer, "frame_post_draw")
	if HOST:
		var image = get_viewport().get_texture().get_data()
		image.flip_y()
		image.save_png("E:/Cruelty/Online/development/artifacts/community-layout.png")
	print("COMMUNITY_PREVIEW_RESULT complete")
	get_tree().quit()
