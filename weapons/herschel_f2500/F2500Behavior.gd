extends Reference

const GRENADE_SCENE = "res://MOD_CONTENT/CruS Online/weapons/herschel_f2500/F2500Grenade.tscn"

func launch_direction(aim_raycast):
	return (aim_raycast.to_global(aim_raycast.cast_to) - aim_raycast.global_transform.origin).normalized()

func fire_primary(gun):
	if not gun.timer.is_stopped() or gun.magazine_ammo[gun.current_weapon] <= 0:
		return
	gun.timer.start(0.085 if gun.player else 0.18)
	gun.raycast.rotation = gun.raycast_init_rot + Vector3(rand_range(-gun.recoil - gun.leaning_modifier, gun.recoil + gun.leaning_modifier), rand_range(-gun.recoil - gun.leaning_modifier, gun.recoil + gun.leaning_modifier), 0)
	if not gun.player:
		gun.raycast.rotation += Vector3(rand_range(-gun.enemy_accuracy, gun.enemy_accuracy), rand_range(-gun.enemy_accuracy, gun.enemy_accuracy), 0)
	gun.raycast.force_raycast_update()
	if gun.raycast.is_colliding():
		var collider = gun.raycast.get_collider()
		gun.do_damage(collider)
		gun.decal(collider, gun.raycast.get_collision_point(), gun.raycast.get_collision_normal())
	gun.recoil += gun.accuracy[gun.current_weapon]
	gun.magazine_ammo[gun.current_weapon] -= 1
	if gun.player:
		gun.muzzle_light.light_energy = 1
		gun.glob.player.reticle.shoot()
		gun.anim.stop()
		gun.anim.play(gun.FIRE_ANIM[gun.current_weapon])
		gun.set_UI_ammo()
		if is_instance_valid(gun.playerPuppet):
			gun.playerPuppet.shoot_play(1.0)
	else:
		gun.NetworkBridge.n_rpc(gun, "npc_muzzleflash", [gun.current_weapon, 1.0])
	gun.audio[gun.current_weapon].play()

func fire_secondary(gun):
	if gun.custom_launcher_loaded <= 0 or not gun.custom_launcher_timer.is_stopped():
		if gun.player and gun.has_node("No_Ammo"):
			gun.get_node("No_Ammo").play()
		return
	gun.custom_launcher_loaded -= 1
	gun.custom_launcher_timer.start(2.0)
	gun.set_UI_ammo()
	var aim_direction = launch_direction(gun.raycast)
	var origin = gun.global_transform.origin + aim_direction
	var velocity = aim_direction * 28.0
	if gun.player:
		velocity += gun.glob.player.player_velocity
	if gun.player and gun.NetworkBridge.check_connection():
		var multiplayer = gun.glob.get_node("Multiplayer")
		if gun.NetworkBridge.is_world_authority():
			multiplayer.request_f2500_grenade(gun.NetworkBridge.get_id(), origin, velocity)
		else:
			gun.NetworkBridge.n_rpc(multiplayer, "request_f2500_grenade", [origin, velocity])
	else:
		var projectile = load(GRENADE_SCENE).instance()
		projectile.name = "F2500Grenade_" + str(gun.get_instance_id()) + "_" + str(OS.get_ticks_msec())
		gun.NetworkBridge.inherit_damage_source(projectile, gun)
		var projectile_parent = gun.get_parent().get_parent().get_parent() if gun.player else gun.get_parent().get_parent().get_parent().get_parent()
		projectile_parent.add_child(projectile)
		projectile.global_transform.origin = origin
		projectile.velocity = velocity
		gun.NetworkBridge.n_rpc(gun, "_spawn_object", [projectile.get_parent().get_path(), GRENADE_SCENE, projectile.name, projectile.global_transform, projectile.velocity])
	var launcher_sound = gun.custom_launcher_audio.get(gun.current_weapon)
	if is_instance_valid(launcher_sound):
		launcher_sound.play()
	if gun.player and is_instance_valid(gun.playerPuppet):
		gun.playerPuppet.shoot_play(1.0, 1)
	elif not gun.player:
		gun.NetworkBridge.n_rpc(gun, "custom_launcher_sound", [gun.current_weapon])
