extends Control

signal finished(automatically)

const BUGS_TEXTURE = "res://MOD_CONTENT/CruS Online/assets/credits/bugs.png"
const REVITALIZED_LOGO = "res://MOD_CONTENT/CruS Online/branding/logo.png"
const ONLINE_LOGO = "res://MOD_CONTENT/CruS Online/assets/interface/crus_online_logo.png"
const SOFTPRODUCTS_LOGO = "res://MOD_CONTENT/CruS Online/assets/interface/softproducts.png"
const PURGATEAM_LOGO = "res://MOD_CONTENT/CruS Online/assets/interface/purgateam.png"
const CREDITS_MUSIC = "res://Sfx/Music/clubambient.ogg"
const ROLL_SPEED = 52.0
const FINAL_CARD_CENTER = 1930.0
const EXIT_EFFECT_SECONDS = 3.0
const CREDIT_URLS = {"CONSUMER SOFTPRODUCTS": "https://csoftproducts.life/", "PURGATEAM": "https://purgateam.com/", "WHATSDOWN": "https://www.youtube.com/@WhatsDown", "CHASMY": "https://www.youtube.com/@Chasmytheman", "TRIGGERED P": "https://triggeredp.com/"}

var credits_music = null
var paused_music = []
var border_was_visible = false
var roll_window = null
var roll_content = null
var credits_buffer = null
var exit_effect = null
var exit_effect_time = -1.0
var previous_mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready():
	name = "CreditsScreen"
	pause_mode = Node.PAUSE_MODE_PROCESS
	rect_size = Vector2(1280, 720)
	mouse_filter = MOUSE_FILTER_STOP
	hide()
	set_process(false)
	var backdrop = TextureRect.new()
	backdrop.texture = _load_runtime_texture(BUGS_TEXTURE)
	backdrop.rect_size = rect_size
	backdrop.expand = true
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	backdrop.material = _bug_wave_material()
	add_child(backdrop)
	roll_window = Control.new()
	roll_window.rect_position = Vector2(58, 0)
	roll_window.rect_size = Vector2(1164, 720)
	roll_window.rect_clip_content = true
	roll_window.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(roll_window)
	roll_content = Control.new()
	roll_content.rect_position = Vector2(0, 800)
	roll_content.rect_size = Vector2(1164, 2750)
	roll_content.mouse_filter = MOUSE_FILTER_IGNORE
	roll_window.add_child(roll_content)
	_add_title_mesh(roll_content, Vector2(367, 0), Vector2(430, 283))
	_add_text(roll_content, "CREATED BY CONSUMER SOFTPRODUCTS\nDEVELOPED BY VILLE KALLIO", Vector2(72, 225), Vector2(1020, 100), 26)
	_add_image(roll_content, REVITALIZED_LOGO, Vector2(367, 430), Vector2(430, 283))
	_add_text(roll_content, "CREATED BY PURGATEAM\nDEVELOPED BY WHATSDOWN\nART & DESIGN BY CHASMY\n\nSPECIAL THANKS\nPBF GUY: IDEA ASSISTANCE & PLAYTESTING\nCORVID12: PNEUMATIC MERIT PUMP INSPIRATION\nSCHPACEMAN: SURVEILLANCE EYECAM INSPIRATION", Vector2(72, 730), Vector2(1020, 330), 26)
	_add_image(roll_content, ONLINE_LOGO, Vector2(367, 1120), Vector2(430, 283))
	_add_text(roll_content, "CREATED & DEVELOPED BY TRIGGERED P\n\nSPECIAL THANKS\nDX: PLAYER ANIMATION, ONLINE ICON ART, PLAYTESTING\nXUESOS (4CNE): PLAYTESTING", Vector2(72, 1420), Vector2(1020, 265), 26)
	_add_image(roll_content, SOFTPRODUCTS_LOGO, Vector2(342, 1820), Vector2(220, 220))
	_add_image(roll_content, PURGATEAM_LOGO, Vector2(602, 1820), Vector2(220, 220))
	credits_music = AudioStreamPlayer.new()
	credits_music.pause_mode = Node.PAUSE_MODE_PROCESS
	credits_music.bus = "Music"
	credits_music.stream = load(CREDITS_MUSIC)
	add_child(credits_music)
	credits_buffer = BackBufferCopy.new()
	credits_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(credits_buffer)
	credits_buffer.hide()
	exit_effect = ColorRect.new()
	exit_effect.rect_size = rect_size
	exit_effect.color = Color.white
	exit_effect.mouse_filter = MOUSE_FILTER_IGNORE
	exit_effect.material = load("res://Materials/screenmat.tres").duplicate(true)
	exit_effect.material.set_shader_param("intro", true)
	exit_effect.material.set_shader_param("amplitude", 0.0)
	add_child(exit_effect)
	exit_effect.hide()

func _font(size):
	var font = DynamicFont.new()
	font.font_data = load("res://Fonts/MingLiU-ExtB-01.ttf")
	font.size = size
	return font

func _load_runtime_texture(path):
	var source = Image.new()
	if source.load(path) != OK:
		return null
	var texture = ImageTexture.new()
	texture.create_from_image(source, 0)
	return texture

