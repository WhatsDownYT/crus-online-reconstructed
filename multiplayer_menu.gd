extends Control

var profile_store = preload("res://MOD_CONTENT/CruS Online/ProfileStore.gd").new()

var ip = "127.0.0.1"
var port = 25567
var stats_tab
var stats_tab_update_pending = false
var host_tooltips_ready = false
var credit_logos_ready = false
var credits_overlay = null
var credit_logo_nodes = []
var credit_logo_positions = []
var credit_spacer_texture = null
var host_tab_shown = null
var lobby_type_mode_shown = null
var modes_tab_shown = null
var implants_tab_shown = null
var shared_settings_syncing = false
var cruelty_settings_tab = null
var cruelty_bottom_tab = null
var counterop_settings_tab = null
var counterop_bottom_tab = null
var deathmatch_settings_tab = null
var deathmatch_bottom_tab = null
var deathmatch_spawn_npcs = null
var deathmatch_settings_syncing = false
var counterop_setting_boxes = {}
var counterop_settings_syncing = false
var counterop_bottom_shown = null
var counterop_settings_descriptions = {
	"enemyFriendlyFire": ["Enemy Friendly Fire", "Allow Counter-Operatives to damage and kill hostile NPCs and mission targets."],
	"neutralEnemies": ["Neutral Enemies", "When a Counter-Operative attacks a friendly NPC, that NPC becomes hostile to Counter-Operatives. Requires Enemy Friendly Fire."],
	"randomizeTeams": ["Randomize Teams", "Hide manual team selection and give every player an equal random chance of being assigned to either team when a round starts."],
	"overrideTeams": ["Override Teams", "Prevent players from choosing their own team and allow the host to reassign teams from Stats."]
}
var host_tooltips = {
	"LobbyName": "The name shown for your Steam lobby. An empty or invalid name uses your Steam name.",
	"LobbyType": "Public lobbies appear in the browser. Friends Only allows Steam friends to join. Private requires a code or Discord invite.",
	"Port": "The network port used when hosting a LAN lobby.",
	"TickRate": "How often the host processes multiplayer synchronization ticks. Lower values update more frequently.",
	"CanRespawn": "Allow players to come back after dying. When disabled, both self-respawning and teammate revives are disabled.",
	"SelfRespawn": "Allow players to respawn themselves after dying. Counter-Opps still requires teammate revives.",
	"ShareDifficulty": "Keep all players on the host's current difficulty state instead of letting difficulty state remain local.",
	"FriendlyFire": "Allow players on the same side to damage each other. Counter-Opps always allows damage between opposing teams.",
	"useVoiceChat": "Enable multiplayer voice chat for the lobby.",
	"proximityVoiceChat": "Make voice chat positional so players get quieter as they move farther away.",
	"hearDeadPlayers": "Allow living players to hear voice chat from dead players.",
	"ChangeModeOnDeath": "Allow the game's difficulty mode to change after death when the normal game rules would do so.",
	"ReviveTimer": "How long a dead player must wait before the revive interaction becomes available.",
	"Lives": "How many times each player can be revived during a level. Set this to 0 for unlimited revives."
}

onready var IpEdit = $CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/IpEdit
onready var PortEdit = $CenterContainer/TabContainer/Main/LAN/VBoxContainer/IpPort/PortEdit

onready var NicknameEdit = $CenterContainer/TabContainer/Player/VBoxContainer/Nickname/NicknameEdit
onready var NicknameColor = $CenterContainer/TabContainer/Player/VBoxContainer/Color/ColorRect

onready var Multiplayer = Global.get_node("Multiplayer")

