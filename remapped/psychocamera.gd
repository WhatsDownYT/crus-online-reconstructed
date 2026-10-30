extends Area
var active_player = null

func _process(_delta):
	if active_player != null and (not is_instance_valid(active_player) or active_player.dead or active_player.died):
		_release_camera()
		return
	if $Camera.current and is_instance_valid(Global.player):
		$Camera.look_at(Global.player.global_transform.origin + Vector3.UP, Vector3.UP)

func _on_Area_body_entered(body):
	if body != Global.player or body.dead or body.died: return
	active_player = body
	$Camera.current = true
	$Camera/Weapon.disabled = false
	$Camera/Weapon.show()
	$Camera/Weapon.current_weapon = 6
	$Camera/Weapon.damage[6] = 200
	$Camera/Weapon/RayCast.set_collision_mask_bit(1, true)
	Global.player.rotation_helper.hide()
	Global.player.weapon.disabled = true

func _on_Area_body_exited(body):
	if body != Global.player: return
	_release_camera()

func _release_camera():
	active_player = null
	$Camera.current = false
	$Camera/Weapon.disabled = true
	$Camera/Weapon.hide()
	if not is_instance_valid(Global.player): return
	Global.player.rotation_helper.show()
	Global.player.weapon.disabled = Global.player.dead or Global.player.died
	Global.player.player_view.current = true
