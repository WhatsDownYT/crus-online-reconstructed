extends Reference

const Codec = preload("res://MOD_CONTENT/CruS Online/VoiceCodec.gd")
class Bridge:
	extends Node
	var local = 1
	func get_id():
		return local
	func get_host_id():
		return 1
	func is_world_authority():
		return local == 1
	func is_steam():
		return false
	func is_lan():
		return true
	func check_connection():
		return true
class Session:
	extends Node
	var players = {1: {}, 2: {}, 3: {}}
	var hostSettings = {}
class Voice:
	extends "res://MOD_CONTENT/CruS Online/VoiceChat.gd"
	var outgoing = []
	var actors = {}
	func voice_actor(peer):
		return actors.get(peer, null)
	func _ready():
		pass
	func _send_peer(peer, packet, reliable):
		outgoing.append([peer, packet, reliable])
class Flow:
	extends Node
	var result_active = true
	var result_won = false
class Capture:
	extends Reference
	var remaining = 0
	var level = 0.1
	func get_discarded_frames():
		return 0
	func clear_buffer():
		remaining = 0
	func get_frames_available():
		return remaining * int(AudioServer.get_mix_rate() / 50.0)
	func can_get_buffer(_count):
		return remaining > 0
	func get_buffer(count):
		remaining -= int(count / (AudioServer.get_mix_rate() / 50.0))
		var frames = PoolVector2Array()
		frames.resize(count)
		for i in range(count):
			frames[i] = Vector2.ONE * level
		return frames

