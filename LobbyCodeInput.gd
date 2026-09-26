extends WindowDialog

signal code_entered(code)

onready var code_edit = $Panel/MarginContainer/RichTextLabel/CodeEdit
onready var prompt = $Panel/MarginContainer/RichTextLabel/Label
var entered_code = ""

func _ready():
	code_edit.max_length = 6
	code_edit.secret = false
	code_edit.placeholder_text = ""

func open():
	code_edit.text = ""
	prompt.text = "Enter Lobby Code"
	entered_code = ""
	rect_scale = Vector2(Global.resolution[0] / 1280, Global.resolution[1] / 720)
	popup_centered()
	code_edit.grab_focus()

func code_submitted(_text):
	var code = code_edit.text.strip_edges().to_upper()
	if code.length() != 6:
		prompt.text = "Enter a 6-character code"
		return
	for index in range(code.length()):
		if not code.substr(index, 1) in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789":
			prompt.text = "Code contains invalid characters"
			return
	entered_code = code
	hide()
	emit_signal("code_entered", code)