func _ready():
	_ensure_cruelty_settings_tab()
	_ensure_deathmatch_settings_tab()
	$CenterContainer/TabContainer.connect("tab_changed", self, "_close_mode_settings")
	$CenterContainer/TabContainer.connect("tab_changed", self, "_close_credits")
	$CenterContainer/TabContainer.connect("gui_input", self, "_mode_header_input")
	_setup_credits_overlay()
	_setup_credits_buttons()
	call_deferred("_add_voice_tabs")
	if not Multiplayer.profile_loaded:
		var loadedPlayerData = load_data("player.save")
		Multiplayer.playerInfo = profile_store.merge_defaults(Multiplayer.playerInfo, loadedPlayerData)
		Multiplayer.profile_loaded = true
	var loadedConfigData = load_data("config.save")
	var legacy_respawn = typeof(loadedConfigData) == TYPE_DICTIONARY and loadedConfigData.has("canRespawn") and not loadedConfigData.has("selfRespawn")
	var legacy_lives = typeof(loadedConfigData) == TYPE_DICTIONARY and not loadedConfigData.has("reviveLivesZeroInfinite")
	Multiplayer.config = profile_store.merge_defaults(Multiplayer.config, loadedConfigData)
	var lobby_name_row = HBoxContainer.new()
	lobby_name_row.name = "LobbyName"
	var lobby_name_label = Label.new()
	lobby_name_label.text = "Lobby name:"
	lobby_name_row.add_child(lobby_name_label)
	var lobby_name_edit = LineEdit.new()
	lobby_name_edit.name = "NameEdit"
	lobby_name_edit.theme = $CenterContainer/TabContainer/Host/VBoxContainer/LobbyType/TypeSelect.theme
	lobby_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_name_edit.align = LineEdit.ALIGN_CENTER
	lobby_name_edit.max_length = 40
	var saved_lobby_name = Multiplayer.config.get("hostLobbyName", "")
	var default_lobby_name = "CruS Online lobby"
	if typeof(saved_lobby_name) == TYPE_STRING and not saved_lobby_name.strip_edges().empty() and saved_lobby_name.strip_edges().to_lower().find("null") < 0 and saved_lobby_name.length() <= 40:
		lobby_name_edit.text = saved_lobby_name.strip_edges()
	else:
		lobby_name_edit.text = default_lobby_name
	lobby_name_row.add_child(lobby_name_edit)
	var host_rows = $CenterContainer/TabContainer/Host/VBoxContainer
	host_rows.add_child(lobby_name_row)
	host_rows.move_child(lobby_name_row, 1)
	if legacy_respawn:
		Multiplayer.config.selfRespawn = bool(loadedConfigData.canRespawn)
		Multiplayer.config.canRespawn = true
	if legacy_lives:
		Multiplayer.config.reviveLives = 0

	Multiplayer.config.tickRate = int(clamp(Multiplayer.config.tickRate, 1, 60))
	Multiplayer.config.helpTimer = int(clamp(Multiplayer.config.helpTimer, 0, 3600))
	Multiplayer.config.reviveLives = int(clamp(Multiplayer.config.reviveLives, 0, 5))
	
	var modloaderVersion = Global.get_node_or_null("Menu/ModLoaderVersion")
	
	if modloaderVersion != null:
		modloaderVersion.hide()
	
	IpEdit.text = Multiplayer.config.lastIp
	PortEdit.text = str(Multiplayer.config.lastPort)
	
	$CenterContainer/TabContainer/Host/VBoxContainer/Port/PortEdit.text = str(Multiplayer.config.hostPort)
	
	$CenterContainer/TabContainer/Host/VBoxContainer/TickRate/TickEdit.value = int(clamp(Multiplayer.config.tickRate, 1, 60))
	
	$CrueltySettings/VBoxContainer/CanRespawn/TickEdit.pressed = Multiplayer.config.canRespawn
	$CrueltySettings/VBoxContainer/SelfRespawn/TickEdit.pressed = Multiplayer.config.selfRespawn
	for key in ["useVoiceChat", "proximityVoiceChat", "hearDeadPlayers"]:
		get_node("CenterContainer/TabContainer/Host/VBoxContainer/" + key + "/TickEdit").pressed = Multiplayer.config[key]
	$CrueltySettings/VBoxContainer/FriendlyFire/TickEdit.pressed = Multiplayer.config.friendlyFire
	$CenterContainer/TabContainer/Host/VBoxContainer/ShareDifficulty/TickEdit.pressed = Multiplayer.config.shareDifficulty
	$CrueltySettings/VBoxContainer/ChangeModeOnDeath/TickEdit.pressed = Multiplayer.config.changeModeOnDeath
	$CrueltySettings/VBoxContainer/ReviveTimer/ReviveEdit.value = int(clamp(Multiplayer.config.helpTimer, 0, 3600))
	$CrueltySettings/VBoxContainer/Lives/LivesEdit.value = int(clamp(Multiplayer.config.reviveLives, 0, 5))
	
	cruelty_settings_tab.get_node("VBoxContainer/SaveProgress/TickEdit").pressed = Multiplayer.config.saveProgress
	NicknameEdit.text = Multiplayer.playerInfo.nickname
	NicknameEdit.connect("focus_exited", self, "save_player")
	NicknameColor.color = Multiplayer.playerInfo.color
	
	$CenterContainer/TabContainer/Player/VBoxContainer/Skin.set_texture(Multiplayer.playerInfo.skinPath)
	
	$CenterContainer/TabContainer/Player/VBoxContainer/Color.r_change(str(NicknameColor.color.r8))
	$CenterContainer/TabContainer/Player/VBoxContainer/Color.g_change(str(NicknameColor.color.g8))
	$CenterContainer/TabContainer/Player/VBoxContainer/Color.b_change(str(NicknameColor.color.b8))
	
	$CenterContainer.hide()
	$CenterContainer/TabContainer.set_tab_hidden($CenterContainer/TabContainer/Implants.get_index(), true)
	$CenterContainer/TabContainer.set_tab_hidden($CenterContainer/TabContainer/Chat.get_index(), true)
	$CenterContainer/TabContainer.set_tab_hidden($CenterContainer/TabContainer/Host.get_index(), true)
	host_tab_shown = false
	$CenterContainer/TabContainer.current_tab = 0
	
	Multiplayer.connect("connected_to_server", self, "_on_connected")
	Multiplayer.connect("status_update", self, "status_update")


func _load_runtime_texture(path):
	var image = Image.new()
	if image.load(path) != OK:
		return null
	var texture = ImageTexture.new()
	texture.create_from_image(image, 0)
	return texture

func _credit_wave_material():
	var shader = Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV;\n\tuv.x += sin(UV.y * 2.4 + TIME * 0.65) * 0.015;\n\tuv.y += sin(UV.x * 1.8 + TIME * 0.45) * 0.008;\n\tif (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {\n\t\tCOLOR = vec4(0.0);\n\t} else {\n\t\tCOLOR = texture(TEXTURE, uv) * COLOR;\n\t}\n}"
	var material = ShaderMaterial.new()
	material.shader = shader
	return material

