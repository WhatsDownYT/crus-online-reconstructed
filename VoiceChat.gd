extends Node

const Codec = preload("res://MOD_CONTENT/CruS Online/VoiceCodec.gd")
const CHANNEL = 2
const HEADER = 26
const VERSION = 3
const STATE = 0
const AUDIO = 1
const TALK_ICON = preload("res://Textures/Menu/Civ_Mouth/2.png")
const QUIET_ICON = preload("res://Textures/Menu/Civ_Mouth/1.png")
onready var Multiplayer = get_parent()
onready var bridge = get_parent().get_node("NetworkBridge")
var settings = {"enabled": false, "volume": 100.0, "device": "Default", "push_to_talk": true, "binding": {"kind": "key", "code": KEY_V}}
var store = preload("res://MOD_CONTENT/CruS Online/ProfileStore.gd").new()
var peers = {}
var muted = {}
var sinks = {}
var microphone
var capture
var generation = 1
var sequence = 0
var last_talk = -1000
var voice_until = 0
var announce_elapsed = 0.0
var connected = false
var session_host = 0
var binding_active = false
var capture_error = ""
var test_capture = false
var sent_frames = 0
var received_frames = 0
var dropped_frames = 0
var played_frames = 0
var rate_limits = {}
var capture_retry = 0
var input_peak = 0.0
var peak_process_usec = 0
var capture_started = 0
var capture_initial_frames = 0
var muted_steam = []
var capture_pending = []
var capture_pairs = 1
var capture_blocks = 0
var capture_discarded = 0
var input_gate = false
var local_dead = false
var local_water = false
var voice_buses = {}

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	settings = store.merge_defaults(settings, store.load_data("voice.save"))
	settings.volume = clamp(float(settings.volume), 0, 200)
	_apply_binding()
	if AudioServer.get_bus_index("CruS Voice") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "CruS Voice")
	var saved = store.load_data("voice.save")
	if typeof(saved) == TYPE_DICTIONARY and typeof(saved.get("muted_steam")) == TYPE_ARRAY:
		muted_steam = saved.muted_steam

func save_settings():
	var data = settings.duplicate(true)
	data["muted_steam"] = muted_steam
	if not store.save_data("voice.save", data):
		capture_error = store.last_error

func change_setting(key, value):
	if not settings.has(key):
		return
	settings[key] = value
	settings.volume = clamp(float(settings.volume), 0, 200)
	if key in ["enabled", "device", "push_to_talk"]:
		_stop_capture()
		generation += 1
		last_talk = -1000
		voice_until = 0
		if connected:
			announce()
	if key == "binding":
		_apply_binding()
	save_settings()

func _apply_binding():
	if not InputMap.has_action("crus_voice_talk"):
		InputMap.add_action("crus_voice_talk")
	InputMap.action_erase_events("crus_voice_talk")
	var binding = settings.binding
	if typeof(binding) != TYPE_DICTIONARY or not binding.get("kind", "") in ["key", "mouse"] or not typeof(binding.get("code")) in [TYPE_INT, TYPE_REAL] or int(binding.code) <= 0:
		binding = {"kind": "key", "code": KEY_V}
		settings.binding = binding
	var event = InputEventKey.new() if binding.kind == "key" else InputEventMouseButton.new()
	if event is InputEventKey:
		event.scancode = int(binding.code)
	else:
		event.button_index = int(binding.code)
	InputMap.action_add_event("crus_voice_talk", event)

func binding_text():
	return OS.get_scancode_string(int(settings.binding.code)) if settings.binding.kind == "key" else "Mouse " + str(int(settings.binding.code))

func devices():
	return AudioServer.capture_get_device_list()

func reset_session():
	_stop_capture()
	_clear_sinks()
	for peer in voice_buses.keys():
		_remove_voice_bus(peer)
	peers.clear()
	muted.clear()
	rate_limits.clear()
	connected = false
	session_host = 0
	generation += 1
	sequence = 0
	last_talk = -1000
	voice_until = 0

