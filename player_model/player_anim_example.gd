extends Spatial

onready var anim_tree = $"../anim_tree"

func _ready():


	anim_tree.set("parameters/LOOK_DIRECTION/blend_amount", 0.0)

	anim_tree.set("parameters/ARMS_BLEND/blend_amount", 1.0)



	anim_tree.set("parameters/MOVE_BLEND/blend_amount", 0.0)

	anim_tree.set("parameters/CROUCHMOVE_AMOUNT/blend_amount", 1.0)

	anim_tree.set("parameters/STANDMOVE_AMOUNT/blend_amount", 1.0)

	anim_tree.set("parameters/RUN_DIRECTION/blend_amount", 0.0)

	anim_tree.set("parameters/LEGS_BLEND/blend_amount", 0.0)
	


	anim_tree.set("parameters/DEATH1/active", false)

	anim_tree.set("parameters/DEATH2/active", false)

	anim_tree.set("parameters/KICK/active", false)
	