func _credit_spacer():
	if credit_spacer_texture != null:
		return credit_spacer_texture
	var image = Image.new()
	image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	credit_spacer_texture = ImageTexture.new()
	credit_spacer_texture.create_from_image(image, 0)
	return credit_spacer_texture

func _add_credit_logo(rich, texture, width):
	var texture_size = texture.get_size()
	var height = int(round(float(width) * texture_size.y / max(texture_size.x, 1.0)))
	var y = rich.get_content_height()
	rich.add_image(_credit_spacer(), width, height)
	var logo = TextureRect.new()
	logo.texture = texture
	logo.expand = true
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.rect_size = Vector2(width, height)
	logo.material = _credit_wave_material()
	rich.add_child(logo)
	credit_logo_nodes.append(logo)
	credit_logo_positions.append(float(y))

func _update_credit_logo_positions():
	if credit_logo_nodes.empty():
		return
	var rich = get_node_or_null("Credits/VBoxContainer/RichTextLabel")
	if rich == null:
		return
	var scroll = rich.get_v_scroll().value
	for index in range(credit_logo_nodes.size()):
		var logo = credit_logo_nodes[index]
		if is_instance_valid(logo):
			logo.rect_position = Vector2((rich.rect_size.x - logo.rect_size.x) * 0.5, credit_logo_positions[index] - scroll)

func _credit_link(rich, label, url):
	rich.push_color(Color(0, 0, 1))
	rich.push_meta(url)
	rich.add_text(label)
	rich.pop()
	rich.pop()

func _credit_maroon(rich, text):
	rich.push_color(Color(0.5, 0, 0))
	rich.add_text(text)
	rich.pop()

func _setup_credit_logos():
	if credit_logos_ready:
		return
	var rich = get_node_or_null("Credits/VBoxContainer/RichTextLabel")
	if rich == null:
		return
	rich.clear()
	rich.push_align(1)
	var reconstructed_logo = _load_runtime_texture("res://MOD_CONTENT/CruS Online/crus_online_reconstructed_logo.png")
	if reconstructed_logo != null:
		_add_credit_logo(rich, reconstructed_logo, 330)
	rich.add_text("\nCreated by ")
	_credit_link(rich, "PurgaTeam", "https://www.youtube.com/@PurgaTeam")
	rich.add_text("\nDeveloped by ")
	_credit_link(rich, "WhatsDown", "https://www.youtube.com/@WhatsDown")
	rich.add_text("\n\n")
	var online_logo = _load_runtime_texture("res://MOD_CONTENT/CruS Online/crus_online_logo.png")
	if online_logo != null:
		_add_credit_logo(rich, online_logo, 330)
	rich.add_text("\nCreated by ")
	_credit_link(rich, "TriggeredP", "https://www.youtube.com/@triggeredp")
	rich.add_text("\n\nSpecial Thanks")
	rich.pop()
	rich.add_text("\n\nDX: ")
	_credit_maroon(rich, "Helped with animations for the player, menu icon and CruS Online testing")
	rich.add_text("\n\nKeith Mason: ")
	_credit_maroon(rich, "creator of Construct map")
	rich.add_text("\n\nXuesos (4cne): ")
	_credit_maroon(rich, "My IRL friend who helped me with CruS Online testing")
	rich.add_text("\n\nChasmy: ")
	_credit_maroon(rich, "Reconstructed testing")
	rich.add_text("\n\nPBF Guy: ")
	_credit_maroon(rich, "Reconstructed testing")
	credit_logos_ready = true
	call_deferred("_update_credit_logo_positions")

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

func _select_main_tab():
	if is_inside_tree():
		$CenterContainer/TabContainer.current_tab = 0

func _setup_credits_buttons():
	var tabs = $CenterContainer/TabContainer
	for page in ["Select", "LAN", "Steam"]:
		var footer = tabs.get_node("Main/" + page + "/VBoxContainer/HBoxContainer")
		var button = Button.new()
		button.text = " Credits "
		button.connect("pressed", self, "_open_credits")
		footer.add_child(button)
		footer.move_child(button, 0)
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer.add_child(spacer)
		footer.move_child(spacer, 1)

func _setup_credits_overlay():
	var tabs = $CenterContainer/TabContainer
	credits_overlay = tabs.get_node("Credits")
	tabs.remove_child(credits_overlay)
	add_child(credits_overlay)
	credits_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	credits_overlay.hide()
	var rich = credits_overlay.get_node("RichTextLabel")
	credits_overlay.remove_child(rich)
	var box = VBoxContainer.new()
	box.name = "VBoxContainer"
	credits_overlay.add_child(box)
	box.add_child(rich)
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var back = Button.new()
	back.name = "Back"
	back.text = " Back "
	back.connect("pressed", self, "_close_credits")
	back.rect_min_size = Vector2(120, 26)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	_layout_credits_overlay()

func _layout_credits_overlay():
	if not is_instance_valid(credits_overlay):
		return
	var tabs = $CenterContainer/TabContainer
	credits_overlay.rect_position = get_global_transform().affine_inverse().xform(tabs.rect_global_position + Vector2(7, 39))
	credits_overlay.rect_size = tabs.rect_size - Vector2(14, 46)

