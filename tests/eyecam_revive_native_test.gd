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
	player.global_transform.origin=Vector3(0,1000,0) if HOST else Vector3(0,1000,-4)

	mp.Eyecam.set_process(false)
	for avatar in mp.Players.get_children():
		avatar.global_transform.origin=Vector3(0,1000,0) if int(avatar.name)==1 else Vector3(0,1000,-4)
		avatar.transform_lerp=avatar.global_transform
	yield(barrier("positions"),"completed")
	yield(get_tree().create_timer(1.0),"timeout")
	var other_id=client_id if HOST else 1
	var eye=mp.Eyecam
	var camera=player.player_view
	player.rotation_helper.global_transform=Transform(Basis(),player.global_transform.origin+Vector3.UP)
	camera.transform=Transform()
	if not HOST: camera.rotate_y(PI)
	set_head("Surveillance Eyecam")
	eye._process(0.1)
	check(eye.acquired.has(other_id) and eye.rectangles.size()==1,"normal eyecam finds visible other player")
	var small=eye.rectangles[0][0].size if not eye.rectangles.empty() else Vector2.ZERO
	eye._process(0.4)
	check(not eye.rectangles.empty() and eye.rectangles[0][0].size.x>small.x,"scan expands over half a second")
	camera.rotate_y(PI)
	eye._process(0.1)
	check(eye.acquired.empty(),"offscreen resets acquisition")
	camera.rotate_y(PI)
	var wall=StaticBody.new()
	var collision=CollisionShape.new()
	var shape=BoxShape.new()
	shape.extents=Vector3(2,2,0.25)
	collision.shape=shape
	wall.add_child(collision)
	get_node("/root/Level").add_child(wall)
	wall.global_transform.origin=Vector3(0,1001,-2)
	yield(get_tree(),"physics_frame")
	yield(get_tree(),"physics_frame")
	eye._process(0.1)
	check(eye.acquired.empty(),"normal eyecam cannot see through walls")
	set_head("Surveillance Eyecam PRO MAX")
	yield(get_tree().create_timer(0.8),"timeout")
	yield(barrier("pro_ready"),"completed")
	eye._process(0.1)
	check(eye.target==other_id and eye.is_camera_locked(),"pro locks nearest player through wall")
	yield(get_tree().create_timer(0.4),"timeout")
	check(eye.sounds.size()==2,"both scanners broadcast global charge sound")
	eye._process(0.0)
	var projected=camera.unproject_position(eye._center(other_id))
	check(projected.distance_to(get_viewport().size*0.5)<2,"pro aims at target center")
	eye._process(1.9)
	check(eye.contracting and not eye.is_camera_locked(),"camera unlocks after two second charge")
	eye._process(0.5)
	check(eye.target==0 and eye.cooldown==30,"contraction starts thirty second cooldown")
	yield(get_tree().create_timer(2.6),"timeout")
	eye._process(1.1)
	check(eye.sounds.empty(),"scan audio and one second target fade stop")
	wall.queue_free()
	set_head("N/A")
	eye.reset()
	mp.hostSettings.canRespawn=true
	mp.hostSettings.selfRespawn=false
	mp.hostSettings.helpTimer=0.2
	mp.hostSettings.gameMode="cruelty"
	yield(barrier("scans_done"),"completed")
	if not HOST:
		player.instadie()
	yield(get_tree().create_timer(1),"timeout")
	yield(barrier("client_dead"),"completed")
	var corpse=mp.players[client_id].puppet
	check(mp.died_players.has(client_id),"dead client recorded")
	check(corpse.get_node("Puppet/PlayerModel/HelpLabel").visible and corpse.get_node("Puppet/PlayerModel/HelpLabel").text=="Press [Use] to revive","dead client has revive prompt despite explosion arriving first")
	check(corpse.get_node("Puppet/PlayerModel/Armature/Skeleton/Chest/Body").get_collision_layer_bit(8),"dead client is interactable")
	yield(barrier("prompt_checked"),"completed")
	if HOST:
		player.global_transform.origin=corpse.global_transform.origin+Vector3(0,0,2)
		corpse.get_node("Puppet/PlayerModel/Armature/Skeleton/Chest/Body").player_use()
	yield(get_tree().create_timer(1),"timeout")
	check(not mp.died_players.has(client_id),"host Use revives client on both peers")
	if not HOST: check(not player.dead and not player.died and player.health==20,"client actually restored")
	yield(barrier("revive_checked"),"completed")
	var menu=Global.menu
	menu.in_game=false
	menu.active_menus=[menu.menu[menu.LEVEL_SELECT]]
	menu.online_navigation_active=false
	for panel in get_tree().get_nodes_in_group("MultiplayerMenu"): panel.hide()
	menu.show()
	menu._update_waiting_menu()
	if not HOST:
		check(menu._waiting_label.visible,"waiting message shows while online menu is closed")
		menu.online_navigation_active=true
		menu._update_waiting_menu()
		check(not menu._waiting_label.visible,"waiting message hides during online navigation")
		menu.online_navigation_active=false
		get_tree().get_nodes_in_group("MultiplayerMenu")[0].show()
		menu._update_waiting_menu()
		check(not menu._waiting_label.visible,"waiting message hides when online panel is visible")
		menu._ensure_counterop_overlay()
		mp.CounterOp._update_overlay()
		check(not mp.CounterOp.ready_button.get_node("Text").visible,"Ready has no label underneath")
		for button in menu.menu[menu.LEVEL_SELECT].get_children():
			if button.has_meta("menu_button_type") and button.get_meta("menu_button_type")==menu.B_MISSION_START:
				check(mp.CounterOp.ready_button.rect_position==button.rect_position,"Ready matches Start Mission square")
	menu.in_game=true
	for panel in get_tree().get_nodes_in_group("MultiplayerMenu"): panel.hide()
	yield(barrier("all_done"),"completed")
	print("EYECAM_RESULT host=",HOST," failures=",failures)
	get_tree().quit(1 if failures else 0)

func set_head(label):
	Global.implants.head_implant=Global.implants.empty_implant
	for implant in Global.implants.IMPLANTS:
		if implant.i_name==label: Global.implants.head_implant=implant

func barrier(stage):
	var prefix="E:/Cruelty/Online/dist/pickup-barrier-"+str(PORT)+"-"+stage+"-"
	var file=File.new()
	file.open(prefix+str(HOST),File.WRITE)
	file.store_string("ready")
	file.close()
	yield(get_tree(),"idle_frame")
	while not file.file_exists(prefix+str(not HOST)):
		yield(get_tree().create_timer(0.05),"timeout")
