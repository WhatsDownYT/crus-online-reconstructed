extends Area





export  var soul = true
var gib = preload("res://Entities/Physics_Objects/Chest_Gib.tscn")

func _ready():
	pass





func player_use():
	var mp = Global.get_node("Multiplayer")
	if mp.NetworkBridge.check_connection():
		if mp.NetworkBridge.is_world_authority():
			mp.Flow.request_orb(mp.NetworkBridge.get_id(), str(get_path()))
		else:
			mp.NetworkBridge.request_host(mp.Flow, "request_orb", [str(get_path())])
		return
	if soul:
		Global.set_soul()
	else :
		Global.set_hope()
		Global.player.suicide()
	Global.save_game()
	consume_orb()

func consume_orb():
	var bridge = Global.get_node("Multiplayer/NetworkBridge")
	get_parent().get_node("MeshInstance").hide()
	if not soul:
		for i in range(10):
			var new_gib = gib.instance()
			new_gib.name = "OrbGib_" + str(str(get_path()).hash()) + "_" + str(i)
			get_parent().get_parent().add_child(new_gib)
			new_gib.global_transform.origin = global_transform.origin
			if not bridge.check_connection() or bridge.is_world_authority():
				new_gib.damage(20, Vector3.FORWARD.rotated(Vector3.UP, rand_range( - PI, PI)), global_transform.origin, global_transform.origin)
		get_parent().get_node("AudioStreamPlayer3D").play()
		queue_free()
		return 
	get_parent().get_node("Particles").emitting = true
	get_parent().get_node("AudioStreamPlayer3D").play()
	queue_free()
