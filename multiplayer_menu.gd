extends Control

var profile_store = preload("res://MOD_CONTENT/CruS Online/ProfileStore.gd").new()

var ip = "127.0.0.1"
var port = 25567
var stats_tab
var stats_tab_update_pending = false

onready var IpEdit = $CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/IpEdit
onready var PortEdit = $CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/PortEdit

onready var NicknameEdit = $CenterContainer/TabContainer/Player/VBoxContainer/Nickname/NicknameEdit
onready var NicknameColor = $CenterContainer/TabContainer/Player/VBoxContainer/Color/ColorRect

onready var Multiplayer = Global.get_node("Multiplayer")

func _ready():
	call_deferred("_add_voice_tabs")
	if not Multiplayer.profile_loaded:
		var loadedPlayerData = load_data("player.save")
		Multiplayer.playerInfo = profile_store.merge_defaults(Multiplayer.playerInfo, loadedPlayerData)
		Multiplayer.profile_loaded = true
	var loadedConfigData = load_data("config.save")
	Multiplayer.config = profile_store.merge_defaults(Multiplayer.config, loadedConfigData)

	Multiplayer.config.tickRate = int(clamp(Multiplayer.config.tickRate, 1, 60))
	Multiplayer.config.helpTimer = int(clamp(Multiplayer.config.helpTimer, 0, 3600))
	
	var modloaderVersion = Global.get_node_or_null("Menu/ModLoaderVersion")
	
	if modloaderVersion != null:
		modloaderVersion.hide()
	
	IpEdit.text = Multiplayer.config.lastIp
	PortEdit.text = str(Multiplayer.config.lastPort)
	
	$CenterContainer/TabContainer/Host/VBoxContainer/Port/PortEdit.text = str(Multiplayer.config.hostPort)
	$CenterContainer/TabContainer/Host/VBoxContainer/Password/PasswordEdit.text = Multiplayer.config.hostPassword
	
	$CenterContainer/TabContainer/Host/VBoxContainer/TickRate/TickEdit.value = int(clamp(Multiplayer.config.tickRate, 1, 60))
	
	$CenterContainer/TabContainer/Host/VBoxContainer/CanRespawn/TickEdit.pressed = Multiplayer.config.canRespawn
	for key in ["useVoiceChat", "proximityVoiceChat", "hearDeadPlayers"]:
		get_node("CenterContainer/TabContainer/Host/VBoxContainer/" + key + "/TickEdit").pressed = Multiplayer.config[key]
	$CenterContainer/TabContainer/Host/VBoxContainer/FriendlyFire/TickEdit.pressed = Multiplayer.config.friendlyFire
	$CenterContainer/TabContainer/Host/VBoxContainer/ShareDifficulty/TickEdit.pressed = Multiplayer.config.shareDifficulty
	$CenterContainer/TabContainer/Host/VBoxContainer/ChangeModeOnDeath/TickEdit.pressed = Multiplayer.config.changeModeOnDeath
	$CenterContainer/TabContainer/Host/VBoxContainer/HelpTimer/HelpEdit.value = int(clamp(Multiplayer.config.helpTimer, 0, 3600))
	
	NicknameEdit.text = Multiplayer.playerInfo.nickname
	NicknameEdit.connect("focus_exited", self, "save_player")
	NicknameColor.color = Multiplayer.playerInfo.color
	
	$CenterContainer/TabContainer/Player/VBoxContainer/Image.set_texture(Multiplayer.playerInfo.image)
	$CenterContainer/TabContainer/Player/VBoxContainer/Skin.set_texture(Multiplayer.playerInfo.skinPath)
	
	$CenterContainer/TabContainer/Player/VBoxContainer/Color.r_change(str(NicknameColor.color.r8))
	$CenterContainer/TabContainer/Player/VBoxContainer/Color.g_change(str(NicknameColor.color.g8))
	$CenterContainer/TabContainer/Player/VBoxContainer/Color.b_change(str(NicknameColor.color.b8))
	
	$CenterContainer.hide()
	$CenterContainer/TabContainer.set_tab_hidden(4, true)
	$CenterContainer/TabContainer.set_tab_hidden(5, true)
	$CenterContainer/TabContainer.current_tab = 0
	
	Multiplayer.connect("connected_to_server", self, "_on_connected")
	Multiplayer.connect("status_update", self, "status_update")

