extends Node

var elapsed = 0.0
var viewer = Vector3.ZERO

func _process(delta):
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0.0
	if not is_instance_valid(Global.player): return
	viewer = Global.player.global_transform.origin
	var clouds = get_tree().get_nodes_in_group("acr_clouds")
	clouds.sort_custom(self, "_nearer")
	for index in range(clouds.size()):
		var cloud = clouds[index]
		var wanted = index < 32
		if cloud.emitting == wanted: continue
		cloud.emitting = wanted
		cloud.visible = wanted
		cloud.amount = cloud.get_meta("acr_particle_amount") if wanted else 1
		if wanted:
			cloud.add_to_group("acr_visible_clouds")
		else:
			cloud.remove_from_group("acr_visible_clouds")

func _nearer(first, second):
	return first.global_transform.origin.distance_squared_to(viewer) < second.global_transform.origin.distance_squared_to(viewer)
