extends Node

var mp
var failures = 0
var restarted = false
var sent_ready = false
var role = ROLE

class SteamWire:
	extends Reference
	var sent = []
	func sendP2PPacket(peer, bytes, mode, channel):
		sent.append([peer, bytes, mode, channel])
		return true

class SteamParent:
	extends Node
	var Steam = SteamWire.new()
	var steam_id = 1

class WireLobby:
	extends Node
	func in_lobby(): return true
	func get_lobby_owner(): return 1

class ContentTarget:
	extends Node
	var received = []
	func content_request(sender, path, offset): received.append([sender, path, offset])
	func content_chunk(sender, path, offset, bytes): received.append([sender, path, offset, bytes])
	func gameplay(sender, value): received.append([sender, value])

func wire_packet(net, method, args, epoch):
	var inner = PoolByteArray([net.PACKET_TYPE.RPC])
	inner.append_array(var2bytes([0, method, args]))
	var packet = PoolByteArray([net.SCENE_EVENT])
	packet.append_array(var2bytes([epoch, inner]))
	return packet

func test_steam_content():
	var parent = SteamParent.new()
	add_child(parent)
	var lobby = WireLobby.new()
	lobby.name = "SteamLobby"
	parent.add_child(lobby)
	var net = preload("res://MOD_CONTENT/CruS Online/SteamNetwork.gd").new()
	parent.add_child(net)
	net.set_process(false)
	var target = ContentTarget.new()
	add_child(target)
	net.register_rpcs(target, [["content_request", net.PERMISSION.ALL], ["content_chunk", net.PERMISSION.SERVER], ["gameplay", net.PERMISSION.SERVER]])
	for id in [1, 2, 3]:
		var peer = net._create_peer(id)
		peer.connected = true
		peer.host = id == 1
		net._peers[id] = peer
	net._my_steam_id = 1
	net._server_steam_id = 1
	net.scene_epoch = 42
	net._add_node_path_cache(target.get_path(), 0)
	net._handle_packet(2, wire_packet(net, "content_request", ["levels/test/level.json", 0], -1))
	check(target.received.size() == 1 and target.received[0][0] == 2, "Steam content requests cross differing scene epochs")
	net._handle_packet(2, wire_packet(net, "content_chunk", ["levels/test/level.json", 0, PoolByteArray([1])], -1))
	check(target.received.size() == 1, "Steam clients cannot supply host content chunks")
	net._handle_packet(2, wire_packet(net, "gameplay", [1], -1))
	check(target.received.size() == 1, "Steam content exception cannot bypass gameplay epoch checks")
	net._rpc(3, target, "content_chunk", ["levels/test/level.json", 0, PoolByteArray([1])])
	var sent = parent.Steam.sent.back()[1]
	var envelope = bytes2var(sent.subarray(1, sent.size() - 1))
	check(envelope[0] == -1, "Steam content send uses lobby-wide epoch")
	net._my_steam_id = 3
	net._handle_packet(1, wire_packet(net, "content_chunk", ["levels/test/level.json", 0, PoolByteArray([1])], -1))
	check(target.received.size() == 2 and target.received.back()[0] == 1, "Steam client accepts authenticated host content")
	target.free()
	parent.free()

