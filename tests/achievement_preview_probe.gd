extends Node

var min_rotation = 360.0
var max_rotation = -360.0
var direction_changes = 0
var previous_direction = -1

func _process(_delta):
	var preview = Global.get_node_or_null("AchievementPreview")
	if preview == null: return
	min_rotation = min(min_rotation, preview.rotation_angle)
	max_rotation = max(max_rotation, preview.rotation_angle)
	if preview.rotation_direction != previous_direction:
		direction_changes += 1
		previous_direction = preview.rotation_direction

func _ready():
	call_deferred("capture")

func capture():
	yield(get_tree().create_timer(1.0), "timeout")
	var preview = Global.get_node_or_null("AchievementPreview")
	print("ACHIEVEMENT_INITIAL hidden=", preview != null and not preview.output.visible)
	if preview == null:
		get_tree().quit()
		return
	print("ACHIEVEMENT_SOUND loaded=", preview.cash_ding.stream != null)
	print("ACHIEVEMENT_ICON loaded=", preview.screen.icon != null)
	preview.show_achievement("steam_pharmakokinetiks")
	yield(get_tree().create_timer(0.06), "timeout")
	print("ACHIEVEMENT_ENTERING scale=", preview.output.rect_scale, " sound=", preview.cash_ding.playing)
	var entering = get_viewport().get_texture().get_data()
	entering.flip_y()
	print("ACHIEVEMENT_ENTERING_SAVE ", entering.save_png("E:/Cruelty/Online/dist/achievement-entering.png"))
	yield(get_tree().create_timer(0.29), "timeout")
	print("ACHIEVEMENT_OPEN visible=", preview.output.visible, " scale=", preview.output.rect_scale)
	var art = preview.screen_viewport.get_texture().get_data()
	art.flip_y()
	print("ACHIEVEMENT_ART_SAVE ", art.save_png("E:/Cruelty/Online/dist/achievement-art.png"))
	var image = get_viewport().get_texture().get_data()
	image.flip_y()
	print("ACHIEVEMENT_SCREEN_SAVE ", image.save_png("E:/Cruelty/Online/dist/achievement-screen.png"))
	yield(get_tree().create_timer(8.8), "timeout")
	print("ACHIEVEMENT_FINISHED hidden=", not preview.output.visible, " scale=", preview.output.rect_scale)
	print("ACHIEVEMENT_ROTATION min=", min_rotation, " max=", max_rotation, " direction_changes=", direction_changes)
	get_tree().quit()
