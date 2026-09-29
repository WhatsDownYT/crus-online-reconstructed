extends Control

const DATA_PATH = "res://MOD_CONTENT/CruS Online/achievements/achievements.json"
const SECRET_ICON = "res://Textures/Menu/mystery.png"
const TAP_SOUND = "res://MOD_CONTENT/CruS Online/phone-tap.wav"
const MASTERY_KEYS = ["s_rank", "hope_eradicated", "punishment", "chaos", "extravagance", "stripped"]

var ui_overlay
var goals = []
var category_ids = ["all", "campaign", "online", "extras", "mastery"]
var category_labels = {"all": "ALL", "campaign": "CAMPAIGN", "online": "ONLINE", "extras": "EXTRAS", "mastery": "MASTERY"}
var current_category = "all"
var current_category_index = 0
var ming_title
var ming_body
var game_body
var header_nav_button
var filter_label
var list_scroll
var cards
var category_menu
var category_buttons = {}
var category_numbers = {}
var filter_count_label
var mastery_panel
var mastery_level = -1
var card_width = 0
var card_border_color = Color(1.0, 0.0, 0.68)
var screen_viewport
var scene_viewport
var scene_display
var input_overlay
var scene_camera
var scene_phone
var scene_phone_holder
var scene_camera_base_translation = Vector3.ZERO
var scene_camera_base_rotation = Vector3.ZERO
var hand_target
var hand_ik
var phone_hand_offset = Transform.IDENTITY
var desired_phone_transform = Transform.IDENTITY
var drag_active = false
var drag_scrolling = false
var scrollbar_drag = false
var drag_start = Vector2.ZERO
var drag_last = Vector2.ZERO
const DRAG_THRESHOLD = 7.0
var initialized = false
var tap_player

func _ready():
	name = "GoalsScreen"
	mouse_filter = MOUSE_FILTER_IGNORE
	rect_size = Vector2(1280, 720)
	hide()
	set_process(false)
	set_process_input(false)
	tap_player = AudioStreamPlayer.new()
	tap_player.bus = "SFX"
	tap_player.volume_db = 18.0
	var tap_file = File.new()
	if tap_file.open(TAP_SOUND, File.READ) == OK:
		tap_file.seek(44)
		var sound = AudioStreamSample.new()
		sound.format = AudioStreamSample.FORMAT_16_BITS
		sound.stereo = true
		sound.mix_rate = 44100
		sound.data = tap_file.get_buffer(tap_file.get_len() - 44)
		tap_player.stream = sound
		tap_file.close()
	add_child(tap_player)

func open():
	if not initialized:
		_initialize()
		if not is_instance_valid(scene_phone):
			return
		initialized = true
	else:
		mastery_level = -1
		mastery_panel.hide()
		_set_category_menu_visible(false)
		_refresh_category_view()
	set_process(true)
	set_process_input(true)
	show()

func _input(event):
	if not visible or not event is InputEventMouseButton or not event.pressed:
		return
	var local_point = get_global_transform_with_canvas().affine_inverse().xform(event.position)
	if event.button_index in [BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN]:
		var mapped = _map_input_position(local_point - input_overlay.rect_position)
		var list_rect = Rect2(ui_overlay.rect_position + list_scroll.rect_position, list_scroll.rect_size)
		if mastery_level < 0 and not category_menu.visible and list_rect.has_point(mapped):
			_scroll_by(-52 if event.button_index == BUTTON_WHEEL_UP else 52)
			get_tree().set_input_as_handled()
		return
	if event.button_index in [BUTTON_LEFT, BUTTON_RIGHT] and tap_player.stream != null:
		var mapped = _map_input_position(local_point - input_overlay.rect_position)
		if Rect2(Vector2.ZERO, screen_viewport.size).has_point(mapped):
			tap_player.play()