func _process(delta):
	var process_start = OS.get_ticks_usec()
	var online = bridge.check_connection() and Multiplayer.players.has(bridge.get_id())
	if not online:
		if connected:
			reset_session()
		return
	if not connected or session_host != bridge.get_host_id():
		reset_session()
		connected = true
		session_host = bridge.get_host_id()
		announce_elapsed = 1.0
	var dead_now = is_instance_valid(Global.get("player")) and bool(Global.player.get("dead"))
	var water_now = is_instance_valid(Global.get("player")) and bool(Global.player.get("water"))
	if dead_now != local_dead or water_now != local_water:
		local_dead = dead_now
		local_water = water_now
		announce()
	announce_elapsed += delta
	if announce_elapsed >= 1.0:
		announce_elapsed = 0.0
		announce()
		for peer in peers.keys():
			if not Multiplayer.players.has(peer):
				peers.erase(peer)
				_drop_sink(peer)
				_remove_voice_bus(peer)
	if bridge.is_steam():
		_poll_steam()
	if settings.enabled and lobby_enabled() and not test_capture:
		if not is_instance_valid(microphone) and OS.get_ticks_msec() >= capture_retry:
			capture_retry = OS.get_ticks_msec() + 2000
			_start_capture()
		_capture_frames()
	if not lobby_enabled() and is_instance_valid(microphone):
		_stop_capture()
	_update_playback()
	peak_process_usec = max(peak_process_usec, OS.get_ticks_usec() - process_start)

func _start_capture():
	capture_error = ""
	var available = devices()
	if available.empty():
		capture_error = "No microphone detected"
		return
	if not available.has(settings.device):
		capture_error = "Selected microphone unavailable; using Default"
	AudioServer.capture_device = settings.device if available.has(settings.device) else "Default"
	ProjectSettings.set_setting("audio/enable_audio_input", true)
	var bus = AudioServer.get_bus_index("CruS Microphone")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "CruS Microphone")
		AudioServer.set_bus_mute(bus, true)
	_reset_capture_buffer(bus)
	microphone = AudioStreamPlayer.new()
	microphone.bus = "CruS Microphone"
	microphone.mix_target = AudioStreamPlayer.MIX_TARGET_STEREO
	microphone.stream = AudioStreamMicrophone.new()
	add_child(microphone)
	microphone.play()

func _reset_capture_buffer(bus):
	while AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.remove_bus_effect(bus, 0)
	capture_pairs = int(AudioServer.get_speaker_mode()) + 1
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.5 * capture_pairs
	capture_pending = []
	capture_discarded = 0
	AudioServer.add_bus_effect(bus, capture)
	capture_started = OS.get_ticks_msec()
	capture_initial_frames = capture.get_pushed_frames()

func _stop_capture():
	capture_retry = 0
	capture_error = ""
	input_peak = 0.0
	if is_instance_valid(microphone):
		microphone.stop()
		microphone.queue_free()
	microphone = null
	capture_pending = []
	var bus = AudioServer.get_bus_index("CruS Microphone")
	if bus >= 0:
		while AudioServer.get_bus_effect_count(bus) > 0:
			AudioServer.remove_bus_effect(bus, 0)
	capture = null

func _capture_frames():
	if not is_instance_valid(capture):
		return
	if not test_capture and is_instance_valid(microphone) and OS.get_ticks_msec() - capture_started > 3000 and capture.get_pushed_frames() == capture_initial_frames:
		capture_error = "No microphone audio. Check the input device and microphone access."
	elif capture_error == "No microphone audio. Check the input device and microphone access.":
		capture_error = ""
	var count = int(AudioServer.get_mix_rate() / 50.0)
	var discarded = capture.get_discarded_frames()
	if discarded > capture_discarded:
		dropped_frames += max(1, int((discarded - capture_discarded) / (count * capture_pairs)))
		_reset_capture_buffer(AudioServer.get_bus_index("CruS Microphone"))
		return
	if capture_pairs > 1:
		var group_size = 1024 * capture_pairs
		var groups = int(capture.get_frames_available() / group_size)
		for _group in range(groups):
			var group = capture.get_buffer(group_size)
			group.resize(1024)
			capture_pending.append_array(Array(group))
	else:
		var available = capture.get_frames_available()
		if available > 0:
			capture_pending.append_array(Array(capture.get_buffer(available)))
	if capture_pending.size() > count * 5:
		dropped_frames += int((capture_pending.size() - count * 2) / count)
		capture_pending = capture_pending.slice(capture_pending.size() - count * 2, capture_pending.size() - 1)
	var focus = get_viewport().gui_get_focus_owner()
	var typing = (focus is LineEdit or focus is TextEdit) and focus.is_visible_in_tree()
	var allowed = not binding_active and (not settings.push_to_talk or (Input.is_action_pressed("crus_voice_talk") and not typing))
	input_gate = allowed
	for _frame in range(4):
		if capture_pending.size() < count:
			break
		var source = capture_pending.slice(0, count - 1)
		capture_pending = capture_pending.slice(count, capture_pending.size() - 1) if capture_pending.size() > count else []
		capture_blocks += 1
		var samples = PoolRealArray()
		samples.resize(Codec.FRAMES)
		var peak = 0.0
		for i in range(Codec.FRAMES):
			var position = i * float(count) / Codec.FRAMES
			var left = int(position)
			var sample = source[left].linear_interpolate(source[min(left + 1, count - 1)], position - left)
			samples[i] = (sample.x + sample.y) * 0.5
			peak = max(peak, abs(samples[i]))
		input_peak = peak
		if not allowed:
			voice_until = 0
			continue
		if peak >= (0.002 if settings.push_to_talk else 0.012):
			voice_until = OS.get_ticks_msec() + 250
		if OS.get_ticks_msec() <= voice_until:
			send_audio(Codec.encode(samples))

