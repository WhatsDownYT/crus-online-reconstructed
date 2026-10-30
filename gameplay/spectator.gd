extends Node

onready var mp = get_parent()
var active = false
var target = 0
var distance = 4.0
var yaw = 0.0
var pitch = -0.15
var pivot
var arm
var camera
var button
var caption
var overlay
var watched_scene = null
var previous_input = true
var previous_key_input = true

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	pivot = Spatial.new()
	add_child(pivot)
	arm = SpringArm.new()
	arm.collision_mask = 1
	arm.margin = 0.15
	pivot.add_child(arm)
	camera = Camera.new()
	camera.near = 0.05
	arm.add_child(camera)
	var layer = CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	caption = Label.new()
	caption.align = Label.ALIGN_CENTER
	caption.add_font_override("font", _font())
	caption.add_color_override("font_color", Color(0, 1, 0))
	caption.add_color_override("font_color_shadow", Color.black)
	caption.add_constant_override("shadow_offset_x", 1)
	caption.add_constant_override("shadow_offset_y", 1)
	overlay.add_child(caption)
	overlay.hide()

func _font(size = 18):
	var font = DynamicFont.new()
	font.font_data = load("res://Fonts/gamefont(1).ttf")
	font.size = size
	return font

func _death_screen():
	return Global.get_node_or_null("DeathScreen")

func _dead_in_mission():
	return mp.NetworkBridge.check_connection() and mp.player_scene_loaded and not mp.Flow.result_active and is_instance_valid(Global.menu) and Global.menu.in_game and is_instance_valid(Global.player) and (Global.player.dead or Global.player.died)

func candidates():
	var peers = []
	var local = mp.NetworkBridge.get_id()
	for peer in mp.players:
		if peer == local or mp.died_players.has(peer) or mp.Flow.waiting_peers.has(peer): continue
		if mp.CounterOp.is_active() and not mp.CounterOp.settings.get("spectateOpponents", false) and not mp.CounterOp.same_team(local, peer): continue
		var actor = mp.NetworkBridge.get_peer_actor(peer)
		if not is_instance_valid(actor) or actor.get("death") == true: continue
		peers.append(peer)
	peers.sort()
	return peers

func _process(_delta):
	var death = _death_screen()
	if is_instance_valid(death) and not is_instance_valid(button):
		button = Button.new()
		button.name = "Spectate"
		button.text = "Spectate"
		button.theme = load("res://Menu/menu_theme.tres")
		button.add_font_override("font", _font(26))
		button.anchor_left = 0.5
		button.anchor_right = 0.5
		button.anchor_top = 0.82
		button.anchor_bottom = 0.82
		button.margin_left = -140
		button.margin_right = 140
		button.margin_bottom = 54
		button.connect("pressed", self, "start")
		death.add_child(button)
	var allowed = _dead_in_mission() and mp.hostSettings.get("spectating", true)
	if is_instance_valid(button):
		button.visible = allowed and not active
		button.disabled = candidates().empty() if allowed else true
		button.hint_tooltip = "No living players available to spectate." if button.disabled else "Spectate a living player."
	if allowed and not active and is_instance_valid(death) and death.visible and not mp.Menu.visible and not Global.menu.online_pause_settings:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not active: return
	if not allowed or Global.current_scene != watched_scene:
		stop()
		return
	var peers = candidates()
	if not peers.has(target):
		if peers.empty():
			stop()
			return
		_choose(peers[0])
	# Death UI can be raised by a delayed death packet; keep it out of the view.
	if is_instance_valid(death): death.hide()
	caption.text = "Spectating: " + str(mp.players[target].get("nickname", "Player")) + "\nStrafe: previous / next   Scroll: zoom   Esc: return"
	caption.rect_size = Vector2(1000, 60)
	overlay.rect_scale = Vector2(get_viewport().size) / Vector2(1280, 720)
	caption.rect_position = Vector2(140, 630)

func start():
	if active or not _dead_in_mission() or not mp.hostSettings.get("spectating", true): return
	var peers = candidates()
	if peers.empty(): return
	active = true
	Global.player.shader_screen.material.set_shader_param("hit_red", 0.0)
	watched_scene = Global.current_scene
	previous_input = Global.player.is_processing_input()
	previous_key_input = Global.player.is_processing_unhandled_key_input()
	Global.player.set_process_input(false)
	Global.player.set_process_unhandled_key_input(false)
	_death_screen().hide()
	_choose(peers[0])
	camera.fov = Global.FOV
	camera.current = true
	overlay.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_physics_process(0.0)

func _choose(peer):
	target = peer
	arm.clear_excluded_objects()
	_exclude(Global.player)
	var actor = mp.NetworkBridge.get_peer_actor(peer)
	_exclude(actor)
	yaw = actor.rotation.y + PI
	pitch = -0.15

func _exclude(node):
	if not is_instance_valid(node): return
	if node is CollisionObject: arm.add_excluded_object(node.get_rid())
	for child in node.get_children(): _exclude(child)

func cycle(step):
	var peers = candidates()
	if peers.empty():
		stop()
		return
	var index = peers.find(target)
	_choose(peers[posmod(index + step, peers.size())])

func _physics_process(_delta):
	if not active: return
	var actor = mp.NetworkBridge.get_peer_actor(target)
	if not is_instance_valid(actor): return
	var height = 1.4
	if actor.get("implant_state") is Dictionary:
		if actor.implant_state.get("golem_exosystem", false): height = 2.0
		if actor.implant_state.get("shrink", false): height *= 0.1
		if actor.get("playerCrouch") == true: height *= 0.65
	pivot.global_transform = Transform(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), actor.global_transform.origin + Vector3.UP * height)
	arm.spring_length = distance

func _input(event):
	if not active or mp.Menu.visible or mp.Menu.quick_chat_active or Global.menu.online_pause_settings: return
	if event.is_action_pressed("ui_cancel"):
		stop()
	elif event.is_action_pressed("movement_left") and not event.is_echo():
		cycle(-1)
	elif event.is_action_pressed("movement_right") and not event.is_echo():
		cycle(1)
	elif event is InputEventMouseMotion:
		yaw -= event.relative.x * 0.003
		pitch = clamp(pitch - event.relative.y * 0.003, -1.2, 1.1)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN]:
		distance = clamp(distance + (-0.5 if event.button_index == BUTTON_WHEEL_UP else 0.5), 1.2, 8.0)
	else:
		return
	get_tree().set_input_as_handled()

func stop():
	if not active: return
	active = false
	target = 0
	watched_scene = null
	camera.current = false
	overlay.hide()
	if is_instance_valid(Global.player):
		Global.player.player_view.current = true
		Global.player.set_process_input(previous_input)
		Global.player.set_process_unhandled_key_input(previous_key_input)
	var death = _death_screen()
	if is_instance_valid(death) and _dead_in_mission():
		death.show()
	var show_cursor = _dead_in_mission() or mp.Flow.result_active or not is_instance_valid(Global.menu) or not Global.menu.in_game or mp.Menu.visible or Global.menu.online_pause_settings
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if show_cursor else Input.MOUSE_MODE_CAPTURED)
