extends "res://MOD_CONTENT/CruS Online/interface/floating_panel.gd"

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

func set_size_ratio(_ratio = 1.0):
	sizeRatio = 20
	for item in [[textBox, "normal_font"], [lineEdit, "font"], [labelText, "font"]]:
		if item[0] == null:
			continue
		var font = item[0].get_font(item[1]).duplicate()
		font.size = sizeRatio
		item[0].add_font_override(item[1], font)

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
			if get_parent().quick_chat_active:
				get_parent().close_quick_chat()
			return
		if NetworkBridge.n_is_network_master(self):
			send_message_host(null, new_text, parent.playerInfo.nickname, parent.playerInfo.color)
		else:
			NetworkBridge.n_rpc(self, "send_message_host", [new_text, parent.playerInfo.nickname, parent.playerInfo.color])
		lineEdit.text = ""
		if get_parent().quick_chat_active:
			get_parent().close_quick_chat()

func open_chat(type):
	show()
	set_size_ratio(get_parent().native_panel_ratio)
	fit_in_parent()

func close_chat(type):
	hide()