func _bug_wave_material():
	var shader = Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n vec2 uv = UV * vec2(10.0, 5.625);\n uv.x += sin(uv.y * 1.4 + TIME * 0.8) * 0.12;\n uv.y += sin(uv.x * 1.1 + TIME * 0.6) * 0.07;\n COLOR = texture(TEXTURE, fract(uv)) * vec4(0.62, 0.62, 0.62, 1.0);\n}"
	var material = ShaderMaterial.new()
	material.shader = shader
	return material

func _add_image(parent, path, position, size):
	var image = TextureRect.new()
	image.rect_position = position
	image.rect_size = size
	image.expand = true
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = _load_runtime_texture(path)
	image.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _add_title_mesh(parent, position, size):
	var viewport = Viewport.new()
	viewport.size = size * 2
	viewport.usage = Viewport.USAGE_3D
	viewport.own_world = true
	viewport.transparent_bg = true
	viewport.msaa = Viewport.MSAA_4X
	viewport.render_target_v_flip = true
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	parent.add_child(viewport)
	var scene = Spatial.new()
	viewport.add_child(scene)
	var logo = MeshInstance.new()
	logo.mesh = load("res://Imported_Mesh/3dlogo.obj")
	var surface = SpatialMaterial.new()
	surface.albedo_texture = load("res://Textures/Menu/logo_3d_texture.png")
	surface.metallic_specular = 0.0
	surface.roughness = 0.0
	surface.emission_enabled = true
	surface.emission_texture = load("res://Textures/Menu/logo_3d_texture_emission.png")
	logo.material_override = surface
	logo.rotation_degrees.x = 90
	scene.add_child(logo)
	var bounds = logo.mesh.get_aabb()
	logo.translation = -logo.transform.basis.xform(bounds.position + bounds.size * 0.5)
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_color = Color.white
	environment.ambient_light_energy = 0.8
	var world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	scene.add_child(world_environment)
	var light = DirectionalLight.new()
	light.rotation_degrees = Vector3(-25, 30, 0)
	scene.add_child(light)
	var camera = Camera.new()
	camera.translation = Vector3(0, 0, 4.6)
	camera.fov = 50
	scene.add_child(camera)
	camera.current = true
	var display = TextureRect.new()
	display.rect_position = position
	display.rect_size = size
	display.expand = true
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.texture = viewport.get_texture()
	display.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(display)

func _add_text(parent, value, position, size, font_size):
	var label = RichTextLabel.new()
	label.rect_position = position
	label.rect_size = size
	label.bbcode_enabled = true
	label.scroll_active = false
	label.add_font_override("normal_font", _font(font_size))
	label.add_color_override("default_color", Color(0.92, 0.95, 0.85))
	label.add_color_override("font_color_shadow", Color.black)
	label.add_constant_override("shadow_offset_x", 2)
	label.add_constant_override("shadow_offset_y", 2)
	label.mouse_filter = MOUSE_FILTER_STOP
	for credit_name in CREDIT_URLS:
		value = value.replace(credit_name, "[url=" + CREDIT_URLS[credit_name] + "][color=#00ff00]" + credit_name + "[/color][/url]")
	label.bbcode_text = "[center]" + value + "[/center]"
	label.connect("meta_clicked", self, "_open_credit_link")
	parent.add_child(label)
	return label

func _open_credit_link(url):
	OS.shell_open(str(url))

func _process(delta):
	var target = roll_window.rect_size.y * 0.5 - FINAL_CARD_CENTER
	if roll_content.rect_position.y > target:
		roll_content.rect_position.y = max(target, roll_content.rect_position.y - delta * ROLL_SPEED * (4.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0))
	if roll_content.rect_position.y <= target:
		if exit_effect_time < 0.0:
			exit_effect_time = 0.0
			exit_effect.material.set_shader_param("amplitude", 0.0)
			credits_buffer.show()
			exit_effect.show()
		else:
			exit_effect_time += delta
			exit_effect.material.set_shader_param("amplitude", min(exit_effect_time / EXIT_EFFECT_SECONDS, 1.0))
		if exit_effect_time >= EXIT_EFFECT_SECONDS:
			close(true)

func open():
	roll_content.rect_position.y = 800
	exit_effect_time = -1.0
	credits_buffer.hide()
	exit_effect.hide()
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(Global.border):
		border_was_visible = Global.border.visible
		Global.border.hide()
	paused_music.clear()
	for player in [Global.music, Global.ambience]:
		if is_instance_valid(player):
			paused_music.append([player, player.stream_paused])
			player.stream_paused = true
	credits_music.play()
	show()
	raise()
	set_process(true)

func close(automatically = false):
	if not visible:
		return
	hide()
	credits_buffer.hide()
	exit_effect.hide()
	Input.mouse_mode = previous_mouse_mode
	set_process(false)
	credits_music.stop()
	if is_instance_valid(Global.border):
		Global.border.visible = border_was_visible
	for item in paused_music:
		if is_instance_valid(item[0]):
			item[0].stream_paused = item[1]
	paused_music.clear()
	emit_signal("finished", automatically)

func _exit_tree():
	close()
