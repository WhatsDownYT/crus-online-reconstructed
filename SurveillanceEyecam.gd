extends Control

const NORMAL = "Surveillance Eyecam"
const PRO = "Surveillance Eyecam PRO MAX"
const SCAN_SOUND = preload("res://Sfx/superchimp.wav")
const EXPAND_TIME = 0.5
const CHARGE_TIME = 3.0
const COOLDOWN_TIME = 30.0
const ENTRY_COOLDOWN_TIME = 10.0
const RECT_PADDING = 3.0
const DATABASE_TIME = 5.0

var mp
var bridge
var acquired = {}
var rectangles = []
var target = 0
var elapsed = 0.0
var contracting = false
var cooldown = 0.0
var entry_pending = true
var locked_camera = null
var sounds = {}
var finished_sounds = {}
var host_scans = {}
var host_cooldowns = {}
var mission = null
var mesh_geometry = {}
var scan_data = {}
var analyzed = {}
var readouts = {}
var data_elapsed = 0.0

func _ready():
	mp = Global.get_node("Multiplayer")
	bridge = mp.NetworkBridge
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	bridge.register_rpcs(self, [["sync_scan_data", bridge.PERMISSION.ALL], ["request_scan", bridge.PERMISSION.ALL], ["sync_sound", bridge.PERMISSION.SERVER]])
	process_priority = 100

func is_camera_locked():
	return target != 0 and not contracting and _available() and Global.implants.head_implant.i_name == PRO

func _available():
	return bridge.check_connection() and mp.player_scene_loaded and is_instance_valid(Global.menu) and Global.menu.in_game and is_instance_valid(Global.player) and Global.player.is_inside_tree() and not Global.player.dead and not mp.Flow.result_active and not mp.Flow.waiting_peers.has(bridge.get_id())

func _process(delta):
	if mission != Global.current_scene:
		reset()
		mission = Global.current_scene
	_sync_local_data(delta)
	for peer in readouts:
		readouts[peer].conceal()
	_update_sounds(delta)
	if bridge.is_world_authority():
		_update_host_scans(delta)
	rectangles.clear()
	if not _available():
		_cancel_local()
		update()
		return
	if entry_pending:
		cooldown = ENTRY_COOLDOWN_TIME
		entry_pending = false
	else:
		cooldown = max(0.0, cooldown - delta)
	var mode = Global.implants.head_implant.i_name
	var camera = Global.player.player_view
	if mode == NORMAL:
		_cancel_lock()
		_update_normal(camera, delta)
	elif mode == PRO:
		acquired.clear()
		_update_pro(camera, delta)
	else:
		_cancel_local()
	update()

func _eligible(peer, distance):
	if peer == bridge.get_id() or mp.Flow.waiting_peers.has(peer):
		return false
	var actor = bridge.get_peer_actor(peer)
	return is_instance_valid(actor) and Global.player.global_transform.origin.distance_to(actor.global_transform.origin) <= distance

func _center(peer):
	var avatar = mp.players[peer].get("puppet")
	if is_instance_valid(avatar):
		return avatar.global_transform.origin + Vector3.UP * (0.65 if avatar.playerCrouch else 1.0)
	return bridge.get_peer_actor(peer).global_transform.origin + Vector3.UP

func _visible(camera, peer):
	var center = _center(peer)
	if camera.is_position_behind(center):
		return false
	var exclusions = [Global.player.get_rid()]
	var avatar = mp.players[peer].get("puppet")
	if is_instance_valid(avatar):
		_collect_rids(avatar, exclusions)
	return Global.player.get_world().direct_space_state.intersect_ray(camera.global_transform.origin, center, exclusions, 1).empty()

func _collect_rids(node, result):
	if node is CollisionObject:
		result.append(node.get_rid())
	for child in node.get_children():
		_collect_rids(child, result)

func _geometry(mesh):
	var key = mesh.get_instance_id()
	if not mesh_geometry.has(key):
		var surfaces = []
		for surface in range(mesh.get_surface_count()):
			var arrays = mesh.surface_get_arrays(surface)
			if not arrays.empty():
				surfaces.append(arrays)
		mesh_geometry[key] = surfaces
	return mesh_geometry[key]

