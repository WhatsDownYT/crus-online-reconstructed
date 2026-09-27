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
	mp.Eyecam.set_process(false)
	var eye=mp.Eyecam
	var jam=eye.Jam
	var pump=mp.MeritPump
	pump.set_process(false)
	pump.mission=Global.current_scene
	pump.epoch=mp.SteamNetwork.scene_epoch
	Global.implants.head_implant=Global.implants.empty_implant
	Global.implants.arm_implant=Global.implants.empty_implant
	player.weapon.weapon1=0
	player.weapon.weapon2=null
	player.weapon.current_weapon=0
	var client=0
	for peer in mp.players:
		if peer!=1: client=peer
	var data={"money":1000,"health":10000,"death_mode":false,"implants":["N/A","N/A","N/A","N/A"],"weapons":[0,null]}
	eye.scan_data[1]=data
	eye.scan_data[client]=data
	for avatar in mp.Players.get_children():
		avatar.global_transform.origin=Vector3(0,1000,0) if int(avatar.name)==1 else Vector3(0,1000,-4)
		avatar.transform_lerp=avatar.global_transform
	yield(barrier("positions"),"completed")
	yield(get_tree().create_timer(1.0),"timeout")
	if HOST:
		for implant in Global.implants.IMPLANTS:
			if implant.i_name=="Surveillance Eyecam PRO MAX": Global.implants.head_implant=implant
		eye.cooldown=0
		eye.entry_pending=false
		eye.mission=Global.current_scene
		eye._update_pro(player.player_view,0.016)
	yield(barrier("scan_issued"),"completed")
	yield(get_tree().create_timer(0.2),"timeout")
	if not HOST:
		var deadline=OS.get_ticks_msec()+4000
		while jam.remaining<=0 and OS.get_ticks_msec()<deadline:
			yield(get_tree().create_timer(0.05),"timeout")
	if not HOST: check(jam.remaining>12 and jam.weapon_jammed(0),"host lock immediately starts fifteen second hijack")
	if HOST: check(eye.is_camera_locked() and eye.host_scans.has(1),"scanner lock and charge progression stay active")
	yield(barrier("instant_host"),"completed")
	if HOST:
		eye._update_host_scans(3.1)
		eye._process(3.1)
	yield(get_tree().create_timer(0.4),"timeout")
	if not HOST: check(jam.remaining<14.8 and jam.remaining>9,"charge completion does not reapply or extend hijack")
	jam.clear()
	if HOST:
		Global.implants.head_implant=Global.implants.empty_implant
		eye.scan_data[1]=data
	yield(barrier("first_scan_done"),"completed")
	if not HOST:
		for implant in Global.implants.IMPLANTS:
			if implant.i_name=="Surveillance Eyecam PRO MAX": Global.implants.head_implant=implant
		eye.cooldown=0
		eye.entry_pending=false
		eye.mission=Global.current_scene
		mp.playerPuppet.sync_implants(null,["Surveillance Eyecam PRO MAX","N/A","N/A","N/A"])
		mp.NetworkBridge.n_rpc(mp.playerPuppet,"sync_implants",[["Surveillance Eyecam PRO MAX","N/A","N/A","N/A"]])
	yield(get_tree().create_timer(0.5),"timeout")
	if not HOST: eye._update_pro(player.player_view,0.016)
	yield(get_tree().create_timer(0.4),"timeout")
	if HOST: check(jam.remaining>14 and jam.weapon_jammed(0),"client lock immediately hijacks host despite LAN request context")
	jam.clear()
	yield(barrier("scans_done"),"completed")
	var fixture_path="E:/Cruelty/Online/dist/bribe-fixture-"+str(PORT)+".json"
	var file=File.new()
	if HOST:
		var selected=[]
		for npc in get_tree().get_nodes_in_group("merit_bribable_npcs"):
			if not npc.dead and not npc.civilian and not npc.creature and is_instance_valid(npc.body):
				selected.append(npc)
				if selected.size()==2: break
		check(selected.size()==2,"hostile human NPC fixtures available")
		for index in range(selected.size()):
			selected[index].body.set_physics_process(false)
			selected[index].body.global_transform.origin=Vector3(index*5,1000,3)
		selected[1].creature=true
		file.open(fixture_path,File.WRITE)
		file.store_string(to_json([str(selected[0].get_path()),str(selected[1].get_path())]))
		file.close()
	yield(barrier("fixtures"),"completed")
	file.open(fixture_path,File.READ)
	var fixture=parse_json(file.get_as_text())
	file.close()
	var human=get_node(fixture[0])
	var creature=get_node(fixture[1])
	player.UI.message_box.text=""
	if HOST:
		pump._publish("sync_drop",[pump.epoch,100,1,human.body.global_transform.origin,client,Vector3.ZERO])
		pump._check_bribes()
		var required=human.get_meta("merit_bribe_required")
		check(required>=50 and required<=500,"human requirement lies between fifty and five hundred")
		file.open(fixture_path+".amount",File.WRITE)
		file.store_string(str(required))
		file.close()
	yield(barrier("payment_issued"),"completed")
	yield(get_tree().create_timer(0.5),"timeout")
	check(not human.has_meta("merit_bribed") and pump.drops.empty(),"human takes insufficient cash and remains hostile")
	file.open(fixture_path+".amount",File.READ)
	var required=int(file.get_as_text())
	file.close()
	if not HOST:
		var deadline=OS.get_ticks_msec()+4000
		while not player.UI.message_box.text.begins_with("Bring me $") and OS.get_ticks_msec()<deadline:
			yield(get_tree().create_timer(0.05),"timeout")
	if not HOST: check(player.UI.message_box.text=="Bring me $"+str(required)+" and then we'll talk. Otherwise your life means nothing to me.","failed bribe instantly displays exact dialogue to giver")
	else: check(player.UI.message_box.text=="","bribe dialogue is not broadcast to uninvolved players")
	yield(barrier("underpaid"),"completed")
	if HOST:
		pump._publish("sync_drop",[pump.epoch,101,required-1,human.body.global_transform.origin,client,Vector3.ZERO])
		pump._check_bribes()
		check(human.get_meta("merit_bribe_required")==required and not human.has_meta("merit_bribed"),"human price remains fixed across attempts")
	yield(get_tree().create_timer(0.5),"timeout")
	yield(barrier("price_fixed"),"completed")
	if HOST:
		pump._publish("sync_drop",[pump.epoch,102,required,human.body.global_transform.origin,1,Vector3.ZERO])
		pump._check_bribes()
	yield(get_tree().create_timer(0.5),"timeout")
	check(human.has_meta("merit_bribed") and pump.drops.empty(),"exact required payment pacifies human on both peers")
	if HOST: check(player.UI.message_box.text=="You're free to go.","successful bribe instantly displays exact dialogue")
	yield(barrier("paid"),"completed")
	if HOST:
		pump._publish("sync_drop",[pump.epoch,103,1,creature.body.global_transform.origin,1,Vector3.ZERO])
		pump._check_bribes()
	yield(get_tree().create_timer(0.5),"timeout")
	check(creature.has_meta("merit_bribed") and pump.drops.empty(),"nonhumanoid accepts one dollar on both peers")
	yield(barrier("all_done"),"completed")
	print("BRIBE_RESULT host=",HOST," failures=",failures)
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