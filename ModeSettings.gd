extends PanelContainer

var gamemodesList = [
	["Cruelty", "The default gameplay of Cruelty Squad. Eliminate all mission targets, then reach the exit.\n\nThis is the only mode that can save campaign progress.", "cruelty"],
	["Deathmatch", "Every player is a target. Be the last survivor. Touching exits will relocate you.", "deathmatch"],
	["Counter-Op", "Operatives must eliminate all mission targets and reach the exit. Counter-Operatives fight alongside hostile NPCs and win by eliminating every Operative.", "counter_op"]
]

var gamemodeSelected = 0
var modes_available = null
onready var Multiplayer = Global.get_node("Multiplayer")
onready var mode_list = $HBoxContainer/LevelController/GamemodeList
onready var play_button = $HBoxContainer/GamemodeDescription/Button

func _ready():
	for gamemode in gamemodesList:
		mode_list.add_item(gamemode[0])
	var current_mode = Multiplayer.hostSettings.get("gameMode", "cruelty")
	for index in range(gamemodesList.size()):
		if gamemodesList[index][2] == current_mode:
			gamemodeSelected = index
			break
	mode_list.select(gamemodeSelected)
	_gamemode_select(gamemodeSelected)
	_refresh_mode_availability()

func _process(_delta):
	if is_visible_in_tree():
		_refresh_mode_availability()

func _can_select_other_modes():
	return Multiplayer.players.size() >= 2 and Multiplayer.NetworkBridge.check_connection() and Multiplayer.NetworkBridge.is_world_authority()

func _refresh_mode_availability():
	var available = _can_select_other_modes()
	if modes_available == available:
		return
	modes_available = available
	for index in [1, 2]:
		mode_list.set_item_disabled(index, false)
		mode_list.set_item_tooltip(index, gamemodesList[index][0] if available else "Requires at least two players to play")
	play_button.disabled = gamemodeSelected != 0 and not available
	if not available and Multiplayer.hostSettings.get("gameMode", "cruelty") != "cruelty" and is_instance_valid(Global.menu) and not Global.menu.in_game and Multiplayer.NetworkBridge.is_world_authority():
		Multiplayer.CounterOp.host_apply_mode("cruelty")

func _gamemode_select(index):
	if index < 0 or index >= gamemodesList.size():
		return
	gamemodeSelected = index
	$HBoxContainer/GamemodeDescription/MapLabel.text = "Gamemode description:\n\n" + gamemodesList[index][1]
	play_button.disabled = index != 0 and not _can_select_other_modes()

func play_button_pressed():
	if not Multiplayer.NetworkBridge.check_connection() or not Multiplayer.NetworkBridge.is_world_authority():
		return
	var selected_mode = gamemodesList[gamemodeSelected][2]
	if selected_mode != "cruelty" and not _can_select_other_modes():
		play_button.disabled = true
		return
	if Multiplayer.hostSettings.get("gameMode", "cruelty") != selected_mode:
		Multiplayer.CounterOp.host_apply_mode(selected_mode)