func _initialize():

	screen_viewport = Viewport.new()
	screen_viewport.name = "GoalsScreenViewport"
	screen_viewport.size = Vector2(256, 544)
	screen_viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
	screen_viewport.render_target_v_flip = false
	add_child(screen_viewport)

	scene_viewport = Viewport.new()
	scene_viewport.name = "GoalsSceneViewport"
	scene_viewport.size = Vector2(Global.resolution[0], Global.resolution[1])
	scene_viewport.usage = Viewport.USAGE_3D
	scene_viewport.audio_listener_enable_3d = true
	scene_viewport.own_world = true
	scene_viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
	scene_viewport.render_target_v_flip = true
	add_child(scene_viewport)

	var packed = load("res://Cutscenes/Cutscene1.tscn")
	if packed == null:
		return
	var scene_root = packed.instance()
	_prepare_intro_scene(scene_root)
	scene_viewport.add_child(scene_root)
	connect("visibility_changed", self, "_on_goals_visibility_changed")

	if not scene_root.has_node("intro_guy2"):
		return
	var phone_holder = scene_root.get_node("intro_guy2")
	scene_phone_holder = phone_holder
	var animation_player = phone_holder.get_node_or_null("AnimationPlayer")
	if is_instance_valid(animation_player) and animation_player.has_animation("Phone"):
		animation_player.play("Phone")
		animation_player.seek(0.85, true)
		animation_player.stop(false)
	phone_holder.show()
	var torso_mesh = phone_holder.get_node_or_null("Armature/Skeleton/Torso_Mesh")
	if is_instance_valid(torso_mesh):
		torso_mesh.show()
	_show_character_meshes(phone_holder)
	_smooth_character_vertex_snap(phone_holder)
	var head_mesh = phone_holder.get_node_or_null("Armature/Skeleton/Head_Mesh")
	if is_instance_valid(head_mesh):
		head_mesh.hide()
	var handheld_path = "Armature/Skeleton/BoneAttachment 2/Cube"
	if not phone_holder.has_node(handheld_path):
		return
	scene_phone = phone_holder.get_node(handheld_path)
	scene_phone.show()
	scene_phone.mesh = scene_phone.mesh.duplicate(true)
	var table_phone = scene_root.get_node_or_null("Cube")
	if is_instance_valid(table_phone):
		table_phone.hide()

	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.flags_albedo_tex_force_srgb = true
	material.albedo_color = Color(0.94, 0.94, 0.94, 1.0)
	material.albedo_texture = screen_viewport.get_texture()
	material.params_cull_mode = SpatialMaterial.CULL_DISABLED
	material.uv1_scale = Vector3(2.258, -1, 1)
	material.uv1_offset = Vector3(-0.617, 1, 0)
	scene_phone.set_surface_material(1, material)

	scene_camera = Camera.new()
	scene_camera.name = "GoalsCamera"
	scene_camera.fov = 55.0
	scene_camera.near = 0.005
	scene_root.add_child(scene_camera)
	scene_camera.translation = Vector3(3.104, -0.235, -4.325)
	scene_camera.rotation_degrees = Vector3(-41.884, 277.354, -0.001)
	scene_camera_base_translation = scene_camera.translation
	scene_camera_base_rotation = scene_camera.rotation_degrees
	scene_camera.current = true

	var skeleton = phone_holder.get_node_or_null("Armature/Skeleton")
	if not is_instance_valid(skeleton):
		return
	var hand_index = skeleton.find_bone("right_hand")
	if hand_index < 0:
		return
	var hand_global = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	phone_hand_offset = hand_global.affine_inverse() * scene_phone.global_transform
	desired_phone_transform = _desired_phone_transform(scene_phone, scene_camera)
	_pose_phone_arm(phone_holder, desired_phone_transform)
	call_deferred("_move_phone_only_closer")

	scene_display = TextureRect.new()
	scene_display.name = "GoalsScene"
	scene_display.rect_position = Vector2.ZERO
	scene_display.rect_size = rect_size
	scene_display.expand = true
	scene_display.stretch_mode = TextureRect.STRETCH_SCALE
	scene_display.mouse_filter = MOUSE_FILTER_IGNORE
	scene_display.texture = scene_viewport.get_texture()
	add_child(scene_display)
	scene_display.show_behind_parent = true
	scene_display.z_as_relative = false
	scene_display.z_index = -100
	move_child(scene_display, 0)

	_build_ui(scene_phone)
	set_process(false)

func _desired_phone_transform(phone, camera):
	var cam_basis = camera.global_transform.basis.orthonormalized()
	var cam_right = cam_basis.x.normalized()
	var cam_up = cam_basis.y.normalized()
	var cam_forward = -cam_basis.z.normalized()
	var arrays = phone.mesh.surface_get_arrays(1)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var phone_position = camera.global_transform.origin + cam_forward * 0.29 + cam_right * 0.035 - cam_up * 0.01
	if vertices.size() < 5:
		return Transform(phone.global_transform.basis.orthonormalized(), phone_position)
	var model_up = (vertices[0] - vertices[1]).normalized()
	var model_right = (vertices[0] - vertices[4]).normalized()
	model_right = (model_right - model_up * model_right.dot(model_up)).normalized()
	var model_front = model_right.cross(model_up).normalized()
	var model_basis = Basis(model_right, model_up, model_front)
	var desired_basis = Basis(-cam_right, -cam_up, -cam_forward)
	var orientation = desired_basis * model_basis.inverse()
	return Transform(orientation.orthonormalized(), phone_position)

func _pose_phone_arm(phone_holder, phone_transform):
	var skeleton = phone_holder.get_node_or_null("Armature/Skeleton")
	if not is_instance_valid(skeleton):
		return
	if not is_instance_valid(hand_target):
		hand_target = Spatial.new()
		hand_target.name = "GoalsPhoneHandTarget"
		phone_holder.get_parent().add_child(hand_target)
	if not is_instance_valid(hand_ik):
		hand_ik = SkeletonIK.new()
		hand_ik.name = "GoalsPhoneIK"
		hand_ik.root_bone = "right_upper_arm"
		hand_ik.tip_bone = "right_hand"
		hand_ik.override_tip_basis = true
		hand_ik.interpolation = 1.0
		skeleton.add_child(hand_ik)
		hand_ik.target_node = hand_ik.get_path_to(hand_target)
	var desired_hand = phone_transform * phone_hand_offset.affine_inverse()
	hand_target.global_transform = desired_hand
	hand_ik.start(true)

func _move_phone_only_closer():
	if not is_instance_valid(scene_phone) or not is_instance_valid(scene_camera):
		return
	var transform = scene_phone.global_transform
	var toward_camera = (scene_camera.global_transform.origin - transform.origin).normalized()
	transform.origin += toward_camera * 0.022
	scene_phone.global_transform = transform

func _smooth_character_vertex_snap(node):
	if node is MeshInstance:
		if node.material_override is ShaderMaterial and _has_snap_shader(node.material_override):
			var override_material = node.material_override.duplicate(true)
			override_material.set_shader_param("snapRes", 100000.0)
			node.material_override = override_material
		if node.mesh != null:
			for surface in range(node.mesh.get_surface_count()):
				var material = node.get_surface_material(surface)
				if material is ShaderMaterial and _has_snap_shader(material):
					var smooth_material = material.duplicate(true)
					smooth_material.set_shader_param("snapRes", 100000.0)
					node.set_surface_material(surface, smooth_material)
	for child in node.get_children():
		_smooth_character_vertex_snap(child)