func _open_credits():
	$CenterContainer/TabContainer.current_tab = 0
	_layout_credits_overlay()
	credits_overlay.show()
	credits_overlay.raise()

func _close_credits(_tab = 0):
	if is_instance_valid(credits_overlay):
		credits_overlay.hide()

func _physics_process(delta):
	_update_stats_tab()
	_update_credit_logo_positions()
	if credits_overlay.visible:
		_layout_credits_overlay()
	if $CenterContainer.visible:
		_sync_host_tab_visibility()
		_sync_modes_tab()
		_sync_implant_tab()
		_sync_counterop_settings_tab()
		_sync_deathmatch_settings_tab()
		_sync_cruelty_settings_tab()
		_layout_mode_panels()
	if Global.menu.in_game:
		hide()
	else:
		show()

func save_player():
	Multiplayer.playerInfo.nickname = NicknameEdit.text.strip_edges()
	Multiplayer.playerInfo.color = NicknameColor.color.to_html(false)
	Multiplayer.playerInfo.skinPath = $CenterContainer/TabContainer/Player/VBoxContainer/Skin.get_texture()
	
	if Multiplayer.playerInfo.nickname.empty():
		Multiplayer.playerInfo.nickname = "MT Foxtrot"
	NicknameEdit.text = Multiplayer.playerInfo.nickname
	save_data("player.save", Multiplayer.playerInfo)
	Multiplayer.refresh_local_profile()

func save_host():
	var lobby_name_edit = $CenterContainer/TabContainer/Host/VBoxContainer/LobbyName/NameEdit
	Multiplayer.config.hostLobbyName = Multiplayer.SteamLobby.valid_lobby_name(lobby_name_edit.text)
	lobby_name_edit.text = Multiplayer.config.hostLobbyName
	Multiplayer.config.saveProgress = cruelty_settings_tab.get_node("VBoxContainer/SaveProgress/TickEdit").pressed
	Multiplayer.config.deathmatchSpawnNPCs = deathmatch_spawn_npcs.pressed
	Multiplayer.config.hostPort = int($CenterContainer/TabContainer/Host/VBoxContainer/Port/PortEdit.text)
	var type_select = $CenterContainer/TabContainer/Host/VBoxContainer/LobbyType/TypeSelect
	Multiplayer.config.hostLobbyType = str(type_select.get_item_metadata(type_select.selected))
	Multiplayer.config.tickRate = int($CenterContainer/TabContainer/Host/VBoxContainer/TickRate/TickEdit.value)
	
	Multiplayer.config.canRespawn = $CrueltySettings/VBoxContainer/CanRespawn/TickEdit.pressed
	Multiplayer.config.selfRespawn = $CrueltySettings/VBoxContainer/SelfRespawn/TickEdit.pressed
	for key in ["useVoiceChat", "proximityVoiceChat", "hearDeadPlayers"]:
		Multiplayer.config[key] = get_node("CenterContainer/TabContainer/Host/VBoxContainer/" + key + "/TickEdit").pressed
	Multiplayer.config.friendlyFire = $CrueltySettings/VBoxContainer/FriendlyFire/TickEdit.pressed
	Multiplayer.config.shareDifficulty = $CenterContainer/TabContainer/Host/VBoxContainer/ShareDifficulty/TickEdit.pressed
	Multiplayer.config.changeModeOnDeath = $CrueltySettings/VBoxContainer/ChangeModeOnDeath/TickEdit.pressed
	Multiplayer.config.helpTimer = int($CrueltySettings/VBoxContainer/ReviveTimer/ReviveEdit.value)
	Multiplayer.config.reviveLives = int($CrueltySettings/VBoxContainer/Lives/LivesEdit.value)
	
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
	$CenterContainer/TabContainer.set_tab_hidden($CenterContainer/TabContainer/Host.get_index(), true)
	host_tab_shown = false
	$CenterContainer/TabContainer.set_tab_hidden($CenterContainer/TabContainer/Player.get_index(), true)
	$CenterContainer/TabContainer.set_tab_hidden($CenterContainer/TabContainer/Chat.get_index(), false)
	_sync_modes_tab()

func enable_tabs():
	_sync_host_tab_visibility()
	$CenterContainer/TabContainer.set_tab_hidden($CenterContainer/TabContainer/Player.get_index(), false)
	$CenterContainer/TabContainer.set_tab_hidden($CenterContainer/TabContainer/Chat.get_index(), true)
	_sync_modes_tab()

func _sync_modes_tab():
	var tabs = $CenterContainer/TabContainer
	var modes = tabs.get_node_or_null("Modes")
	if modes == null:
		return
	var in_lobby = Multiplayer.NetworkBridge.check_connection() and Multiplayer.players.has(Multiplayer.NetworkBridge.get_id())
	var show_modes = in_lobby and Multiplayer.NetworkBridge.is_world_authority()
	if modes_tab_shown == show_modes:
		return
	modes_tab_shown = show_modes
	var selected = tabs.get_current_tab_control()
	var index = modes.get_index()
	tabs.set_tab_hidden(index, not show_modes)
	if selected == modes and not show_modes:
		tabs.current_tab = 0
	elif is_instance_valid(selected):
		tabs.current_tab = selected.get_index()

