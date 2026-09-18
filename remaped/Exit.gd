extends Area

const ExitPolicy = preload("res://MOD_CONTENT/CruS Online/MissionExitPolicy.gd")
onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")
onready var Multiplayer = Global.get_node("Multiplayer")
var exitPlayers = []
var exitTimer
var exiting = false
var committed = false
var evaluation_elapsed = 0.0
var last_counts = []

func _ready():
	connect("body_entered", self, "_on_Body_entered")
	connect("body_exited", self, "_on_Body_exited")

	set_collision_mask_bit(2, true)
	NetworkBridge.register_rpcs(self, [
		["send_player_count", NetworkBridge.PERMISSION.SERVER],
		["send_exit_message", NetworkBridge.PERMISSION.SERVER],
		["send_exit_cancelled", NetworkBridge.PERMISSION.SERVER],
		["player_exited", NetworkBridge.PERMISSION.ALL],
		["player_entered", NetworkBridge.PERMISSION.ALL]
	])
	exitTimer = Timer.new()
	add_child(exitTimer)
	exitTimer.wait_time = 5
	exitTimer.one_shot = true
	exitTimer.connect("timeout", self, "exit_to_menu")

func _physics_process(delta):
	if not NetworkBridge.check_connection() or not NetworkBridge.is_world_authority():
		return
	evaluation_elapsed += delta
	if evaluation_elapsed >= 0.2:
		evaluation_elapsed = 0.0
		_evaluate_exit()

func _on_Body_exited(body):
	if NetworkBridge.is_world_authority():
		call_deferred("_evaluate_exit")
	elif body == Global.player:
		NetworkBridge.n_rpc_id(self, NetworkBridge.get_host_id(), "player_exited")

func _on_Body_entered(body):
	if NetworkBridge.is_world_authority():
		call_deferred("_evaluate_exit")
	elif body == Global.player:
		NetworkBridge.n_rpc_id(self, NetworkBridge.get_host_id(), "player_entered")

master func player_exited(id):
	_request_evaluation(id)

master func player_entered(id):
	_request_evaluation(id)

func _request_evaluation(id):
	if NetworkBridge.is_world_authority() and Multiplayer.players.has(NetworkBridge.request_sender(id)):

		_evaluate_exit()

func _collect_exit_peers():
	var present = []
	for body in get_overlapping_bodies():
		var peer = null
		if body == Global.player:
			peer = NetworkBridge.get_id()
		else:
			var ancestor = body
			while ancestor != null and ancestor != Multiplayer.Players:
				if ancestor.get_parent() == Multiplayer.Players:
					peer = int(ancestor.name)
					break
				ancestor = ancestor.get_parent()
		if peer != null and Multiplayer.players.has(peer) and not present.has(peer):
			present.append(peer)
	return present

func _evaluate_exit():
	if committed or not NetworkBridge.is_world_authority():
		return false
	exitPlayers = _collect_exit_peers()
	var required = ExitPolicy.required_players(Multiplayer.players, Multiplayer.died_players)
	var can_exit = ExitPolicy.can_exit(Global.objective_complete, required, exitPlayers)
	if can_exit and not exiting:
		exiting = true
		send_exit_message(null)
		NetworkBridge.n_rpc(self, "send_exit_message")
		exitTimer.start()
	elif not can_exit and exiting:
		exiting = false
		exitTimer.stop()
		send_exit_cancelled(null)
		NetworkBridge.n_rpc(self, "send_exit_cancelled")
	var present_living = 0
	for peer in required:
		if exitPlayers.has(peer):
			present_living += 1
	var counts = [present_living, required.size()]
	if Global.objective_complete and present_living > 0 and not can_exit and counts != last_counts:
		send_player_count(null, counts[0], counts[1])
		NetworkBridge.n_rpc(self, "send_player_count", counts)
	last_counts = counts
	return can_exit

puppet func send_player_count(id, exitCount, hostCount):
	Global.UI.notify(str(exitCount) + "/" + str(hostCount) + " need to exit", Color(1, 0, 0))

puppet func send_exit_message(id):
	Global.UI.notify("Exiting...", Color(1, 0, 0))
	Global.UI.notify("All living players are at the exit", Color(1, 0, 0))

puppet func send_exit_cancelled(id):
	Global.UI.notify("Exit cancelled.", Color(1, 0, 0))

func exit_to_menu():
	if _evaluate_exit():
		committed = true
		exitTimer.stop()
		Multiplayer.goto_menu_host(true)
