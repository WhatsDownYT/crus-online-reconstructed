extends Area

var controller
var identifier = 0
var value = 0
var owner_peer = 0

func player_use():
	if is_instance_valid(controller) and controller.bridge.get_id() != owner_peer:
		controller.bridge.request_host(controller, "request_collect", [identifier])