func _has_snap_shader(material):
	if material == null or not material is ShaderMaterial or material.shader == null:
		return false
	return str(material.shader.code).find("uniform float snapRes") != -1

func _show_character_meshes(node):
	if node is MeshInstance:
		node.show()
	for child in node.get_children():
		_show_character_meshes(child)

func _process(delta):
	if not visible:
		return
	if not is_instance_valid(scene_camera) or not is_instance_valid(scene_phone):
		return
	var mouse = get_local_mouse_position()
	var centered = Vector2(
		clamp((mouse.x / max(1.0, rect_size.x) - 0.5) * 2.0, -1.0, 1.0),
		clamp((mouse.y / max(1.0, rect_size.y) - 0.5) * 2.0, -1.0, 1.0)
	)
	var target_rotation = scene_camera_base_rotation + Vector3(-centered.y * 2.6, -centered.x * 3.7, 0)
	scene_camera.translation = scene_camera_base_translation
	scene_camera.rotation_degrees = scene_camera.rotation_degrees.linear_interpolate(target_rotation, min(1.0, delta * 7.5))
	if is_instance_valid(header_nav_button):
		var nav_hovered = _is_category_nav_screen_hit(mouse)
		var nav_color = Color(1.0, 0.0, 0.68) if nav_hovered else Color(0.12, 1.0, 0.18)
		header_nav_button.add_color_override("font_color", nav_color)
		header_nav_button.add_color_override("font_color_hover", nav_color)
	_update_phone_input_bounds()

func _prepare_intro_scene(node):
	if node.name == "Activator":
		node.set_script(null)
		return
	if node.name == "Navigation":
		node.set_script(null)
		return
	if node.get_script() != null:
		node.set_script(null)
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D or child is Timer or child is Particles:
			node.remove_child(child)
			child.free()
			continue
		_prepare_intro_scene(child)
	for name in ["MarginContainer", "Cameras", "intro_guy", "intro_guy3", "phone_end", "phone_start", "Activator", "Navigation"]:
		if node.has_node(name):
			var child = node.get_node(name)
			node.remove_child(child)
			child.free()

func _on_goals_visibility_changed():
	if is_instance_valid(screen_viewport):
		screen_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS if visible else Viewport.UPDATE_DISABLED
	if is_instance_valid(scene_viewport):
		scene_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS if visible else Viewport.UPDATE_DISABLED
	_set_main_menu_gunshots_enabled(not visible)

func _set_main_menu_gunshots_enabled(enabled):
	_set_gunshot_emitters_recursive(get_tree().root, enabled)

func _set_gunshot_emitters_recursive(node, enabled):
	if node == self or node == scene_viewport or node == screen_viewport:
		return
	if node.name == "Gunshot_Emitter":
		node.set_physics_process(enabled)
		var sound = node.get_node_or_null("Sound")
		if is_instance_valid(sound) and not enabled:
			sound.stop()
	for child in node.get_children():
		_set_gunshot_emitters_recursive(child, enabled)

func _font(path, size):
	var font = DynamicFont.new()
	font.font_data = load(path)
	font.size = size
	font.use_filter = true
	return font

func _label(value, font, position, size):
	var label = Label.new()
	label.text = value
	label.rect_position = position
	label.rect_size = size
	label.add_font_override("font", font)
	label.add_color_override("font_color", Color(0.86, 0.85, 0.82))
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label

func _texture(path):
	if path.empty(): return null
	if ResourceLoader.exists(path): return load(path)
	var file = File.new()
	if file.open(path, File.READ) != OK: return null
	var image = Image.new()
	var result = image.load_png_from_buffer(file.get_buffer(file.get_len()))
	file.close()
	if result != OK: return null
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

