extends Node

const DEBUG = preload("res://MOD_CONTENT/CruS Online/BuildFlags.gd").DEBUG
const HELP = "/kick <player>, /ban <player>, /mute <player>, /unmute <player>, /players, /announce <message>, /restart, /end, /tp <player1> <player2>, /op <player>, /deop <player>, /help"
const DEVHELP = "/god <player>, /map <level>, /noclip <player>, /heal <player>, /revive <player>, /kill <player>, /money <amount> [player], /give <weapon> [player], /implant <implant> [player], /spawn <npc>, /killall, /freezeai, /unfreezeai"
onready var mp = get_parent()
onready var bridge = get_parent().get_node("NetworkBridge")
var short_ids = {}
var next_id = 1
var bans = {}
var removed = {}
var global_mutes = {}
var pings = {}
var probes = {}
var probe_elapsed = 0.0
var spawn_sequence = 0
var spawned = {}
var frozen = false
var frozen_nodes = {}
var mission = null
var last_reply = ""
var operators = {}
var reply_peer = 0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	bridge.register_rpcs(self, [["request_command", bridge.PERMISSION.ALL], ["command_reply", bridge.PERMISSION.SERVER], ["sync_roles", bridge.PERMISSION.SERVER], ["apply_action", bridge.PERMISSION.SERVER], ["sync_mutes", bridge.PERMISSION.SERVER], ["probe", bridge.PERMISSION.SERVER], ["probe_reply", bridge.PERMISSION.ALL], ["spawn_npc", bridge.PERMISSION.SERVER], ["remove_npc", bridge.PERMISSION.SERVER], ["sync_announcement", bridge.PERMISSION.SERVER]])
	mp.connect("players_update", self, "players_changed")

func reset_session():
	set_frozen(false)
	operators.clear()
	reply_peer = 0
	short_ids.clear()
	next_id = 1
	bans.clear()
	removed.clear()
	global_mutes.clear()
	pings.clear()
	probes.clear()
	spawned.clear()
	last_reply = ""

func players_changed(_players):
	if not bridge.is_world_authority():
		return
	if mp.players.has(bridge.get_id()) and not short_ids.has(bridge.get_id()):
		short_ids[bridge.get_id()] = next_id
		next_id += 1
	for peer in mp.players:
		if not short_ids.has(peer):
			short_ids[peer] = next_id
			next_id += 1
	for peer in operators.keys():
		if not mp.players.has(peer): operators.erase(peer)
	bridge.n_rpc(self, "sync_roles", [operators])
	bridge.n_rpc(self, "sync_mutes", [global_mutes])

func identity(peer):
	if bridge.is_steam():
		return "steam:" + str(peer)
	var transport = get_tree().network_peer
	if transport != null and transport.has_method("get_peer_address"):
		return "lan:" + str(transport.get_peer_address(peer))
	return "peer:" + str(peer)

func is_banned(peer):
	return bans.has(identity(peer))

func resolve_player(token):
	if token.begins_with("#") and token.substr(1).is_valid_integer(): token = token.substr(1)
	var exact = []
	var partial = []
	for peer in mp.players:
		var nickname = str(mp.players[peer].get("nickname", ""))
		if token == str(short_ids.get(peer, -1)) or token == str(peer) or token.to_lower() == nickname.to_lower():
			exact.append(peer)
		elif nickname.to_lower().find(token.to_lower()) >= 0:
			partial.append(peer)
	if exact.size() == 1:
		return exact[0]
	if exact.empty() and partial.size() == 1:
		return partial[0]
	return 0

func tokenize(message):
	var tokens = []
	var word = ""
	var quote = false
	for character in message:
		if character == '"':
			quote = not quote
		elif character in [" ", "\t"] and not quote:
			if not word.empty():
				tokens.append(word)
				word = ""
		else:
			word += character
	if quote:
		return []
	if not word.empty():
		tokens.append(word)
	return tokens

func has_access(peer):
	return peer == bridge.get_host_id() or operators.get(peer, false)

