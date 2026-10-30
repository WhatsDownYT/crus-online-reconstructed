extends Node

class CaptureSteam extends Reference:
	var sent = []
	func sendP2PPacket(peer, data, mode, channel):
		sent.append([peer, data, mode, channel])
		return true

class SteamFixture extends Node:
	var Steam = CaptureSteam.new()

class LobbyFixture extends Node:
	func get_lobby_owner(): return 1
	func in_lobby(): return true

func _ready():
	call_deferred("run")

func run():
	yield(get_tree().create_timer(12), "timeout")
	var parent = SteamFixture.new()
	add_child(parent)
	var lobby = LobbyFixture.new()
	lobby.name = "SteamLobby"
	parent.add_child(lobby)
	var network = load("res://MOD_CONTENT/CruS Online/network/steam_network.gd").new()
	network.set_process(false)
	parent.add_child(network)
	network._my_steam_id = 1
	for peer_id in [1, 2]:
		var peer = network._create_peer(peer_id)
		peer.connected = true
		peer.host = peer_id == 1
		network._peers[peer_id] = peer
	network.register_rpc(self, "show_result", network.PERMISSION.SERVER)
	var path_id = network._add_node_path_cache(get_path())
	network._server_confirm_peer_node_path(2, path_id)
	parent.Steam.sent.clear()
	network._rpc(2, self, "show_result", [{}])
	var packet = parent.Steam.sent.back()
	var envelope = bytes2var(packet[1].subarray(1, packet[1].size() - 1))
	var ok = packet[3] == network.PRIORITY_CHANNEL and packet[2] == network.RELIABLE_SEND_MODE and envelope[0] == -1 and envelope[1][0] == network.PACKET_TYPE.RPC_WITH_NODE_PATH
	print("PRIORITY_RESULT failures=", 0 if ok else 1)
	parent.free()
	get_tree().quit(0 if ok else 1)
