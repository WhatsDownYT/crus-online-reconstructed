extends Spatial

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

export  var next_scene = ""
export (Array, String, MULTILINE) var LINES:Array = [""]
export (Array, float) var DURATION:Array = [1]
export (String) var music
export  var instant = false
export  var line_skip = true
export  var introskip = false
var CAMERAS
onready var TIMER = $Timer
onready var SUBTITLE = $MarginContainer / CenterContainer / Subtitle
var current_scene = 0
var t = 0

onready var Multiplayer = Global.get_node('Multiplayer')

func _ready():
	NetworkBridge.register_rpcs(self, [["skip_line", NetworkBridge.PERMISSION.SERVER]])
	$MarginContainer / CenterContainer / Subtitle.get_font("font").size = 32 * (Global.resolution[0] / 1280)
	
	Global.menu.hide()
	if music != "":
		if music == "NO":
			Global.music.stop()
		else :
			Global.music.stream = load(music)
			Global.music.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Global.cutscene = true
	Global.border.hide()
	CAMERAS = $Cameras.get_children()
	if introskip and NetworkBridge.is_world_authority():
		Multiplayer.goto_menu_host()

func _process(delta):
	if instant:
		t += 1
		SUBTITLE.modulate = Color((cos(t * 0.01) + 1) * 0.5, 0, 0)
	if TIMER.is_stopped() and current_scene != LINES.size():
		current_scene = clamp(current_scene, 0, LINES.size() - 1)
		TIMER.wait_time = DURATION[current_scene]
		if CAMERAS.size() > 0:
			CAMERAS[current_scene].current = true
		SUBTITLE.text = LINES[current_scene]
		if not instant:
			SUBTITLE.speech()
		else :
			SUBTITLE.visible_characters = - 1
		current_scene += 1
		TIMER.start()
	if TIMER.is_stopped() and current_scene == LINES.size():
		if NetworkBridge.n_is_network_master(self):
			if next_scene == "res://Menu/Main_Menu.tscn":
				Multiplayer.goto_menu_host()
			else:
				Multiplayer.goto_scene_host(next_scene)

func _input(event):
	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_accept"):
			if NetworkBridge.n_is_network_master(self):
				if next_scene == "res://Menu/Main_Menu.tscn":
					Multiplayer.goto_menu_host()
				else:
					Multiplayer.goto_scene_host(next_scene)
		if Input.is_action_just_pressed("movement_jump") and line_skip and NetworkBridge.is_world_authority():
			NetworkBridge.n_rpc(self, "skip_line", [current_scene])
			skip_line(null, current_scene)

puppet func skip_line(id, line):
	current_scene = clamp(line, 0, LINES.size())
	TIMER.stop()
