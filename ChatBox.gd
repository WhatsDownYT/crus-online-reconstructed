extends "res://MOD_CONTENT/CruS Online/FloatingPanel.gd"

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

export var in_game_chat = true

onready var textBox = $VBoxContainer/PanelContainer/RichTextLabel
onready var lineEdit = $VBoxContainer/LineEdit
onready var labelText = get_node_or_null("VBoxContainer/Label")

onready var parent = Global.get_node("Multiplayer")

var sizeRatio = 20

func _ready():
	add_to_group("online_chatboxes")
	window_drag_enabled = in_game_chat
	NetworkBridge.register_rpcs(self,[
		["send_message_host", NetworkBridge.PERMISSION.ALL],
		["send_message", NetworkBridge.PERMISSION.SERVER]
	])
	
	if in_game_chat:
		hide()

func set_size_ratio():
	sizeRatio = 20
	
	textBox.get_font("normal_font").size = sizeRatio
	lineEdit.get_font("font").size = sizeRatio
	if labelText != null:
		labelText.get_font("font").size = sizeRatio

master func send_message_host(id, message, author, color = "ff0000"):
	var sender = NetworkBridge.request_sender(id)
	if not NetworkBridge.is_world_authority() or not parent.players.has(sender) or typeof(message) != TYPE_STRING or message.length() > 2048: return
	if parent.Commands.consume(self, message, sender): return
	if sender != NetworkBridge.get_host_id():
		author = parent.players[sender].nickname
		color = parent.players[sender].color
	NetworkBridge.n_rpc(self, "send_message", [message, author, color])
	send_message(null, message, author, color)

puppet func send_message(id, message, author, color = "ff0000", prominent = true):
	var rawText = '\n'
	
	if color != "ff0000":
		rawText = rawText + '[color=#' + color + ']'
	
	rawText = rawText + author + ': ' + message
	if color != "ff0000": rawText += '[/color]'
	
	textBox.bbcode_text = textBox.bbcode_text + rawText
	$AudioStreamPlayer.play()
	
	if prominent and in_game_chat and is_instance_valid(Global.UI) and is_instance_valid(Global.menu) and Global.menu.in_game:
		Global.UI.notify(message, Color(1, 0, 0))
		Global.UI.notify(author + ":", Color(color))

func _text_entered(new_text):
	if new_text != "":
		if new_text.begins_with("/"):
			parent.Commands.submit(self, new_text)
			lineEdit.text = ""
			return
		if NetworkBridge.n_is_network_master(self):
			send_message_host(null, new_text, parent.playerInfo.nickname, parent.playerInfo.color)
		else:
			NetworkBridge.n_rpc(self, "send_message_host", [new_text, parent.playerInfo.nickname, parent.playerInfo.color])
		lineEdit.text = ""

func open_chat(type):
	show()
	set_size_ratio()
	fit_in_parent()
	$"../OpenChat".button_disable()
	$"../CloseChat".button_enable()

func close_chat(type):
	hide()
	$"../OpenChat".button_enable()
	$"../CloseChat".button_disable()