func find_chat(in_game):
	for chat in get_tree().get_nodes_in_group("online_chatboxes"):
		if chat.in_game_chat == in_game: return chat
	return null

func submit(chat, message):
	if bridge.is_world_authority():
		consume(chat, message, bridge.get_id())
	else:
		bridge.request_host(self, "request_command", [message, chat.in_game_chat])

master func request_command(sender, message, in_game):
	var peer = bridge.request_sender(sender)
	if not bridge.is_world_authority() or not mp.players.has(peer) or typeof(message) != TYPE_STRING or message.length() > 2048 or typeof(in_game) != TYPE_BOOL: return
	call_deferred("execute_requested_command", peer, message, in_game)

func execute_requested_command(peer, message, in_game):
	if not bridge.is_world_authority() or not mp.players.has(peer): return
	var chat = find_chat(in_game)
	if chat == null: return
	reply_peer = peer
	consume(chat, message, peer)
	reply_peer = 0

puppet func sync_roles(sender, roles):
	if bridge.request_sender(sender) != bridge.get_host_id() or typeof(roles) != TYPE_DICTIONARY: return
	operators = roles.duplicate()

puppet func command_reply(sender, message, in_game):
	if bridge.request_sender(sender) != bridge.get_host_id() or typeof(message) != TYPE_STRING or typeof(in_game) != TYPE_BOOL: return
	var chat = find_chat(in_game)
	if chat != null: chat.send_message(null, message, "HOST", "00ff00", false)

func reply(chat, message):
	last_reply = message
	if reply_peer != 0 and reply_peer != bridge.get_id():
		bridge.n_rpc_id(self, reply_peer, "command_reply", [message, chat.in_game_chat])
	else:
		chat.send_message(null, message, "HOST", "00ff00", false)