func _setup_host_tooltips():
	if host_tooltips_ready:
		return
	for setting in host_tooltips:
		var row = get_node_or_null("CenterContainer/TabContainer/Host/VBoxContainer/" + setting)
		if row == null:
			row = get_node_or_null("CrueltySettings/VBoxContainer/" + setting)
		if row != null:
			_connect_host_tooltip(row, host_tooltips[setting])
	host_tooltips_ready = true

func _connect_host_tooltip(node, description):
	if node is Control:
		if not node.is_connected("mouse_entered", self, "_host_tooltip_entered"):
			node.connect("mouse_entered", self, "_host_tooltip_entered", [description])
		if not node.is_connected("mouse_exited", self, "_host_tooltip_exited"):
			node.connect("mouse_exited", self, "_host_tooltip_exited")
	for child in node.get_children():
		_connect_host_tooltip(child, description)

func _host_tooltip_entered(description):
	if not is_instance_valid(Global.menu) or not is_instance_valid(Global.menu.hover_info):
		return
	var hover = Global.menu.hover_info
	hover.get_node("Image").hide()
	hover.get_node("Name").hide()
	hover.get_node("Hint").show()
	hover.get_node("Hint").text = description
	hover.get_parent().rect_size = Vector2.ZERO
	hover.get_parent().raise()
	hover.get_parent().show()

func _host_tooltip_exited():
	if not is_instance_valid(Global.menu) or not is_instance_valid(Global.menu.hover_info):
		return
	var hover = Global.menu.hover_info
	hover.get_node("Name").show()
	hover.get_parent().hide()
	hover.get_parent().rect_size = Vector2.ZERO

func _on_connected():
	$CenterContainer/TabContainer/Main.current_tab = 1
	_select_main_tab()

func enable_menu():
	_close_credits()
	$CenterContainer/TabContainer/Host/VBoxContainer/LobbyName/NameEdit.text = Multiplayer.SteamLobby.valid_lobby_name(Multiplayer.config.get("hostLobbyName", ""))
	_sync_lobby_type_options()
	_setup_host_tooltips()
	_setup_credit_logos()
	_ensure_counterop_settings_tab()
	_sync_modes_tab()
	_sync_implant_tab()
	if not $CenterContainer/TabContainer/Implants.updated:
		$CenterContainer/TabContainer/Implants.update()
	$CenterContainer/TabContainer.current_tab = 0
	$CenterContainer.visible = true
	_sync_counterop_settings_tab()
	_sync_deathmatch_settings_tab()

func _sync_lobby_type_options():
	var picker = $CenterContainer/TabContainer/Host/VBoxContainer/LobbyType/TypeSelect
	lobby_type_mode_shown = Multiplayer.NetworkBridge.is_steam()
	var previous = str(Multiplayer.config.get("hostLobbyType", "public"))
	picker.clear()
	for entry in [["Public", "public"], ["Friends Only", "friends_only"], ["Private", "private"]]:
		if entry[1] == "friends_only" and not lobby_type_mode_shown:
			continue
		picker.add_item(entry[0])
		picker.set_item_metadata(picker.get_item_count() - 1, entry[1])
		if previous == entry[1]:
			picker.select(picker.get_item_count() - 1)
	if picker.selected < 0:
		picker.select(0)

func _sync_host_tab_visibility():
	var tabs = $CenterContainer/TabContainer
	var main = tabs.get_node("Main")
	var show_host = main.current_tab != 0 and (not Multiplayer.NetworkBridge.check_connection() or Multiplayer.NetworkBridge.is_world_authority())
	if host_tab_shown != show_host:
		var selected = tabs.get_current_tab_control()
		host_tab_shown = show_host
		tabs.set_tab_hidden(tabs.get_node("Host").get_index(), not show_host)
		if selected == tabs.get_node("Host") and not show_host:
			tabs.current_tab = 0
		elif is_instance_valid(selected):
			tabs.current_tab = selected.get_index()
	if lobby_type_mode_shown != Multiplayer.NetworkBridge.is_steam():
		_sync_lobby_type_options()

func disable_menu():
	_close_credits()
	_close_mode_settings()
	if is_instance_valid(cruelty_bottom_tab):
		cruelty_bottom_tab.hide()
	$CenterContainer.visible = false
	counterop_bottom_shown = null
	if is_instance_valid(counterop_bottom_tab):
		counterop_bottom_tab.hide()
	if is_instance_valid(deathmatch_bottom_tab):
		deathmatch_bottom_tab.hide()

