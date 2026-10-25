extends Control

const COLUMN_COUNT = 112
var columns = []
var cursor = 0
var elapsed = 0.0
var voice = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect_size = Vector2(300, 58)
	position_on_screen()
	columns.resize(COLUMN_COUNT)
	for index in range(COLUMN_COUNT):
		columns[index] = 0.0

func _process(delta):
	position_on_screen()
	var active = is_instance_valid(voice) and voice.bridge.check_connection() and voice.Multiplayer.players.has(voice.bridge.get_id()) and voice.settings.enabled and voice.lobby_enabled() and is_instance_valid(Global.player) and is_instance_valid(Global.menu) and Global.menu.in_game
	visible = active
	if not active:
		return
	elapsed += delta
	if elapsed < 0.02:
		return
	elapsed = fmod(elapsed, 0.02)
	columns[cursor] = clamp(sqrt(max(0.0, voice.input_peak)) * 2.0, 0.0, 1.0)
	cursor = (cursor + 1) % COLUMN_COUNT
	update()

func position_on_screen():
	var viewport_size = get_viewport_rect().size
	var scale_factor = max(1.0, viewport_size.x / 1280.0)
	rect_scale = Vector2(scale_factor, scale_factor)
	rect_position = viewport_size - (rect_size + Vector2(24, 24)) * scale_factor

func _draw():
	var baseline = rect_size.y - 2.0
	for index in range(COLUMN_COUNT):
		var level = float(columns[index])
		var x = 3.0 + index * 2.6
		var height = 2.0 + level * (rect_size.y - 5.0)
		draw_line(Vector2(x, baseline), Vector2(x, baseline - height), Color(level, 1.0 - level, 0.0), 1.5)
