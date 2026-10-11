extends Control
var keylist
export  var x_size = 640
func _ready():
	pass


func come():
	show()
	rect_size.y = 600
	rect_size.x = x_size
	rect_position.y = 60
func go():
	hide()


func _on_Punishment_Mode_toggled(button_pressed):
	Global.punishment_mode = button_pressed


func _on_Chaos_Mode_toggled(value):
	Global.chaos_mode = value
	if value:
		var goals = Global.get_node_or_null("AchievementGoals")
		if goals != null:
			goals.mark_discovered("chaos")
