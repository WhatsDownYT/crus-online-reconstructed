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
var save_selector_active = false

onready var Multiplayer = Global.get_node('Multiplayer')

func _ready():
	NetworkBridge.register_rpcs(self, [["skip_line", NetworkBridge.PERMISSION.SERVER]])
	$MarginContainer / CenterContainer / Subtitle.get_font("font").size = 32 * (Global.resolution[0] / 1280)
	
	Global.menu.hide()
	var active_music = "res://Sfx/Music/level5_alt.ogg" if filename == "res://Cutscenes/Cutscene1.tscn" else music
	if active_music != "":
		if active_music == "NO":
			Global.music.stop()
		else :
			Global.music.stream = load(active_music)
			if filename == "res://Cutscenes/Cutscene1.tscn":
				Global.music.pitch_scale = 1.0
			Global.music.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Global.cutscene = true
	Global.border.hide()
	CAMERAS = $Cameras.get_children()
	if filename == "res://Cutscenes/Cutscene1.tscn":
		var final_camera = $Cameras.get_node_or_null("Camera15")
		if final_camera != null:
			final_camera.to_fov = 60
	if introskip and Global.skip_intro and NetworkBridge.is_world_authority():
		Global.goto_scene("res://Cutscenes/Cutscene1.tscn")
		set_process(false)
		set_process_input(false)
		return
	if filename == "res://Cutscenes/Cutscene1.tscn" and Global.skip_intro:
		_show_save_selector()

func _show_save_selector():
	if save_selector_active:
		return
	save_selector_active = true
	for static_node_name in ["AudioStreamPlayer3D", "AudioStreamPlayer3D2"]:
		var static_player = get_node_or_null(static_node_name)
		if static_player != null:
			static_player.stop()
	current_scene = LINES.size()
	TIMER.stop()
	SUBTITLE.hide()
	$MarginContainer.hide()
	var final_camera = $Cameras.get_node_or_null("Camera15")
	if final_camera != null:
		final_camera.current = true
		final_camera.fov = 60
		final_camera.set_process(false)
	var final_actor = get_node_or_null("intro_guy3")
	if final_actor != null:
		final_actor.show()
		var animation = final_actor.get_node_or_null("AnimationPlayer")
		if animation != null:
			animation.play("Sitting")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var selector = load("res://MOD_CONTENT/CruS Online/SaveSlotSelector.gd").new()
	add_child(selector)

func _process(delta):
	if save_selector_active:
		return
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
				if filename == "res://Cutscenes/Cutscene1.tscn":
					_show_save_selector()
				else:
					Multiplayer.goto_menu_host()
			else:
				Multiplayer.goto_scene_host(next_scene)

func _input(event):
	if save_selector_active:
		return
	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("ui_accept"):
			if NetworkBridge.n_is_network_master(self):
				if next_scene == "res://Menu/Main_Menu.tscn":
					if filename == "res://Cutscenes/Cutscene1.tscn":
						_show_save_selector()
					else:
						Multiplayer.goto_menu_host()
				else:
					Multiplayer.goto_scene_host(next_scene)
		if Input.is_action_just_pressed("movement_jump") and line_skip and NetworkBridge.is_world_authority():
			NetworkBridge.n_rpc(self, "skip_line", [current_scene])
			skip_line(null, current_scene)

puppet func skip_line(id, line):
	current_scene = clamp(line, 0, LINES.size())
	TIMER.stop()
