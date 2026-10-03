extends Node

const Paths = preload("res://MOD_CONTENT/CruS Online/ContentPaths.gd")
const CHUNK_BYTES = 24576
const RESUME_FILE = "user://online-rejoin.json"
var manifest = {"protocol": 1, "groups": []}
var host_offers = {}
var incoming = {}
var requested = []
var downloads = []
var current = {}
var destination = {}
var transfer_id = ""
var accepted = false
var installing = false
var preserve_staging = false
var transferred = 0
var total_bytes = 0
var last_activity = 0
var receiver = null
var popup
var content_rows
var status_label
var footer_label
var progress
var yes_button
var no_button
var hash_thread = null
var hash_result = null
var catalog_pending = false
var join_pending = false
var disable_only_offer = false
onready var Multiplayer = get_parent()
onready var Bridge = get_parent().get_node("NetworkBridge")

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	Bridge.register_rpcs(self, [["content_offer", Bridge.PERMISSION.SERVER], ["content_request", Bridge.PERMISSION.ALL], ["content_chunk", Bridge.PERMISSION.SERVER], ["content_cancel", Bridge.PERMISSION.ALL]])
	create_popup()

func create_popup():
	var layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	popup = WindowDialog.new()
	popup.name = "HostContent"
	popup.window_title = "Cruelty Squad Online"
	popup.rect_min_size = Vector2(650, 440)
	popup.rect_size = popup.rect_min_size
	popup.theme = load("res://Menu/menu_theme.tres")
	popup.add_color_override("title_color", Color(1, 0, 0))
	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = Color(0.15863, 0.441406, 0, 0.470588)
	outer_style.expand_margin_top = 20
	popup.add_stylebox_override("panel", outer_style)
	layer.add_child(popup)
	popup.connect("popup_hide", self, "popup_closed")
	var panel = Panel.new()
	panel.anchor_right = 1
	panel.anchor_bottom = 1
	var panel_style = StyleBoxTexture.new()
	panel_style.texture = load("res://Textures/Menu/background_1.png")
	panel_style.region_rect = Rect2(0, 0, 256, 256)
	panel_style.modulate_color = Color(0.831373, 0.878431, 0.419608, 0.705882)
	panel.add_stylebox_override("panel", panel_style)
	popup.add_child(panel)
	var column = VBoxContainer.new()
	column.anchor_right = 1
	column.anchor_bottom = 1
	column.margin_left = 18
	column.margin_right = -18
	column.margin_top = 14
	column.margin_bottom = -14
	panel.add_child(column)
	status_label = Label.new()
	status_label.autowrap = true
	status_label.rect_min_size.y = 115
	column.add_child(status_label)
	var list_panel = PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_stylebox_override("panel", load("res://MOD_CONTENT/CruS Online/redpanel.tres"))
	column.add_child(list_panel)
	var list_scroll = ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.add_stylebox_override("bg", StyleBoxEmpty.new())
	list_panel.add_child(list_scroll)
	content_rows = VBoxContainer.new()
	content_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_rows.add_constant_override("separation", 2)
	list_scroll.add_child(content_rows)
	footer_label = Label.new()
	footer_label.text = "Existing active mods will be disabled for this lobby."
	footer_label.autowrap = true
	footer_label.rect_min_size.y = 40
	column.add_child(footer_label)
	progress = ProgressBar.new()
	progress.percent_visible = false
	column.add_child(progress)
	progress.hide()
	var buttons = HBoxContainer.new()
	column.add_child(buttons)
	yes_button = Button.new()
	yes_button.text = "Install and join"
	yes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(yes_button)
	yes_button.connect("pressed", self, "accept_content")
	no_button = Button.new()
	no_button.text = "Cancel"
	no_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(no_button)
	no_button.connect("pressed", self, "decline_content")

