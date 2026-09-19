extends "res://MOD_CONTENT/CruS Online/FloatingPanel.gd"

onready var Multiplayer = Global.get_node("Multiplayer")
onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

onready var playersList = $VBoxContainer/PanelContainer/RichTextLabel

var sizeRatio = 20

func _ready():
	playersList.clear()
	hide()

func set_size_ratio():
	sizeRatio = 20
	
	$VBoxContainer/PanelContainer/RichTextLabel.get_font("normal_font").size = sizeRatio
	$VBoxContainer/Label.get_font("font").size = sizeRatio

func open_stats(type):
	playersList.clear()
	tick = 0
	show()
	set_size_ratio()
	fit_in_parent()
	$"../OpenStats".button_disable()
	$"../CloseStats".button_enable()

func close_stats(type):
	hide()
	$"../OpenStats".button_enable()
	$"../CloseStats".button_disable()

var tick = 0

func _physics_process(delta):
	if visible and $"..".visible:
		tick += 1
		if tick % 15 == 0:
			var playerNumber = 1
			playersList.bbcode_text = ""
			
			for player in Multiplayer.players:
				playersList.bbcode_text += str(playerNumber) + ": [color=#" + Multiplayer.players[player].color + "]" + Multiplayer.players[player].nickname + "[/color]"
				
				if player == NetworkBridge.get_host_id():
					playersList.bbcode_text += " (host)\n"
				else:
					playersList.bbcode_text += "\n"
				
				playerNumber += 1
				
			
			tick = 0
