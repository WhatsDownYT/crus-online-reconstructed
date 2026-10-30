extends Node
class FakeSteam extends Reference:
	var data = {}
	var types = 0
	var writes = 0
	var age = 0
	var requests = 0
	var estimate = 42
	func getLobbyOwner(_id): return 123
	func getLobbyMemberLimit(_id): return 16
	func setLobbyMemberLimit(_id, _cap): pass
	func getLobbyData(_id, key): return data.get(key, "")
	func setLobbyData(_id, key, value):
		data[key] = value
		writes += 1
	func setLobbyType(_id, _type): types += 1
	func setRichPresence(_key, _value): pass
	func getLocalPingLocation(): return {"age": age, "location": PoolByteArray([1, 2, 3])}
	func convertPingLocationToString(value): return "valid-location" if typeof(value) == TYPE_RAW_ARRAY else ""
	func parsePingLocationString(value): return {"success": value == "valid-location", "ping_location": PoolByteArray([1, 2, 3])}
	func estimatePingTimeFromLocalHost(value): return estimate if typeof(value) == TYPE_RAW_ARRAY else -1
	func requestLobbyData(_id):
		requests += 1
		return true
	func getNumLobbyMembers(_id): return 2
	func getFriendPersonaName(_id): return "Test"
class FakeInit extends Reference:
	var Steam = FakeSteam.new()
	var steam_username = "Test"
var failures = 0
func check(value, label):
	var trace = File.new()
	trace.open("E:/Cruelty/Online/development/artifacts/lobby-check-" + str(HOST) + ".txt", File.WRITE)
	trace.store_line(label + "=" + str(value))
	trace.close()
	print("LOBBY_CHECK ", label, "=", value)
	if not value: failures += 1
func _ready(): call_deferred("run")
func run():
	yield(get_tree().create_timer(12), "timeout")
	var mp = Global.get_node("Multiplayer")
	var lobby = mp.SteamLobby
	var saved_init = lobby.SteamInit
	var saved_id = lobby._steam_lobby_id
	var saved_me = lobby._my_steam_id
	var saved_type = lobby._published_lobby_type
	var fake = FakeInit.new()
	lobby.SteamInit = fake
	lobby._steam_lobby_id = 999
	lobby._my_steam_id = 123
	lobby._published_lobby_type = ""
	lobby.publish_lobby_settings()
	var writes = fake.Steam.writes
	for _i in range(20): lobby.publish_lobby_settings()
	check(fake.Steam.types == 1 and fake.Steam.writes == writes, "unchanged settings do not republish")
	fake.Steam.age = -1
	lobby.publish_ping_location()
	check(not fake.Steam.data.has("ping_location"), "wait for relay measurement")
	fake.Steam.age = 0
	lobby.publish_ping_location()
	check(fake.Steam.data.get("ping_location") == "valid-location", "publish serialized byte location")
	check(lobby.lobby_ping_ms(999) == 42, "decode location for estimated ping")
	fake.Steam.data.ping_location = "invalid"
	check(lobby.lobby_ping_ms(999) == -1, "invalid locations remain unavailable")
	fake.Steam.data.ping_location = "valid-location"
	var browser = Global.get_node("Menu/MultiplayerMenu/CenterContainer/TabContainer/Main/Steam")
	var saved_browser_init = browser.SteamInit
	browser.SteamInit = fake
	lobby._steam_lobby_id = 0
	fake.Steam.data.crus_online = "reconstructed"
	fake.Steam.data.version = lobby.network_version()
	fake.Steam.data.erase("lobby_type")
	browser._on_match_list([999])
	check(browser.lobbies == [999] and fake.Steam.requests > 0, "filtered public result survives missing local metadata")
	fake.Steam.data.lobby_type = "public"
	lobby._on_lobby_data_update(true, 999, 0)
	check(browser.lobbies == [999], "late metadata displays lobby without refresh")
	browser._on_match_list([])
	lobby._on_lobby_data_update(true, 999, 0)
	check(browser.lobbies == [999], "search omission preserves a verified live lobby")
	fake.Steam.data.erase("lobby_type")
	lobby._on_lobby_data_update(true, 999, 0)
	check(browser.lobbies == [999], "partial metadata cannot hide a confirmed lobby")
	var row = browser.LobbyList.get_node("Rows").get_child(0)
	check(row.get_node("Columns/Details/Ping").text == "42 ms est.", "browser displays estimated ping")
	lobby._on_lobby_data_update(false, 999, 0)
	check(browser.lobbies.empty(), "remove lobby when Steam reports it unavailable")
	browser.SteamInit = saved_browser_init
	lobby.SteamInit = saved_init
	lobby._steam_lobby_id = saved_id
	lobby._my_steam_id = saved_me
	lobby._published_lobby_type = saved_type
	print("LOBBY_BROWSER_RESULT failures=", failures)
	get_tree().quit()