func add_content_row(name, version):
	var row = Panel.new()
	row.rect_min_size = Vector2(0, 32)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_stylebox_override("panel", popup.theme.get_stylebox("normal", "Button").duplicate())
	content_rows.add_child(row)
	for item in [[name, Label.ALIGN_LEFT, 0.0, 0.75], [version, Label.ALIGN_RIGHT, 0.75, 1.0]]:
		var label = Label.new()
		label.text = item[0]
		label.align = item[1]
		label.anchor_left = item[2]
		label.anchor_right = item[3]
		label.anchor_bottom = 1
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
	return row

func set_destination(value):
	destination = value.duplicate(true)

func refresh_manifest():
	if hash_thread != null:
		return
	var groups = []
	var loader = get_node_or_null("/root/Mod")
	if loader != null:
		for mod in loader.get_children():
			if not "packs" in mod or not mod.loaded or str(mod.name) == "CruS Online":
				continue
			var folder = str(mod.modpath).get_file()
			var root = "user://mods/" + folder
			if not File.new().file_exists(root + "/mod.json"):
				continue
			var files = [{"path": "mod.json"}]
			for pack in mod.packs:
				if str(pack).begins_with(root + "/"):
					files.append({"path": str(pack).trim_prefix(root + "/")})
			files.sort_custom(self, "file_order")
			groups.append({"kind": "mods", "folder": folder, "name": str(mod.name), "version": str(mod.version), "files": files})
	if Multiplayer.Extensions.modbase() != null:
		for level in Multiplayer.Extensions.custom_levels:
			if level.get("local_debug", false) or level.has("campaign_id"):
				continue
			var files = []
			collect_files("user://levels/" + level.folder, "", files)
			groups.append({"kind": "levels", "folder": level.folder, "name": level.name, "version": str(level.get("version", "")), "files": files})
		for campaign in Multiplayer.Extensions.campaigns:
			if not campaign.has("folder"):
				continue
			var files = []
			collect_files("user://campaigns/" + campaign.folder, "", files)
			groups.append({"kind": "campaigns", "folder": campaign.folder, "name": campaign.name, "version": campaign.version, "files": files})
	groups.sort_custom(self, "group_order")
	hash_thread = Thread.new()
	var error = hash_thread.start(self, "hash_manifest", {"protocol": 1, "groups": groups})
	if error != OK:
		hash_thread = null
		hash_result = {"error": "Cannot start content verification."}

func group_order(a, b):
	return (a.kind + "/" + a.folder) < (b.kind + "/" + b.folder)

func file_order(a, b):
	return a.path < b.path

func collect_files(root, relative, files):
	var directory = Directory.new()
	if directory.open(root + ("/" + relative if not relative.empty() else "")) != OK:
		return
	directory.list_dir_begin(true, true)
	var name = directory.get_next()
	var entries = []
	while not name.empty():
		entries.append([name, directory.current_is_dir()])
		name = directory.get_next()
	directory.list_dir_end()
	entries.sort()
	for entry in entries:
		var path = entry[0] if relative.empty() else relative + "/" + entry[0]
		if not Paths.safe_relative(path) or files.size() >= Paths.MAX_FILES:
			continue
		if entry[1]:
			collect_files(root, path, files)
		else:
			files.append({"path": path})

func hash_manifest(value):
	for group in value.groups:
		for entry in group.files:
			var path = "user://" + group.kind + "/" + group.folder + "/" + entry.path
			var file = File.new()
			if file.open(path, File.READ) != OK:
				return {"error": "Cannot read host content: " + path}
			entry["size"] = file.get_len()
			file.close()
			entry["sha256"] = File.new().get_sha256(path)
	var error = Paths.validate(value)
	return value if error.empty() else {"error": error}

func fingerprint():
	return JSON.print(manifest).sha256_text()

func ready_for_join():
	return Multiplayer.Extensions.initialized and hash_thread == null and not catalog_pending