func _load_goals():
	var file = File.new()
	goals = []
	if file.open(DATA_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
			goals = parsed.result.get("achievements", [])

func _build_ui(phone):
	ui_overlay = Control.new()
	ui_overlay.name = "GoalsUI"
	ui_overlay.rect_position = Vector2(-4, -4)
	ui_overlay.rect_size = screen_viewport.size + Vector2(8, 8)
	ui_overlay.rect_clip_content = true
	screen_viewport.add_child(ui_overlay)

	input_overlay = Control.new()
	input_overlay.name = "GoalsInputOverlay"
	input_overlay.rect_position = Vector2.ZERO
	input_overlay.rect_size = rect_size
	input_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	input_overlay.connect("gui_input", self, "_on_input_overlay_gui_input")
	add_child(input_overlay)

	var width = ui_overlay.rect_size.x
	ming_title = _font("res://Fonts/MingLiU-ExtB-01.ttf", 23)
	ming_body = _font("res://Fonts/MingLiU-ExtB-01.ttf", 16)
	game_body = _font("res://Fonts/gamefont(1).ttf", 13)
	_load_goals()
	var field = ColorRect.new()
	field.color = Color(0.055, 0.008, 0.07)
	field.rect_size = ui_overlay.rect_size
	ui_overlay.add_child(field)
	var header_back = ColorRect.new()
	header_back.color = Color(0.16, 0.18, 0.24)
	header_back.rect_size = Vector2(width, 37)
	ui_overlay.add_child(header_back)
	var header = _label("GOALS", ming_title, Vector2(38, 6), Vector2(width - 105, 27))
	ui_overlay.add_child(header)
	header_nav_button = Button.new()
	header_nav_button.rect_position = Vector2(width - 96, 2)
	header_nav_button.rect_size = Vector2(72, 33)
	header_nav_button.flat = true
	header_nav_button.focus_mode = Control.FOCUS_NONE
	header_nav_button.text = "01"
	header_nav_button.add_font_override("font", ming_body)
	header_nav_button.add_color_override("font_color", Color(0.12, 1.0, 0.18))
	header_nav_button.add_color_override("font_color_hover", Color(1.0, 0.0, 0.68))
	header_nav_button.add_color_override("font_color_pressed", Color(1.0, 0.0, 0.68))
	header_nav_button.align = Button.ALIGN_RIGHT
	var nav_normal = StyleBoxEmpty.new()
	var nav_hover = StyleBoxFlat.new()
	nav_hover.bg_color = Color(0.21, 0.09, 0.2, 0.55)
	nav_hover.border_color = Color(1.0, 0.0, 0.68)
	nav_hover.border_width_left = 1
	var nav_pressed = StyleBoxFlat.new()
	nav_pressed.bg_color = Color(0.17, 0.07, 0.16, 0.7)
	nav_pressed.border_color = Color(0.12, 1.0, 0.18)
	nav_pressed.border_width_left = 1
	header_nav_button.add_stylebox_override("normal", nav_normal)
	header_nav_button.add_stylebox_override("hover", nav_hover)
	header_nav_button.add_stylebox_override("pressed", nav_pressed)
	header_nav_button.connect("pressed", self, "_on_header_nav_pressed")
	ui_overlay.add_child(header_nav_button)
	var rule = ColorRect.new()
	rule.color = Color(0.55, 0.57, 0.61)
	rule.rect_position = Vector2(0, 36)
	rule.rect_size = Vector2(width, 1)
	ui_overlay.add_child(rule)
	filter_label = _label("ALL", ming_body, Vector2(12, 42), Vector2(width - 100, 18))
	filter_label.add_color_override("font_color", Color(1.0, 0.0, 0.68))
	ui_overlay.add_child(filter_label)
	filter_count_label = _label("0/0", ming_body, Vector2(width - 88, 42), Vector2(76, 18))
	filter_count_label.align = Label.ALIGN_RIGHT
	filter_count_label.add_color_override("font_color", Color(1.0, 0.0, 0.68))
	ui_overlay.add_child(filter_count_label)
	list_scroll = ScrollContainer.new()
	list_scroll.name = "GoalsList"
	list_scroll.rect_position = Vector2(12, 58)
	list_scroll.rect_size = Vector2(width - 24, ui_overlay.rect_size.y - 64)
	var clear = StyleBoxEmpty.new()
	list_scroll.add_stylebox_override("bg", clear)
	list_scroll.scroll_horizontal_enabled = false
	ui_overlay.add_child(list_scroll)
	cards = VBoxContainer.new()
	card_width = list_scroll.rect_size.x - 9
	cards.rect_position = Vector2.ZERO
	cards.rect_min_size = Vector2(card_width, 0)
	cards.add_constant_override("separation", 5)
	list_scroll.add_child(cards)
	_style_scrollbar()
	category_menu = Control.new()
	category_menu.rect_position = list_scroll.rect_position
	category_menu.rect_size = list_scroll.rect_size
	category_menu.visible = false
	ui_overlay.add_child(category_menu)
	_build_category_menu()
	mastery_panel = Control.new()
	mastery_panel.rect_position = list_scroll.rect_position
	mastery_panel.rect_size = list_scroll.rect_size
	mastery_panel.visible = false
	ui_overlay.add_child(mastery_panel)
	_refresh_category_view()
	call_deferred("_update_phone_input_bounds")

func _update_phone_input_bounds():
	if not is_instance_valid(scene_phone) or not is_instance_valid(scene_camera) or not is_instance_valid(input_overlay):
		return
	var arrays = scene_phone.mesh.surface_get_arrays(1)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var low = Vector2(100000, 100000)
	var high = Vector2(-100000, -100000)
	var scale = Vector2(
		scene_display.rect_size.x / max(1.0, scene_viewport.size.x),
		scene_display.rect_size.y / max(1.0, scene_viewport.size.y)
	)
	for vertex in vertices:
		var world = scene_phone.global_transform.xform(vertex)
		var point = scene_camera.unproject_position(world)
		point *= scale
		low.x = min(low.x, point.x)
		low.y = min(low.y, point.y)
		high.x = max(high.x, point.x)
		high.y = max(high.y, point.y)
	var margin = Vector2(8, 8)
	input_overlay.rect_position = low - margin
	input_overlay.rect_size = (high - low) + margin * 2.0

func _on_input_overlay_gui_input(event):
	if not is_instance_valid(screen_viewport):
		return
	if event is InputEventMouseButton:
		if event.button_index in [BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN]:
			accept_event()
			return
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				scrollbar_drag = _is_scrollbar_hit(event.position)
				if scrollbar_drag:
					_forward_mouse_button(event)
				drag_active = not scrollbar_drag and _is_list_hit(event.position)
				drag_scrolling = false
				drag_start = event.position
				drag_last = event.position
			else:
				if scrollbar_drag:
					_forward_mouse_button(event)
				elif not drag_scrolling:
					if _is_category_nav_hit(event.position):
						_on_header_nav_pressed()
					else:
						_send_click(event.position)
				scrollbar_drag = false
				drag_active = false
				drag_scrolling = false
			accept_event()
			return
		_forward_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		if scrollbar_drag:
			_forward_mouse_motion(event)
			accept_event()
			return
		if drag_active and (event.button_mask & BUTTON_MASK_LEFT) != 0:
			if not drag_scrolling and event.position.distance_to(drag_start) >= DRAG_THRESHOLD:
				drag_scrolling = true
			if drag_scrolling:
				var scale_y = screen_viewport.size.y / max(1.0, input_overlay.rect_size.y)
				_scroll_by(int(-(event.position.y - drag_last.y) * scale_y))
			drag_last = event.position
			accept_event()
			return
		_forward_mouse_motion(event)

func _is_list_hit(position):
	if category_menu.visible or mastery_level >= 0:
		return false
	var mapped = _map_input_position(position)
	return Rect2(ui_overlay.rect_position + list_scroll.rect_position, list_scroll.rect_size).has_point(mapped)

func _is_scrollbar_hit(position):
	if not _is_list_hit(position):
		return false
	var scrollbar = list_scroll.get_v_scrollbar()
	var origin = ui_overlay.rect_position + list_scroll.rect_position + scrollbar.rect_position
	return Rect2(origin, scrollbar.rect_size).has_point(_map_input_position(position))

func _is_category_nav_hit(position):
	if not is_instance_valid(input_overlay) or not is_instance_valid(header_nav_button):
		return false
	var mapped = _map_input_position(position)
	var nav_rect = Rect2(ui_overlay.rect_position + header_nav_button.rect_position, header_nav_button.rect_size)
	return nav_rect.has_point(mapped)

func _barycentric_2d(point, a, b, c):
	var v0 = b - a
	var v1 = c - a
	var v2 = point - a
	var denom = v0.x * v1.y - v1.x * v0.y
	if abs(denom) < 0.000001:
		return Vector3(-1, -1, -1)
	var v = (v2.x * v1.y - v1.x * v2.y) / denom
	var w = (v0.x * v2.y - v2.x * v0.y) / denom
	var u = 1.0 - v - w
	return Vector3(u, v, w)

func _ui_point_to_scene(point):
	if not is_instance_valid(scene_phone) or not is_instance_valid(scene_camera):
		return Vector2(-10000, -10000)
	var arrays = scene_phone.mesh.surface_get_arrays(1)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indices = arrays[Mesh.ARRAY_INDEX]
	if vertices.empty() or uvs.empty():
		return Vector2(-10000, -10000)
	var texture_uv = Vector2(point.x / screen_viewport.size.x, point.y / screen_viewport.size.y)
	var raw_uv = Vector2((texture_uv.x + 0.617) / 2.258, texture_uv.y)
	var triangle_count = int(indices.size() / 3) if not indices.empty() else int(vertices.size() / 3)
	for triangle in range(triangle_count):
		var i0 = indices[triangle * 3] if not indices.empty() else triangle * 3
		var i1 = indices[triangle * 3 + 1] if not indices.empty() else triangle * 3 + 1
		var i2 = indices[triangle * 3 + 2] if not indices.empty() else triangle * 3 + 2
		var bary = _barycentric_2d(raw_uv, uvs[i0], uvs[i1], uvs[i2])
		if bary.x >= -0.001 and bary.y >= -0.001 and bary.z >= -0.001:
			var local = vertices[i0] * bary.x + vertices[i1] * bary.y + vertices[i2] * bary.z
			var world = scene_phone.global_transform.xform(local)
			var projected = scene_camera.unproject_position(world)
			projected *= Vector2(scene_display.rect_size.x / max(1.0, scene_viewport.size.x), scene_display.rect_size.y / max(1.0, scene_viewport.size.y))
			return projected
	return Vector2(-10000, -10000)

func _category_nav_polygon():
	var origin = ui_overlay.rect_position + header_nav_button.rect_position
	var size = header_nav_button.rect_size
	origin.y = max(2.0, origin.y)
	return [
		_ui_point_to_scene(origin),
		_ui_point_to_scene(origin + Vector2(size.x, 0)),
		_ui_point_to_scene(origin + size),
		_ui_point_to_scene(origin + Vector2(0, size.y))
	]

func _point_in_triangle_2d(point, a, b, c):
	var bary = _barycentric_2d(point, a, b, c)
	return bary.x >= -0.001 and bary.y >= -0.001 and bary.z >= -0.001

func _is_category_nav_screen_hit(position):
	if not is_instance_valid(input_overlay):
		return false
	var local = position - input_overlay.rect_position
	if not Rect2(Vector2.ZERO, input_overlay.rect_size).has_point(local):
		return false
	return _is_category_nav_hit(local)

func _send_click(position):
	var mapped_position = _map_input_position(position)
	var press = InputEventMouseButton.new()
	press.button_index = BUTTON_LEFT
	press.button_mask = BUTTON_MASK_LEFT
	press.pressed = true
	press.position = mapped_position
	press.global_position = mapped_position
	screen_viewport.input(press)
	var release = InputEventMouseButton.new()
	release.button_index = BUTTON_LEFT
	release.button_mask = 0
	release.pressed = false
	release.position = mapped_position
	release.global_position = mapped_position
	screen_viewport.input(release)

func _forward_mouse_button(event):
	var mapped = InputEventMouseButton.new()
	mapped.button_index = event.button_index
	mapped.doubleclick = event.doubleclick
	mapped.factor = event.factor
	mapped.pressed = event.pressed
	mapped.button_mask = event.button_mask
	mapped.position = _map_input_position(event.position)
	mapped.global_position = mapped.position
	screen_viewport.input(mapped)

func _forward_mouse_motion(event):
	var mapped = InputEventMouseMotion.new()
	mapped.button_mask = event.button_mask
	mapped.pressure = event.pressure
	mapped.speed = event.speed
	mapped.tilt = event.tilt
	mapped.position = _map_input_position(event.position)
	mapped.global_position = mapped.position
	mapped.relative = event.relative * Vector2(screen_viewport.size.x / max(1.0, input_overlay.rect_size.x), screen_viewport.size.y / max(1.0, input_overlay.rect_size.y))
	screen_viewport.input(mapped)

func _scroll_by(amount):
	if not is_instance_valid(list_scroll) or category_menu.visible or mastery_level >= 0:
		return
	list_scroll.scroll_vertical = int(clamp(list_scroll.scroll_vertical + amount, 0, list_scroll.get_v_scrollbar().max_value))

func _style_scrollbar():
	if not is_instance_valid(list_scroll):
		return
	var scrollbar = list_scroll.get_v_scrollbar()
	if not is_instance_valid(scrollbar):
		return
	scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	scrollbar.modulate = Color(1, 1, 1, 1)
	scrollbar.rect_min_size.x = 8
	scrollbar.add_stylebox_override("scroll", _scroll_grabber(Color(0.18, 0.02, 0.18)))
	scrollbar.add_stylebox_override("grabber", _scroll_grabber(Color(0.08, 0.9, 0.16)))
	scrollbar.add_stylebox_override("grabber_highlight", _scroll_grabber(Color(1, 0, 0.68)))
	scrollbar.add_stylebox_override("grabber_pressed", _scroll_grabber(Color(1, 0, 0.68)))

func _map_input_position(position):
	if not is_instance_valid(scene_phone) or not is_instance_valid(scene_camera):
		return Vector2(-10000, -10000)
	var point = position + input_overlay.rect_position
	var arrays = scene_phone.mesh.surface_get_arrays(1)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indices = arrays[Mesh.ARRAY_INDEX]
	var scale = Vector2(scene_display.rect_size.x / max(1.0, scene_viewport.size.x), scene_display.rect_size.y / max(1.0, scene_viewport.size.y))
	var triangle_count = int(indices.size() / 3) if not indices.empty() else int(vertices.size() / 3)
	for triangle in range(triangle_count):
		var i0 = indices[triangle * 3] if not indices.empty() else triangle * 3
		var i1 = indices[triangle * 3 + 1] if not indices.empty() else triangle * 3 + 1
		var i2 = indices[triangle * 3 + 2] if not indices.empty() else triangle * 3 + 2
		var a = scene_camera.unproject_position(scene_phone.global_transform.xform(vertices[i0])) * scale
		var b = scene_camera.unproject_position(scene_phone.global_transform.xform(vertices[i1])) * scale
		var c = scene_camera.unproject_position(scene_phone.global_transform.xform(vertices[i2])) * scale
		var bary = _barycentric_2d(point, a, b, c)
		if bary.x >= -0.001 and bary.y >= -0.001 and bary.z >= -0.001:
			var uv = uvs[i0] * bary.x + uvs[i1] * bary.y + uvs[i2] * bary.z
			return Vector2((uv.x * 2.258 - 0.617) * screen_viewport.size.x, uv.y * screen_viewport.size.y)
	return Vector2(-10000, -10000)

func _scroll_grabber(color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	return style

func _build_category_menu():
	var title = _label("CATEGORIES", ming_body, Vector2(9, 10), Vector2(category_menu.rect_size.x - 18, 20))
	title.add_color_override("font_color", Color(1.0, 0.0, 0.68))
	category_menu.add_child(title)
	var line = ColorRect.new()
	line.color = Color(0.46, 0.27, 0.43)
	line.rect_position = Vector2(8, 34)
	line.rect_size = Vector2(category_menu.rect_size.x - 16, 1)
	category_menu.add_child(line)
	for i in range(category_ids.size()):
		var id = category_ids[i]
		var button = Button.new()
		button.rect_position = Vector2(8, 44 + i * 54)
		button.rect_size = Vector2(category_menu.rect_size.x - 16, 46)
		button.focus_mode = Control.FOCUS_NONE
		button.text = "  " + category_labels[id]
		button.align = Button.ALIGN_LEFT
		button.add_font_override("font", ming_body)
		button.connect("pressed", self, "_on_category_button_pressed", [id])
		button.connect("mouse_entered", self, "_on_category_number_hover", [id, true])
		button.connect("mouse_exited", self, "_on_category_number_hover", [id, false])
		category_menu.add_child(button)
		category_buttons[id] = button
		var number = _label(str(i + 1).pad_zeros(2), ming_body, Vector2(category_menu.rect_size.x - 45, 57 + i * 54), Vector2(30, 20))
		number.align = Label.ALIGN_RIGHT
		category_menu.add_child(number)
		category_numbers[id] = number
	_update_category_menu_styles()

func _on_category_number_hover(id, hovered):
	category_numbers[id].add_color_override("font_color", Color(1, 0, 0.68) if hovered else (Color(0.12, 1, 0.18) if id == current_category else Color(0.86, 0.85, 0.82)))

func _make_menu_button_style(active, hover):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.01, 0.07)
	style.border_width_left = 2 if active else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.08, 0.95, 0.15) if active else Color(0.46, 0.27, 0.43)
	if hover:
		style.bg_color = Color(0.14, 0.04, 0.14)
		style.border_color = Color(1.0, 0.0, 0.68)
	if active and hover:
		style.bg_color = Color(0.12, 0.04, 0.11)
		style.border_color = Color(0.08, 0.95, 0.15)
	return style

