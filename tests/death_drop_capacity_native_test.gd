extends Node
class MockSteam:
	extends Reference
	var owner = 0
	var limit = 0
	func getLobbyOwner(_id): return owner
	func setLobbyMemberLimit(_id, value):
		limit = value
		return true
	func setLobbyData(_id, _key, _value): return true
class MockInit:
	extends Reference
	var Steam = MockSteam.new()
	var steam_username = "Native Test"
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
		var menu = Global.get_node("Menu/MultiplayerMenu")
		var cap = menu.get_node("CenterContainer/TabContainer/Host/VBoxContainer/MaxPlayers/CountEdit")
		cap.value=2
		menu.get_node("CenterContainer/TabContainer/Host/VBoxContainer/DropWeaponsOnDeath/TickEdit").pressed=false
		menu.save_host()
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
	var online_menu = Global.get_node("Menu/MultiplayerMenu")
	var rows = online_menu.get_node("CenterContainer/TabContainer/Host/VBoxContainer")
	check(rows.get_node("MaxPlayers").get_index()==rows.get_node("LobbyType").get_index()+1,"capacity row directly below lobby type")
	check(rows.get_node("DropWeaponsOnDeath/TickEdit").theme==rows.get_node("useVoiceChat/TickEdit").theme,"death drop checkbox uses host theme")
	check(mp.hostSettings.maxPlayers==2,"selected capacity synchronized to both peers")
	if HOST:
		check(mp.lobby_is_full(999) and not mp.lobby_is_full(1),"capacity counts host and preserves connected players")
		check(mp.player_limit_ceiling()==4096,"LAN transport player ceiling")
		mp.NetworkBridge.multiplayer_mode=mp.NetworkBridge.MULTIPLAYER_TYPE.STEAM
		var saved_cap=mp.config.maxPlayers
		mp.config.maxPlayers=10000
		check(mp.selected_player_limit()==250,"Steam capacity clamps to supported ceiling")
		mp.NetworkBridge.multiplayer_mode=mp.NetworkBridge.MULTIPLAYER_TYPE.LAN
		check(mp.selected_player_limit()==4096,"LAN capacity clamps to transport ceiling")
		mp.config.maxPlayers=saved_cap
		var lobby=mp.SteamLobby
		var saved_init=lobby.SteamInit
		var saved_id=lobby._steam_lobby_id
		var fake=MockInit.new()
		fake.Steam.owner=lobby._my_steam_id
		lobby.SteamInit=fake
		lobby._steam_lobby_id=1234
		lobby.publish_lobby_settings()
		check(fake.Steam.limit==2,"Steam member limit follows selected host setting")
		lobby.SteamInit=saved_init
		lobby._steam_lobby_id=saved_id
		rows.get_node("MaxPlayers/CountEdit").value=3
		online_menu.save_host()
		check(mp.hostSettings.maxPlayers==3 and not mp.lobby_is_full(999),"capacity can increase during LAN session")
		rows.get_node("MaxPlayers/CountEdit").value=2
		online_menu.save_host()
	var cmd=mp.Commands
	var chat=mp.get_node("Menu/ChatBox")
	if HOST:
		player.weapon.weapon1=0
		player.weapon.weapon2=1
		player.weapon.set_weapon(0)
		player.instadie()
	yield(barrier("disabled_death"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	check(death_drops().empty(),"disabled death drop setting spawns nothing")
	if HOST:
		check(player.weapon.weapon1==0 and player.weapon.weapon2==1,"disabled setting preserves carried weapons")
		cmd.consume(chat,"/revive 1",1)
	yield(barrier("revived_host"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	player.set_physics_process(false)
	player.set_process(false)
	if HOST:
		rows.get_node("DropWeaponsOnDeath/TickEdit").pressed=true
		online_menu.save_host()
	yield(barrier("enabled"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	check(mp.hostSettings.dropWeaponsOnDeath,"death drop setting synchronized")
	if not HOST:
		player.weapon.weapon1=0
		player.weapon.weapon2=1
		player.weapon.magazine_ammo[0]=7
		player.weapon.magazine_ammo[1]=9
		player.weapon.set_weapon(0)
		player.instadie()
	yield(barrier("client_dead"),"completed")
	yield(get_tree().create_timer(2),"timeout")
	check(death_drops().size()==2,"client death spawns both weapons on every peer")
	if not HOST: check(player.weapon.weapon1==null and player.weapon.weapon2==null,"dead client cannot retain dropped weapons")
	if HOST:
		player.weapon.weapon1=null
		player.weapon.weapon2=null
		player.weapon.current_weapon=null
	for drop in death_drops():
		drop.set_physics_process(false)
		drop.velocity=Vector3.ZERO
		check(drop.gun.ammo==(7 if drop.gun.current_weapon==0 else 9),"death drop preserves loaded ammunition")
	yield(barrier("ammunition_checked"),"completed")
	if HOST:
		for drop in death_drops():
			drop.global_transform.origin=player.global_transform.origin+Vector3.UP
			if drop.gun.current_weapon==0: drop.gun.player_use()
	yield(barrier("client_drop_picked"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	var consumed=0
	for drop in death_drops():
		if drop.removed: consumed+=1
	check(consumed==1,"host pickup consumes shared client drop on both peers")
	if HOST:
		cmd.consume(chat,"/revive 2",1)
	yield(barrier("revived_client"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	player.set_physics_process(false)
	player.set_process(false)
	if not HOST: check(player.weapon.current_weapon==null,"revive does not duplicate dropped loadout")
	if HOST:
		player.weapon.weapon1=2
		player.weapon.weapon2=3
		player.weapon.magazine_ammo[2]=1
		player.weapon.magazine_ammo[3]=1
		player.weapon.set_weapon(2)
		player.instadie()
	yield(barrier("host_dead"),"completed")
	yield(get_tree().create_timer(2),"timeout")
	check(death_drops().size()==4,"host death spawns both weapons on every peer")
	for drop in death_drops():
		drop.set_physics_process(false)
		if drop.gun.current_weapon==2:
			if not HOST: player.global_transform.origin=drop.global_transform.origin+Vector3.RIGHT
	yield(get_tree().create_timer(1),"timeout")
	if not HOST:
		for drop in death_drops():
			if drop.gun.current_weapon==2: drop.gun.player_use()
	yield(barrier("host_drop_picked"),"completed")
	yield(get_tree().create_timer(1),"timeout")
	consumed=0
	for drop in death_drops():
		if drop.removed: consumed+=1
	check(consumed==2,"client pickup consumes shared host drop on both peers")
	if not HOST: check(player.weapon.current_weapon==2,"living client receives host dropped weapon")
	if HOST:
		mp.report_death_weapons(client_id,[[2,1]],mp.SteamNetwork.scene_epoch-1)
		check(death_drops().size()==4,"old mission cannot create death drops")
		check(online_menu.load_data("config.save").dropWeaponsOnDeath,"host setting persisted")
	yield(barrier("all_done"),"completed")
	print("DEATH_DROP_RESULT host=",HOST," failures=",failures)
	get_tree().quit(1 if failures else 0)

func death_drops():
	var found=[]
	for child in Global.current_scene.get_children():
		if child.name.begins_with("DeathWeapon_"): found.append(child)
	return found

func barrier(stage):
	var prefix="E:/Cruelty/Online/dist/pickup-barrier-"+str(PORT)+"-"+stage+"-"
	var file=File.new()
	file.open(prefix+str(HOST),File.WRITE)
	file.store_string("ready")
	file.close()
	yield(get_tree(),"idle_frame")
	while not file.file_exists(prefix+str(not HOST)):
		yield(get_tree().create_timer(0.05),"timeout")