func _ensure_deathmatch_settings_tab():
	var tabs = $CenterContainer/TabContainer
	var host = tabs.get_node("Host")
	deathmatch_settings_tab = PanelContainer.new()
	deathmatch_settings_tab.name = "DeathmatchSettings"
	deathmatch_settings_tab.add_stylebox_override("panel", host.get_stylebox("panel"))
	var box = VBoxContainer.new()
	box.name = "VBoxContainer"
	box.add_constant_override("separation", 10)
	deathmatch_settings_tab.add_child(box)
	var header = Label.new()
	header.text = "Deathmatch settings"
	header.align = Label.ALIGN_CENTER
	box.add_child(header)
	var row = HBoxContainer.new()
	row.name = "SpawnNPCs"
	box.add_child(row)
	var label = Label.new()
	label.text = "Spawn NPCs:"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	deathmatch_spawn_npcs = CheckBox.new()
	deathmatch_spawn_npcs.name = "TickEdit"
	deathmatch_spawn_npcs.text = "<<"
	deathmatch_spawn_npcs.rect_min_size = Vector2(50, 0)
	deathmatch_spawn_npcs.theme = cruelty_settings_tab.get_node("VBoxContainer/CanRespawn/TickEdit").theme
	deathmatch_spawn_npcs.pressed = true
	deathmatch_spawn_npcs.connect("toggled", self, "_deathmatch_spawn_toggled")
	row.add_child(deathmatch_spawn_npcs)
	_connect_host_tooltip(row, "Keep enemies and civilians in Deathmatch missions.")
	deathmatch_settings_tab.theme = tabs.theme
	add_child(deathmatch_settings_tab)
	deathmatch_settings_tab.hide()
	deathmatch_bottom_tab = Button.new()
	deathmatch_bottom_tab.name = "DeathmatchBottomTab"
	deathmatch_bottom_tab.text = " Deathmatch Settings "
	deathmatch_bottom_tab.focus_mode = Control.FOCUS_NONE
	deathmatch_bottom_tab.toggle_mode = true
	deathmatch_bottom_tab.rect_min_size = Vector2(220, 30)
	deathmatch_bottom_tab.add_stylebox_override("normal", tabs.get_stylebox("tab_bg"))
	deathmatch_bottom_tab.add_stylebox_override("hover", tabs.get_stylebox("tab_fg"))
	deathmatch_bottom_tab.add_stylebox_override("pressed", tabs.get_stylebox("tab_fg"))
	deathmatch_bottom_tab.add_stylebox_override("focus", StyleBoxEmpty.new())
	deathmatch_bottom_tab.connect("pressed", self, "_deathmatch_settings_pressed")
	add_child(deathmatch_bottom_tab)
	deathmatch_bottom_tab.hide()

func _sync_deathmatch_settings_tab():
	if not is_instance_valid(deathmatch_settings_tab):
		return
	var available = $CenterContainer.visible and Multiplayer.NetworkBridge.check_connection() and Multiplayer.players.has(Multiplayer.NetworkBridge.get_id()) and Multiplayer.NetworkBridge.is_world_authority() and Multiplayer.Deathmatch.is_active()
	deathmatch_bottom_tab.visible = available
	_layout_mode_button(deathmatch_bottom_tab)
	if not available:
		deathmatch_settings_tab.hide()
		return
	deathmatch_bottom_tab.pressed = deathmatch_settings_tab.visible
	deathmatch_settings_syncing = true
	deathmatch_spawn_npcs.pressed = Multiplayer.config.get("deathmatchSpawnNPCs", true)
	deathmatch_settings_syncing = false

func _deathmatch_settings_pressed():
	_open_mode_settings(deathmatch_settings_tab)

func _deathmatch_spawn_toggled(value):
	if deathmatch_settings_syncing:
		return
	Multiplayer.config.deathmatchSpawnNPCs = value
	save_host()

func _ensure_counterop_settings_tab():
	if is_instance_valid(counterop_settings_tab):
		return
	var tabs = $CenterContainer/TabContainer
	var host = tabs.get_node("Host")
	counterop_settings_tab = PanelContainer.new()
	counterop_settings_tab.name = "CounterOpSettings"
	counterop_settings_tab.add_stylebox_override("panel", host.get_stylebox("panel"))
	var box = VBoxContainer.new()
	box.name = "VBoxContainer"
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_constant_override("separation", 10)
	counterop_settings_tab.add_child(box)
	var header = Label.new()
	header.text = "Counter-Opps settings"
	header.align = Label.ALIGN_CENTER
	box.add_child(header)
	var check_theme = cruelty_settings_tab.get_node("VBoxContainer/CanRespawn/TickEdit").theme
	for key in ["enemyFriendlyFire", "neutralEnemies", "randomizeTeams", "overrideTeams"]:
		var row = HBoxContainer.new()
		row.name = key
		var label = Label.new()
		label.text = counterop_settings_descriptions[key][0] + ":"
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)
		var check = CheckBox.new()
		check.name = "TickEdit"
		check.rect_min_size = Vector2(50, 0)
		check.theme = check_theme
		check.text = "<<"
		check.connect("toggled", self, "_counterop_setting_toggled", [key])
		row.add_child(check)
		box.add_child(row)
		counterop_setting_boxes[key] = check
		_connect_host_tooltip(row, counterop_settings_descriptions[key][1])
	_add_shared_counterop_settings(box)
	counterop_settings_tab.theme = tabs.theme
	add_child(counterop_settings_tab)
	counterop_settings_tab.hide()
	counterop_bottom_tab = Button.new()
	counterop_bottom_tab.name = "CounterOpBottomTab"
	counterop_bottom_tab.text = " Counter-Opps Settings "
	counterop_bottom_tab.focus_mode = Control.FOCUS_NONE
	counterop_bottom_tab.rect_min_size = Vector2(220, 30)
	counterop_bottom_tab.toggle_mode = true
	counterop_bottom_tab.add_stylebox_override("normal", tabs.get_stylebox("tab_bg"))
	counterop_bottom_tab.add_stylebox_override("hover", tabs.get_stylebox("tab_fg"))
	counterop_bottom_tab.add_stylebox_override("pressed", tabs.get_stylebox("tab_fg"))
	counterop_bottom_tab.add_stylebox_override("focus", StyleBoxEmpty.new())
	counterop_bottom_tab.connect("pressed", self, "_counterop_bottom_tab_pressed")
	add_child(counterop_bottom_tab)
	_layout_counterop_bottom_tab()