func status_update(new_status):
	if new_status == "Offline":
		enable_tabs()
		enable_buttons()
		$CenterContainer/TabContainer.current_tab = 0
	
		$CenterContainer/TabContainer/Main/LAN/VBoxContainer/PlayersList/PlayersListLabel.text = ""
		$CenterContainer/TabContainer/Main/Steam/VBoxContainer/PlayersList/PlayersListLabel.text = ""
	else:
		disable_buttons()
		disable_tabs()
		$CenterContainer/TabContainer.current_tab = 0

func _physics_process(delta):
	_update_stats_tab()
	if Global.menu.in_game:
		hide()
	else:
		show()

func save_player():
	Multiplayer.playerInfo.nickname = NicknameEdit.text.strip_edges()
	Multiplayer.playerInfo.color = NicknameColor.color.to_html(false)
	Multiplayer.playerInfo.image = $CenterContainer/TabContainer/Player/VBoxContainer/Image.get_texture()
	Multiplayer.playerInfo.skinPath = $CenterContainer/TabContainer/Player/VBoxContainer/Skin.get_texture()
	
	if Multiplayer.playerInfo.nickname.empty():
		Multiplayer.playerInfo.nickname = "MT Foxtrot"
	NicknameEdit.text = Multiplayer.playerInfo.nickname
	save_data("player.save", Multiplayer.playerInfo)
	Multiplayer.refresh_local_profile()

func save_host():
	Multiplayer.config.hostPort = int($CenterContainer/TabContainer/Host/VBoxContainer/Port/PortEdit.text)
	Multiplayer.config.hostPassword = $CenterContainer/TabContainer/Host/VBoxContainer/Password/PasswordEdit.text
	Multiplayer.config.tickRate = int($CenterContainer/TabContainer/Host/VBoxContainer/TickRate/TickEdit.value)
	
	Multiplayer.config.canRespawn = $CenterContainer/TabContainer/Host/VBoxContainer/CanRespawn/TickEdit.pressed
	for key in ["useVoiceChat", "proximityVoiceChat", "hearDeadPlayers"]:
		Multiplayer.config[key] = get_node("CenterContainer/TabContainer/Host/VBoxContainer/" + key + "/TickEdit").pressed
	Multiplayer.config.friendlyFire = $CenterContainer/TabContainer/Host/VBoxContainer/FriendlyFire/TickEdit.pressed
	Multiplayer.config.shareDifficulty = $CenterContainer/TabContainer/Host/VBoxContainer/ShareDifficulty/TickEdit.pressed
	Multiplayer.config.changeModeOnDeath = $CenterContainer/TabContainer/Host/VBoxContainer/ChangeModeOnDeath/TickEdit.pressed
	Multiplayer.config.helpTimer = int($CenterContainer/TabContainer/Host/VBoxContainer/HelpTimer/HelpEdit.value)
	
	save_data("config.save", Multiplayer.config)
	if not Multiplayer.NetworkBridge.check_connection() or Multiplayer.NetworkBridge.is_world_authority():
		Multiplayer.apply_host_settings()

func get_data():
	ip = IpEdit.text
	port = int(PortEdit.text)
	
	Multiplayer.playerInfo.color = NicknameColor.color.to_html(false)
	
	if NicknameEdit.text == "":
		Multiplayer.playerInfo.nickname = "Mt Foxtrot"
	else:
		Multiplayer.playerInfo.nickname = NicknameEdit.text

func host():
	get_data()
	Multiplayer.hostSettings.bannedImplants = []

	for implant in $CenterContainer/TabContainer/Implants.bannedImplants:
		Multiplayer.hostSettings.bannedImplants.append(implant)

	Multiplayer.host_server()

func join():
	get_data()
	Multiplayer.join_to_server(ip, port)