func offer(peer, info, code):
	if not ready_for_join():
		host_offers[peer] = {"info": info, "code": code, "pending": true, "time": OS.get_ticks_msec()}
		return
	if hash_result != null and hash_result.has("error"):
		Bridge.n_rpc_id(self, peer, "content_offer", [{"error": hash_result.error}])
		return
	host_offers[peer] = {"info": info, "code": code, "manifest": manifest.duplicate(true), "time": OS.get_ticks_msec()}
	Bridge.n_rpc_id(self, peer, "content_offer", [manifest])

puppet func content_offer(sender, value):
	if Bridge.request_sender(sender) != Bridge.get_host_id() or Bridge.is_world_authority() or Multiplayer.dataLoaded:
		return
	if typeof(value) == TYPE_DICTIONARY and value.has("error"):
		fail(str(value.error))
		return
	if accepted:
		return
	var error = Paths.validate(value)
	if not error.empty():
		fail(error)
		return
	incoming = value.duplicate(true)
	requested.clear()
	downloads.clear()
	for row in content_rows.get_children():
		content_rows.remove_child(row)
		row.queue_free()
	total_bytes = 0
	var disabled_mods = []
	var extra_mods = []
	var host_names = []
	for group in incoming.groups:
		if group.kind == "mods":
			host_names.append(group.name)
		for entry in group.files:
			var path = group.kind + "/" + group.folder + "/" + entry.path
			var item = entry.duplicate()
			item["full_path"] = path
			var same = local_hash(path) == entry.sha256
			item["download"] = not same
			downloads.append(item)
			if not same:
				requested.append(path)
				total_bytes += entry.size
		add_content_row(group.name, group.version)
	var loader = get_node_or_null("/root/Mod")
	if loader != null:
		for mod in loader.get_children():
			if "packs" in mod and mod.loaded and mod.name != "CruS Online" and not host_names.has(str(mod.name)):
				disabled_mods.append(str(mod.name))
				extra_mods.append([str(mod.name), str(mod.version)])
	incoming["disable"] = disabled_mods
	if requested.empty() and disabled_mods.empty() and enabled_matches(host_names):
		manifest = value.duplicate(true)
		send_join()
		return
	transfer_id = str(OS.get_ticks_msec()) + "-" + str(randi())
	last_activity = OS.get_ticks_msec()
	disable_only_offer = requested.empty() and not disabled_mods.empty() and enabled_matches(host_names)
	footer_label.visible = not disable_only_offer
	if disable_only_offer:
		for row in content_rows.get_children():
			content_rows.remove_child(row)
			row.queue_free()
		for mod in extra_mods:
			add_content_row(mod[0], mod[1])
		status_label.text = "This lobby does not use the active mods listed below.\n\nDisable them, then restart and join automatically?"
		yes_button.text = "Disable and Join"
	else:
		status_label.text = "This lobby uses mods, custom missions, or campaigns.\n\nInstall or update the content below, then restart and join automatically?"
		yes_button.text = "Install and Join"
	progress.value = 0
	yes_button.disabled = false
	popup.rect_scale = Vector2(Global.resolution[0] / 1280, Global.resolution[1] / 720)
	popup.popup_centered()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func enabled_matches(names):
	var enabled = Multiplayer.Extensions.read_json("user://enabled_mods.json")
	for name in names:
		if enabled.get(name, true) == false:
			return false
	return true

func local_hash(path):
	for group in manifest.groups:
		for item in group.files:
			if group.kind + "/" + group.folder + "/" + item.path == path:
				return item.sha256
	return ""

func accept_content():
	if incoming.empty() or accepted:
		return
	accepted = true
	preserve_staging = false
	yes_button.disabled = true
	status_label.text = "Disabling extra mods and restarting..." if disable_only_offer else "Downloading and verifying host content..."
	transferred = 0
	if not prepare_staging():
		fail("Cannot prepare the content installation folder.")
		return
	request_next()

func staging_root():
	return "user://online-content/" + transfer_id

func prepare_staging():
	if Directory.new().make_dir_recursive(staging_root()) != OK:
		return false
	for item in downloads:
		var path = staging_root() + "/" + item.full_path
		if Directory.new().make_dir_recursive(path.get_base_dir()) != OK:
			return false
		if not item.download and Directory.new().copy("user://" + item.full_path, path) != OK:
			return false
	return true

