extends Spatial

const NAME = "Pneumatic Merit Pump"
const CASH_SOUND = preload("res://Sfx/slots.wav")
const OVERLOAD_SOUND = preload("res://Sfx/Environment/sunscream.mp3")
const MONEY = preload("res://Entities/Physics_Objects/Money.tscn")
const PICKUP = preload("res://MOD_CONTENT/CruS Online/MeritPumpPickup.gd")
const MONEY_BODY = preload("res://MOD_CONTENT/CruS Online/MeritPumpMoney.gd")
var mp
var bridge
var mission
var epoch = 0
var active = false
var pending = false
var elapsed = 0.0
var amount = 0.0
var balance = 0.0
var sessions = {}
var drops = {}
var sounds = {}
var sequence = 0
var tick = 0.0
var pose_offset = 0
var state_requested = false
var counter
var cash_voices = {}
var cash_counts = {}
var cash_cursor = {}

func _ready():
	mp = get_parent()
	bridge = mp.NetworkBridge
	bridge.register_rpcs(self, [["request_begin", bridge.PERMISSION.ALL], ["request_finish", bridge.PERMISSION.ALL], ["request_cancel", bridge.PERMISSION.ALL], ["request_collect", bridge.PERMISSION.ALL], ["request_state", bridge.PERMISSION.ALL], ["sync_cash", bridge.PERMISSION.SERVER], ["sync_sound", bridge.PERMISSION.SERVER], ["sync_drop", bridge.PERMISSION.SERVER], ["sync_remove", bridge.PERMISSION.SERVER], ["sync_payment", bridge.PERMISSION.SERVER], ["sync_bribe", bridge.PERMISSION.SERVER], ["sync_bribe_dialogue", bridge.PERMISSION.SERVER], ["sync_positions", bridge.PERMISSION.SERVER]])
	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	counter = Label.new()
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.align = Label.ALIGN_CENTER
	counter.add_color_override("font_color", Color.white)
	var background = StyleBoxFlat.new()
	background.bg_color = Color.black
	background.content_margin_left = 10
	background.content_margin_right = 10
	background.content_margin_top = 6
	background.content_margin_bottom = 6
	counter.add_stylebox_override("normal", background)
	var font = load("res://Fonts/mingliut.tres").duplicate()
	font.size = 64
	font.outline_size = 0
	counter.add_font_override("font", font)
	layer.add_child(counter)
	counter.hide()

func growth(seconds):
	return 10.0 * (exp(min(seconds, 45.0) * 0.8) - 1.0)

func _available():
	return bridge.check_connection() and mp.player_scene_loaded and is_instance_valid(Global.current_scene) and is_instance_valid(Global.player) and is_instance_valid(Global.menu) and Global.menu.in_game and not Global.player.dead and not Global.player.died and not mp.Flow.result_active and not mp.Flow.waiting_peers.has(bridge.get_id()) and Global.implants.arm_implant.i_name == NAME and not Global.implants.arm_implant.jammed

func _process(delta):
	if mission != Global.current_scene or epoch != mp.SteamNetwork.scene_epoch or not bridge.check_connection():
		reset()
		mission = Global.current_scene
		epoch = mp.SteamNetwork.scene_epoch
	if not state_requested and bridge.check_connection() and mp.player_scene_loaded and is_instance_valid(Global.player) and is_instance_valid(Global.menu) and Global.menu.in_game:
		state_requested = true
		bridge.request_host(self, "request_state", [epoch])
	if not _available() or mp.Menu.visible or Global.menu.visible:
		if active:
			bridge.request_host(self, "request_cancel")
		active = false
		pending = false
		counter.hide()
	elif Input.is_action_just_pressed("Tertiary_Weapon") and not pending:
		begin()
	elif active:
		elapsed += delta
		balance = max(0.0, float(Global.money))
		amount = growth(elapsed)
		counter.text = "$" + str(int(amount))
		_cash_tick(bridge.get_id(), int(amount))
		var size = get_viewport().size
		var font = counter.get_font("font")
		font.size = max(1, int(64 * size.y / 720.0))
		counter.rect_size = font.get_string_size(counter.text) + Vector2(20, 12)
		counter.rect_position = Vector2((size.x - counter.rect_size.x) * 0.5, size.y * 0.77)
		var capture = Global.get_node_or_null("DebugCapture")
		counter.visible = not (is_instance_valid(capture) and capture.ui_hidden)
		if amount >= max(balance, 1.0) * 2.0 or Input.is_action_just_released("Tertiary_Weapon"):
			finish()
	tick += delta
	if tick >= 0.2:
		tick = 0.0
		if bridge.is_world_authority():
			_update_sessions()
			_check_bribes()
			var poses = []
			var identifiers = drops.keys()
			for index in range(min(10, identifiers.size())):
				var identifier = identifiers[(pose_offset + index) % identifiers.size()]
				if is_instance_valid(drops[identifier]): poses.append([identifier, drops[identifier].global_transform])
			pose_offset += 10
			if not poses.empty(): bridge.n_rpc_unreliable(self, "sync_positions", [epoch, poses])
	for peer in sounds.keys():
		var actor = bridge.get_peer_actor(peer)
		if not is_instance_valid(actor):
			sounds[peer].queue_free()
			sounds.erase(peer)
		else:
			sounds[peer].global_transform.origin = actor.global_transform.origin

