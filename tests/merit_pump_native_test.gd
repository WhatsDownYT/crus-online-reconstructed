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
	box.extents=Vector3(100,0.1,100)
	floor_shape.shape=box
	floor_body.add_child(floor_shape)
	Global.current_scene.add_child(floor_body)
	floor_body.global_transform.origin=Vector3(0,999,0)
	Global.money=1000
	var implant=null
	for item in Global.implants.IMPLANTS:
		if item.i_name=="Pneumatic Merit Pump": implant=item
	check(implant!=null and implant.arms and implant.price==20000,"pump catalog arm slot and price")
	Global.implants.arm_implant=implant
	Global.menu.visible=false
	mp.Menu.hide()
	var pump=mp.MeritPump
	pump.set_process(false)
	pump.mission=Global.current_scene
	pump.epoch=mp.SteamNetwork.scene_epoch
	mp.Eyecam.set_process(true)
	check(pump.growth(2)>pump.growth(1)*2,"exponential pump rate")
	yield(barrier("equipped"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	pump.begin()
	yield(get_tree().create_timer(1.1),"timeout")
	pump.amount=20
	pump.finish()
	yield(get_tree().create_timer(0.8),"timeout")
	check(Global.money==980,"only paid amount deducted")
	check(pump.drops.size()==2,"both peers' money drops synchronized")
	for drop in pump.drops.values(): check(drop.global_transform.origin.y>=999.09,"cash rests on world floor")
	yield(barrier("dropped"),"completed")
	var owned_id=0
	var host_owned=0
	var client_owned=0
	for identifier in pump.drops:
		var owner=pump.drops[identifier].get_node("Area").owner_peer
		if owner==mp.NetworkBridge.get_id(): owned_id=identifier
		if owner==1: host_owned=identifier
		else: client_owned=identifier
	pump.drops[owned_id].get_node("Area").player_use()
	mp.NetworkBridge.request_host(pump,"request_collect",[owned_id])
	yield(get_tree().create_timer(0.5),"timeout")
	check(Global.money==980 and pump.drops.size()==2,"owner cannot collect through UI or direct request")
	yield(barrier("owner_checked"),"completed")
	if HOST:
		var drop=pump.drops.get(client_owned)
		if is_instance_valid(drop):
			player.global_transform.origin=drop.global_transform.origin
			pump.request_collect(null,client_owned)
			pump.request_collect(null,client_owned)
		check(Global.money==1000,"another player collects once despite duplicate request")
	yield(get_tree().create_timer(0.8),"timeout")
	check(pump.drops.size()==1 and not pump.drops.has(client_owned),"claimed drop removed for everyone")
	yield(barrier("collected"),"completed")
	if not HOST:
		var old_drop=pump.drops.get(host_owned)
		if is_instance_valid(old_drop): old_drop.queue_free()
		pump.drops.erase(host_owned)
		mp.NetworkBridge.request_host(pump,"request_state",[pump.epoch])
	yield(get_tree().create_timer(0.5),"timeout")
	check(pump.drops.has(host_owned) and pump.drops[host_owned].get_node("Area").owner_peer==1,"existing cash and owner restored on state request")
	yield(barrier("state_restored"),"completed")
	if HOST:
		var npc=null
		for candidate in get_tree().get_nodes_in_group("merit_bribable_npcs"):
			if not candidate.dead and not candidate.civilian and is_instance_valid(candidate.body):
				npc=candidate
				break
		check(npc!=null,"hostile NPC fixture available")
		if npc!=null:
			npc.creature=true
			var drop=pump.drops.get(host_owned)
			npc.body.global_transform.origin=drop.global_transform.origin
			pump._check_bribes()
			check(npc.has_meta("merit_bribed") and mp.get_alive_actors(npc).empty(),"cash bribes hostile NPC and clears player targets")
	yield(get_tree().create_timer(0.8),"timeout")
	check(pump.drops.empty(),"NPC consumes shared cash once")
	var bribed=0
	for npc in get_tree().get_nodes_in_group("merit_bribable_npcs"):
		if npc.has_meta("merit_bribed"): bribed+=1
	check(bribed==1,"bribed NPC synchronized to both peers")
	yield(barrier("bribed"),"completed")
	var snapshots=preload("res://MOD_CONTENT/CruS Online/NetworkSnapshots.gd").new(mp.SteamNetwork)
	check(snapshots.valid_value("sync_positions",[pump.epoch,[[1,Transform()]]],false),"Steam cash poses accepted by snapshot validator")
	check(not snapshots.valid_value("sync_positions",[pump.epoch,[[1,Vector3.ZERO]]],false),"malformed cash poses rejected")
	pump.begin()
	yield(get_tree().create_timer(0.5),"timeout")
	mp.Eyecam.Jam.apply("implant",2)
	pump._process(0.016)
	check(not pump.active and not pump._available(),"implant hijack cancels pump")
	yield(get_tree().create_timer(0.8),"timeout")
	if HOST: check(pump.sessions.empty(),"hijacked pumps leave no charging host sessions")
	mp.Eyecam.Jam.clear()
	yield(get_tree().create_timer(0.8),"timeout")
	yield(barrier("jam_checked"),"completed")
	Input.action_press("Tertiary_Weapon")
	pump._process(0.016)
	check(pump.active,"tertiary hold starts pump")
	yield(get_tree().create_timer(1.0),"timeout")
	pump._process(1.0)
	check(pump.counter.visible and pump.amount>0,"held key builds visible amount")
	check(pump.counter.text=="$"+str(int(pump.amount)),"UI shows only money amount")
	check(pump.counter.get_color("font_color")==Color.white and pump.counter.get_stylebox("normal").bg_color==Color.black,"white text with opaque black background")
	check(pump.counter.get_font("font").size>=64 and abs(pump.counter.rect_position.x+pump.counter.rect_size.x*0.5-get_viewport().size.x*0.5)<1,"large centered counter")
	check(pump.cash_counts.get(mp.NetworkBridge.get_id(),0)==int(pump.amount) and not pump.cash_voices.empty(),"whole dollar changes play pooled cash sounds")
	Input.action_release("Tertiary_Weapon")
	pump._process(0.016)
	yield(get_tree().create_timer(0.5),"timeout")
	check(not pump.active and not pump.pending and not pump.counter.visible,"release commits and hides pump counter")
	pump.reset()
	pump.mission=Global.current_scene
	pump.epoch=mp.SteamNetwork.scene_epoch
	Global.money=1000 if HOST else 980
	yield(barrier("input_checked"),"completed")
	if HOST: pump.begin()
	yield(get_tree().create_timer(0.5),"timeout")
	if HOST:
		pump.sessions[1].started=OS.get_ticks_msec()-7000
		pump._complete(1,1500)
		var tossed=pump.drops.values()[0]
		check(tossed.velocity.dot(player.global_transform.basis.z.normalized())>3.9 and tossed.velocity.y>1.4,"cash receives small forward and upward toss")
		check(Global.money==-500 and not player.dead,"releasing overdraft charges full amount into debt below 200 percent")
	yield(get_tree().create_timer(0.8),"timeout")
	check(pump.drops.size()==1,"overdraft creates one shared drop")
	var capped_drop=pump.drops.values()[0]
	check(capped_drop.get_node("Area").value==1000 and capped_drop.get_node("Area").owner_peer==1,"overdraft drop capped at available cash with owner recorded")
	if HOST: pump._publish("sync_positions",[pump.epoch,[[pump.drops.keys()[0],capped_drop.global_transform]]])
	yield(barrier("toss_settled"),"completed")
	yield(get_tree().create_timer(0.6),"timeout")
	if not HOST:
		player.global_transform.origin=capped_drop.global_transform.origin
		mp.NetworkBridge.n_rpc(mp.playerPuppet,"_update_puppet",[player.global_transform,[0.0,0.0],0.0,null])
		yield(get_tree().create_timer(0.5),"timeout")
		capped_drop.get_node("Area").player_use()
	yield(get_tree().create_timer(0.8),"timeout")
	check(pump.drops.empty(),"client collects host overdraft drop")
	if not HOST: check(Global.money==1980,"recipient receives capped cash")
	yield(barrier("overdraw_checked"),"completed")
	Global.money=1000 if HOST else 980
	yield(get_tree().create_timer(0.5),"timeout")
	pump.begin()
	yield(get_tree().create_timer(0.5),"timeout")
	if HOST:
		pump.sessions[1].started=OS.get_ticks_msec()-6300
		pump.sessions[1].balance=980
		pump._update_sessions()
		check(pump.sounds.has(1),"overdraft plays positional cradle sound")
		if pump.sounds.has(1): check(pump.sounds[1].pitch_scale>0 and pump.sounds[1].pitch_scale<=1.2,"overload sound pitch ramps")
	yield(get_tree().create_timer(0.5),"timeout")
	check(pump.sounds.has(1),"other peer hears overload sound")
	yield(barrier("overload_sound"),"completed")
	if HOST:
		pump.sessions[1].started=OS.get_ticks_msec()-10000
		pump._update_sessions()
		check(player.dead and Global.money==1000,"IED overload keeps cash")
	yield(get_tree().create_timer(0.8),"timeout")
	check(pump.drops.empty(),"overload creates no cash drop")
	check(not pump.sounds.has(1),"overload sound stops on explosion")
	yield(barrier("all_done"),"completed")
	print("PUMP_RESULT host=",HOST," failures=",failures)
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