func request_next():
	if receiver != null:
		receiver.close()
		receiver = null
	if requested.empty():
		install_content()
		return
	var path = requested.pop_front()
	for item in downloads:
		if item.full_path == path:
			current = item.duplicate()
			break
	current["offset"] = 0
	receiver = File.new()
	if receiver.open(staging_root() + "/" + path, File.WRITE) != OK:
		fail("Cannot write the downloaded content.")
		return
	Bridge.n_rpc_id(self, Bridge.get_host_id(), "content_request", [path, 0])
	last_activity = OS.get_ticks_msec()

master func content_request(sender, path, offset):
	var peer = Bridge.request_sender(sender)
	if not Bridge.is_world_authority() or not host_offers.has(peer) or host_offers[peer].get("pending", false) or typeof(offset) != TYPE_INT or typeof(path) != TYPE_STRING:
		return
	var offer_data = host_offers[peer]
	var expected = {}
	for group in offer_data.manifest.groups:
		for entry in group.files:
			if group.kind + "/" + group.folder + "/" + entry.path == path:
				expected = entry
	if expected.empty() or offset < 0 or offset > expected.size or offset % CHUNK_BYTES != 0:
		return
	var next_offset = offer_data.get("offset", 0) if offer_data.get("path", "") == path else 0
	if offset != next_offset:
		return
	var file = File.new()
	if file.open("user://" + path, File.READ) != OK or file.get_len() != expected.size:
		Bridge.n_rpc_id(self, peer, "content_offer", [{"error": "Host content changed; reconnect to refresh it."}])
		return
	file.seek(offset)
	var bytes = file.get_buffer(min(CHUNK_BYTES, expected.size - offset))
	file.close()
	offer_data["path"] = path
	offer_data["offset"] = offset + bytes.size()
	offer_data["time"] = OS.get_ticks_msec()
	Bridge.n_rpc_id(self, peer, "content_chunk", [path, offset, bytes])

puppet func content_chunk(sender, path, offset, bytes):
	if Bridge.request_sender(sender) != Bridge.get_host_id() or not accepted or receiver == null or path != current.get("full_path") or offset != current.get("offset") or typeof(bytes) != TYPE_RAW_ARRAY or bytes.size() > CHUNK_BYTES:
		return
	var remaining = current.size - offset
	if bytes.size() != min(CHUNK_BYTES, remaining):
		fail("Invalid download chunk.")
		return
	receiver.store_buffer(bytes)
	if receiver.get_error() != OK:
		fail("Cannot save downloaded content.")
		return
	current.offset += bytes.size()
	transferred += bytes.size()
	last_activity = OS.get_ticks_msec()
	progress.value = 100.0 * transferred / max(1, total_bytes)
	status_label.text = "Downloading %s\n%.1f / %.1f MB" % [path.get_file(), transferred / 1048576.0, total_bytes / 1048576.0]
	if current.offset == current.size:
		receiver.close()
		receiver = null
		if File.new().get_sha256(staging_root() + "/" + path) != current.sha256:
			fail("Downloaded file verification failed: " + path.get_file())
			return
		call_deferred("request_next")
	else:
		Bridge.n_rpc_id(self, Bridge.get_host_id(), "content_request", [path, current.offset])