func begin():
	if not _available(): return
	active = true
	elapsed = 0.0
	amount = 0.0
	cash_counts[bridge.get_id()] = 0
	balance = max(0.0, float(Global.money))
	bridge.request_host(self, "request_begin", [balance])

func finish():
	if not active: return
	active = false
	pending = true
	counter.hide()
	bridge.request_host(self, "request_finish", [amount])

func reset():
	state_requested = false
	active = false
	pending = false
	amount = 0.0
	sessions.clear()
	for drop in drops.values():
		if is_instance_valid(drop): drop.queue_free()
	drops.clear()
	for sound in sounds.values():
		if is_instance_valid(sound): sound.queue_free()
	sounds.clear()
	for voices in cash_voices.values():
		for voice in voices:
			if is_instance_valid(voice): voice.queue_free()
	cash_voices.clear()
	cash_counts.clear()
	cash_cursor.clear()
	if is_instance_valid(counter): counter.hide()

func _equipped(peer):
	if peer == bridge.get_id():
		return _available()
	var actor = bridge.get_peer_actor(peer)
	return is_instance_valid(actor) and actor.implant_state.get("merit_pump", false) and not mp.Flow.waiting_peers.has(peer)

master func request_state(sender, event_epoch):
	var peer = bridge.request_sender(sender)
	if not bridge.is_world_authority() or peer == bridge.get_id() or event_epoch != epoch or not mp.players.has(peer): return
	for identifier in drops:
		var drop = drops[identifier]
		if is_instance_valid(drop): bridge.n_rpc_id(self, peer, "sync_drop", [epoch, identifier, drop.get_node("Area").value, drop.global_transform.origin, drop.get_node("Area").owner_peer, drop.velocity])
	for npc in get_tree().get_nodes_in_group("merit_bribable_npcs"):
		if npc.has_meta("merit_bribed"): bridge.n_rpc_id(self, peer, "sync_bribe", [epoch, npc.get_path()])

master func request_begin(sender, capital):
	var peer = bridge.request_sender(sender)
	if not bridge.is_world_authority() or not _equipped(peer) or sessions.has(peer) or not is_instance_valid(bridge.get_peer_actor(peer)) or not typeof(capital) in [TYPE_INT, TYPE_REAL] or is_nan(capital) or is_inf(capital) or capital < 0 or capital > 1e15: return
	sessions[peer] = {"started": OS.get_ticks_msec(), "balance": float(capital), "dollars": 0}
	_publish("sync_cash", [peer, 0])

master func request_cancel(sender):
	var peer = bridge.request_sender(sender)
	if not bridge.is_world_authority(): return
	sessions.erase(peer)
	_publish("sync_sound", [peer, -2.0])

master func request_finish(sender, requested):
	var peer = bridge.request_sender(sender)
	if not bridge.is_world_authority() or not sessions.has(peer) or not typeof(requested) in [TYPE_INT, TYPE_REAL] or is_nan(requested) or is_inf(requested) or requested < 0: return
	var session = sessions[peer]
	var seconds = (OS.get_ticks_msec() - session.started) / 1000.0
	var payable = min(float(requested), growth(seconds + 0.35))
	_complete(peer, payable)

func _complete(peer, payable):
	if not sessions.has(peer): return
	var capital = _capital(peer)
	sessions.erase(peer)
	_publish("sync_sound", [peer, -2.0])
	var actor = bridge.get_peer_actor(peer)
	if not is_instance_valid(actor): return
	var overload = payable >= max(capital, 1.0) * 2.0
	var value = int(payable)
	if peer == bridge.get_id():
		sync_payment(null, epoch, value, overload)
	else:
		bridge.n_rpc_id(self, peer, "sync_payment", [epoch, value, overload])
	var dropped = min(value, int(capital))
	if overload or dropped <= 0: return
	sequence += 1
	var forward = actor.global_transform.basis.z.normalized()
	var position = actor.global_transform.origin + forward + Vector3.UP * 0.3
	_publish("sync_drop", [epoch, sequence, dropped, position, peer, forward * 4.0 + Vector3.UP * 1.5])