func _bounds(camera, peer):
	var avatar = mp.players[peer].get("puppet")
	if not is_instance_valid(avatar):
		return Rect2()
	var skeleton = avatar.get_node("Puppet/PlayerModel/Armature/Skeleton")
	var bounds = Rect2()
	var found = false
	for path in ["Head_Mesh", "Torso_Mesh", "Head/glasses"]:
		var instance = skeleton.get_node(path)
		if not instance.is_visible_in_tree() or instance.mesh == null:
			continue
		var poses = []
		if instance.skin != null:
			for bind in range(instance.skin.get_bind_count()):
				var bone = instance.skin.get_bind_bone(bind)
				if bone < 0:
					bone = skeleton.find_bone(instance.skin.get_bind_name(bind))
				poses.append(skeleton.get_bone_global_pose(bone) * instance.skin.get_bind_pose(bind) if bone >= 0 else Transform())
		for arrays in _geometry(instance.mesh):
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			var skinned = not poses.empty() and bones != null and weights != null and bones.size() == vertices.size() * 4 and weights.size() == bones.size()
			for index in range(vertices.size()):
				var world
				if skinned:
					var posed = Vector3.ZERO
					for influence in range(4):
						var offset = index * 4 + influence
						if weights[offset] > 0 and bones[offset] >= 0 and bones[offset] < poses.size():
							posed += poses[bones[offset]].xform(vertices[index]) * weights[offset]
					world = skeleton.global_transform.xform(posed)
				else:
					world = instance.global_transform.xform(vertices[index])
				if camera.is_position_behind(world):
					continue
				var point = camera.unproject_position(world)
				if not found:
					bounds = Rect2(point, Vector2.ZERO)
					found = true
				else:
					bounds = bounds.expand(point)
	return bounds.grow(RECT_PADDING) if found else Rect2()

func _on_screen(bounds):
	return bounds.size.x > 0 and bounds.size.y > 0 and Rect2(Vector2.ZERO, get_viewport_rect().size).intersects(bounds)

func _animated_rect(bounds, amount):
	var scale_amount = max(0.005, floor(clamp(amount, 0.0, 1.0) * 5.0 + 0.0001) / 5.0)
	var size = bounds.size * scale_amount
	return Rect2(bounds.position + (bounds.size - size) * 0.5, size)

func _update_normal(camera, delta):
	var present = []
	for peer in mp.players:
		if not _eligible(peer, 25.0):
			continue
		var bounds = _bounds(camera, peer)
		if not _on_screen(bounds) or not _visible(camera, peer):
			continue
		present.append(peer)
		acquired[peer] = min(DATABASE_TIME, float(acquired.get(peer, 0.0)) + delta)
		if acquired[peer] >= DATABASE_TIME:
			analyzed[peer] = true
		_show_readout(peer, bounds, analyzed.has(peer), false, delta)
		rectangles.append([_animated_rect(bounds, acquired[peer] / EXPAND_TIME), Color(0, 1, 0)])
	for peer in acquired.keys():
		if not present.has(peer):
			acquired.erase(peer)
			if readouts.has(peer):
				readouts[peer].typing = 0.0
				readouts[peer].details_typing = 0.0

func _closest():
	var closest = 0
	var distance = 10.001
	for peer in mp.players:
		if not _eligible(peer, 10.0):
			continue
		var next_distance = Global.player.global_transform.origin.distance_to(bridge.get_peer_actor(peer).global_transform.origin)
		if next_distance < distance:
			distance = next_distance
			closest = peer
	return closest