func consume(chat, message, sender):
	if not message.begins_with("/"):
		return false
	if not bridge.check_connection() or not bridge.is_world_authority() or not has_access(sender):
		reply(chat, "Only the host and operators can use commands.")
		return true
	players_changed(mp.players)
	var args = tokenize(message)
	if args.empty():
		reply(chat, "Close quoted names with another double quote.")
		return true
	var command = args.pop_front().to_lower().trim_prefix("/")
	if command in ["op", "deop"]:
		if sender != bridge.get_host_id():
			reply(chat, "Only the host can grant or remove operator access.")
			return true
		var peer = resolve_player(args[0]) if args.size() == 1 else 0
		if peer == 0 or peer == bridge.get_host_id():
			reply(chat, "Usage: /%s <non-host player>" % command)
			return true
		if command == "op": operators[peer] = true
		else: operators.erase(peer)
		bridge.n_rpc(self, "sync_roles", [operators])
		reply(chat, mp.players[peer].nickname + (" is now an operator." if command == "op" else " is no longer an operator."))
		bridge.n_rpc_id(self, peer, "command_reply", [("You now have operator access." if command == "op" else "Your operator access was removed."), chat.in_game_chat])
		return true
	if command == "help":
		reply(chat, HELP + "\nUse /players for IDs. Put names containing spaces in double quotes." + ("\n/devhelp lists debug commands." if DEBUG else ""))
		return true
	if command == "devhelp":
		reply(chat, DEVHELP if DEBUG else "Debug commands are unavailable in this build.")
		return true
	if command == "players":
		for peer in mp.players:
			var team = mp.CounterOp.team_of(peer).replace("counter_operative", "Counter-Opps").replace("operative", "Operatives") if mp.CounterOp.is_active() else ("Deathmatch" if mp.Deathmatch.is_active() else "Cruelty")
			var state = "waiting" if mp.Flow.waiting_peers.has(peer) else ("dead" if mp.died_players.has(peer) else "alive")
			var ping = "0 ms" if peer == bridge.get_id() else (str(pings[peer]) + " ms" if pings.has(peer) else "measuring")
			reply(chat, "#%s %s | %s | %s | %s%s" % [short_ids[peer], mp.players[peer].nickname, team, ping, state, " | voice muted" if global_mutes.get(peer, false) else ""])
		return true
	if command == "announce":
		var text = message.substr(message.find(" ") + 1).strip_edges() if message.find(" ") >= 0 else ""
		if text.empty():
			reply(chat, "Usage: /announce <message>")
			return true
		sync_announcement(bridge.get_host_id(), text)
		bridge.n_rpc(self, "sync_announcement", [text])
		return true
	if command == "end":
		mp.goto_menu_host(false, true)
		return true
	if command == "restart":
		if not in_mission():
			reply(chat, "There is no mission to restart.")
		else:
			mp.game_init(mp.hostSettings.map)
		return true
	if command in ["freezeai", "unfreezeai", "killall", "map", "spawn", "god", "noclip", "heal", "revive", "kill", "money", "give", "implant"] and not DEBUG:
		reply(chat, "Debug commands are unavailable in this build."); return true
	if command == "map":
		if args.empty():
			reply(chat, "Usage: /map <level name or 0-based ID>")
			return true
		var level = resolve_level(PoolStringArray(args).join(" "))
		if level < 0:
			reply(chat, "Unknown or ambiguous level. Use its name or ID (0-%s)." % (Global.LEVELS.size()-1))
		else:
			Global.CURRENT_LEVEL = level
			mp.game_init(Global.LEVELS[level])
		return true
	if command in ["freezeai", "unfreezeai", "killall", "spawn"]:
		if not in_mission():
			reply(chat, "This command needs a loaded mission.")
			return true
		if command == "freezeai":
			set_frozen(true)
		elif command == "unfreezeai":
			set_frozen(false)
		elif command == "killall":
			for npc in get_tree().get_nodes_in_group("admin_npcs"):
				if npc.has_method("admin_kill"):
					npc.admin_kill()
				elif npc.is_in_group("merit_bribable_npcs"):
					if not npc.dead:
						npc.health = 0
						npc.die(100, Vector3.ZERO, npc.body.global_transform.origin)
				else:
					bridge.n_rpc(self, "remove_npc", [mp.SteamNetwork.scene_epoch,npc.get_path()])
					remove_npc(bridge.get_id(),mp.SteamNetwork.scene_epoch,npc.get_path())
		else:
			if args.empty():
				reply(chat, "Usage: /spawn <NPC scene name>")
				return true
			var scene = resolve_npc(PoolStringArray(args).join(" "))
			if scene.empty():
				reply(chat, "Unknown NPC. Use an enemy scene name, such as E_Grunt or E_Killerbot.")
				return true
			spawn_sequence += 1
			var pose = Global.player.global_transform
			pose.origin += pose.basis.z.normalized() * 3.0
			var name = "AdminNPC_" + str(spawn_sequence)
			spawn_npc(bridge.get_id(), mp.SteamNetwork.scene_epoch, scene, name, pose)
			bridge.n_rpc(self, "spawn_npc", [mp.SteamNetwork.scene_epoch, scene, name, pose])
		reply(chat, command + " applied."); return true
	if command in ["money", "give", "implant"]:
		if args.empty():
			reply(chat, "Usage: /%s <value> [player]; quote names containing spaces." % command)
			return true
		var peer = resolve_player(args[1]) if args.size() == 2 else sender
		if args.size() > 2 or peer == 0:
			reply(chat, "Unknown or ambiguous player/value. Quote names containing spaces.")
			return true
		var value = args[0]
		if command == "money":
			if not value.is_valid_float() or abs(float(value)) > 1e12:
				reply(chat, "Money must be a number between -1000000000000 and 1000000000000.")
				return true
			value = float(value)
		elif command == "give":
			value = resolve_weapon(value)
			if value < 0:
				reply(chat, "Unknown weapon. Use its name or 0-based weapon ID.")
				return true
		else:
			value = resolve_implant(value)
			if value.empty():
				reply(chat, "Unknown implant. Quote its name, including + where applicable.")
				return true
		if command != "money" and not usable_player(peer):
			reply(chat, "That player must be alive in the mission.")
			return true
		dispatch(peer, command, value)
		reply(chat, command + " applied to " + mp.players[peer].nickname + "."); return true
	if not command in ["kick", "ban", "mute", "unmute", "tp", "god", "noclip", "heal", "revive", "kill"]:
		reply(chat, "Unknown command. Use /help."); return true
	if args.size() != (2 if command == "tp" else 1):
		reply(chat, "Usage: /" + command + (" <player1> <player2>" if command == "tp" else " <player>"))
		return true
	var peer = resolve_player(args[0])
	if peer == 0:
		reply(chat, "Unknown or ambiguous player. Use /players for IDs.")
		return true
	if command in ["kick", "ban"]:
		if peer == bridge.get_id():
			reply(chat, "You cannot kick or ban the host.")
			return true
		if command == "ban":
			bans[identity(peer)] = true
		removed[peer] = true
		dispatch(peer, "kick", "Banned for this hosted session." if command == "ban" else "Kicked by the host.")
		call_deferred("close_peer", peer)
	elif command in ["mute", "unmute"]:
		global_mutes[peer] = command == "mute"
		bridge.n_rpc(self, "sync_mutes", [global_mutes])
	elif command == "tp":
		var destination = resolve_player(args[1])
		if not usable_player(peer) or not usable_player(destination):
			reply(chat, "Both players must be alive in the same mission.")
			return true
		dispatch(peer, "tp", bridge.get_peer_actor(destination).global_transform.origin + Vector3.RIGHT * 1.0)
	else:
		if not in_mission() or mp.Flow.waiting_peers.has(peer):
			reply(chat, "That player must be in the mission.")
			return true
		if command != "revive" and not usable_player(peer):
			reply(chat, "That player is dead. Use /revive first.")
			return true
		dispatch(peer, command, null)
	reply(chat, command + " applied to " + mp.players.get(peer, {}).get("nickname", args[0]) + ".")
	return true

