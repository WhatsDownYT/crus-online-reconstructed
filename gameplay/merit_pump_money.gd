extends KinematicBody

var controller
var velocity = Vector3.ZERO
var target_pose = Transform()

func _ready():
	collision_layer = 64
	collision_mask = 13

func _physics_process(delta):
	if not is_instance_valid(controller): return
	if controller.bridge.is_world_authority():
		velocity.y -= 22.0 * delta
		velocity = move_and_slide(velocity, Vector3.UP)
		if is_on_floor():
			velocity.x *= 0.9
			velocity.z *= 0.9
	else:
		global_transform = global_transform.interpolate_with(target_pose, min(1.0, delta * 15.0))