func _update_category_menu_styles():
	for id in category_buttons.keys():
		var button = category_buttons[id]
		var active = id == current_category
		button.add_stylebox_override("normal", _make_menu_button_style(active, false))
		button.add_stylebox_override("hover", _make_menu_button_style(active, true))
		button.add_stylebox_override("pressed", _make_menu_button_style(true, false))
		button.add_color_override("font_color", Color(0.12, 1.0, 0.18) if active else Color(0.86, 0.85, 0.82))
		button.add_color_override("font_color_hover", Color(1.0, 0.0, 0.68))
		button.add_color_override("font_color_pressed", Color(0.12, 1.0, 0.18))
		_on_category_number_hover(id, false)

func _filtered_goals():
	if current_category == "all":
		return goals
	var filtered = []
	for goal in goals:
		if typeof(goal) != TYPE_DICTIONARY:
			continue
		var category = str(goal.get("category", "campaign")).to_lower()
		if category == current_category:
			filtered.append(goal)
	return filtered

func _wrap_text_lines(text, font, width):
	var lines = []
	for paragraph in str(text).split("\n", true):
		var line = ""
		for word in paragraph.split(" ", false):
			var candidate = word if line.empty() else line + " " + word
			if font.get_string_size(candidate).x <= width:
				line = candidate
				continue
			if not line.empty():
				lines.append(line)
				line = ""
			var piece = ""
			for character in word:
				if not piece.empty() and font.get_string_size(piece + character).x > width:
					lines.append(piece)
					piece = ""
				piece += character
			line = piece
		lines.append(line)
	return lines

