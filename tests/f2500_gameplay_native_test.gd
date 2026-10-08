extends Node

var failures = 0

func check(value, label):
	print("F2500_GAME_CHECK host=", HOST, " ", label, " = ", value)
	if not value:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6.0), "timeout")
	var index = Global.get_node("WeaponRegistry").index_for("herschel:f2500")
	check(index == 29, "weapon available")
	if index < 0:
		finish()
		return
	Global.menu.weapon_1 = index
	var mp = Global.get_node("Multiplayer")
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1", PORT)
	var deadline = OS.get_ticks_msec() + 30000
	while mp.players.size() < 2 and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.1), "timeout")
	check(mp.players.size() == 2, "peers connected")
	if HOST and mp.players.size() == 2:
		Global.CURRENT_LEVEL = 1
		mp.game_init(Global.LEVELS[1])
	deadline = OS.get_ticks_msec() + 60000
	while (Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not mp.player_scene_loaded or get_tree().paused) and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.1), "timeout")
	check(is_instance_valid(Global.player) and is_instance_valid(Global.player.weapon), "mission and weapon loaded")
	if not is_instance_valid(Global.player) or not is_instance_valid(Global.player.weapon):
		finish()
		return
	var gun = Global.player.weapon
	var definition = Global.get_node("WeaponRegistry").definition_for(index)
	Global.player.health = 10000
	check(gun.current_weapon == index and gun.ammo[index] == 135 and gun.magazine_ammo[index] == 30, "F2500 equipped with starting ammunition")
	check(gun.audio[index].stream == definition.fire_sound and gun.custom_launcher_audio[index].stream == definition.launcher_sound, "bundled primary and launcher sounds equipped")
	check(gun.AR_mesh.mesh != gun.original_ar_mesh, "first-person model switches to bundled mesh")
	check(gun.custom_launcher_loaded == 1 and gun.custom_launcher_reserve == 3, "launcher starts with one loaded and three spare")
	check(Global.player.UI.secondary_ammo_row.visible and Global.player.UI.secondary_ammo_row.get_child_count() == 4, "secondary ammo icons show loaded and spare grenades")
	check(gun.custom_behaviors.has(index), "packaged firing behavior available")
	var before = gun.magazine_ammo[index]
	gun.custom_behaviors[index].fire_primary(gun)
	check(gun.magazine_ammo[index] == before - 1, "primary fire consumes one round")
	gun.custom_behaviors[index].fire_secondary(gun)
	check(gun.custom_launcher_loaded == 0 and gun.custom_launcher_reserve == 3, "launcher shot consumes loaded grenade")
	check(Global.player.UI.secondary_ammo_row.get_child(3).visible == false, "secondary ammo icons decrease after firing")
	var grenade_found = false
	var grenade_deadline = OS.get_ticks_msec() + 1200
	while not grenade_found and OS.get_ticks_msec() < grenade_deadline:
		for child in gun.get_parent().get_parent().get_parent().get_children():
			if child.name.begins_with("F2500Grenade_"):
				grenade_found = true
		if not grenade_found:
			yield(get_tree().create_timer(0.05), "timeout")
	check(grenade_found, "launcher creates a moving grenade projectile")
	yield(get_tree().create_timer(2.5), "timeout")
	check(gun.custom_launcher_loaded == 1 and gun.custom_launcher_reserve == 2, "launcher reloads from reserve")
	finish()

func finish():
	print("F2500_GAME_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
