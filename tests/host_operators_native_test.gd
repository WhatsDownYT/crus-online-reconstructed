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
	Global.money=1234
	if HOST: cmd.consume(chat,"/op 2",1)
	yield(barrier("op_granted"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	check(cmd.has_access(client_id),"operator role synchronized")
	if not HOST:
		cmd.submit(chat,"/money 5678")
		cmd.submit(chat,"/god 2")
		cmd.submit(chat,"/op 1")
		cmd.submit(chat,"/players")
	yield(barrier("op_commands"),"completed")
	yield(get_tree().create_timer(2),"timeout")
	check(Global.money==(1234 if HOST else 5678),"operator money defaults to requesting player")
	if not HOST:
		check(player._admin_god(),"operator debug command executed by host")
		check(chat.textBox.bbcode_text.find("Only the host can grant")>=0,"operator cannot grant access")
	else:
		check(chat.textBox.bbcode_text.find("Only the host can grant")<0,"operator replies remain private")
		cmd.consume(chat,"/deop 2",1)
	yield(barrier("deop"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	check(not cmd.has_access(client_id),"deop removes role")
	if not HOST: cmd.submit(chat,"/money 99")
	yield(barrier("denied"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	check(Global.money==(1234 if HOST else 5678),"deopped client cannot execute commands")
	if not HOST: check(chat.textBox.bbcode_text.find("Only the host and operators")>=0,"permission rejection delivered to client")
	yield(barrier("all_done"),"completed")
	print("OP_RESULT host=",HOST," failures=",failures)
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