func _refresh_cards():
	for child in cards.get_children():
		child.queue_free()
	var filtered = _filtered_goals()
	for goal in filtered:
		if typeof(goal) == TYPE_DICTIONARY:
			var display_goal = goal
			var manager = Global.get_node_or_null("AchievementGoals")
			if manager != null and manager.is_hidden(goal):
				display_goal = goal.duplicate(true)
				display_goal["name"] = "???"
				display_goal["description"] = "???"
				display_goal["icon"] = SECRET_ICON
			_add_card(cards, display_goal, card_width, ming_body, game_body)
	list_scroll.scroll_vertical = 0
	filter_label.text = category_labels.get(current_category, "ALL")
	var manager = Global.get_node_or_null("AchievementGoals")
	var earned = 0
	if manager != null:
		for goal in filtered:
			if manager.unlocked.has(str(goal.get("id", ""))):
				earned += 1
	filter_count_label.text = str(earned) + "/" + str(filtered.size())

func _refresh_category_view():
	header_nav_button.text = str(current_category_index + 1).pad_zeros(2)
	_refresh_cards()
	_update_category_menu_styles()

func _set_category_menu_visible(visible):
	category_menu.visible = visible
	list_scroll.visible = not visible and mastery_level < 0
	filter_label.visible = not visible and mastery_level < 0
	filter_count_label.visible = not visible and mastery_level < 0

