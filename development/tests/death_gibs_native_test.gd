extends Node

var mp
var failures = 0
var client_id = 0

class SniperWeaponFixture extends Spatial:
	var disabled = true
	var current_weapon = 0
	var damage = [0, 0, 0, 0, 0, 0, 0]

func check(ok, label):
	print("REVISION_CHECK host=", HOST, " ", label, "=", ok)
	var trace = File.new()
	trace.open("E:/Cruelty/Online/development/artifacts/ban-test-progress-" + str(HOST) + ".txt", File.WRITE)
	trace.store_line(label + "=" + str(ok))
	trace.close()
	if not ok: failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func barrier(stage):
	var prefix = "E:/Cruelty/Online/development/artifacts/revision-" + str(PORT) + "-" + stage + "-"
	var file = File.new()
	file.open(prefix + str(HOST), File.WRITE)
	file.store_string("ready")
	file.close()
	yield(get_tree(), "idle_frame")
	while not file.file_exists(prefix + str(not HOST)):
		yield(get_tree().create_timer(0.05), "timeout")

func run():
	yield(get_tree().create_timer(12), "timeout")
	while not is_instance_valid(Global.menu):
		yield(get_tree().create_timer(0.1), "timeout")
	mp = Global.get_node("Multiplayer")
	mp.Voice.test_capture = true
	Global.select_save_slot(1)
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	if HOST:
		mp.config.hostPort = PORT
		mp.config.canRespawn = true
		mp.config.selfRespawn = false
		mp.config.reviveLives = 1
		mp.config.dropWeaponsOnDeath = true
		mp.config.spawnInvulnerability = 2.0
		mp.config.helpTimer = 0
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1", PORT)
	while mp.players.size() < 2:
		yield(get_tree().create_timer(0.1), "timeout")
	for peer in mp.players:
		if peer != 1: client_id = peer
	if not HOST:
		Global.menu.weapon_menu_panel.show()
	if HOST:
		yield(get_tree().create_timer(1), "timeout")
		Global.CURRENT_LEVEL = 1
		mp.game_init(Global.LEVELS[1])
	while Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	mp.hostSettings.canRespawn = false
	yield(barrier("final-death"), "completed")
	var player = Global.player
	player.set_process(false)
	player.set_physics_process(false)
	player.start_flag = true
	player.global_transform.origin = Vector3(0, 1000, 0) if HOST else Vector3(0, 1000, 10)
	if HOST:
		player.instadie(100, Vector3.UP, player.global_transform.origin, Vector3.ZERO)
	yield(get_tree().create_timer(1), "timeout")
	var count = 0
	for child in Global.current_scene.get_children():
		if child.name.begins_with("Chest_Gib#") or child.name.begins_with("Leg_Gib#") or child.name.begins_with("Arm_Gib#") or child.name.begins_with("Head_Gib#"):
			count += 1
	check(count == 6, "six body parts visible on each peer")
	if HOST:
		check(player.player_view.get_parent().get("player_head") == true, "camera attached to flying head")
		check(not player.get_node("Body_Mesh").visible, "local intact body hidden after gibbing")
		check(not mp.DeathScreen.get_node("HelpLabel").visible, "no revival-disabled caption")
		mp.Spectator.start()
		check(mp.Spectator.active and is_zero_approx(player.shader_screen.material.get_shader_param("hit_red")), "spectator starts without death tint")
	else:
		check(not mp.players[1].puppet.get_node("Puppet").visible, "permanent corpse hidden")
	yield(barrier("checked"), "completed")
	print("DEATH_GIB_RESULT failures=", failures)
	get_tree().quit()
