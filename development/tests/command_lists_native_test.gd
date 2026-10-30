extends Node

class ChatFixture extends Control:
	var in_game_chat = false
	var messages = []
	func send_message(_sender, text, _author, _color, _prominent):
		messages.append(text)

var failures = 0
var mp

func check(ok, label):
	print("COMMAND_LIST_CHECK ", label, "=", ok)
	if not ok: failures += 1

func _ready():
	call_deferred("run")

func barrier(stage):
	var prefix = "E:/Cruelty/Online/development/artifacts/command-list-" + str(PORT) + stage
	var file = File.new()
	file.open(prefix + str(HOST), File.WRITE)
	file.store_string("ready")
	file.close()
	yield(get_tree(), "idle_frame")
	while not file.file_exists(prefix + str(not HOST)):
		yield(get_tree().create_timer(0.05), "timeout")

func run():
	yield(get_tree().create_timer(12), "timeout")
	Global.select_save_slot(1)
	mp = Global.get_node("Multiplayer")
	mp.Voice.test_capture = true
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1", PORT)
	while mp.players.size() < 2:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(1.0), "timeout")
	var chat = ChatFixture.new()
	add_child(chat)
	if HOST:
		for peer in mp.players:
			if peer != 1: mp.Commands.operators[peer] = true
		mp.NetworkBridge.n_rpc(mp.Commands, "sync_roles", [mp.Commands.operators])
		for command in ["map", "give", "spawn"]:
			chat.messages.clear()
			check(mp.Commands.consume(chat, "/" + command + " list", 1), command + " list handled")
			var text = PoolStringArray(chat.messages).join("\n")
			var complete = true
			if command == "map":
				for index in range(Global.LEVELS.size()):
					complete = complete and text.find("%d: %s" % [index, mp.get_node("DiscordPresence")._level_name(index)]) >= 0
			elif command == "give":
				for entry in mp.weapon_ban_entries():
					complete = complete and text.find(entry.name) >= 0 and mp.Commands.resolve_weapon(str(entry.index)) == entry.index and mp.Commands.resolve_weapon(entry.key) == entry.index
			else:
				for path in mp.Commands.entity_catalog(): complete = complete and text.find(path) >= 0
			check(complete, command + " list contains every catalog entry and usable IDs")
			var bounded = true
			for message in chat.messages: bounded = bounded and message.to_utf8().size() <= 1800
			check(bounded, command + " list uses bounded messages")
		check(not Global.menu.in_game, "list commands do not start missions")
	yield(barrier("ready"), "completed")
	if not HOST:
		check(mp.Commands.has_access(mp.NetworkBridge.get_id()), "remote operator has access")
		mp.Commands.submit(chat, "/spawn list")
		yield(get_tree().create_timer(1.0), "timeout")
		var actual_chat = mp.Commands.find_chat(false)
		var complete = actual_chat != null
		if actual_chat != null:
			for path in mp.Commands.entity_catalog(): complete = complete and actual_chat.textBox.bbcode_text.find(path) >= 0
		check(complete, "remote operator receives entire entity list without a loaded mission")
	yield(barrier("done"), "completed")
	print("COMMAND_LIST_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