func _update_sessions():
	for peer in sessions.keys():
		var actor = bridge.get_peer_actor(peer)
		if not is_instance_valid(actor) or mp.Flow.result_active or not _equipped(peer):
			request_cancel(peer)
			continue
		var capital = _capital(peer)
		var current = growth((OS.get_ticks_msec() - sessions[peer].started) / 1000.0)
		if int(current) > sessions[peer].dollars:
			sessions[peer].dollars = int(current)
			_publish("sync_cash", [peer, int(current)])
		if current >= max(capital, 1.0) * 2.0:
			_complete(peer, current)
		elif current >= capital:
			_publish("sync_sound", [peer, clamp((current - capital) / max(capital, 1.0), 0.0, 1.0) * 1.2])

func _publish(method, args):
	var local = args.duplicate()
	local.push_front(null)
	callv(method, local)
	bridge.n_rpc(self, method, args)

func _capital(peer):
	return max(0.0, float(Global.money if peer == bridge.get_id() else mp.Eyecam.scan_data.get(peer, {}).get("money", sessions[peer].balance)))

puppet func sync_payment(_sender, event_epoch, value, overload):
	if event_epoch != epoch or typeof(value) != TYPE_INT or value < 0 or typeof(overload) != TYPE_BOOL: return
	active = false
	pending = false
	counter.hide()
	if overload:
		if is_instance_valid(Global.player) and not Global.player.dead: Global.player.instadie()
	else:
		Global.money -= value
		Global.save_game()

puppet func sync_sound(_sender, peer, pitch):
	if typeof(peer) != TYPE_INT or not typeof(pitch) in [TYPE_INT, TYPE_REAL]: return
	var actor = bridge.get_peer_actor(peer)
	if not is_instance_valid(actor): return
	if pitch == -2.0:
		if sounds.has(peer):
			sounds[peer].queue_free()
			sounds.erase(peer)
		return
	if pitch < 0 or pitch > 1.2: return
	if not sounds.has(peer):
		var sound = AudioStreamPlayer3D.new()
		sound.stream = OVERLOAD_SOUND
		sound.bus = "SFX"
		sound.unit_size = 19.0
		sound.max_distance = 100.0
		add_child(sound)
		sounds[peer] = sound
		sound.connect("finished", sound, "play")
		sound.pitch_scale = max(0.01, pitch)
		sound.play()
	sounds[peer].global_transform.origin = actor.global_transform.origin
	sounds[peer].pitch_scale = max(0.01, pitch)

func _cash_tick(peer, total):
	var previous = int(cash_counts.get(peer, 0))
	cash_counts[peer] = total
	if total <= previous: return
	var actor = bridge.get_peer_actor(peer)
	if not is_instance_valid(actor): return
	if not cash_voices.has(peer):
		var voices = []
		for index in range(8):
			var voice = AudioStreamPlayer3D.new()
			voice.stream = CASH_SOUND
			voice.bus = "SFX"
			voice.unit_db = -12
			add_child(voice)
			voices.append(voice)
		cash_voices[peer] = voices
		cash_cursor[peer] = 0
	for index in range(min(total - previous, 8)):
		var voice = cash_voices[peer][cash_cursor[peer] % 8]
		cash_cursor[peer] += 1
		voice.global_transform.origin = actor.global_transform.origin
		voice.play()

puppet func sync_cash(_sender, peer, total):
	if typeof(peer) != TYPE_INT or typeof(total) != TYPE_INT or total < 0 or peer == bridge.get_id(): return
	_cash_tick(peer, total)

puppet func sync_drop(_sender, event_epoch, identifier, value, position, owner_peer, launch = Vector3.ZERO):
	if event_epoch != epoch or typeof(identifier) != TYPE_INT or typeof(value) != TYPE_INT or value <= 0 or typeof(position) != TYPE_VECTOR3 or drops.has(identifier): return
	var drop = MONEY.instance()
	drop.set_script(MONEY_BODY)
	drop.controller = self
	drop.name = "MeritPumpMoney#" + str(identifier)
	var area = drop.get_node("Area")
	area.set_script(PICKUP)
	area.controller = self
	area.identifier = identifier
	area.value = value
	area.owner_peer = owner_peer
	area.set_collision_layer_bit(8, owner_peer != bridge.get_id())
	drop.set_network_master(bridge.get_host_id())
	Global.current_scene.add_child(drop)
	drop.global_transform.origin = position
	drop.target_pose = drop.global_transform
	drop.velocity = launch
	drops[identifier] = drop

puppet func sync_positions(_sender, event_epoch, poses):
	if event_epoch != epoch or typeof(poses) != TYPE_ARRAY: return
	for pose in poses:
		if typeof(pose) != TYPE_ARRAY or pose.size() != 2 or typeof(pose[1]) != TYPE_TRANSFORM: continue
		var drop = drops.get(pose[0])
		if is_instance_valid(drop): drop.target_pose = pose[1]