func in_mission():
	return is_instance_valid(Global.player) and is_instance_valid(Global.menu) and Global.menu.in_game and Global.loader == null and mp.player_scene_loaded

func usable_player(peer):
	return in_mission() and peer != 0 and not mp.died_players.has(peer) and not mp.Flow.waiting_peers.has(peer) and is_instance_valid(bridge.get_peer_actor(peer))

func dispatch(peer, action, value):
	if action == "revive":
		mp.revive_authorizations[peer] = "admin"
	if peer == bridge.get_id():
		apply_action(bridge.get_host_id(), action, value, mp.SteamNetwork.scene_epoch)
	else:
		bridge.n_rpc_id(self, peer, "apply_action", [action, value, mp.SteamNetwork.scene_epoch])

puppet func apply_action(sender, action, value, epoch = -1):
	if bridge.request_sender(sender) != bridge.get_host_id():
		return
	if action == "kick":
		mp.call_deferred("host_session_ended")
		return
	if action == "money" and DEBUG:
		if typeof(value) in [TYPE_INT, TYPE_REAL] and not is_nan(float(value)) and not is_inf(float(value)) and abs(value) <= 1e12:
			Global.money = value
		return
	if epoch != mp.SteamNetwork.scene_epoch or not in_mission():
		return
	var player = Global.player
	if action == "tp" and typeof(value) == TYPE_VECTOR3:
		player.global_transform.origin = value
		player.player_velocity = Vector3.ZERO
		return
	if not DEBUG:
		return
	match action:
		"god":
			player.set_meta("admin_god", not player.get_meta("admin_god") if player.has_meta("admin_god") else true)
		"noclip":
			player.set_meta("admin_noclip", not player.get_meta("admin_noclip") if player.has_meta("admin_noclip") else true)
			player.player_velocity = Vector3.ZERO
		"heal":
			player.health = 200.0 if player.orb else 100.0
			player.UI.set_health(player.health)
		"kill":
			player.remove_meta("admin_god")
			player.instadie()
		"revive":
			if player.dead or player.died:
				mp.Flow.clear_result()
				var enabled = mp.hostSettings.canRespawn
				mp.hostSettings.canRespawn = true
				Global.get_node("DeathScreen").respawn(true)
				mp.hostSettings.canRespawn = enabled
		"give":
			if typeof(value) != TYPE_INT or value < 0 or value >= player.weapon.MAX_AMMO.size():
				return
			var weapon = player.weapon
			if weapon.current_weapon == null:
				weapon.weapon1 = value
			weapon.ammo[value] = weapon.MAX_AMMO[value]
			weapon.magazine_ammo[value] = weapon.MAX_MAG_AMMO[value]
			weapon.set_weapon(value)
		"implant":
			for implant in Global.implants.IMPLANTS:
				if implant.i_name != value:
					continue
				var slot = "head_implant" if implant.head else ("torso_implant" if implant.torso else ("arm_implant" if implant.arms else "leg_implant"))
				Global.implants.set(slot, implant)
				player.update_implants()
				player.weapon.update_implants()