func _layout_counterop_bottom_tab():
	if not is_instance_valid(counterop_bottom_tab):
		return
	_layout_mode_button(counterop_bottom_tab)

func _counterop_settings_available():
	return $CenterContainer.visible and Multiplayer.NetworkBridge.check_connection() and Multiplayer.players.has(Multiplayer.NetworkBridge.get_id()) and Multiplayer.NetworkBridge.is_world_authority() and Multiplayer.CounterOp.is_active()

func _sync_counterop_settings_tab():
	if not is_instance_valid(counterop_settings_tab) or not is_instance_valid(counterop_bottom_tab):
		return
	_layout_counterop_bottom_tab()
	var tabs = $CenterContainer/TabContainer
	var show_tab = _counterop_settings_available()
	if counterop_bottom_shown != show_tab:
		counterop_bottom_shown = show_tab
		counterop_bottom_tab.visible = show_tab
		if not show_tab and counterop_settings_tab.visible:
			counterop_settings_tab.hide()
	if not show_tab:
		return
	counterop_bottom_tab.pressed = counterop_settings_tab.visible
	counterop_settings_syncing = true
	for key in counterop_setting_boxes:
		counterop_setting_boxes[key].pressed = Multiplayer.CounterOp.settings[key]
	counterop_setting_boxes["neutralEnemies"].disabled = not Multiplayer.CounterOp.settings.enemyFriendlyFire
	counterop_setting_boxes["randomizeTeams"].disabled = Multiplayer.CounterOp.settings.overrideTeams
	counterop_settings_syncing = false

func _counterop_bottom_tab_pressed():
	if not _counterop_settings_available():
		return
	_open_mode_settings(counterop_settings_tab)
	counterop_bottom_tab.pressed = true

func _counterop_setting_toggled(value, key):
	if counterop_settings_syncing or not Multiplayer.NetworkBridge.is_world_authority():
		return
	Multiplayer.CounterOp.set_setting(key, value)

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
	var selected = tabs.get_current_tab_control()
	if in_lobby and stats_tab.get_parent() == null:
		tabs.add_child(stats_tab)
	elif not in_lobby and stats_tab.get_parent() != null:
		if tabs.current_tab == stats_tab.get_index():
			tabs.current_tab = 0
		tabs.remove_child(stats_tab)
	if is_instance_valid(selected) and selected.get_parent() == tabs:
		tabs.current_tab = selected.get_index()

func _exit_tree():
	if is_instance_valid(stats_tab) and stats_tab.get_parent() == null:
		stats_tab.free()

func _ensure_cruelty_settings_tab():
	var tabs = $CenterContainer/TabContainer
	var host = tabs.get_node("Host")
	cruelty_settings_tab = PanelContainer.new()
	cruelty_settings_tab.name = "CrueltySettings"
	cruelty_settings_tab.add_stylebox_override("panel", host.get_stylebox("panel"))
	var box = VBoxContainer.new()
	box.name = "VBoxContainer"
	box.add_constant_override("separation", 10)
	cruelty_settings_tab.add_child(box)
	var header = Label.new()
	header.text = "Cruelty settings"
	header.align = Label.ALIGN_CENTER
	box.add_child(header)
	for key in ["CanRespawn", "SelfRespawn", "FriendlyFire", "ChangeModeOnDeath", "ReviveTimer", "Lives"]:
		var row = host.get_node("VBoxContainer/" + key)
		row.get_parent().remove_child(row)
		box.add_child(row)
	var saving_row = HBoxContainer.new()
	saving_row.name = "SaveProgress"
	var saving_label = Label.new()
	saving_label.text = "Save Campaign Progress:"
	saving_label.size_flags_horizontal = SIZE_EXPAND_FILL
	saving_row.add_child(saving_label)
	var saving = CheckBox.new()
	saving.name = "TickEdit"
	saving.text = "<<"
	saving.theme = box.get_node("CanRespawn/TickEdit").theme
	saving.pressed = true
	saving_row.add_child(saving)
	box.add_child(saving_row)
	_connect_host_tooltip(saving_row, "Save campaign progress for everyone in this lobby. When disabled, progress, money, unlocks and stocks are temporary and restored when saving is enabled again or you leave. Singleplayer saving is unchanged.")
	var save = Button.new()
	save.name = "Save"
	save.text = "  Save  "
	save.rect_min_size = Vector2(120, 26)
	save.connect("pressed", self, "save_host")
	cruelty_settings_tab.add_child(save)
	cruelty_settings_tab.theme = tabs.theme
	add_child(cruelty_settings_tab)
	cruelty_settings_tab.hide()
	cruelty_bottom_tab = Button.new()
	cruelty_bottom_tab.text = " Cruelty Settings "
	cruelty_bottom_tab.focus_mode = Control.FOCUS_NONE
	cruelty_bottom_tab.toggle_mode = true
	for style in ["normal", "hover", "pressed"]:
		cruelty_bottom_tab.add_stylebox_override(style, tabs.get_stylebox("tab_bg" if style == "normal" else "tab_fg"))
	cruelty_bottom_tab.add_stylebox_override("focus", StyleBoxEmpty.new())
	cruelty_bottom_tab.connect("pressed", self, "_cruelty_settings_pressed")
	add_child(cruelty_bottom_tab)
	cruelty_bottom_tab.hide()