func check(condition, label):
	print("EXTENSION_CHECK role=", role, " ", label, "=", condition)
	if not condition:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6), "timeout")
	mp = Global.get_node("Multiplayer")
	mp.Voice.test_capture = true
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	while not mp.Content.ready_for_join():
		yield(get_tree().create_timer(0.1), "timeout")
	if role == "download" and mp.Extensions.modbase() != null:
		role = "rejoin"
	test_steam_content()
	var Paths = preload("res://MOD_CONTENT/CruS Online/ContentPaths.gd")
	for path in ["../bad", "bad/../path", "C:/escape", "bad\\path", "CON", "bad.", "bad//path"]:
		check(not Paths.safe_relative(path), "reject path " + path)
	if role == "host":
		var online_menu = get_tree().get_nodes_in_group("MultiplayerMenu")[0]
		online_menu._setup_credit_logos()
		online_menu._open_credits()
		yield(get_tree(), "idle_frame")
		var credits_sections = online_menu.credits_overlay.get_node("VBoxContainer/Scroll/Sections")
		check(credits_sections.get_child_count() == 2 and credits_sections.get_node("Reconstructed").get_child(0).texture != null and credits_sections.get_node("Original").get_child(1).texture != null, "credits show logos beside their respective text")
		var reconstructed_credits = credits_sections.get_node("Reconstructed/CreditsText")
		var original_credits = credits_sections.get_node("Original/CreditsText")
		check("Art & Design by Chasmy" in reconstructed_credits.text and "Idea inspiration for Surveillance Eyecam" in reconstructed_credits.text and "TRIGGERED P" in original_credits.text, "credits show updated roles")
		check("Player animation assistance, Online menu icon art, playtesting" in original_credits.text and "Xuesos (4cne): Playtesting" in original_credits.text and not ("Keith Mason" in original_credits.text), "original credits use revised Special Thanks")
		var credits_capture = get_viewport().get_texture().get_data()
		credits_capture.flip_y()
		credits_capture.save_png("user://credits-layout.png")
		online_menu._close_credits()
		var loader_version = Global.get_node_or_null("Menu/ModLoaderVersion")
		check(loader_version != null and loader_version.visible and "Loaded mods: 2/2" in loader_version.get_child(0).get_child(0).text, "Modloader loaded-mods count attached to menu")
		check(Global.menu.menu[Global.menu.START].get_child(6).texture_normal == Global.menu.BUTTON_TEXTURES.back() and Global.menu.BUTTON_TEXTURES.back().resource_path.ends_with("icon.png"), "Online button uses its original globe icon")
		check(mp.Extensions.custom_levels.size() == 1, "sample custom level registered")
		check(Global.LEVEL_TIMES_RAW[19] == 83 and Global.LEVEL_TIMES[19] == "1:23" and Global.level_ranks[19] == "S" and Global.LEVEL_PUNISHED[19], "Modbase custom mission records loaded")
		Global.LEVEL_TIMES_RAW[19] = 72
		Global.save_game()
		check(mp.Extensions.read_json("user://custom_level_times.save").get("Hilton Hitjob_raw_time") == 72, "Modbase custom mission records saved")
		check(Global.LEVELS[19].ends_with("HiltonHitjob.scn"), "compiled scene supported")
		check(mp.Extensions.custom_levels[0].scene_path == mp.Extensions.modbase().data.levels[0].scene_path, "custom catalog uses Modbase-processed mission")
		check(Global.menu.level_buttons.size() == 20 and Global.menu.level_buttons[19].get_parent() == null, "custom mission starts on separate grid page")
		check(Global.menu.level_buttons[19].texture_normal == Global.LEVEL_IMAGES[19] and not Global.menu.has_node("CustomMissionButton"), "custom portrait replaces separate selector")
		check(Global.menu.page_buttons.size() == 1 and Global.menu.page_buttons[0].name == "More levels", "normal missions have original down arrow")
		var mods_control = Global.menu.get_node_or_null("Settings/GridContainer/PanelContainer6/VBoxContainer3/ShowMods")
		check(mods_control != null and mods_control.visible and mods_control.has_method("show_mods_popup"), "Modbase loaded-mods control present in Settings")
		if mods_control != null:
			mods_control.show_mods_popup()
			check(mods_control.mods_popup.find_node("List").get_child_count() == 2, "Modbase enable-disable list contains both installed mods")
			yield(get_tree(), "idle_frame")
			var mods_capture = get_viewport().get_texture().get_data()
			mods_capture.flip_y()
			mods_capture.save_png("user://modbase-popup.png")
			mods_control.mods_popup.hide()
			Global.menu._on_Settings_Button_Pressed(Global.menu.START, Global.menu.menu[Global.menu.START].get_child(1))
			while Global.menu.menu_changing:
				yield(get_tree(), "idle_frame")
			yield(get_tree().create_timer(1), "timeout")
			check(mods_control.is_visible_in_tree() and mods_control.get_global_rect().end.y < get_viewport().size.y, "Modbase mod manager button accessible inside Settings")
			var settings_capture = get_viewport().get_texture().get_data()
			settings_capture.flip_y()
			settings_capture.save_png("user://modbase-settings.png")
			Global.menu.go_back(Global.menu.SETTINGS, Global.menu.menu[Global.menu.SETTINGS].get_child(0))
			while Global.menu.menu_changing:
				yield(get_tree(), "idle_frame")
			yield(get_tree().create_timer(1), "timeout")
			check(not Global.menu.get_node("Settings").visible, "Modbase Settings closes before opening mission select")
		Global.menu._on_Start_Button_Pressed(Global.menu.START, Global.menu.menu[Global.menu.START].get_child(0))
		while Global.menu.menu_changing:
			yield(get_tree(), "idle_frame")
		yield(get_tree().create_timer(1), "timeout")
		check(not loader_version.visible, "Modloader count hidden outside main menu")
		var normal_capture = get_viewport().get_texture().get_data()
		normal_capture.flip_y()
		normal_capture.save_png("user://normal-level-page.png")
		Global.menu._on_Next_Levels_Button_Pressed(0, null)
		check(Global.menu.level_buttons[19].get_parent() == Global.menu.menu[Global.menu.LEVEL_SELECT] and Global.menu.page_buttons[0].name == "Previous levels", "up arrow leads back from custom missions")
		Global.CURRENT_LEVEL = 19
		Global.menu.update_level_info()
		check(Global.menu.get_node("Level_Info_Grid/HBoxContainer/Description_Scroll/Description").text == "", "empty authored custom mission description stays empty")
		yield(get_tree().create_timer(1), "timeout")
		var capture = get_viewport().get_texture().get_data()
		capture.flip_y()
		capture.save_png("user://custom-level-page.png")
		mp.config.hostPort = PORT
		mp.host_server()
		yield(get_tree(), "idle_frame")
		check(is_instance_valid(mp.CounterOp.overlay) and mp.CounterOp.ready_count.visible and mp.CounterOp.ready_count.text.begins_with("Players ready:"), "host ready count appears immediately on Level Select")
		check(mp.CounterOp.ready_count.rect_position.x == 120, "ready count moves left without More levels")
		Global.menu.online_navigation_active = true
		Global.menu._apply_online_level_lock()
		check(Global.menu.page_buttons[0].disabled and Global.menu.page_buttons[0].texture_disabled == Global.menu.BUTTON_TEXTURES_D[0], "Previous levels uses disabled square in Online menu")
		Global.menu.online_navigation_active = false
		Global.menu._restore_online_page_buttons()
		check(not Global.menu.page_buttons[0].disabled, "Previous levels works after Online menu closes")
		Global.menu._on_Prev_Levels_Button_Pressed(0, null)
		yield(get_tree(), "idle_frame")
		check(mp.CounterOp.ready_count.rect_position.x == 184, "ready count keeps its position beside More levels")
		Global.menu.online_navigation_active = true
		Global.menu._apply_online_level_lock()
		check(Global.menu.page_buttons[0].disabled and Global.menu.page_buttons[0].texture_disabled == Global.menu.BUTTON_TEXTURES_D[0], "More levels uses disabled square in Online menu")
		Global.menu.online_navigation_active = false
		Global.menu._restore_online_page_buttons()
		check(not Global.menu.page_buttons[0].disabled, "More levels works after Online menu closes")
		while mp.players.size() < 2:
			yield(get_tree().create_timer(0.1), "timeout")
		check(mp.Content.host_offers.empty(), "join admitted only after matching content")
		yield(get_tree().create_timer(2), "timeout")
		Global.CURRENT_LEVEL = 19
		mp.game_init(Global.LEVELS[19])
	elif role == "download":
		check(mp.Extensions.modbase() == null, "Modbase optional before installation")
		mp.join_to_server("127.0.0.1", PORT)
		while mp.Content.incoming.empty():
			yield(get_tree().create_timer(0.1), "timeout")
		check(not mp.dataLoaded and mp.players.empty(), "content prompt precedes lobby admission")
		check(mp.Content.popup.visible, "install prompt shown")
		check(mp.Content.incoming.groups.size() == 2, "host Modbase and sample map listed")
		yield(get_tree(), "idle_frame")
		var offer_capture = get_viewport().get_texture().get_data()
		offer_capture.flip_y()
		offer_capture.save_png("user://content-offer.png")
		mp.Content.popup.hide()
		check(not mp.NetworkBridge.check_connection() and not mp.dataLoaded, "closing install popup cancels joining")
		check(not File.new().file_exists("user://mods/CruS Mod Base/mod.json"), "cancel does not install content")
		mp.join_to_server("127.0.0.1", PORT)
		while mp.Content.incoming.empty() or not mp.Content.popup.visible:
			yield(get_tree().create_timer(0.1), "timeout")
		var offered_names = []
		for row in mp.Content.content_rows.get_children():
			offered_names.append(row.get_child(0).text)
		check(offered_names.has("Hilton Hitjob") and offered_names.has("CruS Mod Base"), "retry offer lists host mods and missions")
		mp.Content.accept_content()
		var downloading_captured = false
		while mp.Content.accepted or mp.Content.installing:
			if not downloading_captured and mp.Content.progress.value >= 25 and mp.Content.progress.value < 95:
				yield(get_tree(), "idle_frame")
				var downloading_capture = get_viewport().get_texture().get_data()
				downloading_capture.flip_y()
				downloading_capture.save_png("user://content-downloading.png")
				downloading_captured = true
			yield(get_tree(), "idle_frame")
		check(downloading_captured, "mod download progress visibly advances")
		print("EXTENSION_INSTALL_FAILURE ", mp.Content.status_label.text)
		get_tree().quit(1)
		return
	else:
		check(mp.Extensions.modbase() != null and mp.Extensions.custom_levels.size() == 1, "downloaded Modbase and map loaded after restart")
		while not mp.dataLoaded:
			yield(get_tree().create_timer(0.1), "timeout")
		check(not File.new().file_exists("user://online-rejoin.json"), "rejoin record consumed once")
	while Global.loader != null or not is_instance_valid(Global.current_scene) or not Global.current_scene.filename.ends_with("HiltonHitjob.scn") or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	check(Global.CURRENT_LEVEL == 19, "custom mission identity resolved on both peers")
	check(mp.players.size() == 2, "both players in custom mission")
	Global.player.health = 10000
	Global.player.set_physics_process(false)
	Global.player.global_transform.origin = Vector3(0, 1000, 0)
	var cheat_scene = load("res://MOD_CONTENT/CruS Mod Base/scenes/Cheats.tscn").instance()
	Global.current_scene.add_child(cheat_scene)
	check(cheat_scene.has_method("_online_blocked") and cheat_scene._online_blocked(), "Modbase commands use guarded script")
	cheat_scene.toggle_infinite_magazine()
	cheat_scene.toggle_infinite_jump()
	cheat_scene.toggle_zombie()
	check(not cheat_scene.inf_mag and not cheat_scene.inf_jump and not cheat_scene.zombie, "Modbase cheat handlers blocked online")
	yield(get_tree().create_timer(2), "timeout")
	check(Global.objectives_total > 0 and Global.objectives == Global.objectives_total, "custom mission targets synchronized")
	if role == "host":
		while not File.new().file_exists("user://client-ready"):
			yield(get_tree().create_timer(0.1), "timeout")
		Global.level_finished()
	else:
		var file = File.new()
		file.open(READY_PATH, File.WRITE)
		file.store_string("ready")
		file.close()
	while not mp.Flow.result_active:
		yield(get_tree().create_timer(0.1), "timeout")
	check(mp.Flow.result_won and Global.menu.visible, "custom mission results displayed")
	check(not Global.menu.get_node("Level_End_Grid/Level_Info_Vbox/Next_Level").visible, "custom results do not advance into unrelated levels")
	if role == "host":
		for index in range(2):
			var extra = Global.menu.create_button(Global.menu.LEVEL_SELECT, "Extra mission", "_on_Level_Pressed", Global.menu.B_LEVEL)
			extra.set_meta("level_index", 20 + index)
			Global.menu.level_buttons.append(extra)
		Global.menu.all_level_buttons = Global.menu.level_buttons.duplicate()
		Global.menu.level_page_start = 0
		Global.menu.level_page_history.clear()
		Global.menu.show_level_page()
		check(Global.menu.page_buttons.size() == 1 and Global.menu.page_buttons[0].texture_normal != null, "Modbase-style next page control has original artwork")
		Global.menu._on_Next_Levels_Button_Pressed(0, null)
		check(Global.menu.level_buttons[21].get_parent() == Global.menu.menu[Global.menu.LEVEL_SELECT], "additional missions appear on next grid page")
		Global.menu._on_Prev_Levels_Button_Pressed(0, null)
		check(Global.menu.level_buttons[0].get_parent() == Global.menu.menu[Global.menu.LEVEL_SELECT], "previous grid page restores base missions")
		var debug_level = mp.Extensions.custom_levels[0].duplicate(true)
		debug_level["name"] = "Development map"
		mp.Extensions.modbase().data["debug_level"] = debug_level
		mp.Extensions.load_custom_levels()
		check(mp.Extensions.custom_levels.back().get("local_debug", false) and mp.Extensions.custom_levels.back().folder == "_debug", "Modbase development map joins the singleplayer catalog")
		Global.CURRENT_LEVEL = Global.LEVELS.size() - 1
		check("singleplayer only" in Global.menu._competitive_start_reason(), "Modbase development map cannot launch as an Online match")
	print("EXTENSION_RESULT role=", role, " failures=", failures)
	var result_file = File.new()
	result_file.open("user://extension-result", File.WRITE)
	result_file.store_string(str(failures))
	result_file.close()
	yield(get_tree().create_timer(2), "timeout")
	get_tree().quit(0 if failures == 0 else 1)
