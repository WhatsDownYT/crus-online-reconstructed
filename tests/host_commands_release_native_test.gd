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
	check(not cmd.DEBUG and not mp.version.ends_with("-debug"),"normal package debug flag disabled")
	var key=InputEventKey.new()
	key.pressed=true
	key.scancode=KEY_F8
	var capture=Global.get_node("DebugCapture")
	capture._input(key)
	check(not capture.ui_hidden and Global.border.modulate.a>0,"normal build F8 cannot hide HUD")
	Global.money=1234
	if HOST:
		for command in ["/money 1", "/god 1", "/noclip 1", "/heal 1", "/revive 1", "/kill 1", "/give 0", '/implant "Augmented Arms+"', "/map 1", "/spawn E_Grunt", "/killall", "/freezeai", "/unfreezeai"]:
			cmd.consume(chat,command,1)
			check(cmd.last_reply=="Debug commands are unavailable in this build.","normal build blocks "+command)
		cmd.consume(chat,"/devhelp",1)
		check(cmd.last_reply=="Debug commands are unavailable in this build.","normal build has no debug help")
	if HOST: cmd.consume(chat,"/op 2",1)
	yield(barrier("operator"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	if not HOST: cmd.submit(chat,"/money 999")
	yield(barrier("operator_debug"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	check(Global.money==1234,"normal package blocks operator debug commands")
	cmd.apply_action(1,"god",null,mp.SteamNetwork.scene_epoch)
	cmd.apply_action(1,"money",1,mp.SteamNetwork.scene_epoch)
	check(Global.money==1234 and not player._admin_god(),"normal receiver rejects debug admin actions")
	if HOST:
		var online_chat=null
		for box_node in get_tree().get_nodes_in_group("online_chatboxes"):
			if not box_node.in_game_chat: online_chat=box_node
		check(online_chat!=null,"main online menu chat available")
		cmd.consume(online_chat,"/announce release announcement",1)
	yield(barrier("announced"),"completed")
	yield(get_tree().create_timer(2.0),"timeout")
	for box_node in get_tree().get_nodes_in_group("online_chatboxes"):
		check(box_node.textBox.bbcode_text.find("release announcement")>=0,"announcement reaches every chat from online menu")
	yield(barrier("all_done"),"completed")
	print("RELEASE_RESULT host=",HOST," failures=",failures)
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