func _update_pro(camera, delta):
	if target == 0 and cooldown <= 0:
		target = _closest()
		if target != 0:
			elapsed = 0.0
			contracting = false
			locked_camera = camera
			if readouts.has(target):
				readouts[target].typing = 0.0
			bridge.request_host(self, "request_scan", [target])
	if target == 0:
		return
	if not mp.players.has(target) or mp.Flow.waiting_peers.has(target) or not is_instance_valid(bridge.get_peer_actor(target)):
		_cancel_lock()
		return
	if not contracting:
		_lock_camera(camera, _center(target))
	elapsed += delta
	if not contracting and elapsed >= CHARGE_TIME:
		contracting = true
		elapsed = 0.0
		_restore_camera()
	var bounds = _bounds(camera, target)
	var progress = 1.0 - elapsed / EXPAND_TIME if contracting else elapsed / EXPAND_TIME
	if _on_screen(bounds) and not contracting:
		_show_readout(target, bounds, false, true, delta)
	if _on_screen(bounds) and Engine.get_idle_frames() % 2 == 0:
		rectangles.append([_animated_rect(bounds, progress), Color(1, 0, 0)])
	if contracting and elapsed >= EXPAND_TIME:
		target = 0
		contracting = false
		cooldown = COOLDOWN_TIME

func _aim_player(direction):
	var player = Global.player
	var local_direction = player.get_parent().global_transform.basis.orthonormalized().xform_inv(direction)
	player.rotation.y = atan2(local_direction.x, local_direction.z)
	if player.interpolated_camera:
		player.rotation_helper.get_parent().rotation.y = player.rotation.y
	player.rotation_helper.rotation = Vector3(-asin(clamp(direction.y, -1.0, 1.0)), 0, 0)
	player.player_view.transform.basis = Basis(Vector3.UP, PI)

func _lock_camera(camera, point):
	_aim_player((point - camera.global_transform.origin).normalized())
	camera.look_at(point, Vector3.UP)

func _restore_camera():
	if is_instance_valid(locked_camera) and is_instance_valid(Global.player) and Global.player.player_view == locked_camera:
		_aim_player(-locked_camera.global_transform.basis.z.normalized())
	locked_camera = null

func _cancel_lock():
	if target != 0:
		cooldown = COOLDOWN_TIME
		_apply_sound(bridge.get_id(), target, 2, Vector3.ZERO)
	_restore_camera()
	target = 0
	contracting = false
	elapsed = 0.0

func _cancel_local():
	_cancel_lock()
	acquired.clear()

func _draw():
	var debug_capture = Global.get_node_or_null("DebugCapture")
	if is_instance_valid(debug_capture) and debug_capture.ui_hidden:
		return
	for rectangle in rectangles:
		draw_rect(rectangle[0], rectangle[1], false, 1.0)

remote func request_scan(id, peer):
	if not bridge.is_world_authority() or typeof(peer) != TYPE_INT:
		return
	var source = bridge.request_sender(id)
	if not mp.players.has(source) or not mp.players.has(peer) or source == peer or host_scans.has(source) or host_cooldowns.has(source) or mp.Flow.result_active:
		return
	var has_pro = mp.peer_has_implant_flag(source, "eyecam_pro")
	var actor = bridge.get_peer_actor(source)
	var other = bridge.get_peer_actor(peer)
	if not has_pro or not is_instance_valid(actor) or not is_instance_valid(other) or mp.Flow.waiting_peers.has(source) or mp.Flow.waiting_peers.has(peer) or actor.global_transform.origin.distance_to(other.global_transform.origin) > 10.5:
		return
	host_scans[source] = {"target": peer, "time": CHARGE_TIME}
	host_cooldowns[source] = CHARGE_TIME + EXPAND_TIME + COOLDOWN_TIME
	var position = _center(peer)
	_apply_sound(source, peer, 0, position)
	bridge.n_rpc(self, "sync_sound", [source, peer, 0, position])

func _update_host_scans(delta):
	for peer in host_cooldowns.keys():
		host_cooldowns[peer] -= delta
		if host_cooldowns[peer] <= 0:
			host_cooldowns.erase(peer)
	for source in host_scans.keys():
		var scan = host_scans[source]
		scan.time -= delta
		var actor = bridge.get_peer_actor(source)
		var other = bridge.get_peer_actor(scan.target)
		var valid = bridge.check_connection() and mp.player_scene_loaded and not mp.Flow.result_active and is_instance_valid(actor) and is_instance_valid(other) and not mp.Flow.waiting_peers.has(source) and not mp.Flow.waiting_peers.has(scan.target)
		if valid:
			var has_pro = mp.peer_has_implant_flag(source, "eyecam_pro")
			valid = valid and has_pro
		if scan.time <= 0 or not valid:
			var position = other.global_transform.origin + Vector3.UP if is_instance_valid(other) else Vector3.ZERO
			var phase = 1 if valid else 2
			_apply_sound(source, scan.target, phase, position)
			bridge.n_rpc(self, "sync_sound", [source, scan.target, phase, position])
			host_scans.erase(source)