func close_peer(peer):
	yield(get_tree().create_timer(0.6), "timeout")
	if not bridge.is_world_authority():
		return
	if bridge.is_steam():
		mp.SteamNetwork._close_p2p_session(peer)
		mp.peer_update(peer)
	elif get_tree().network_peer != null and mp.players.has(peer):
		get_tree().network_peer.disconnect_peer(peer, true)
	removed.erase(peer)

puppet func sync_mutes(sender, state):
	if bridge.request_sender(sender) != bridge.get_host_id() or typeof(state) != TYPE_DICTIONARY:
		return
	global_mutes = state.duplicate()

func _process(delta):
	if not bridge.check_connection() or not bridge.is_world_authority():
		return
	probe_elapsed += delta
	if probe_elapsed >= 2.0:
		probe_elapsed = 0.0
		for peer in mp.players:
			if peer == bridge.get_id():
				continue
			probes[peer] = OS.get_ticks_msec()
			bridge.n_rpc_id(self, peer, "probe", [probes[peer]])
	if mission != Global.current_scene:
		set_frozen(false)
		mission = Global.current_scene
		spawned.clear()
	if frozen:
		freeze_new_nodes()

puppet func probe(sender, stamp):
	if bridge.request_sender(sender) == bridge.get_host_id() and typeof(stamp) == TYPE_INT:
		bridge.request_host(self, "probe_reply", [stamp])

master func probe_reply(sender, stamp):
	var peer = bridge.request_sender(sender)
	if bridge.is_world_authority() and mp.players.has(peer) and probes.get(peer, -1) == stamp:
		pings[peer] = max(0, OS.get_ticks_msec() - stamp)
		probes.erase(peer)

func resolve_level(token):
	if token.is_valid_integer():
		var index = int(token)
		return index if index >= 0 and index < Global.LEVELS.size() else -1
	var found = []
	for index in range(Global.LEVELS.size()):
		var title = mp.get_node("DiscordPresence")._level_name(index).to_lower()
		if title == token.to_lower() or Global.LEVELS[index].get_file().get_basename().to_lower() == token.to_lower():
			return index
		if title.find(token.to_lower()) >= 0:
			found.append(index)
	return found[0] if found.size() == 1 else -1

func resolve_weapon(token):
	var menu = Global.menu.menu[Global.menu.WEAPON_SELECT]
	if token.is_valid_integer():
		return int(token) if int(token) >= 0 and int(token) < menu.get_child_count()-1 else -1
	var found = []
	for index in range(1, menu.get_child_count()):
		var name = str(menu.get_child(index).name).to_lower()
		if name == token.to_lower():
			return index-1
		if name.find(token.to_lower()) >= 0:
			found.append(index-1)
	return found[0] if found.size() == 1 else -1

func resolve_implant(token):
	var found = []
	for implant in Global.implants.IMPLANTS:
		if implant.i_name.to_lower() == token.to_lower():
			return implant.i_name
		if implant.i_name.to_lower().find(token.to_lower()) >= 0:
			found.append(implant.i_name)
	return found[0] if found.size() == 1 else ""

