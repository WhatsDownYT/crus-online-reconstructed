extends Node
var done = false
var stage = 0
func _ready(): call_deferred("run")
func run():
	yield(get_tree().create_timer(6), "timeout")
	var init = Global.get_node("Multiplayer/SteamInit")
	print("LIVE_LOBBY_LOCAL online=", init.is_online, " version=", init.SteamLobby.network_version())
	init.Steam.connect("lobby_match_list", self, "received")
	init.Steam.addRequestLobbyListDistanceFilter(init.Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	init.Steam.requestLobbyList()
	var deadline = OS.get_ticks_msec() + 15000
	while not done and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.1), "timeout")
	print("LIVE_LOBBY_RESULT complete")
	get_tree().quit()
func received(lobbies, count):
	var steam = Global.get_node("Multiplayer/SteamInit").Steam
	print("LIVE_LOBBY_COUNT ", count, " ids=", lobbies)
	for lobby in lobbies:
		var info = {"id":str(lobby), "members":steam.getNumLobbyMembers(lobby), "capacity":steam.getLobbyMemberLimit(lobby)}
		for key in ["name", "mode", "lobby_type", "crus_online", "version", "ping_location"]:
			info[key] = steam.getLobbyData(lobby, key)
		print("LIVE_LOBBY_ENTRY ", info)
	if stage == 0:
		stage = 1
		call_deferred("filtered")
	else:
		var browser = Global.get_node("Menu/MultiplayerMenu/CenterContainer/TabContainer/Main/Steam")
		browser._on_match_list(lobbies)
		print("LIVE_BROWSER_ROWS ", browser.lobbies, " connecting=", browser.connecting)
		for row in browser.LobbyList.get_node("Rows").get_children(): print("LIVE_BROWSER_PING ", row.get_node("Columns/Details/Ping").text)
		done = true
func filtered():
	print("LIVE_FILTERED_REQUEST")
	Global.get_node("Multiplayer/SteamInit/SteamLobby").request_lobby_list()

