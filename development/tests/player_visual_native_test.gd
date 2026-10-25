extends Node

var failures = 0
var mp

func check(value, label):
	print("VISUAL_CHECK host=", HOST, " ", label, "=", value)
	if not value:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6), "timeout")
	mp = Global.get_node("Multiplayer")
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1", PORT)
	while mp.players.size() < 2:
		yield(get_tree().create_timer(0.1), "timeout")
	if HOST:
		mp.goto_scene_host(Global.LEVELS[1])
	while Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(2), "timeout")
	var player = mp.Players.get_child(0)
	var torso = player.get_node("Puppet/PlayerModel/Armature/Skeleton/Torso_Mesh")
	var original_mesh = torso.mesh
	var outfits = ["Enemy_Worker", "Enemy_Nude", "cultist_civilian", "bosssguy_clothes", "Enemy_Assassin", "Enemy_Assassin_Alt", "Enemy_Civilian2", "Enemy_Cop1", "Enemy_Kevin", "Objective_CEO", "Elsa"]
	for outfit in outfits:
		player.skinPath = "res://Textures/NPC/" + outfit + ".png"
		player._apply_outfit_mesh()
		check(torso.mesh != original_mesh, outfit + " uses matching UV mesh")
	player.implant_state["golem_exosystem"] = true
	player._update_golem_visual()
	check(player._golem_model != null and player._golem_model.visible, "golem visual appears")
	check(player._golem_anim != null and player._golem_anim.has_animation("Attack") and player._golem_anim.has_animation("Run"), "golem animations exist")
	var golem_torso = player._golem_model.get_node("Armature/Skeleton/Torso_Mesh")
	var normal_bottom = torso.global_transform.origin.y + torso.get_aabb().position.y
	var golem_bottom = golem_torso.global_transform.origin.y + golem_torso.get_aabb().position.y
	check(golem_bottom < normal_bottom - 0.5, "golem body sits lower")
	yield(get_tree().create_timer(0.1), "timeout")
	var golem_top = golem_torso.global_transform.origin.y + golem_torso.get_aabb().position.y + golem_torso.get_aabb().size.y
	check(player.get_node("Puppet/PlayerModel/Nickname").global_transform.origin.y > golem_top + 0.2, "name is above golem head")
	check(not torso.visible, "normal torso hidden with exosystem")
	player.implant_state["golem_exosystem"] = false
	player._update_golem_visual()
	check(torso.visible and not player._golem_model.visible, "normal body restored")
	print("VISUAL_RESULT host=", HOST, " failures=", failures)
	get_tree().quit(1 if failures else 0)