func resolve_npc(token):
	var directory = Directory.new()
	if directory.open("res://Entities/Enemies") != OK:
		return ""
	directory.list_dir_begin(true, true)
	var name = directory.get_next()
	var found = []
	while not name.empty():
		if name.ends_with(".tscn") and (name.begins_with("E_") or name.begins_with("Obj_") or name == "Grid_Crab.tscn"):
			var base = name.get_basename().to_lower()
			if base == token.to_lower() or base.trim_prefix("e_") == token.to_lower():
				directory.list_dir_end()
				return "res://Entities/Enemies/" + name
			if base.find(token.to_lower()) >= 0:
				found.append("res://Entities/Enemies/" + name)
		name = directory.get_next()
	directory.list_dir_end()
	return found[0] if found.size() == 1 else ""

puppet func spawn_npc(sender, epoch, path, name, pose):
	if not DEBUG or bridge.request_sender(sender) != bridge.get_host_id() or epoch != mp.SteamNetwork.scene_epoch or typeof(path) != TYPE_STRING or typeof(name) != TYPE_STRING or typeof(pose) != TYPE_TRANSFORM:
		return
	if not path.begins_with("res://Entities/Enemies/") or path.find("..") >= 0 or not path.ends_with(".tscn") or not name.begins_with("AdminNPC_"):
		return
	if not is_instance_valid(Global.current_scene) or Global.current_scene.has_node(name):
		return
	var packed = load(path)
	if not packed is PackedScene:
		return
	var npc = packed.instance()
	npc.name = name
	npc.set_network_master(bridge.get_host_id())
	Global.current_scene.add_child(npc)
	npc.global_transform = pose
	spawned[name] = path
	if frozen:
		freeze_new_nodes()

func set_frozen(enabled):
	frozen = enabled and DEBUG
	if frozen:
		freeze_new_nodes()
		return
	for entry in frozen_nodes.values():
		var node = entry[0].get_ref()
		if not is_instance_valid(node):
			continue
		node.set_process(entry[1])
		node.set_physics_process(entry[2])
		if node is Timer:
			node.paused = entry[3]
	frozen_nodes.clear()

func freeze_new_nodes():
	for npc in get_tree().get_nodes_in_group("admin_npcs"):
		freeze_node(npc)

func freeze_node(node):
	if not frozen_nodes.has(node.get_instance_id()):
		frozen_nodes[node.get_instance_id()] = [weakref(node), node.is_processing(), node.is_physics_processing(), node.paused if node is Timer else false]
		node.set_process(false)
		node.set_physics_process(false)
		if node is Timer:
			node.paused = true
	for child in node.get_children():
		freeze_node(child)

puppet func remove_npc(sender, epoch, path):
	if not DEBUG or bridge.request_sender(sender) != bridge.get_host_id() or epoch != mp.SteamNetwork.scene_epoch or typeof(path) != TYPE_NODE_PATH: return
	var npc = get_node_or_null(path)
	if is_instance_valid(npc) and npc.is_in_group("admin_npcs"): npc.queue_free()

func send_spawn_state(peer):
	if not DEBUG or not bridge.is_world_authority() or peer == bridge.get_id() or not is_instance_valid(Global.current_scene): return
	for name in spawned:
		var npc = Global.current_scene.get_node_or_null(name)
		if is_instance_valid(npc):
			var pose = npc.global_transform
			if "body" in npc and is_instance_valid(npc.body): pose.origin = npc.body.global_transform.origin
			bridge.n_rpc_id(self,peer,"spawn_npc",[mp.SteamNetwork.scene_epoch,spawned[name],name,pose])

puppet func sync_announcement(sender, message):
	if bridge.request_sender(sender) != bridge.get_host_id() or typeof(message) != TYPE_STRING or message.length()>2048: return
	for chat in get_tree().get_nodes_in_group("online_chatboxes"):
		chat.send_message(null,message,"HOST ANNOUNCEMENT","00ff00")
