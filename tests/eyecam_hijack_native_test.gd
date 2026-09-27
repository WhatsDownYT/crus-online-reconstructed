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
	for avatar in mp.Players.get_children():
		avatar.global_transform.origin=Vector3(0,1000,0) if int(avatar.name)==1 else Vector3(0,1000,-4)
		avatar.transform_lerp=avatar.global_transform
	yield(barrier("positions"),"completed")
	yield(get_tree().create_timer(1.0),"timeout")
	var eye=mp.Eyecam
	var jam=eye.Jam
	var weapon=player.weapon
	weapon.weapon1=0
	weapon.weapon2=null
	weapon.current_weapon=0
	jam.apply("weapon",0)
	weapon.magazine_ammo[0]=1
	weapon.ammo[0]=24
	weapon.shoot()
	check(jam.remaining==15 and weapon.magazine_ammo[0]==1,"weapon jam blocks loaded gun for fifteen seconds")
	Input.action_press("mouse_1")
	weapon._process(0.016)
	check(weapon.get_node("No_Ammo").playing,"jammed trigger plays empty-ammo sound")
	Input.action_release("mouse_1")
	weapon.reload()
	check(weapon.magazine_ammo[0]>1,"jam does not block reload")
	jam._process(15.1)
	check(not weapon._eyecam_weapon_jammed() and not jam.visible,"weapon jam expires and clears overlay")
	for index in [3,11,17,23]:
		weapon.weapon1=index
		weapon.current_weapon=index
		jam.apply("weapon",index)
		weapon.shoot()
		check(weapon._eyecam_weapon_jammed(),"jam supports weapon "+str(index))
		jam.clear()
	weapon.weapon1=0
	weapon.current_weapon=0
	var sprite_count=0
	for implant in Global.implants.IMPLANTS:
		if implant.i_name.ends_with("+"):
			var source=Image.new()
			var error=source.load("res://MOD_CONTENT/CruS Online/"+implant.i_name+".png")
			var actual=implant.texture.get_data()
			source.convert(Image.FORMAT_RGBA8)
			actual.convert(Image.FORMAT_RGBA8)
			check(error==OK and source.get_data()==actual.get_data(),"new sprite for "+implant.i_name)
			sprite_count+=1
	check(sprite_count==7,"all seven plus variants use supplied sprites")
	var original_arm=Global.implants.arm_implant
	for implant in Global.implants.IMPLANTS:
		if implant.i_name=="Augmented Arms+": original_arm=implant
	Global.implants.arm_implant=original_arm
	var health=player.health
	jam.apply("implant",2)
	check(Global.implants.arm_implant.jammed and not Global.implants.arm_implant.multiplayer_augmented_arms,"implant jam disables functionality")
	check(Global.implants.arm_implant.i_name==original_arm.i_name and player.health==health,"jam retains equipped identity and health")
	jam.elapsed=2.1
	jam.update()
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")
	var image=get_viewport().get_texture().get_data()
	image.flip_y()
	image.save_png("E:/Cruelty/Online/dist/hijack-preview-"+str(HOST)+".png")
	jam._process(15.1)
	check(Global.implants.arm_implant==original_arm and not original_arm.jammed,"implant restores original instance on expiry")
	for slot in jam.SLOTS: Global.implants.set(slot,Global.implants.empty_implant)
	set_head("Surveillance Eyecam PRO MAX" if HOST else "N/A")
	player.update_implants()
	player.health=10000
	eye.reset()
	eye.mission=Global.current_scene
	eye.cooldown=0
	eye.entry_pending=false
	eye.set_process(true)
	yield(get_tree().create_timer(1.0),"timeout")
	yield(barrier("hijack_ready"),"completed")
	yield(get_tree().create_timer(4.0),"timeout")
	if HOST:
		check(eye.host_cooldowns.get(1,0)>40,"host enforces forty-five second scan cooldown")
	else:
		check(jam.kind=="weapon" and jam.remaining>9 and jam.visible,"completed host lock applies weapon jam to client")
		check(jam.affected==jam.affected.to_lower(),"affected name is lowercase")
		jam.clear()
	yield(barrier("network_jam_checked"),"completed")
	eye.set_process(false)
	yield(barrier("all_done"),"completed")
	print("HIJACK_RESULT host=",HOST," failures=",failures)
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