master func request_collect(sender, identifier):
	var peer = bridge.request_sender(sender)
	if not bridge.is_world_authority() or not drops.has(identifier): return
	var actor = bridge.get_peer_actor(peer)
	var drop = drops[identifier]
	if is_instance_valid(drop) and drop.get_node("Area").owner_peer == peer: return
	if not is_instance_valid(actor) or not is_instance_valid(drop) or actor.global_transform.origin.distance_to(drop.global_transform.origin) > 4.0: return
	var value = drop.get_node("Area").value
	_publish("sync_remove", [epoch, identifier, peer, value])

puppet func sync_remove(_sender, event_epoch, identifier, recipient, value):
	if event_epoch != epoch or not drops.has(identifier): return
	var drop = drops[identifier]
	drops.erase(identifier)
	if is_instance_valid(drop): drop.queue_free()
	if recipient == bridge.get_id():
		Global.money += value
		Global.player.UI.notify("$" + str(value) + " picked up", Color(1, 1, 0))
		Global.save_game()

func _check_bribes():
	if drops.empty(): return
	var npcs = get_tree().get_nodes_in_group("merit_bribable_npcs")
	for identifier in drops.keys():
		var drop = drops[identifier]
		if not is_instance_valid(drop):
			drops.erase(identifier)
			continue
		for npc in npcs:
			if npc.dead or npc.civilian or npc.has_meta("merit_bribed") or not is_instance_valid(npc.body): continue
			if npc.body.global_transform.origin.distance_to(drop.global_transform.origin) <= 1.5:
				var ray = get_world().direct_space_state.intersect_ray(drop.global_transform.origin + Vector3.UP * 0.1, npc.body.global_transform.origin + Vector3.UP * 0.5, [drop, npc.body], 1)
				if not ray.empty(): continue
				var area = drop.get_node("Area")
				if npc.creature and bribe_range(npc) == Vector2.ZERO:
					_publish("sync_bribe", [epoch, npc.get_path()])
				else:
					if not npc.has_meta("merit_bribe_required"):
						var price_range = bribe_range(npc)
						npc.set_meta("merit_bribe_required", int(price_range.x) + randi() % (int(price_range.y - price_range.x) + 1))
					var required = int(npc.get_meta("merit_bribe_required"))
					var enough = area.value >= required
					if enough: _publish("sync_bribe", [epoch, npc.get_path()])
					var message = "You're free to go." if enough else "Bring me $" + str(required) + " and then we'll talk. Otherwise your life means nothing to me."
					if area.owner_peer == bridge.get_id():
						sync_bribe_dialogue(null, epoch, message)
					elif mp.players.has(area.owner_peer):
						bridge.n_rpc_id(self, area.owner_peer, "sync_bribe_dialogue", [epoch, message])
				_publish("sync_remove", [epoch, identifier, 0, 0])
				break

puppet func sync_bribe_dialogue(_sender, event_epoch, message):
	if event_epoch != epoch or typeof(message) != TYPE_STRING or not is_instance_valid(Global.player): return
	Global.player.UI.message(message, true)

puppet func sync_bribe(_sender, event_epoch, path):
	if event_epoch != epoch or typeof(path) != TYPE_NODE_PATH: return
	var npc = get_node_or_null(path)
	if not is_instance_valid(npc) or not npc.is_in_group("merit_bribable_npcs") or npc.dead or npc.civilian: return
	npc.set_meta("merit_bribed", true)
	if npc.has_method("apply_merit_bribe"):
		npc.apply_merit_bribe()
		return
	npc.alerted = false
	npc.player_seen = false
	var body = npc.body
	for property in ["alerted", "player_spotted", "shoot_mode", "in_sight", "sight_potential"]:
		if property in body: body.set(property, false)
	if "muzzleflash" in body and is_instance_valid(body.muzzleflash): body.muzzleflash.hide()
	if "anim_player" in body and is_instance_valid(body.anim_player) and body.anim_player.has_animation("Idle"): body.anim_player.play("Idle")

func bribe_range(npc):
	var kind = (str(npc.filename) + " " + str(npc.name) + " " + str(npc.npc_name)).to_lower()
	if kind.find("abraxas") >= 0 or kind.find("boss_life") >= 0 or kind.find("lifeman") >= 0: return Vector2(2500, 10000)
	if kind.find("killerbot") >= 0 or kind.find("godbot") >= 0 or kind.find("necromech") >= 0: return Vector2(750, 2000)
	return Vector2.ZERO if npc.creature else Vector2(50, 500)
