extends Label

var speech_break = false
var mouse_hover = false
var speech_flag = false
const CHARACTER_DELAY = 1.0 / 30.0
var speech_generation = 0
var letter_players = []
var next_letter_player = 0
var alpha_sound = [
	preload("res://Sfx/Voice/A.wav"), 
	preload("res://Sfx/Voice/B.wav"), 
	preload("res://Sfx/Voice/C.wav"), 
	preload("res://Sfx/Voice/D.wav"), 
	preload("res://Sfx/Voice/E.wav"), 
	preload("res://Sfx/Voice/F.wav"), 
	preload("res://Sfx/Voice/G.wav"), 
	preload("res://Sfx/Voice/H.wav"), 
	preload("res://Sfx/Voice/I.wav"), 
	preload("res://Sfx/Voice/J.wav"), 
	preload("res://Sfx/Voice/K.wav"), 
	preload("res://Sfx/Voice/L.wav"), 
	preload("res://Sfx/Voice/M.wav"), 
	preload("res://Sfx/Voice/N.wav"), 
	preload("res://Sfx/Voice/O.wav"), 
	preload("res://Sfx/Voice/P.wav"), 
	preload("res://Sfx/Voice/Q.wav"), 
	preload("res://Sfx/Voice/R.wav"), 
	preload("res://Sfx/Voice/S.wav"), 
	preload("res://Sfx/Voice/T.wav"), 
	preload("res://Sfx/Voice/U.wav"), 
	preload("res://Sfx/Voice/V.wav"), 
	preload("res://Sfx/Voice/W.wav"), 
	preload("res://Sfx/Voice/X.wav"), 
	preload("res://Sfx/Voice/Y.wav"), 
	preload("res://Sfx/Voice/Z.wav")
]

signal character_speak

func _ready():
	pass

func list_files_in_directory(path:String, file_type:String)->Array:
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and file.get_extension() == file_type:
			files.append(path + "/" + file)
	return files

func skip():
	speech_generation += 1
	visible_characters = get_total_character_count()

func _input(event):
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed("mouse_1") and mouse_hover:
			skip()
			speech_break = true

func speech():
	speech_generation += 1
	var generation = speech_generation
	speech_break = true
	visible_characters = 0
	yield (get_tree().create_timer(CHARACTER_DELAY), "timeout")
	if generation != speech_generation:
		return
	speech_break = false
	var spoken_text = text
	for index in range(spoken_text.length()):
		if generation != speech_generation or speech_break:
			return
		visible_characters = index + 1
		var letter = spoken_text.substr(index, 1)
		var code = letter.to_upper().ord_at(0)
		if code >= 65 and code <= 90:
			_play_letter(code - 65)
		yield (get_tree().create_timer(CHARACTER_DELAY * (2.0 if letter == " " else 1.0)), "timeout")

func _play_letter(index):
	if letter_players.empty():
		for _i in range(12):
			var player = AudioStreamPlayer.new()
			player.bus = $AudioStreamPlayer.bus
			player.volume_db = $AudioStreamPlayer.volume_db
			player.pitch_scale = $AudioStreamPlayer.pitch_scale
			add_child(player)
			letter_players.append(player)
	var player = letter_players[next_letter_player]
	next_letter_player = (next_letter_player + 1) % letter_players.size()
	player.stream = alpha_sound[index]
	emit_signal("character_speak")
	player.play()

func _on_Description_mouse_entered():
	mouse_hover = true

	set("custom_colors/default_color", Color(0, 1, 0, 1))

func _on_Description_mouse_exited():
	set("custom_colors/default_color", Color(1, 0, 0, 1))
	mouse_hover = false