puppet func sync_sound(_id, source, peer, phase, position):
	if bridge.request_sender(_id) != bridge.get_host_id():
		return
	_apply_sound(source, peer, phase, position)

func _apply_sound(source, peer, phase, position):
	if phase != 0:
		return
	if sounds.has(source):
		_stop_sound(source)
	var sound = AudioStreamPlayer3D.new()
	mp.add_child(sound)
	sound.global_transform.origin = position
	sound.unit_size = 19.0
	sound.max_distance = 100.0
	sound.stream = SCAN_SOUND
	sound.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	sound.play()
	sounds[source] = {"node": sound, "target": peer}

func _stop_sound(source):
	var sound = sounds[source].node
	if is_instance_valid(sound):
		sound.stop()
		sound.queue_free()
	sounds.erase(source)

func _update_sounds(_delta):
	for source in sounds.keys():
		var sound = sounds[source]
		if not is_instance_valid(sound.node) or not sound.node.playing or not bridge.check_connection() or not mp.player_scene_loaded or mp.Flow.result_active:
			_stop_sound(source)
			continue
		var actor = bridge.get_peer_actor(sound.target)
		if is_instance_valid(actor):
			sound.node.global_transform.origin = actor.global_transform.origin + Vector3.UP

func reset():
	_cancel_local()
	cooldown = 0.0
	entry_pending = true
	rectangles.clear()
	for source in sounds.keys():
		_stop_sound(source)
	host_scans.clear()
	host_cooldowns.clear()
	finished_sounds.clear()
	scan_data.clear()
	analyzed.clear()
	for peer in readouts:
		readouts[peer].queue_free()
	readouts.clear()
	data_elapsed = 0.0

func _show_readout(peer, bounds, ready, hijack, delta):
	if not readouts.has(peer):
		var panel = preload("res://MOD_CONTENT/CruS Online/EyecamReadout.gd").new()
		add_child(panel)
		readouts[peer] = panel
	readouts[peer].display(bounds, scan_data.get(peer, {}), ready, hijack, delta)

func _sync_local_data(delta):
	if not bridge.check_connection() or not mp.player_scene_loaded or not is_instance_valid(Global.player) or not is_instance_valid(Global.player.get("weapon")):
		return
	data_elapsed += delta
	if data_elapsed < 0.25: return
	data_elapsed = 0.0
	var implants = Global.implants
	var data = {"money": Global.money, "health": Global.player.health, "death_mode": Global.death, "implants": [implants.head_implant.i_name, implants.torso_implant.i_name, implants.arm_implant.i_name, implants.leg_implant.i_name], "weapons": [Global.player.weapon.weapon1, Global.player.weapon.weapon2]}
	scan_data[bridge.get_id()] = data
	bridge.n_rpc_unreliable(self, "sync_scan_data", [data])

remote func sync_scan_data(id, data):
	var peer = bridge.request_sender(id)
	if not mp.players.has(peer) or not data is Dictionary or data.size() != 5:
		return
	if not data.get("implants") is Array or data.implants.size() != 4 or not data.get("weapons") is Array or data.weapons.size() != 2:
		return
	if not typeof(data.get("money")) in [TYPE_INT, TYPE_REAL] or not typeof(data.get("health")) in [TYPE_INT, TYPE_REAL] or typeof(data.get("death_mode")) != TYPE_BOOL:
		return
	for weapon_id in data.weapons:
		if weapon_id != null and (typeof(weapon_id) != TYPE_INT or weapon_id < 0 or weapon_id > 28): return
	for label in data.implants:
		if not label is String or label.length() > 128: return
	scan_data[peer] = data.duplicate(true)