func _packet(kind, peer, epoch, seq, data):
	var buffer = StreamPeerBuffer.new()
	buffer.put_u8(VERSION)
	buffer.put_u8(kind)
	buffer.put_64(_session_key())
	buffer.put_64(peer)
	buffer.put_u32(epoch)
	buffer.put_u32(seq)
	buffer.put_data(data)
	return buffer.data_array

func announce():
	if not connected:
		return
	var local = bridge.get_id()
	var previous = peers.get(local, {})
	var dead_since = int(previous.get("dead_since", OS.get_ticks_msec())) if previous.get("dead", false) == local_dead else OS.get_ticks_msec()
	peers[local] = {"enabled": settings.enabled, "generation": generation, "sequence": sequence, "talk": last_talk, "dead": local_dead, "dead_since": dead_since, "water": local_water}
	_send(_packet(STATE, local, generation, 0, PoolByteArray([1 if settings.enabled else 0, 1 if local_dead else 0, 1 if local_water else 0])), true)
	if bridge.is_world_authority():
		for peer in peers:
			if peer != local and Multiplayer.players.has(peer):
				var state = peers[peer]
				_send(_packet(STATE, peer, state.generation, 0, PoolByteArray([1 if state.enabled else 0, 1 if state.get("dead", false) else 0, 1 if state.get("water", false) else 0])), true)

func send_audio(data):
	if not connected or not lobby_enabled() or not settings.enabled or data.size() != Codec.BYTES:
		return
	sequence += 1
	last_talk = OS.get_ticks_msec()
	if peers.has(bridge.get_id()):
		peers[bridge.get_id()].talk = last_talk
	_send(_packet(AUDIO, bridge.get_id(), generation, sequence, data), false)
	sent_frames += 1

func _send(packet, reliable, exclude = 0):
	if bridge.is_world_authority():
		for peer in Multiplayer.players:
			if peer != bridge.get_id() and peer != exclude:
				if reliable or can_hear(exclude if exclude != 0 else bridge.get_id(), peer):
					_send_peer(peer, packet, reliable)
	else:
		_send_peer(bridge.get_host_id(), packet, reliable)

func _send_peer(peer, packet, reliable):
	if bridge.is_steam():
		Multiplayer.SteamInit.Steam.sendP2PPacket(peer, packet, 2 if reliable else 0, CHANNEL)
	elif reliable:
		rpc_id(peer, "receive_voice", packet)
	else:
		rpc_unreliable_id(peer, "receive_voice", packet)

func _poll_steam():
	var steam = Multiplayer.SteamInit.Steam
	var start = OS.get_ticks_usec()
	for _i in range(12):
		if OS.get_ticks_usec() - start > 1500:
			break
		var size = steam.getAvailableP2PPacketSize(CHANNEL)
		if size <= 0:
			break
		var packet = steam.readP2PPacket(size, CHANNEL)
		if packet.empty():
			break
		_accept(int(packet.steam_id_remote), packet.data)

remote func receive_voice(packet):
	if bridge.is_lan():
		_accept(get_tree().get_rpc_sender_id(), packet)

