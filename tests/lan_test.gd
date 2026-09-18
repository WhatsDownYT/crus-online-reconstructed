extends Node

const Bridge = preload("res://MOD_CONTENT/CruS Online/NetworkBridge.gd")
var bridge
var role = ""
var port = 0
var connections = []
var reports = {}
var replicated_state = 0
var state_reported = false
var started = 0
var finishing = false
var pending_peer = 0

class MultiplayerStub:
	extends Node
	var packages_count = 0

func _ready():
	for argument in OS.get_cmdline_args():
		if argument.begins_with("--role="):
			role = argument.substr(7)
		if argument.begins_with("--port="):
			port = int(argument.substr(7))
	var multiplayer = MultiplayerStub.new()
	multiplayer.name = "Multiplayer"
	Global.add_child(multiplayer)
	var steam = Node.new()
	steam.name = "SteamInit"
	multiplayer.add_child(steam)
	for node_name in ["SteamNetwork", "SteamLobby"]:
		var child = Node.new()
		child.name = node_name
		steam.add_child(child)
	bridge = Bridge.new()
	bridge.name = "NetworkBridge"
	multiplayer.add_child(bridge)
	rset_config("replicated_state", MultiplayerAPI.RPC_MODE_PUPPET)
	get_tree().connect("network_peer_connected", self, "peer_connected")
	var peer = NetworkedMultiplayerENet.new()
	var error = peer.create_server(port, 3) if role == "host" else peer.create_client("127.0.0.1", port)
	if error != OK:
		fail("ENet setup " + str(error))
		return
	get_tree().network_peer = peer
	started = OS.get_ticks_msec()

func fail(message):
	printerr("LAN_FAIL ", role, ": ", message)
	get_tree().quit(1)

func peer_connected(id):
	if role == "host":
		connections.append(id)
		if connections.size() == 2:
			connections.sort()
			bridge.n_rpc(self, "start_client", [connections])

remote func start_client(sender, peers):
	if sender != 1:
		fail("wrong host identity")
		return
	bridge.n_rpc_id(self, 0, "report", ["client_host"])
	bridge.n_rpc_unreliable_id(self, 1, "report", ["unreliable"])
	if bridge.get_id() == peers[0]:
		pending_peer = peers[1]

remote func peer_message(sender, expected):
	if sender != expected or sender == 1:
		fail("client to client source identity")
		return
	bridge.n_rpc_id(self, 1, "report", ["client_client"])

remote func report(sender, kind):
	if bridge.request_sender(999) != sender:
		fail("claimed sender must not override actual ENet sender")
		return
	if role != "host" or not connections.has(sender):
		fail("invalid report sender")
		return
	reports[[sender, kind]] = true
	if reports.size() == 7 and not finishing:
		finishing = true
		bridge.n_rpc(self, "finish")
		yield(get_tree().create_timer(0.25), "timeout")
		print("LAN_TEST_RESULT host reports=7 peers=3 failures=0")
		get_tree().quit()

remote func finish(sender):
	if sender != 1:
		fail("finish sender")
		return
	print("LAN_TEST_RESULT client failures=0")
	get_tree().quit()

func _process(_delta):
	if started == 0:
		return

	if pending_peer != 0 and get_tree().get_network_connected_peers().has(pending_peer):
		bridge.n_rpc_id(self, pending_peer, "peer_message", [bridge.get_id()])
		pending_peer = 0
	if OS.get_ticks_msec() - started > 12000:
		fail("timeout reports=" + str(reports))
	if role == "host" and connections.size() == 2 and not finishing:
		bridge.n_rset_unreliable(self, "replicated_state", 77)
	elif role != "host" and replicated_state == 77 and not state_reported:
		state_reported = true
		bridge.n_rpc_id(self, 1, "report", ["rset"])