func run(test):
	var samples = PoolRealArray()
	samples.resize(Codec.FRAMES)
	for i in range(Codec.FRAMES):
		samples[i] = 0.4 * sin(TAU * 440.0 * i / Codec.RATE)
	var encoded = Codec.encode(samples)
	var decoded = Codec.decode(encoded)
	test.check(encoded.size() == 163 and decoded.size() == 320, "voice codec produces bounded 20 ms packets")
	var signal_power = 0.0
	var noise = 0.0
	for i in range(Codec.FRAMES):
		signal_power += samples[i] * samples[i]
		noise += pow(samples[i] - decoded[i].x, 2)
	test.check(signal_power / max(noise, 0.000001) > 100, "voice codec preserves a speech-band test tone above 20 dB SNR")
	test.check(Codec.decode(PoolByteArray([1,2,3])).empty(), "truncated voice packet is rejected")
	var invalid = encoded.subarray(0, encoded.size() - 1)
	invalid[2] = 255
	test.check(Codec.decode(invalid).empty(), "invalid ADPCM step index is rejected")
	var parent = Session.new()
	test.add_child(parent)
	var bridge = Bridge.new()
	bridge.name = "NetworkBridge"
	parent.add_child(bridge)
	var voice = Voice.new()
	parent.add_child(voice)
	voice.set_process(false)
	voice.connected = true
	voice.settings.enabled = true
	voice.settings.volume = 0
	voice._apply_binding()
	voice.announce()
	test.check(voice.outgoing.size() == 2 and voice.outgoing[0][2], "voice enable state reaches all lobby peers reliably")
	voice.outgoing.clear()
	var packet = voice._packet(voice.STATE, 2, 10, 0, PoolByteArray([1]))
	voice._accept(3, packet)
	test.check(not voice.peers.has(2), "voice state cannot impersonate another sender")
	voice._accept(2, packet)
	test.check(voice.is_enabled(2) and voice.outgoing.size() == 1 and voice.outgoing[0][0] == 3, "host relays verified voice state to other clients")
	voice.outgoing.clear()
	packet = voice._packet(voice.AUDIO, 2, 10, 1, encoded)
	voice._accept(2, packet)
	voice._accept(2, packet)
	test.check(voice.received_frames == 1 and voice.outgoing.size() == 1 and not voice.outgoing[0][2], "voice packets are unreliable and duplicates are discarded")
	voice._accept(2, voice._packet(voice.STATE, 2, 11, 0, PoolByteArray([0])))
	voice._accept(2, voice._packet(voice.AUDIO, 2, 10, 2, encoded))
	test.check(not voice.is_enabled(2) and voice.received_frames == 1, "disabled voice rejects delayed audio from older generations")
	var capture = Capture.new()
	voice.capture = capture
	voice.settings.push_to_talk = true
	Input.action_release("crus_voice_talk")
	capture.remaining = 1
	voice._capture_frames()
	test.check(voice.sent_frames == 0, "PTT release discards captured audio")
	Input.action_press("crus_voice_talk")
	capture.remaining = 1
	voice._capture_frames()
	test.check(voice.sent_frames == 1, "PTT press sends captured audio")
	Input.action_release("crus_voice_talk")
	voice.settings.push_to_talk = false
	capture.remaining = 1
	voice._capture_frames()
	test.check(voice.sent_frames == 2, "voice activation sends speech without a key")
	voice.voice_until = 0
	capture.level = 0
	capture.remaining = 1
	voice._capture_frames()
	test.check(voice.sent_frames == 2, "voice activation suppresses silence")
	voice.binding_active = true
	capture.level = 0.1
	capture.remaining = 1
	voice._capture_frames()
	test.check(voice.sent_frames == 2, "rebinding controls cannot transmit microphone audio")
	voice.binding_active = false
	voice.toggle_mute(2)
	test.check(voice.is_muted(2), "per-player mute is local")
	voice.settings.enabled = false
	voice.send_audio(encoded)
	test.check(voice.sent_frames == 2, "disabled voice cannot send audio")
	voice.settings.volume = 100
	voice.muted.clear()
	voice._accept(2, voice._packet(voice.STATE, 2, 12, 0, PoolByteArray([1])))
	voice._accept(2, voice._packet(voice.AUDIO, 2, 12, 1, encoded))
	test.check(voice.sinks.has(2), "microphone disabled still receives other players")
	voice.settings.enabled = true
	capture.remaining = 8
	voice._capture_frames()
	test.check(voice.sent_frames > 2, "capture backlog retains recent speech instead of dropping everything")

	voice.peers[1] = {"dead": false}
	voice.peers[2] = {"dead": true, "dead_since": OS.get_ticks_msec()}
	voice.peers[3] = {"dead": false}
	test.check(voice.can_hear(2, 1), "new death retains one-second scream grace")
	voice.peers[2].dead_since = OS.get_ticks_msec() - 750
	test.check(voice.can_hear(2, 1), "voice grace lasts longer than half a second")
	voice.peers[2].dead_since = OS.get_ticks_msec() - 1001
	test.check(not voice.can_hear(2, 1), "living players cannot hear dead after grace")
	voice.peers[3].dead = true
	test.check(voice.can_hear(2, 3) and not voice.spatial_voice(2, 3), "dead players hear each other globally")
	parent.hostSettings.hearDeadPlayers = true
	test.check(voice.can_hear(2, 1), "host can allow living players to hear dead")
	for peer in [1, 2]:
		var actor = Spatial.new()
		parent.add_child(actor)
		voice.actors[peer] = actor
	test.check(voice.spatial_voice(2, 1), "living listeners hear dead speakers positionally")
	voice.local_water = true
	voice._update_voice_effects(2)
	var bus = AudioServer.get_bus_index(voice.voice_buses[2])
	var water_filter = AudioServer.get_bus_effect(bus, 1)
	test.check(water_filter.cutoff_hz == 400.0 and water_filter.db == AudioEffectFilter.FILTER_24DB, "underwater voices use strong low-pass filter")
	test.check(AudioServer.is_bus_effect_enabled(bus, 0) and AudioServer.is_bus_effect_enabled(bus, 1), "dead underwater speaker receives both effects during mission")
	var flow = Flow.new()
	flow.name = "SessionFlow"
	parent.add_child(flow)
	parent.hostSettings.hearDeadPlayers = false
	voice._update_voice_effects(2)
	test.check(voice.can_hear(2, 1) and not voice.spatial_voice(2, 1), "failure screen allows clear global conversation despite delayed death state")
	test.check(not AudioServer.is_bus_effect_enabled(bus, 0) and not AudioServer.is_bus_effect_enabled(bus, 1), "failure screen removes reverb and underwater effects")
	flow.result_active = false
	voice._update_voice_effects(2)
	test.check(AudioServer.is_bus_effect_enabled(bus, 0) and not voice.can_hear(2, 1), "leaving failure screen restores mission voice rules")
	parent.hostSettings.useVoiceChat = false
	test.check(not voice.can_hear(2, 3) and not voice.is_enabled(1), "lobby voice switch overrides individual settings")
	var sent = voice.sent_frames
	voice.send_audio(encoded)
	test.check(voice.sent_frames == sent, "lobby voice switch blocks transmission")
	voice.reset_session()
	test.check(voice.peers.empty() and voice.sinks.empty() and not voice.connected, "leaving clears voice session state")
	parent.free()
