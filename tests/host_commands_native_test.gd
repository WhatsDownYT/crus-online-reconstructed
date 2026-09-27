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
	var floor_body=StaticBody.new()
	var floor_shape=CollisionShape.new()
	var box=BoxShape.new()
	box.extents=Vector3(10,0.1,10)
	floor_shape.shape=box
	floor_body.add_child(floor_shape)
	Global.current_scene.add_child(floor_body)
	floor_body.global_transform.origin=Vector3(0,999,0)
	Global.menu.visible=false
	mp.Menu.hide()
	var cmd=mp.Commands
	var chat=mp.get_node("Menu/ChatBox")
	var client=client_id
	var cid=str(cmd.short_ids.get(client,2))
	if HOST:
		var key=InputEventKey.new()
		key.pressed=true
		key.scancode=KEY_F8
		var capture=Global.get_node("DebugCapture")
		capture._input(key)
		check(capture.ui_hidden and Global.border.modulate.a==0,"debug F8 hides HUD and difficulty border")
		capture._input(key)
		check(not capture.ui_hidden,"debug F8 restores HUD")
		cmd.players_changed(mp.players)
		cid=str(cmd.short_ids[client])
		check(cmd.DEBUG and mp.version.ends_with("-debug"),"package debug flag and separate network version")
		check(cmd.tokenize('/implant "Augmented Arms+" 2')==["/implant","Augmented Arms+","2"],"quoted names parse")
		check(cmd.resolve_player(cid)==client and cmd.resolve_player("1")==1,"stable short player IDs")
		cmd.consume(chat,"/players",1)
		check(not cmd.last_reply.empty(),"player roster includes team life and ping")
		cmd.consume(chat,"/help",1)
		check(cmd.last_reply.find("/kick")>=0,"normal help lists commands")
		cmd.consume(chat,"/devhelp",1)
		check(cmd.last_reply.find("/freezeai")>=0,"debug help lists commands")
		Global.money=1234
		chat.send_message_host(client,"/money 1","forged host","ffffff")
		check(Global.money==1234,"client chat cannot execute commands")
		cmd.apply_action(client,"money",1)
		check(Global.money==1234,"client cannot forge server admin actions")
		cmd.consume(chat,"/money 4321 "+cid,1)
		cmd.consume(chat,"/god "+cid,1)
		cmd.consume(chat,"/noclip "+cid,1)
		cmd.consume(chat,"/give 0 "+cid,1)
		cmd.consume(chat,'/implant "Augmented Arms+" '+cid,1)
		cmd.consume(chat,"/mute "+cid,1)
	yield(barrier("actions_sent"),"completed")
	yield(get_tree().create_timer(2.0),"timeout")
	if not HOST:
		check(Global.money==4321,"host changes client money")
		check(player.has_meta("admin_god") and player.get_meta("admin_god"),"god delivered to client")
		var before=player.health
		player.damage(100,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
		check(player.health==before,"god blocks damage")
		check(player.get_meta("admin_noclip"),"noclip delivered to client")
		var previous_position=player.global_transform.origin
		Input.action_press("movement_forward")
		player._physics_process(0.1)
		Input.action_release("movement_forward")
		check(player.global_transform.origin.distance_to(previous_position)>1.0,"noclip freely moves through direct camera-relative flight")
		check(player.weapon.current_weapon==0,"give equips client weapon")
		check(Global.implants.arm_implant.i_name=="Augmented Arms+","implant equips client slot")
	check(cmd.global_mutes.get(client,false) and mp.Voice.is_muted(client) and not mp.Voice.can_hear(client,1),"host voice mute enforced on all receivers")
	yield(barrier("actions_checked"),"completed")
	if HOST:
		cmd.consume(chat,"/unmute "+cid,1)
		cmd.consume(chat,"/noclip "+cid,1)
		cmd.consume(chat,"/heal "+cid,1)
		cmd.consume(chat,"/tp "+cid+" 1",1)
		cmd.consume(chat,"/announce testing announcement",1)
	yield(barrier("second_actions"),"completed")
	yield(get_tree().create_timer(2.0),"timeout")
	if not HOST:
		check(not player.get_meta("admin_noclip"),"noclip toggles off")
		check(player.health==(200 if player.orb else 100),"heal reaches maximum health")
		check(player.global_transform.origin.distance_to(Vector3(1,1000,0))<0.2,"teleport delivered to client")
		check(chat.textBox.bbcode_text.find("testing announcement")>=0,"announcement received")
	check(not cmd.global_mutes.get(client,true),"host unmute synchronized")
	yield(barrier("second_checked"),"completed")
	if HOST:
		cmd.consume(chat,"/freezeai",1)
		var npc=get_tree().get_nodes_in_group("merit_bribable_npcs")[0]
		check(cmd.frozen and not npc.body.is_physics_processing(),"freeze stops NPC simulation")
		cmd.consume(chat,"/unfreezeai",1)
		check(not cmd.frozen and npc.body.is_physics_processing(),"unfreeze restores simulation")
		for pair in [["E_Boss_Life",Vector2(2500,10000)],["E_Killerbot",Vector2(750,2000)],["E_Godbot",Vector2(750,2000)]]:
			var instance=load("res://Entities/Enemies/"+pair[0]+".tscn").instance()
			check(mp.MeritPump.bribe_range(instance)==pair[1],"bribe range "+pair[0])
			instance.free()
		var boss=load("res://MOD_CONTENT/CruS Online/remaped/abraxas.gd").new()
		check(mp.MeritPump.bribe_range(boss)==Vector2(2500,10000),"Abraxas bribe range")
		boss.free()
		cmd.consume(chat,"/spawn E_Grunt",1)
	yield(barrier("spawned"),"completed")
	yield(get_tree().create_timer(2.0),"timeout")
	check(Global.current_scene.has_node("AdminNPC_1"),"NPC spawned on both peers")
	yield(barrier("spawn_checked"),"completed")
	if HOST: cmd.consume(chat,"/kill "+cid,1)
	yield(barrier("kill_sent"),"completed")
	yield(get_tree().create_timer(2.0),"timeout")
	if not HOST: check(player.dead,"host kill bypasses god mode")
	yield(barrier("death_checked"),"completed")
	if HOST:
		mp.hostSettings.canRespawn=false
		cmd.consume(chat,"/revive "+cid,1)
	yield(barrier("revive_sent"),"completed")
	yield(get_tree().create_timer(2.0),"timeout")
	check(not mp.died_players.has(client),"administrative revive clears host life state despite revive disabled")
	if not HOST: check(not player.dead and not player.died,"administrative revive restores client")
	yield(barrier("revive_checked"),"completed")
	if HOST:
		cmd.consume(chat,"/killall",1)
		check(Global.current_scene.get_node("AdminNPC_1").dead,"killall kills spawned NPC")
		cmd.consume(chat,"/end",1)
	yield(barrier("ending"),"completed")
	yield(get_tree().create_timer(4.0),"timeout")
	check(not Global.menu.in_game and mp.players.size()==2,"end returns everyone to level select and keeps lobby")
	yield(barrier("ended"),"completed")
	var old_epoch=mp.SteamNetwork.scene_epoch
	yield(barrier("map_prepared"),"completed")
	if HOST: cmd.consume(chat,"/map pharma",1)
	while mp.SteamNetwork.scene_epoch==old_epoch:
		yield(get_tree().create_timer(0.1),"timeout")
	while Global.loader!=null or not Global.menu.in_game or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1),"timeout")
	yield(get_tree().create_timer(4.0),"timeout")
	check(Global.CURRENT_LEVEL==1 and Global.menu.in_game,"map launches selected mission from level select")
	var restart_epoch=mp.SteamNetwork.scene_epoch
	yield(barrier("restart_prepared"),"completed")
	if HOST: cmd.consume(chat,"/restart",1)
	while mp.SteamNetwork.scene_epoch==restart_epoch or Global.loader!=null or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1),"timeout")
	yield(get_tree().create_timer(4.0),"timeout")
	check(Global.CURRENT_LEVEL==1 and mp.players.size()==2,"restart keeps mission settings and lobby")
	yield(barrier("all_done"),"completed")
	print("COMMAND_RESULT host=",HOST," failures=",failures)
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