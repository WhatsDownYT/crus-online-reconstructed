extends Node

const PROFILE_STORE = preload("res://MOD_CONTENT/CruS Online/ProfileStore.gd")
const DEFAULTS = {
	"player_kills": 0,
	"deathmatch_wins": 0,
	"deathmatch_losses": 0,
	"counter_op_wins": 0,
	"counter_op_losses": 0
}

var values = DEFAULTS.duplicate()
var store = PROFILE_STORE.new()
onready var Multiplayer = get_parent()
onready var NetworkBridge = get_parent().get_node("NetworkBridge")

func _ready():
	name = "OnlineStats"
	pause_mode = Node.PAUSE_MODE_PROCESS
	values = store.merge_defaults(DEFAULTS, store.load_data("stats.save"))
	NetworkBridge.register_rpcs(self, [["credit_kill", NetworkBridge.PERMISSION.SERVER]])

func record_result(mode, won):
	var prefix = "deathmatch" if mode == "deathmatch" else ("counter_op" if mode in ["operative", "counter_operative"] else "")
	if prefix.empty():
		return
	var key = prefix + ("_wins" if won else "_losses")
	values[key] += 1
	_save()

func award_player_kill(peer):
	if not NetworkBridge.is_world_authority():
		return
	if peer == NetworkBridge.get_id():
		credit_kill(null)
	else:
		NetworkBridge.n_rpc_id(self, peer, "credit_kill")

puppet func credit_kill(_id):
	values.player_kills += 1
	_save()

func clear():
	values = DEFAULTS.duplicate()
	_save()

func _save():
	store.save_data("stats.save", values)