func _on_header_nav_pressed():
	if mastery_level >= 0:
		_close_mastery()
		return
	_set_category_menu_visible(not category_menu.visible)

func _on_category_button_pressed(id):
	current_category = id
	current_category_index = category_ids.find(id)
	if current_category_index < 0:
		current_category_index = 0
	_refresh_category_view()
	_set_category_menu_visible(false)

func _add_card(cards, goal, width, ming_body, game_body):
	var manager = Global.get_node_or_null("AchievementGoals")
	var completed = manager != null and manager.unlocked.has(str(goal.get("id", "")))
	var border_color = Color(0.12, 0.95, 0.18) if completed else card_border_color
	var title_lines = _wrap_text_lines(str(goal.get("name", "")).to_upper(), ming_body, width - 10)
	var title_height = max(20, int(ming_body.get_height()) * max(1, title_lines.size()))
	var image_y = 8 + title_height + 6
	var image_height = 91
	var desc_y = image_y + image_height + 7
	var desc_width = width - 12
	var lines = _wrap_text_lines(str(goal.get("description", "")), game_body, desc_width)
	var line_height = max(14, int(game_body.get_height()))
	var desc_height = max(32, line_height * max(1, lines.size()))
	var divider_y = max(image_y + image_height + 8, desc_y + desc_height + 8)
	var reward_y = divider_y + 6
	var card_height = reward_y + 27 + 4
	var description_text = "\n".join(lines)

	var card = Panel.new()
	card.rect_min_size = Vector2(width, card_height)
	card.mouse_filter = MOUSE_FILTER_PASS
	var style = StyleBoxTexture.new()
	style.texture = load("res://Textures/Menu/background_1.png")
	style.region_rect = Rect2(0, 0, 256, 256)
	style.margin_left = 10.0
	style.margin_right = 10.0
	style.margin_top = 10.0
	style.margin_bottom = 10.0
	style.modulate_color = Color(0.04, 0.58, 0.12, 1.0) if completed else Color(0.52, 0.0, 0.72, 1.0)
	card.add_stylebox_override("panel", style)
	cards.add_child(card)
	for border in [
		Rect2(0, 0, width, 1),
		Rect2(0, card_height - 1, width, 1),
		Rect2(0, 0, 1, card_height),
		Rect2(width - 1, 0, 1, card_height)
	]:
		var edge = ColorRect.new()
		edge.color = border_color
		edge.rect_position = border.position
		edge.rect_size = border.size
		card.add_child(edge)
	var title = _label("\n".join(title_lines), ming_body, Vector2(5, 8), Vector2(width - 10, title_height))
	card.add_child(title)
	var image = TextureRect.new()
	image.rect_position = Vector2(6, image_y)
	image.rect_size = Vector2(91, image_height)
	image.expand = true
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = MOUSE_FILTER_IGNORE
	image.texture = _texture(str(goal.get("icon", "")))
	card.add_child(image)
	if goal.get("category", "") == "campaign" and manager != null and not manager.is_hidden(goal):
		var progress = manager.mastery_for(int(goal.get("level", -1)))
		var mastered = 0
		for key in MASTERY_KEYS:
			if progress[key]:
				mastered += 1
		var mastery_count = _label(str(mastered) + " / 6", ming_title, Vector2(103, image_y + 19), Vector2(width - 110, 31))
		mastery_count.align = Label.ALIGN_CENTER
		mastery_count.add_color_override("font_color", Color(0.12, 1.0, 0.18))
		card.add_child(mastery_count)
		var mastery_button = Button.new()
		mastery_button.text = "MASTERY"
		mastery_button.rect_position = Vector2(103, image_y + 54)
		mastery_button.rect_size = Vector2(width - 110, 31)
		mastery_button.add_font_override("font", ming_body)
		mastery_button.add_color_override("font_color", Color(0.86, 0.85, 0.82))
		mastery_button.add_color_override("font_color_hover", Color(1, 0, 0.68))
		mastery_button.add_color_override("font_color_pressed", Color(1, 0, 0.68))
		mastery_button.add_stylebox_override("normal", _make_menu_button_style(false, false))
		mastery_button.add_stylebox_override("hover", _make_menu_button_style(false, true))
		mastery_button.add_stylebox_override("pressed", _make_menu_button_style(true, false))
		mastery_button.connect("pressed", self, "_open_mastery", [int(goal.get("level", -1))])
		card.add_child(mastery_button)
	var description = _label(description_text, game_body, Vector2(6, desc_y), Vector2(desc_width, desc_height))
	description.clip_text = false
	card.add_child(description)
	var divider = ColorRect.new()
	divider.color = border_color
	divider.rect_position = Vector2(5, divider_y)
	divider.rect_size = Vector2(width - 10, 1)
	card.add_child(divider)
	var reward = _label("COMPLETED" if completed else "REWARD", ming_body, Vector2(6, reward_y), Vector2(width - 12, 27))
	reward.add_color_override("font_color", Color(0.12, 0.95, 0.18))
	card.add_child(reward)
	var reward_amount = _label("$" + str(goal.get("reward", 0)), ming_body, Vector2(6, reward_y), Vector2(width - 12, 27))
	reward_amount.align = Label.ALIGN_RIGHT
	reward_amount.add_color_override("font_color", Color(0.12, 0.95, 0.18))
	card.add_child(reward_amount)

