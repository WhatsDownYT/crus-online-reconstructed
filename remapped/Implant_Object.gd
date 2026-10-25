extends Area

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

export  var implant_name = "Hazmat Suit"

func _ready():
	var implant = _implant()
	if implant == null:
		push_error("Unknown implant pickup: " + implant_name)
		get_parent().hide()
		$CollisionShape.disabled = true
		return
	if Global.implants.purchased_implants.find(_purchase_key()) == - 1:
		for i in Global.implants.IMPLANTS:
			if i == implant:
				
				var new_mat = $implant_object / Cube.mesh.surface_get_material(1).duplicate()
				new_mat.albedo_texture = i.texture
				$implant_object / Cube.set_surface_material(1, new_mat)
	else :
		get_parent().hide()
		$CollisionShape.disabled = true

func player_use():
		var implant = _grant()
		if implant == null:
			return
		if is_instance_valid(Global.player):
			Global.player.UI.notify(implant.i_name + " acquired.", Color(0.2, 1, 0))
		Global.save_game()
		get_parent().hide()
		$CollisionShape.disabled = true

func _grant():
	var implant = _implant()
	if implant == null or Global.implants.purchased_implants.has(_purchase_key()):
		return null
	Global.implants.purchased_implants.append(_purchase_key())
	return implant

func _purchase_key():
	var implant = _implant()
	if implant != null:
		return implant.custom_id if not implant.custom_id.empty() else implant.i_name
	return implant_name

func _implant():
	for implant in Global.implants.IMPLANTS:
		if implant.i_name == implant_name or implant.custom_id == implant_name:
			return implant
	return null