func _sync_cruelty_settings_tab():
	var tabs = $CenterContainer/TabContainer
	var available = $CenterContainer.visible and Multiplayer.hostSettings.get("gameMode", "cruelty") == "cruelty" and Multiplayer.NetworkBridge.check_connection() and Multiplayer.players.has(Multiplayer.NetworkBridge.get_id()) and Multiplayer.NetworkBridge.is_world_authority()
	cruelty_bottom_tab.visible = available
	_layout_mode_button(cruelty_bottom_tab)
	cruelty_bottom_tab.pressed = cruelty_settings_tab.visible
	if not available and cruelty_settings_tab.visible:
		cruelty_settings_tab.hide()

func _cruelty_settings_pressed():
	_open_mode_settings(cruelty_settings_tab)

func _layout_mode_button(button):
	var tabs = $CenterContainer/TabContainer
	button.rect_size = Vector2(max(220, button.get_combined_minimum_size().x), 30)
	var point = Vector2((tabs.rect_size.x - button.rect_size.x) * 0.5, tabs.rect_size.y - 2)
	button.rect_position = get_global_transform().affine_inverse().xform(tabs.get_global_transform().xform(point))
	button.raise()

func _layout_mode_panels():
	var tabs = $CenterContainer/TabContainer
	var current = tabs.get_current_tab_control()
	if current == null:
		return
	var mode_visible = false
	for panel in [cruelty_settings_tab, counterop_settings_tab, deathmatch_settings_tab]:
		if is_instance_valid(panel) and panel.visible:
			mode_visible = true
			panel.rect_position = get_global_transform().affine_inverse().xform(current.rect_global_position)
			panel.rect_size = current.rect_size
			if panel == cruelty_settings_tab:
				var save = panel.get_node("Save")
				save.rect_size = Vector2(120, 26)
				save.rect_position = Vector2((panel.rect_size.x - save.rect_size.x) * 0.5, panel.rect_size.y - save.rect_size.y - 3)
			panel.raise()
	current.visible = not mode_visible

func _open_mode_settings(selected):
	for panel in [cruelty_settings_tab, counterop_settings_tab, deathmatch_settings_tab]:
		if is_instance_valid(panel):
			panel.visible = panel == selected
	_layout_mode_panels()

func _close_mode_settings(_tab = 0):
	var current = $CenterContainer/TabContainer.get_current_tab_control()
	if current != null:
		current.show()
	for panel in [cruelty_settings_tab, counterop_settings_tab, deathmatch_settings_tab]:
		if is_instance_valid(panel):
			panel.hide()

func _mode_header_input(event):
	if event is InputEventMouseButton and event.pressed and event.position.y < 40:
		_close_mode_settings()

func _add_shared_counterop_settings(box):
	box.add_constant_override("separation", 5)
	for key in ["CanRespawn", "FriendlyFire", "ReviveTimer", "Lives"]:
		var original = cruelty_settings_tab.get_node("VBoxContainer/" + key)
		var copy = original.duplicate()
		box.add_child(copy)
		_connect_host_tooltip(copy, host_tooltips[key])
		var widget = "ReviveEdit" if key == "ReviveTimer" else ("LivesEdit" if key == "Lives" else "TickEdit")
		var signal_name = "value_changed" if key in ["ReviveTimer", "Lives"] else "toggled"
		for control in [original.get_node(widget), copy.get_node(widget)]:
			control.connect(signal_name, self, "_shared_mode_setting_changed", [key, widget, control])

func _shared_mode_setting_changed(value, key, widget, source):
	if shared_settings_syncing:
		return
	shared_settings_syncing = true
	for panel in [cruelty_settings_tab, counterop_settings_tab]:
		var control = panel.get_node("VBoxContainer/" + key + "/" + widget)
		if control != source:
			control.set("value" if control is Range else "pressed", value)
	shared_settings_syncing = false
	save_host()

func _sync_implant_tab():
	var tabs = $CenterContainer/TabContainer
	var panel = tabs.get_node("Implants")
	var in_lobby = Multiplayer.NetworkBridge.check_connection() and Multiplayer.players.has(Multiplayer.NetworkBridge.get_id())
	var show_implants = in_lobby and Multiplayer.NetworkBridge.is_world_authority()
	if implants_tab_shown != show_implants:
		var selected = tabs.get_current_tab_control()
		implants_tab_shown = show_implants
		if not show_implants and selected == panel:
			tabs.current_tab = 0
		tabs.set_tab_hidden(panel.get_index(), not show_implants)
		if is_instance_valid(selected) and selected != panel:
			tabs.current_tab = selected.get_index()
	if show_implants:
		panel.refresh()
