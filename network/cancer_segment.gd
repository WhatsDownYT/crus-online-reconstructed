extends StaticBody


var controller
var entity_id = 0
var parent_id = 0
var child_id = 0
var count = 1
var damaged_count = 1
var dir = Vector3.UP * 0.4
var pending_removal = false

func _ready():
	if Engine.get_frames_per_second() > 30:
		$Audio.play()

func _cancer_id():
	pass

func get_type():
	return 0

func damage(amount, normal, point, shooter_position):
	controller.request_hit(entity_id, amount, normal, point, shooter_position)

func _on_Cancerball_body_entered(body):
	if controller.NetworkBridge.is_world_authority() and not pending_removal:
		if body.get_collision_layer_bit(0) and not body.has_method("_cancer_id"):
			controller.destroy_segment(entity_id)

func _on_Area_body_entered(_body):
	pass
