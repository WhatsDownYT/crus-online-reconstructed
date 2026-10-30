extends Area

func _on_Area_body_entered(body):
	var mp = Global.get_node("Multiplayer")
	if not mp.NetworkBridge.is_world_authority(): return
	if body != Global.player and mp.NetworkBridge.damage_target_id(body) <= 0: return
	for path in ["snake/snake/Armature/Bone/Bone001/Bone002/Bone003/Bone004/Bone005/KinematicBody", "snake2/snake/Armature/Bone/Bone001/Bone002/Bone003/Bone004/Bone005/KinematicBody", "snake3/snake/Armature/Bone/Bone001/Bone002/Bone003/Bone004/Bone005/KinematicBody"]:
		var head = get_node_or_null(path)
		if head != null: head.active = true
