extends VBoxContainer

var rows = {}
var elapsed = 0.0
onready var Multiplayer = Global.get_node("Multiplayer")

func _ready():
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_constant_override("separation", 8)

func _process(delta):
	if not is_visible_in_tree():
		return
	elapsed += delta
	if elapsed < 0.1:
		return
	elapsed = 0.0
	var voice = Multiplayer.get_node_or_null("VoiceChat")
	if voice == null:
		return
	for peer in rows.keys():
		if not Multiplayer.players.has(peer):
			rows[peer].hide()
			rows[peer].queue_free()
			rows.erase(peer)
	var position = 0
	for peer in Multiplayer.players:
		if not rows.has(peer):
			var row = HBoxContainer.new()
			row.name = "Peer" + str(peer)
			row.add_constant_override("separation", 10)
			var icon = TextureButton.new()
			icon.name = "Voice"
			icon.rect_min_size = Vector2(32, 32)
			icon.expand = true
			icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			icon.focus_mode = Control.FOCUS_NONE
			icon.connect("pressed", voice, "toggle_mute", [peer])
			row.add_child(icon)
			var label = Label.new()
			label.name = "Name"
			label.size_flags_horizontal = SIZE_EXPAND_FILL
			label.clip_text = true
			var font = DynamicFont.new()
			font.font_data = load("res://Fonts/gamefont(1).ttf")
			font.size = 20
			label.add_font_override("font", font)
			row.add_child(label)
			add_child(row)
			rows[peer] = row
		var row = rows[peer]
		move_child(row, position)
		position += 1
		var info = Multiplayer.players[peer]
		row.get_node("Name").text = str(position) + ": " + str(info.get("nickname", "Player")) + (" (host)" if peer == Multiplayer.NetworkBridge.get_host_id() else "")
		row.get_node("Name").modulate = Color(str(info.get("color", "ffffff")))
		var icon = row.get_node("Voice")
		icon.visible = voice.is_enabled(peer)
		icon.texture_normal = voice.TALK_ICON if voice.is_talking(peer) else voice.QUIET_ICON
		icon.modulate = Color(0.35, 0.35, 0.35) if voice.is_muted(peer) else Color.white
		icon.hint_tooltip = "Your microphone" if peer == Multiplayer.NetworkBridge.get_id() else ("Unmute player" if voice.is_muted(peer) else "Mute player")
