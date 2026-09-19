extends "res://MOD_CONTENT/CruS Online/FloatingPanel.gd"

onready var Multiplayer = Global.get_node("Multiplayer")
onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

onready var playersList = $VBoxContainer/PanelContainer/RichTextLabel

var sizeRatio = 20

func _ready():
	playersList.clear()
	playersList.hide()
	var scroll = ScrollContainer.new()
	scroll.add_stylebox_override("bg", StyleBoxEmpty.new())
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	$VBoxContainer/PanelContainer.add_child(scroll)
	scroll.add_child(preload("res://MOD_CONTENT/CruS Online/VoiceRoster.gd").new())
	hide()

func set_size_ratio():
	sizeRatio = 20
	
	$VBoxContainer/PanelContainer/RichTextLabel.get_font("normal_font").size = sizeRatio
	$VBoxContainer/Label.get_font("font").size = sizeRatio

func open_stats(type):
	playersList.clear()
	show()
	set_size_ratio()
	fit_in_parent()
	$"../OpenStats".button_disable()
	$"../CloseStats".button_enable()

func close_stats(type):
	hide()
	$"../OpenStats".button_enable()
	$"../CloseStats".button_disable()