func _open_mastery(level):
	if level < 0:
		return
	mastery_level = level
	category_menu.hide()
	list_scroll.hide()
	filter_label.hide()
	filter_count_label.hide()
	header_nav_button.text = "BACK"
	_render_mastery()
	mastery_panel.show()

func _close_mastery():
	mastery_level = -1
	mastery_panel.hide()
	list_scroll.show()
	filter_label.show()
	filter_count_label.show()
	header_nav_button.text = str(current_category_index + 1).pad_zeros(2)

func _render_mastery():
	for child in mastery_panel.get_children():
		child.queue_free()
	var manager = Global.get_node_or_null("AchievementGoals")
	if manager == null:
		return
	var entry = null
	for goal in goals:
		if goal.get("category", "") == "mastery" and int(goal.get("level", -1)) == mastery_level:
			entry = goal
			break
	if entry == null:
		return
	var progress = manager.mastery_for(mastery_level)
	var completed = 0
	for key in MASTERY_KEYS:
		if progress[key]:
			completed += 1
	var title = _label(str(entry.get("name", "")).to_upper(), ming_body, Vector2(6, 3), Vector2(mastery_panel.rect_size.x - 12, 44))
	title.autowrap = true
	mastery_panel.add_child(title)
	var icon = TextureRect.new()
	icon.rect_position = Vector2(8, 54)
	icon.rect_size = Vector2(91, 91)
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	icon.texture = _texture(SECRET_ICON if manager.is_hidden(entry) else str(entry.get("icon", "")))
	mastery_panel.add_child(icon)
	var count = _label(str(completed) + " / 6", ming_title, Vector2(115, 79), Vector2(125, 35))
	count.add_color_override("font_color", Color(0.12, 1.0, 0.18))
	mastery_panel.add_child(count)
	var labels = {"s_rank": "S RANK", "hope_eradicated": "HOPE ERADICATED", "punishment": "PUNISHMENT", "chaos": "CHAOS", "extravagance": "EXTRAVAGANCE", "stripped": "STRIPPED"}
	for index in range(MASTERY_KEYS.size()):
		var key = MASTERY_KEYS[index]
		var won = progress[key]
		var row = ColorRect.new()
		row.color = Color(0.01, 0.30, 0.05) if won else Color(0.22, 0.01, 0.08)
		row.rect_position = Vector2(7, 158 + index * 47)
		row.rect_size = Vector2(mastery_panel.rect_size.x - 14, 41)
		mastery_panel.add_child(row)
		var marker = ColorRect.new()
		marker.color = Color(0.12, 1.0, 0.18) if won else Color(1, 0.08, 0.16)
		marker.rect_position = Vector2(15, 174 + index * 47)
		marker.rect_size = Vector2(10, 10)
		mastery_panel.add_child(marker)
		var hidden_name = key in ["hope_eradicated", "chaos", "extravagance"] and not manager.known_condition(key)
		var label = _label("???" if hidden_name else labels[key], ming_body, Vector2(37, 165 + index * 47), Vector2(mastery_panel.rect_size.x - 45, 25))
		mastery_panel.add_child(label)

func go():
	mastery_level = -1
	hide()
	set_process(false)
	set_process_input(false)
