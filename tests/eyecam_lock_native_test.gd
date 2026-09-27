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
	other_id=client_id if HOST else 1
	var eye=mp.Eyecam
	eye.set_process(false)
	set_head("Surveillance Eyecam")
	eye.reset()
	eye.mission=Global.current_scene
	yield(barrier("scan_sync"),"completed")
	eye._sync_local_data(1.0)
	yield(get_tree().create_timer(1.0),"timeout")
	check(eye.scan_data.has(other_id) and eye.scan_data[other_id].health==10000,"receives actual other player health")
	eye._lock_camera(player.player_view,eye._center(other_id))
	eye._update_normal(player.player_view,0.1)
	check(eye.acquired.has(other_id) and not eye.analyzed.has(other_id),"normal first scan still charging")
	eye._update_normal(player.player_view,2.9)
	check(eye.analyzed.has(other_id),"normal scan completes after three seconds")
	eye.acquired.clear()
	eye._update_normal(player.player_view,0.01)
	check(eye.readouts.has(other_id) and eye.readouts[other_id].complete,"continuous scan keeps completed data")
	var saved_camera=player.player_view.global_transform
	player.player_view.rotate_y(PI)
	eye._update_normal(player.player_view,0.1)
	check(not eye.analyzed.has(other_id) and eye.departing.has(other_id),"looking away forgets scan and begins rectangle contraction")
	for index in range(12): eye.readouts[other_id].animate_visibility(false)
	check(eye.readouts[other_id].rect_scale.y<0.0001 and not eye.readouts[other_id].visible,"readout contracts to zero")
	player.player_view.global_transform=saved_camera
	eye._update_normal(player.player_view,0.1)
	check(not eye.analyzed.has(other_id),"new sighting must charge again")
	var floor_body=StaticBody.new()
	var floor_collision=CollisionShape.new()
	var floor_shape=BoxShape.new()
	floor_shape.extents=Vector3(30,1,30)
	floor_collision.shape=floor_shape
	floor_body.add_child(floor_collision)
	Global.current_scene.add_child(floor_body)
	floor_body.global_transform.origin=Vector3(0,998,-2)
	yield(get_tree(),"physics_frame")
	yield(get_tree(),"physics_frame")
	yield(barrier("goop_ready"),"completed")
	player._publish_goop(player.global_transform.origin+Vector3.DOWN,0.0,true)
	yield(get_tree().create_timer(0.4),"timeout")
	var saw_decal=false
	var saw_burst=false
	for child in Global.current_scene.get_children():
		saw_decal=saw_decal or child.name.begins_with("OnlineGoop")
		saw_burst=saw_burst or child.name.begins_with("OnlineGunkBurst")
	check(saw_decal and saw_burst,"remote goop decal and particle burst reach both peers")
	yield(barrier("goop_checked"),"completed")
	var data={"money":3040.933748,"health":100,"death_mode":true,"implants":["N/A","N/A","N/A","N/A"],"weapons":[0,1]}
	eye.scan_data[other_id]=data
	var bounds=Rect2(80,80,93,224)
	eye._show_readout(other_id,bounds,false,false,0.5)
	var panel=eye.readouts[other_id]
	check(not panel.complete and (panel.previews.empty() or not panel.previews[0][1].visible),"scan initially hides equipment and stats")
	eye._show_readout(other_id,bounds,true,false,1.0)
	check(panel.complete and panel.icons[0][0].rect_size==Vector2(51,51),"readout shows exact equipment icon size")
	check(panel.previews.size()==2 and panel.previews[0][1].visible,"two rotating weapon previews")
	yield(get_tree(),"idle_frame")
	yield(get_tree(),"idle_frame")
	var capture=get_viewport().get_texture().get_data()
	capture.flip_y()
	capture.save_png("E:/Cruelty/Online/dist/eyecam-readout-"+str(HOST)+".png")
	check(panel.matrix_value.text=="DEATH" and panel.matrix_value.get_color("font_color")==Color(1,0,1),"death matrix is magenta")
	data.weapons=[null,null]
	eye.scan_data[other_id]=data
	eye._show_readout(other_id,bounds,true,false,0.1)
	check(not panel.previews[0][1].visible and not panel.previews[1][1].visible,"empty weapon slots show no weapons")
	eye._show_readout(other_id,bounds,false,true,0.1)
	check(panel.labels[0].text.begins_with("HIJACKING") and not panel.complete and panel.labels[0].get_color("font_color")==Color(1,0,0),"pro only shows hijacking UI")
	set_head("Surveillance Eyecam PRO MAX")
	eye.reset()
	eye.set_process(true)
	process_priority=200
	tracking=true
	while not eye.contracting:
		yield(get_tree(),"idle_frame")
	tracking=false
	check(samples>=10,"samples during real frame charge")
	check(camera_error<0.001,"camera tracks moving target every frame")
	check(body_error<0.001,"body faces moving target every frame")
	var released=-player.player_view.global_transform.basis.z
	yield(get_tree().create_timer(0.15),"timeout")
	check(abs(abs(player.player_view.rotation.y)-PI)<0.01,"camera retains original rig yaw")
	check(released.dot(-player.player_view.global_transform.basis.z)>0.999,"release keeps final facing")
	print("LOCK_METRICS samples=",samples," camera_error=",camera_error," body_error=",body_error)
	yield(barrier("all_done"),"completed")
	print("LOCK_RESULT host=",HOST," failures=",failures)
	get_tree().quit(1 if failures else 0)

var other_id=0
var tracking=false
var samples=0
var camera_error=0.0
var body_error=0.0
var phase=0.0
func _process(delta):
	if not tracking: return
	var eye=mp.Eyecam
	var avatar=mp.players[other_id].get("puppet")
	if eye.target!=0:
		var camera=Global.player.player_view
		var direction=(eye._center(other_id)-camera.global_transform.origin).normalized()
		camera_error=max(camera_error,1.0-direction.dot(-camera.global_transform.basis.z.normalized()))
		var horizontal=direction
		horizontal.y=0
		var forward=Global.player.global_transform.basis.z
		forward.y=0
		body_error=max(body_error,1.0-horizontal.normalized().dot(forward.normalized()))
		samples+=1
	phase+=delta*3.0
	avatar.global_transform.origin=Vector3(sin(phase)*18,1000+sin(phase*0.7),-4 if HOST else 4)
	avatar.transform_lerp=avatar.global_transform

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
