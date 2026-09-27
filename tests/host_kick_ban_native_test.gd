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
		Global.CURRENT_LEVEL=1
		mp.game_init(Global.LEVELS[1])
	while Global.loader!=null or not Global.menu.in_game or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1),"timeout")
	yield(get_tree().create_timer(4.0),"timeout")	
	var cmd=mp.Commands
	var chat=mp.get_node("Menu/ChatBox")
	chat.in_game_chat=false
	var client=0
	for peer in mp.players:
		if peer!=1: client=peer
	var cid="2"
	yield(barrier("initial"),"completed")
	if HOST:
		cmd.players_changed(mp.players)
		cid=str(cmd.short_ids[client])
		cmd.consume(chat,"/kick "+cid,1)
	yield(barrier("kick_sent"),"completed")
	yield(get_tree().create_timer(2.0),"timeout")
	if HOST: check(mp.players.size()==1 and cmd.bans.empty(),"kick removes peer without banning")
	else: check(not mp.NetworkBridge.check_connection(),"kick disconnects client")
	if HOST:
		cmd.consume(chat,"/end",1)
	while Global.loader!=null:
		yield(get_tree().create_timer(0.1),"timeout")
	yield(get_tree().create_timer(2),"timeout")
	yield(barrier("kick_checked"),"completed")
	if not HOST:
		while Global.loader!=null:
			yield(get_tree().create_timer(0.1),"timeout")
		mp.join_to_server("127.0.0.1",PORT)
	var deadline=OS.get_ticks_msec()+10000
	while mp.players.size()<2 and OS.get_ticks_msec()<deadline:
		yield(get_tree().create_timer(0.1),"timeout")
	check(mp.players.size()==2,"kicked player can rejoin")
	yield(barrier("rejoin_checked"),"completed")
	if HOST and mp.players.size()==2:
		for peer in mp.players:
			if peer!=1: client=peer
		cid=str(cmd.short_ids[client])
		cmd.consume(chat,"/ban "+cid,1)
	yield(barrier("ban_sent"),"completed")
	yield(get_tree().create_timer(2.0),"timeout")
	if HOST: check(mp.players.size()==1 and cmd.bans.size()==1,"ban removes peer and stores session identity")
	yield(barrier("ban_checked"),"completed")
	if not HOST:
		while Global.loader!=null:
			yield(get_tree().create_timer(0.1),"timeout")
		mp.join_to_server("127.0.0.1",PORT)
	yield(get_tree().create_timer(3.0),"timeout")
	if HOST:
		check(mp.players.size()==1,"ban blocks new peer ID")
		cmd.reset_session()
		check(cmd.bans.empty(),"new session clears bans")
	else: check(not mp.NetworkBridge.check_connection(),"banned join exits connecting")
	yield(barrier("all_done"),"completed")
	print("KICK_RESULT host=",HOST," failures=",failures)
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