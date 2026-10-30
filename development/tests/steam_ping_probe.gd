extends Node
func _ready():
	call_deferred("run")
func run():
	yield(get_tree().create_timer(6), "timeout")
	var steam = Global.get_node("Multiplayer/SteamInit").Steam
	for method in steam.get_method_list():
		if "Ping" in method.name or "RelayNetwork" in method.name:
			print("STEAM_PING_METHOD ", method)
	if steam.has_method("initRelayNetworkAccess"): steam.initRelayNetworkAccess()
	if steam.has_method("getLocalPingLocation"): print("STEAM_PING_VALUE ", steam.getLocalPingLocation())
	var location = steam.getLocalPingLocation().location
	var encoded = steam.convertPingLocationToString(location)
	print("STEAM_PING_ENCODED ", encoded)
	var decoded = steam.parsePingLocationString(encoded)
	print("STEAM_PING_DECODED ", decoded)
	print("STEAM_PING_ESTIMATE ", steam.estimatePingTimeFromLocalHost(location))
	print("PING_PROBE_RESULT complete")
	get_tree().quit()