func _accept(sender, packet):
	if not connected or typeof(packet) != TYPE_RAW_ARRAY or packet.size() < HEADER + 1 or packet.size() > HEADER + Codec.BYTES or not Multiplayer.players.has(sender):
		return
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = packet
	if buffer.get_u8() != VERSION:
		return
	var kind = buffer.get_u8()
	if buffer.get_64() != _session_key():
		return
	var peer = buffer.get_64()
	var epoch = buffer.get_u32()
	var seq = buffer.get_u32()
	if not Multiplayer.players.has(peer) or peer == bridge.get_id():
		return
	if bridge.is_world_authority():
		if sender != peer:
			return
	elif sender != bridge.get_host_id():
		return
	var now = OS.get_ticks_msec()
	var rate = rate_limits.get(peer, {"start": now, "count": 0})
	if now - rate.start >= 1000:
		rate = {"start": now, "count": 0}
	rate.count += 1
	rate_limits[peer] = rate
	if rate.count > 80:
		dropped_frames += 1
		return
	var state = peers.get(peer, {"enabled": false, "generation": -1, "sequence": -1, "talk": -1000})
	if kind == STATE:
		if not packet.size() in [HEADER + 1, HEADER + 2, HEADER + 3] or packet[HEADER] > 1 or epoch < state.generation:
			return
		if packet.size() >= HEADER + 2 and packet[HEADER + 1] > 1:
			return
		var dead = packet.size() >= HEADER + 2 and packet[HEADER + 1] == 1
		if dead != state.get("dead", false):
			state.dead_since = now
		if packet.size() == HEADER + 3 and packet[HEADER + 2] > 1:
			return
		state.water = packet.size() == HEADER + 3 and packet[HEADER + 2] == 1
		state.dead = dead
		var enabled = packet[HEADER] == 1
		if epoch != state.generation or not enabled:
			_drop_sink(peer)
			state.sequence = -1
			state.talk = -1000
		state.generation = epoch
		state.enabled = enabled
		peers[peer] = state
	elif kind == AUDIO:
		if not lobby_enabled() or packet.size() != HEADER + Codec.BYTES or not state.enabled or epoch != state.generation or seq <= state.sequence or packet[HEADER + 2] > 88:
			return
		state.sequence = seq
		state.talk = now
		peers[peer] = state
		received_frames += 1
		if can_hear(peer, bridge.get_id()) and not is_muted(peer) and settings.volume > 0:
			_queue_audio(peer, packet.subarray(HEADER, packet.size() - 1))
	else:
		return
	if bridge.is_world_authority():
		_send(packet, kind == STATE, peer)

func _queue_audio(peer, data):
	var spatial = spatial_voice(peer, bridge.get_id())
	if sinks.has(peer) and sinks[peer].spatial != spatial:
		_drop_sink(peer)
	if not sinks.has(peer):
		var stream = AudioStreamGenerator.new()
		stream.mix_rate = Codec.RATE
		stream.buffer_length = 0.16
		var player = AudioStreamPlayer3D.new() if spatial else AudioStreamPlayer.new()
		if spatial:
			player.unit_size = 10.0 if peers.get(peer, {}).get("dead", false) else 8.0
			player.max_distance = 55.0 if peers.get(peer, {}).get("dead", false) else 45.0
			player.max_db = 8.0
		player.stream = stream
		player.bus = _voice_bus(peer)
		add_child(player)
		_update_voice_effects(peer)
		player.play()
		sinks[peer] = {"spatial": spatial, "player": player, "playback": player.get_stream_playback(), "queue": [], "start": OS.get_ticks_msec(), "started": false}
	var sink = sinks[peer]
	if sink.queue.size() >= 6:
		sink.queue.pop_front()
		dropped_frames += 1
	sink.queue.append(data)

func _update_playback():
	for peer in voice_buses:
		_update_voice_effects(peer)
		AudioServer.set_bus_mute(AudioServer.get_bus_index(voice_buses[peer]), not can_hear(peer, bridge.get_id()) or is_muted(peer) or settings.volume <= 0)
	var now = OS.get_ticks_msec()
	for peer in sinks.keys():
		if not peers.has(peer) or now - peers[peer].talk > 400 or is_muted(peer) or settings.volume <= 0 or not can_hear(peer, bridge.get_id()) or sinks[peer].spatial != spatial_voice(peer, bridge.get_id()):
			_drop_sink(peer)
			continue
		var sink = sinks[peer]
		_update_voice_effects(peer)
		if sink.spatial:
			sink.player.unit_size = 10.0 if peers.get(peer, {}).get("dead", false) else 8.0
			sink.player.max_distance = 55.0 if peers.get(peer, {}).get("dead", false) else 45.0
			sink.player.global_transform.origin = voice_actor(peer).global_transform.origin
			sink.player.unit_db = linear2db(settings.volume / 100.0)
		else:
			sink.player.volume_db = linear2db(settings.volume / 100.0)
		if not sink.started and sink.queue.size() < 3 and now - sink.start < 60:
			continue
		sink.started = true
		for _i in range(4):
			if sink.queue.empty() or not sink.playback.can_push_buffer(Codec.FRAMES):
				break
			var frames = Codec.decode(sink.queue.pop_front())
			if frames.size() == Codec.FRAMES:
				sink.playback.push_buffer(frames)
				played_frames += 1

func _drop_sink(peer):
	if sinks.has(peer):
		sinks[peer].player.stop()
		sinks[peer].player.queue_free()
		sinks.erase(peer)