func install_content():
	status_label.text = "Installing verified content..."
	for item in downloads:
		if File.new().get_sha256(staging_root() + "/" + item.full_path) != item.sha256:
			fail("Content changed before installation.")
			return
	for group in incoming.groups:
		if group.kind == "mods":
			var metadata = Multiplayer.Extensions.read_json(staging_root() + "/mods/" + group.folder + "/mod.json")
			if metadata.get("name") != group.name or str(metadata.get("version", "")) != group.version:
				fail("Downloaded mod metadata does not match the host.")
				return
	var moved = []
	var backups = []
	var directory = Directory.new()
	for group in incoming.groups:
		var relative = group.kind + "/" + group.folder
		var target = "user://" + relative
		var source = staging_root() + "/" + relative
		var backup = staging_root() + "/previous/" + relative
		directory.make_dir_recursive(target.get_base_dir())
		if directory.dir_exists(target):
			directory.make_dir_recursive(backup.get_base_dir())
			if directory.rename(target, backup) != OK:
				rollback(moved, backups)
				fail("Cannot replace the installed content. No changes were kept.")
				return
			backups.append([backup, target])
		if directory.rename(source, target) != OK:
			rollback(moved, backups)
			fail("Cannot install content. Previous files have been restored.")
			return
		moved.append([target, source])
	var enabled = Multiplayer.Extensions.read_json("user://enabled_mods.json")
	for group in incoming.groups:
		if group.kind == "mods":
			enabled[group.name] = true
	for name in incoming.get("disable", []):
		enabled[name] = false
	var file = File.new()
	var enabled_path = staging_root() + "/enabled_mods.json"
	if file.open(enabled_path, File.WRITE) != OK:
		rollback(moved, backups)
		fail("Cannot update the enabled mod list.")
		return
	file.store_string(JSON.print(enabled))
	var write_error = file.get_error()
	file.close()
	var saved_enabled = Multiplayer.Extensions.read_json(enabled_path)
	var enabled_matches = saved_enabled.size() == enabled.size()
	for name in enabled:
		if not saved_enabled.has(name) or saved_enabled[name] != enabled[name]:
			enabled_matches = false
	if write_error != OK or not enabled_matches:
		rollback(moved, backups)
		fail("Cannot save the enabled mod list.")
		return
	var enabled_backup = staging_root() + "/previous-enabled-mods.json"
	var had_enabled = File.new().file_exists("user://enabled_mods.json")
	if had_enabled and directory.rename("user://enabled_mods.json", enabled_backup) != OK:
		rollback(moved, backups)
		fail("Cannot replace the enabled mod list.")
		return
	if directory.rename(enabled_path, "user://enabled_mods.json") != OK:
		if had_enabled:
			directory.rename(enabled_backup, "user://enabled_mods.json")
		rollback(moved, backups)
		fail("Cannot install the enabled mod list.")
		return
	preserve_staging = true
	destination["created"] = OS.get_unix_time()
	destination["fingerprint"] = JSON.print({"protocol": 1, "groups": incoming.groups}).sha256_text()
	if file.open(RESUME_FILE, File.WRITE) != OK:
		fail("Content installed, but automatic rejoining could not be saved. Reopen the game and join manually.")
		return
	file.store_string(JSON.print(destination))
	file.close()
	progress.value = 100
	status_label.text = "Installed. Restarting and rejoining the lobby..."
	installing = true
	call_deferred("restart_game")

func rollback(moved, backups):
	var directory = Directory.new()
	moved.invert()
	backups.invert()
	for pair in moved:
		directory.rename(pair[0], pair[1])
	for pair in backups:
		directory.rename(pair[0], pair[1])

func restart_game():
	var process = OS.execute(OS.get_executable_path(), OS.get_cmdline_args(), false)
	if process < 0:
		installing = false
		fail("Content installed. Please restart the game to rejoin.")
		return
	get_tree().quit()

func resume_join():
	catalog_pending = true
	refresh_manifest()

