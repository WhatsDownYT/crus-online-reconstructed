extends StaticBody

onready var client = get_parent().get_parent()
var collision_shape

func _ready():
	collision_layer = 2
	collision_mask = 0
	set_meta("puppet", -1)
	collision_shape = CollisionShape.new()
	collision_shape.shape = BoxShape.new()
	collision_shape.translation.y = 0.918484
	add_child(collision_shape)
	update_stance()

func update_stance():
	collision_shape.shape.extents = Vector3(0.311979, 0.414648 if client.playerCrouch else 0.903937, 0.289931)
	collision_shape.set_deferred("disabled", client.death or int(client.name) == client.NetworkBridge.get_id())

func damage(amount, normal, point, source):
	client.do_damage(amount, normal, point, source)

func set_toxic():
	client.set_toxic()

func tranquilize(unused = null):
	client.set_tranquilize()

func cancer():
	client.set_cancer()
