extends "res://MOD_CONTENT/CruS Online/interface/floating_panel.gd"

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
	scroll.add_child(preload("res://MOD_CONTENT/CruS Online/interface/voice_roster.gd").new())
	hide()

func set_size_ratio(_ratio = 1.0):
	sizeRatio = 20
	for item in [[$VBoxContainer/PanelContainer/RichTextLabel, "normal_font"], [$VBoxContainer/Label, "font"]]:
		var font = item[0].get_font(item[1]).duplicate()
		font.size = sizeRatio
		item[0].add_font_override(item[1], font)

func open_stats(type):
	playersList.clear()
	show()
	set_size_ratio(get_parent().native_panel_ratio)
	fit_in_parent()
	$"../OpenStats".button_disable()
	$"../CloseStats".button_enable()

func close_stats(type):
	hide()
	$"../OpenStats".button_enable()
	$"../CloseStats".button_disable()