func _clear_sinks():
	for peer in sinks.keys():
		_drop_sink(peer)

func is_enabled(peer):
	if not lobby_enabled():
		return false
	return bool(settings.enabled) if peer == bridge.get_id() else bool(peers.get(peer, {}).get("enabled", false))

func is_talking(peer):
	var last = last_talk if peer == bridge.get_id() else int(peers.get(peer, {}).get("talk", -1000))
	return is_enabled(peer) and OS.get_ticks_msec() - last < 650

func is_muted(peer):
	return muted.get(peer, false) or (bridge.is_steam() and muted_steam.has(str(peer)))

func toggle_mute(peer):
	if peer == bridge.get_id():
		return
	var value = not is_muted(peer)
	muted[peer] = value
	if bridge.is_steam():
		muted_steam.erase(str(peer))
		if value:
			muted_steam.append(str(peer))
		save_settings()
	if value:
		_drop_sink(peer)

func _exit_tree():
	_stop_capture()
	_clear_sinks()
	for peer in voice_buses.keys():
		_remove_voice_bus(peer)

func diagnostics():
	var data = {"device": AudioServer.capture_device, "mix_rate": AudioServer.get_mix_rate(), "capture_pairs": capture_pairs, "capture_blocks": capture_blocks, "ptt": settings.push_to_talk, "input_gate": input_gate, "enabled": settings.enabled, "capturing": is_instance_valid(microphone), "input_peak": input_peak, "sent": sent_frames, "received": received_frames, "played": played_frames, "dropped": dropped_frames, "streams": sinks.size(), "peak_usec": peak_process_usec, "error": capture_error}
	peak_process_usec = 0
	return data

func _session_key():
	return Multiplayer.SteamLobby.get_lobby_id() if bridge.is_steam() else 0

func lobby_enabled():
	return Multiplayer.hostSettings.get("useVoiceChat", true)

func can_hear(speaker, listener):
	if not lobby_enabled():
		return false
	if failure_screen():
		return true
	var state = peers.get(speaker, {})
	if not Multiplayer.hostSettings.get("hearDeadPlayers", false) and state.get("dead", false) and not peers.get(listener, {}).get("dead", false):
		return OS.get_ticks_msec() - int(state.get("dead_since", 0)) < 1000
	return true

func voice_actor(peer):
	if not is_instance_valid(Global.get("menu")) or not Global.menu.in_game or not Multiplayer.get("player_scene_loaded"):
		return null
	if peer == bridge.get_id():
		return Global.player if is_instance_valid(Global.get("player")) else null
	var actors = Multiplayer.get_node_or_null("Players")
	return actors.get_node_or_null(str(peer) + "/Puppet") if actors != null else null

func spatial_voice(speaker, listener):
	if failure_screen() or not Multiplayer.hostSettings.get("proximityVoiceChat", true):
		return false
	if peers.get(speaker, {}).get("dead", false) and peers.get(listener, {}).get("dead", false):
		return false
	return is_instance_valid(voice_actor(speaker)) and is_instance_valid(voice_actor(listener))

func failure_screen():
	var flow = Multiplayer.get_node_or_null("SessionFlow")
	return flow != null and flow.result_active and not flow.result_won

func _voice_bus(peer):
	if voice_buses.has(peer):
		return voice_buses[peer]
	var bus_name = "CruS Speaker " + str(peer)
	AudioServer.add_bus()
	var index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "CruS Voice")
	var reverb = AudioEffectReverb.new()
	reverb.room_size = 0.8
	reverb.damping = 0.5
	reverb.wet = 0.45
	reverb.dry = 0.8
	AudioServer.add_bus_effect(index, reverb)
	var water_filter = AudioEffectLowPassFilter.new()
	water_filter.cutoff_hz = 400.0
	water_filter.db = AudioEffectFilter.FILTER_24DB
	AudioServer.add_bus_effect(index, water_filter)
	voice_buses[peer] = bus_name
	return bus_name

func _update_voice_effects(peer):
	var index = AudioServer.get_bus_index(_voice_bus(peer))
	AudioServer.set_bus_effect_enabled(index, 0, not failure_screen() and peers.get(peer, {}).get("dead", false))
	AudioServer.set_bus_effect_enabled(index, 1, not failure_screen() and (local_water or peers.get(peer, {}).get("water", false)))

func _remove_voice_bus(peer):
	if voice_buses.has(peer):
		var index = AudioServer.get_bus_index(voice_buses[peer])
		if index >= 0:
			AudioServer.remove_bus(index)
		voice_buses.erase(peer)
