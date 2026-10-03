extends CanvasLayer

const DATA_PATH = "res://MOD_CONTENT/CruS Online/achievements/achievements.json"
const SCREEN_SCRIPT = preload("res://MOD_CONTENT/CruS Online/achievements/AchievementScreen.gd")
const CASH_DING_PATH = "res://MOD_CONTENT/CruS Online/achievements/cash_ding.ogg"
const STRETCH_STEPS = 12
const STRETCH_DURATION = 0.3
const LEFT_SIDE_ANGLE = 0.0
const RIGHT_SIDE_ANGLE = 168.0

var phone
var turntable
var screen
var screen_viewport
var model_viewport
var output
var cash_ding
var achievements = {}
var animation_generation = 0
var pending_achievements = []
var showing_achievement = false
var rotation_direction = -1
var rotation_angle = 90.0

func _ready():
	name = "AchievementPreview"
	layer = 100
	pause_mode = Node.PAUSE_MODE_PROCESS
	var file = File.new()
	if file.open(DATA_PATH, File.READ) != OK: return
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY: return
	var entries = parsed.result.get("achievements", [])
	if typeof(entries) != TYPE_ARRAY or entries.empty(): return
	for achievement in entries:
		if typeof(achievement) == TYPE_DICTIONARY and achievement.has("id"):
			achievements[str(achievement.id)] = achievement
	if achievements.empty(): return
	_build(entries[0])
	cash_ding = AudioStreamPlayer.new()
	var sound_file = File.new()
	if sound_file.open(CASH_DING_PATH, File.READ) == OK:
		var sound = AudioStreamOGGVorbis.new()
		sound.data = sound_file.get_buffer(sound_file.get_len())
		sound_file.close()
		cash_ding.stream = sound
	cash_ding.bus = "SFX"
	add_child(cash_ding)

func show_achievement(id):
	if not achievements.has(id) or not is_instance_valid(output): return
	pending_achievements.append(id)
	if showing_achievement: return
	_show_next_achievement()

func reset_notifications():
	animation_generation += 1
	pending_achievements.clear()
	showing_achievement = false
	if is_instance_valid(output):
		output.hide()
		output.rect_scale.x = 0
	if is_instance_valid(cash_ding):
		cash_ding.stop()

func _show_next_achievement():
	if pending_achievements.empty():
		showing_achievement = false
		return
	showing_achievement = true
	screen.set_achievement(achievements[pending_achievements.pop_front()])
	animation_generation += 1
	_animate_achievement(animation_generation)

func _animate_achievement(generation):
	output.show()
	if cash_ding.stream != null:
		cash_ding.play()
	var started = OS.get_ticks_msec()
	var progress = 0.0
	while true:
		if generation != animation_generation: return
		progress = min(1.0, float(OS.get_ticks_msec() - started) / (STRETCH_DURATION * 1000.0))
		output.rect_scale.x = ceil(progress * STRETCH_STEPS) / STRETCH_STEPS
		if progress >= 1.0: break
		yield(get_tree(), "idle_frame")
	if generation != animation_generation: return
	yield(get_tree().create_timer(5.0), "timeout")
	started = OS.get_ticks_msec()
	while true:
		if generation != animation_generation: return
		progress = min(1.0, float(OS.get_ticks_msec() - started) / (STRETCH_DURATION * 1000.0))
		output.rect_scale.x = ceil((1.0 - progress) * STRETCH_STEPS) / STRETCH_STEPS
		if progress >= 1.0: break
		yield(get_tree(), "idle_frame")
	if generation == animation_generation:
		output.hide()
		_show_next_achievement()

func _build(achievement):
	screen_viewport = Viewport.new()
	screen_viewport.name = "ScreenViewport"
	screen_viewport.size = Vector2(256, 544)
	screen_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	screen_viewport.render_target_v_flip = true
	add_child(screen_viewport)
	screen = SCREEN_SCRIPT.new()
	screen.rect_size = screen_viewport.size
	screen_viewport.add_child(screen)
	screen.rect_scale = Vector2(1, -1)
	screen.rect_position.y = screen_viewport.size.y
	screen.set_achievement(achievement)

	model_viewport = Viewport.new()
	model_viewport.name = "PhoneViewport"
	model_viewport.size = Vector2(256, 544)
	model_viewport.usage = Viewport.USAGE_3D
	model_viewport.transparent_bg = true
	model_viewport.own_world = true
	model_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	add_child(model_viewport)
	var root = Spatial.new()
	model_viewport.add_child(root)
	turntable = Spatial.new()
	turntable.rotation_degrees.y = rotation_angle
	root.add_child(turntable)
	phone = load("res://phone.tscn").instance()
	phone.transform = Transform.IDENTITY
	phone.rotation_degrees = Vector3(-90, 0, 0)
	turntable.add_child(phone)
	var mesh = phone.mesh.duplicate(true)
	phone.mesh = mesh
	var body_material = SpatialMaterial.new()
	body_material.flags_unshaded = true
	body_material.albedo_color = Color(0.07, 0.07, 0.07)
	body_material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.albedo_texture = screen_viewport.get_texture()
	material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	phone.set_surface_material(0, body_material)
	material.uv1_scale = Vector3(-2.258, -1, 1)
	material.uv1_offset = Vector3(1.641, 1, 0)
	phone.set_surface_material(1, material)
	var camera = Camera.new()
	camera.projection = Camera.PROJECTION_ORTHOGONAL
	camera.size = 0.31
	camera.translation = Vector3(0, 0, 0.7)
	root.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	var light = DirectionalLight.new()
	light.rotation_degrees = Vector3(-25, -15, 0)
	root.add_child(light)
	output = TextureRect.new()
	output.name = "Phone"
	output.anchor_left = 1.0
	output.anchor_top = 1.0
	output.anchor_right = 1.0
	output.anchor_bottom = 1.0
	output.margin_left = -272
	output.margin_top = -576
	output.margin_right = -10
	output.margin_bottom = -10
	output.expand = true
	output.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output.texture = model_viewport.get_texture()
	add_child(output)
	output.rect_pivot_offset = Vector2(output.rect_size.x, 0)
	output.rect_scale.x = 0
	output.hide()

func _process(delta):
	if is_instance_valid(turntable):
		var angle = rotation_angle + delta * 90.0 * rotation_direction
		if angle <= LEFT_SIDE_ANGLE:
			angle = LEFT_SIDE_ANGLE + (LEFT_SIDE_ANGLE - angle)
			rotation_direction = 1
		elif angle >= RIGHT_SIDE_ANGLE:
			angle = RIGHT_SIDE_ANGLE - (angle - RIGHT_SIDE_ANGLE)
			rotation_direction = -1
		rotation_angle = angle
		turntable.rotation_degrees.y = rotation_angle
