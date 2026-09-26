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
