extends Node
var mp
var failures = 0
func check(ok, label):
	print("PICKUP_CHECK host=",HOST," ",label,"=",ok)
	if not ok: failures += 1
func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6),"timeout")
	mp = Global.get_node("Multiplayer")
	mp.Voice.test_capture = true
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1",PORT)
	while mp.players.size()<2:
		yield(get_tree().create_timer(0.1),"timeout")
	if HOST:
		yield(get_tree().create_timer(1),"timeout")
		Global.CURRENT_LEVEL=1
		mp.game_init(Global.LEVELS[1])
	while Global.loader!=null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1),"timeout")
	Global.player.health=10000
	yield(get_tree().create_timer(8),"timeout")

	var client_id=0
	for peer in mp.players:
		if peer!=1: client_id=peer
	var player=Global.player
	player.set_physics_process(false)
	player.start_flag=true
	player.health=10000
	player.set_process(false)
	player.get_parent().rotation.y=PI
	player.global_transform.origin=Vector3(0,1000,0) if HOST else Vector3(0,1000,-4)

	mp.Eyecam.set_process(false)
	mp.Eyecam.set_process(false)
	mp.hostSettings.canRespawn=true
	mp.hostSettings.selfRespawn=false
	mp.hostSettings.helpTimer=0.1
	mp.hostSettings.gameMode="cruelty"
	Global.menu.visible=false
	mp.Menu.hide()
	for avatar in mp.Players.get_children():
		avatar.global_transform.origin=Vector3(0,1000,0) if int(avatar.name)==1 else Vector3(0,1000,-4)
		avatar.transform_lerp=avatar.global_transform
	yield(barrier("positions"),"completed")
	yield(get_tree().create_timer(0.5),"timeout")
	if HOST: player.instadie()
	yield(get_tree().create_timer(1.0),"timeout")
	yield(barrier("host_dead"),"completed")
	var corpse=mp.players[1].puppet
	check(mp.died_players.has(1) and corpse.get_node("Puppet/PlayerModel/HelpLabel").text=="Press [Use] to revive","host corpse has usable revive prompt")
	if not HOST:
		player.global_transform.origin=corpse.global_transform.origin+Vector3(0,0,-2)
		yield(get_tree().create_timer(0.4),"timeout")
		corpse.get_node("Puppet/PlayerModel/Armature/Skeleton/Chest/Body").player_use()
	yield(get_tree().create_timer(1.0),"timeout")
	check(not mp.died_players.has(1) and not mp.revive_authorizations.has(1),"client Use revives host and clears authorization")
	if HOST: check(not player.dead and not player.died and player.health==20,"host restored with assisted health")
	yield(barrier("host_revived"),"completed")
	if not HOST: player.instadie()
	yield(get_tree().create_timer(1.0),"timeout")
	yield(barrier("client_dead"),"completed")
	corpse=mp.players[client_id].puppet
	check(mp.died_players.has(client_id),"client death recorded")
	if HOST:
		player.global_transform.origin=corpse.global_transform.origin+Vector3(0,0,2)
		yield(get_tree().create_timer(0.4),"timeout")
		corpse.get_node("Puppet/PlayerModel/Armature/Skeleton/Chest/Body").player_use()
	yield(get_tree().create_timer(1.0),"timeout")
	check(not mp.died_players.has(client_id),"host Use still revives client")
	if not HOST: check(not player.dead and not player.died and player.health==20,"client restored with assisted health")
	yield(barrier("all_done"),"completed")
	print("REVIVE_RESULT host=",HOST," failures=",failures)
	get_tree().quit(1 if failures else 0)

func barrier(stage):
	var prefix="E:/Cruelty/Online/dist/pickup-barrier-"+str(PORT)+"-"+stage+"-"
	var file=File.new()
	file.open(prefix+str(HOST),File.WRITE)
	file.store_string("ready")
	file.close()
	yield(get_tree(),"idle_frame")
	while not file.file_exists(prefix+str(not HOST)):
		yield(get_tree().create_timer(0.05),"timeout")