func finish_resume():
	var file = File.new()
	if not file.file_exists(RESUME_FILE):
		return
	var saved = Multiplayer.Extensions.read_json(RESUME_FILE)
	Directory.new().remove(RESUME_FILE)
	if saved.empty() or OS.get_unix_time() - int(saved.get("created", 0)) > 600:
		return
	destination = saved
	if saved.get("fingerprint", "") != fingerprint():
		fail("Installed content did not load correctly. Automatic rejoin stopped.")
		return
	for menu in get_tree().get_nodes_in_group("MultiplayerMenu"):
		menu.enable_menu()
		menu.get_node("CenterContainer/TabContainer").current_tab = 0
		menu.get_node("CenterContainer/TabContainer/Main").current_tab = 2 if saved.get("transport") == "steam" else 1
	if saved.get("transport") == "steam":
		Bridge.set_mode(Bridge.MULTIPLAYER_TYPE.STEAM)
		if Multiplayer.SteamInit.is_online:
			Multiplayer.SteamLobby.join_lobby(int(saved.get("lobby", "0")), str(saved.get("code", "")))
		else:
			fail("Steam is unavailable. Installed content is ready; join again once Steam is connected.")
	else:
		Bridge.set_mode(Bridge.MULTIPLAYER_TYPE.LAN)
		Multiplayer.join_to_server(str(saved.get("ip", "127.0.0.1")), int(saved.get("port", 25567)))

func send_join():
	Bridge.n_rpc_id(Multiplayer, Bridge.get_host_id(), "connect_init", [Multiplayer.SteamLobby.join_code() if Bridge.is_steam() else "", Multiplayer.version + ":content1", Multiplayer.playerInfo, fingerprint()])

func begin_join():
	if ready_for_join():
		send_join()
	else:
		join_pending = true

func decline_content():
	if installing:
		return
	Bridge.n_rpc_id(self, Bridge.get_host_id(), "content_cancel")
	reset()
	Multiplayer.leave_server()

func popup_closed():
	if not installing and not incoming.empty():
		decline_content()

func fail(message):
	print("[CruS content] ", message)
	if receiver != null:
		receiver.close()
		receiver = null
	accepted = false
	incoming.clear()
	status_label.text = message
	yes_button.disabled = true
	popup.popup_centered()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Bridge.n_rpc_id(self, Bridge.get_host_id(), "content_cancel")
	Multiplayer.leave_server()
	popup.popup_centered()

master func content_cancel(sender):
	if Bridge.is_world_authority():
		host_offers.erase(Bridge.request_sender(sender))

func reset():
	if receiver != null:
		receiver.close()
		receiver = null
	incoming.clear()
	accepted = false
	disable_only_offer = false
	join_pending = false
	requested.clear()
	downloads.clear()
	current.clear()
	host_offers.clear()
	if not preserve_staging and not transfer_id.empty():
		remove_staging(staging_root())
	transfer_id = ""
	if popup != null:
		popup.hide()

func remove_staging(path):
	if not path.begins_with("user://online-content/") or not Paths.safe_relative(path.trim_prefix("user://online-content/")):
		return
	var directory = Directory.new()
	if directory.open(path) != OK:
		return
	directory.list_dir_begin(true, true)
	var name = directory.get_next()
	var entries = []
	while not name.empty():
		entries.append([name, directory.current_is_dir()])
		name = directory.get_next()
	directory.list_dir_end()
	for entry in entries:
		if entry[1]:
			remove_staging(path + "/" + entry[0])
		else:
			directory.remove(path + "/" + entry[0])
	directory.remove(path)

func _process(_delta):
	if hash_thread != null and not hash_thread.is_alive():
		hash_result = hash_thread.wait_to_finish()
		hash_thread = null
		if not hash_result.has("error"):
			manifest = hash_result
		if catalog_pending:
			catalog_pending = false
			finish_resume()
		for peer in host_offers.keys():
			if host_offers[peer].get("pending", false):
				var data = host_offers[peer]
				offer(peer, data.info, data.code)
	if join_pending and ready_for_join() and Bridge.check_connection():
		join_pending = false
		send_join()
	if accepted and OS.get_ticks_msec() - last_activity > 60000 and not installing:
		fail("Content download timed out. Reconnect to try again.")
	for peer in host_offers.keys():
		if OS.get_ticks_msec() - host_offers[peer].time > 600000:
			host_offers.erase(peer)

func _exit_tree():
	if hash_thread != null:
		hash_thread.wait_to_finish()
		hash_thread = null
