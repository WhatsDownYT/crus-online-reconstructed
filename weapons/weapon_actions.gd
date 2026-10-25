extends Reference

# Default primary fire for a custom hitscan weapon. Override either method in
# a behavior script only when the weapon needs different mechanics.
func projectile_direction(aim_raycast):
	return (aim_raycast.to_global(aim_raycast.cast_to) - aim_raycast.global_transform.origin).normalized()

func fire_primary(gun):
	var definition = gun._custom_definition()
	if definition == null or not gun.timer.is_stopped() or gun.magazine_ammo[gun.current_weapon] <= 0:
		return
	gun.timer.start(definition.primary_fire_interval if gun.player else definition.enemy_fire_interval)
	gun.raycast.rotation = gun.raycast_init_rot + Vector3(rand_range(-gun.recoil - gun.leaning_modifier, gun.recoil + gun.leaning_modifier), rand_range(-gun.recoil - gun.leaning_modifier, gun.recoil + gun.leaning_modifier), 0)
	if not gun.player:
		gun.raycast.rotation += Vector3(rand_range(-gun.enemy_accuracy, gun.enemy_accuracy), rand_range(-gun.enemy_accuracy, gun.enemy_accuracy), 0)
	gun.raycast.force_raycast_update()
	if gun.raycast.is_colliding():
		var collider = gun.raycast.get_collider()
		if definition.armor_piercing and collider.has_method("piercing_damage"):
			var pierce_args = [gun.damage[gun.current_weapon], gun.raycast.get_collision_normal(), gun.raycast.get_collision_point(), gun.global_transform.origin]
			for method in collider.get_method_list():
				if method.name == "piercing_damage" and method.args.size() == 3:
					pierce_args.pop_back()
					break
			gun.NetworkBridge.apply_damage(gun, collider, "piercing_damage", pierce_args)
		else:
			gun.do_damage(collider)
		if gun.DECALS[gun.current_weapon] != null:
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
	if is_instance_valid(gun.audio[gun.current_weapon]):
		gun.audio[gun.current_weapon].play()

func fire_secondary(gun):
	var definition = gun._custom_definition()
	if definition == null or definition.secondary_projectile == null:
		return
	var index = gun.current_weapon
	var timer = gun.custom_secondary_timers.get(index)
	if gun.custom_secondary_loaded.get(index, 0) <= 0 or not is_instance_valid(timer) or not timer.is_stopped():
		if gun.player and gun.has_node("No_Ammo"):
			gun.get_node("No_Ammo").play()
		return
	gun.custom_secondary_loaded[index] -= 1
	timer.start(definition.launcher_reload_time)
	gun.set_UI_ammo()
	var direction = projectile_direction(gun.raycast)
	var origin = gun.global_transform.origin + direction
	var velocity = direction * definition.secondary_projectile_speed
	if gun.player:
		velocity += gun.glob.player.player_velocity
	var multiplayer = gun.glob.get_node("Multiplayer")
	if gun.player and gun.NetworkBridge.check_connection() and not gun.NetworkBridge.is_world_authority():
		gun.NetworkBridge.n_rpc(multiplayer, "request_custom_projectile", [definition.weapon_id, origin, velocity])
	elif gun.player and gun.NetworkBridge.check_connection():
		multiplayer.request_custom_projectile(gun.NetworkBridge.get_id(), definition.weapon_id, origin, velocity)
	else:
		var name = "CustomProjectile_%s_%s" % [gun.get_instance_id(), OS.get_ticks_msec()]
		multiplayer._spawn_custom_projectile(definition.weapon_id, origin, velocity, name, gun.NetworkBridge.get_id() if gun.player else 0)
		if gun.NetworkBridge.check_connection():
			gun.NetworkBridge.n_rpc(multiplayer, "spawn_custom_projectile", [definition.weapon_id, origin, velocity, name, 0])
	var sound = gun.custom_launcher_audio.get(index)
	if is_instance_valid(sound):
		sound.play()
	if gun.player and is_instance_valid(gun.playerPuppet):
		gun.playerPuppet.shoot_play(1.0, 1)
	elif not gun.player:
		gun.NetworkBridge.n_rpc(gun, "custom_launcher_sound", [index])