func leave():
	Multiplayer.leave_server()

func disable_buttons():
	$CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/Buttons/Join.hide()
	$CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/Buttons/Host.hide()
	$CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/Buttons/Leave.show()

func enable_buttons():
	$CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/Buttons/Join.show()
	$CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/Buttons/Host.show()
	$CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/Buttons/Leave.hide()

func disable_tabs():
	$CenterContainer/TabContainer.set_tab_hidden(1, true)
	$CenterContainer/TabContainer.set_tab_hidden(2, true)
	$CenterContainer/TabContainer.set_tab_hidden(5, false)

func enable_tabs():
	$CenterContainer/TabContainer.set_tab_hidden(1, false)
	$CenterContainer/TabContainer.set_tab_hidden(2, false)
	$CenterContainer/TabContainer.set_tab_hidden(5, true)

func _on_connected():
	$CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/Buttons.current_tab = 1

func enable_menu():
	if not $CenterContainer/TabContainer/Implants.updated:
		$CenterContainer/TabContainer/Implants.update()
		
	$CenterContainer.visible = true

func disable_menu():
	$CenterContainer.visible = false

func save_data(fileName, data):
	if not profile_store.save_data(fileName, data):
		push_error("[CruS Online] " + profile_store.last_error)
		return false
	return true

func load_data(fileName):
	return profile_store.load_data(fileName)

func close_menu():
	disable_menu()
	Global.menu.open_online_destination(false)

func _add_voice_tabs():
	var tabs = $CenterContainer/TabContainer
	var vc = preload("res://MOD_CONTENT/CruS Online/VoiceSettings.gd").new()
	vc.name = "VC"
	tabs.add_child(vc)
	tabs.move_child(tabs.get_node("Credits"), tabs.get_child_count() - 1)
	var stats = PanelContainer.new()
	stats.name = "Stats"
	stats_tab = stats
	var source = Multiplayer.get_node("Menu/Stats")
	stats.theme = source.theme
	var box = VBoxContainer.new()
	box.name = "VBoxContainer"
	box.add_constant_override("separation", 3)
	stats.add_child(box)
	var header = Label.new()
	header.text = "Stats"
	header.align = Label.ALIGN_CENTER
	header.add_font_override("font", source.get_node("VBoxContainer/Label").get_font("font"))
	header.add_stylebox_override("normal", source.get_node("VBoxContainer/Label").get_stylebox("normal"))
	box.add_child(header)
	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_stylebox_override("panel", source.get_node("VBoxContainer/PanelContainer").get_stylebox("panel"))
	box.add_child(panel)
	var scroll = ScrollContainer.new()
	scroll.add_stylebox_override("bg", StyleBoxEmpty.new())
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_child(scroll)
	scroll.add_child(preload("res://MOD_CONTENT/CruS Online/VoiceRoster.gd").new())
	_update_stats_tab()

func _update_stats_tab():
	if stats_tab == null or stats_tab_update_pending:
		return
	var in_lobby = Multiplayer.NetworkBridge.check_connection() and Multiplayer.players.has(Multiplayer.NetworkBridge.get_id())
	if in_lobby != (stats_tab.get_parent() != null):
		stats_tab_update_pending = true
		call_deferred("_sync_stats_tab")

func _sync_stats_tab():
	stats_tab_update_pending = false
	var tabs = $CenterContainer/TabContainer
	var in_lobby = Multiplayer.NetworkBridge.check_connection() and Multiplayer.players.has(Multiplayer.NetworkBridge.get_id())
	if in_lobby and stats_tab.get_parent() == null:
		tabs.add_child(stats_tab)
		tabs.move_child(tabs.get_node("Credits"), tabs.get_child_count() - 1)
	elif not in_lobby and stats_tab.get_parent() != null:
		if tabs.current_tab == stats_tab.get_index():
			tabs.current_tab = 0
		tabs.remove_child(stats_tab)

func _exit_tree():
	if is_instance_valid(stats_tab) and stats_tab.get_parent() == null:
		stats_tab.free()
