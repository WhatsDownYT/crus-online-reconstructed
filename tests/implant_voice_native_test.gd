extends Node
var mp
var failures = 0
func check(ok, label):
	print("PICKUP_CHECK host=",HOST," ",label,"=",ok)
	if not ok: failures += 1
func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6),"timeout")
	mp = Global.get_node("Multiplayer")
	mp.Voice.test_capture = true
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	if HOST:
		mp.config.hostPort = PORT
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1",PORT)
	while mp.players.size()<2:
		yield(get_tree().create_timer(0.1),"timeout")
	if HOST:
		yield(get_tree().create_timer(1),"timeout")
		Global.CURRENT_LEVEL=1
		mp.game_init(Global.LEVELS[1])
	while Global.loader!=null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1),"timeout")
	Global.player.health=10000
	yield(get_tree().create_timer(8),"timeout")

	var client_id=0
	for peer in mp.players:
		if peer!=1: client_id=peer
	var player=Global.player
	player.set_physics_process(false)
	player.start_flag=true
	player.health=10000
	player.set_process(false)
	player.get_parent().rotation.y=PI
	player.global_transform.origin=Vector3(0,1000,0) if HOST else Vector3(0,1000,-4)

	mp.Eyecam.set_process(false)
	var floor_body=StaticBody.new()
	var floor_shape=CollisionShape.new()
	var box=BoxShape.new()
	box.extents=Vector3(10,0.1,10)
	floor_shape.shape=box
	floor_body.add_child(floor_shape)
	Global.current_scene.add_child(floor_body)
	floor_body.global_transform.origin=Vector3(0,999,0)
	Global.menu.visible=false
	mp.Menu.hide()
	var voice = mp.Voice
	var fx = preload("res://MOD_CONTENT/CruS Online/VoiceEffects.gd")
	voice.settings.enabled = true
	voice.settings.volume = 100
	voice.set_process(false)
	voice.connected = true
	voice.local_dead = false
	voice.local_water = false
	var peer = client_id if HOST else 1
	var local = mp.NetworkBridge.get_id()
	var samples = PoolRealArray()
	samples.resize(320)
	for i in range(320): samples[i] = 0.2 * sin(TAU * 440.0 * i / 16000.0)
	var packet = voice.Codec.encode(samples)
	var profiles = ["Composite Helmet", "CSIJ Level V Biosuit", "Speed Enhancer Gland", "Speed Enhancer Node Cluster", "Speed Enhancer Total Organ Package", "CSIJ Level VI Golem Exosystem", "Bouncy Suit", "Abominator", "Goo Overdrive", "Cortical Scaledown+", "Hazmat Suit", "Holy Scope", "Stealth Suit+"]
	for profile in profiles:
		equip(profile)
		player.max_gravity = -22 if profile == "Abominator" else 22
		voice.local_effect_mask = voice.local_voice_mask(false)
		voice.announce()
		yield(barrier(profile.replace(" ","_")),"completed")
		var audio_bus = AudioServer.get_bus_index(voice._voice_bus(peer))
		var rendered_audio = AudioEffectCapture.new()
		rendered_audio.buffer_length = 0.3
		AudioServer.add_bus_effect(audio_bus, rendered_audio)
		var captured = PoolVector2Array()
		for frame in range(35):
			voice.send_audio(packet)
			voice._update_playback()
			yield(get_tree().create_timer(0.02),"timeout")
			captured.append_array(rendered_audio.get_buffer(rendered_audio.get_frames_available()))
		check(voice.peers.get(peer,{}).get("effects",0) == fx.IMPLANTS[profile],profile+" effect state synchronized")
		captured.append_array(rendered_audio.get_buffer(rendered_audio.get_frames_available()))
		var peak = 0.0
		for sample in captured: peak = max(peak,max(abs(sample.x),abs(sample.y)))
		check(peak>0.00001,profile+" audio renders through native effects peak="+str(peak))
		AudioServer.remove_bus_effect(audio_bus,6)
		var bus = AudioServer.get_bus_index(voice._voice_bus(peer))
		voice._update_voice_effects(peer)
		if profile in ["Composite Helmet", "Hazmat Suit", "CSIJ Level V Biosuit"]:
			check(AudioServer.is_bus_effect_enabled(bus,voice.BusEffect.FILTER) and AudioServer.get_bus_effect(bus,voice.BusEffect.FILTER).cutoff_hz==fx.cutoff(fx.IMPLANTS[profile]),profile+" filter enabled")
		if profile == "CSIJ Level V Biosuit":
			check(AudioServer.is_bus_effect_enabled(bus,voice.BusEffect.DISTORTION) and AudioServer.is_bus_effect_enabled(bus,voice.BusEffect.DELAY),"biosuit distortion follows muffle with short echo")
		if profile == "CSIJ Level VI Golem Exosystem":
			check(voice.sinks.has(peer) and voice.sinks[peer].layers.size()==1 and abs(voice.sinks[peer].layers[0].pitch.pitch_scale-0.56)<0.0001,"golem has additional low pitched voice")
		if profile == "Bouncy Suit":
			check(voice.sinks.has(peer) and voice.sinks[peer].layers.size()==2,"bouncy suit has independently pitched stereo echoes")
		if profile == "Stealth Suit+":
			check(voice.sinks.has(peer) and voice.sinks[peer].player.max_distance==22.5,"stealth halves proximity range")
		voice._clear_sinks()
		yield(barrier("done_"+profile.replace(" ","_")),"completed")
	check(fx.pitch(fx.GLAND,0)<fx.pitch(fx.CLUSTER,0) and fx.pitch(fx.CLUSTER,0)<fx.pitch(fx.ORGAN,0),"speed enhancer pitch progression")
	equip("Abominator")
	player.max_gravity=22
	check(voice.local_voice_mask(false)==0,"abominator effect requires inverted gravity")
	equip("CSIJ Level VI Golem Exosystem")
	for implant in Global.implants.IMPLANTS:
		if implant.i_name=="Composite Helmet": Global.implants.head_implant=implant
	voice.local_effect_mask=voice.local_voice_mask(false)
	check(voice.local_effect_mask==(fx.GOLEM|fx.HELMET),"equipped implant effects combine across slots")
	voice.peers[local]={"dead":false}
	voice.peers[peer]={"dead":false,"effects":fx.GOLEM|fx.HELMET,"water":true,"talk":OS.get_ticks_msec(),"enabled":true}
	voice.local_water=true
	voice._update_voice_effects(peer)
	var bus=AudioServer.get_bus_index(voice._voice_bus(peer))
	check(AudioServer.is_bus_effect_enabled(bus,voice.BusEffect.WATER) and AudioServer.is_bus_effect_enabled(bus,voice.BusEffect.FILTER),"underwater and implant muffle stack")
	voice.peers[peer].dead=true
	voice._update_voice_effects(peer)
	check(voice.effect_mask(peer)==(fx.GOLEM|fx.HELMET) and AudioServer.is_bus_effect_enabled(bus,voice.BusEffect.REVERB),"living proximity listener hears dead implant effects with reverb")
	voice.peers[local].dead=true
	voice._update_voice_effects(peer)
	check(voice.effect_mask(peer)==0 and not AudioServer.is_bus_effect_enabled(bus,voice.BusEffect.FILTER),"dead listeners hear no implant effects on dead speakers")
	mp.Flow.result_active=true
	voice.enter_results()
	voice._update_voice_effects(peer)
	check(voice.effect_mask(peer)==0 and voice.sinks.empty(),"results clear modified voice buffers")
	for index in range(6): check(not AudioServer.is_bus_effect_enabled(bus,index),"results disable voice effect "+str(index))
	mp.Flow.result_active=false
	Global.menu.in_game=false
	voice._update_voice_effects(peer)
	check(voice.effect_mask(peer)==0 and not AudioServer.is_bus_effect_enabled(bus,voice.BusEffect.REVERB),"menus have unmodified voice")
	Global.menu.in_game=true
	Global.objectives_total=2
	Global.objectives=2
	check(mp.get_node("DiscordPresence").mission_counter()=="Targets: 2/2","discord total and remaining targets")
	Global.objectives=0
	check(mp.get_node("DiscordPresence").mission_counter()=="Targets: 0/2","discord killed targets retain initial total")
	mp.hostSettings.gameMode="deathmatch"
	mp.Flow.world.participants=[1,client_id]
	mp.died_players.clear()
	check(mp.get_node("DiscordPresence").mission_counter()=="Players: 2/2","discord deathmatch player counter")
	mp.died_players.append(client_id)
	check(mp.get_node("DiscordPresence").mission_counter()=="Players: 1/2","discord deathmatch excludes dead players")
	mp.hostSettings.gameMode="counter_op"
	check(mp.get_node("DiscordPresence").mission_counter()=="Targets: 0/2","discord counter-opps uses mission targets")
	var reverse=fx.new()
	var ramp=PoolVector2Array()
	ramp.resize(320)
	for block in range(25):
		for i in range(320): ramp[i]=Vector2.ONE*(float(block*320+i)/8000.0)
		var output=reverse.process(ramp,fx.ABOMINATOR)
		check(output[0]==Vector2.ZERO,"reverse waits half a second block "+str(block))
	var reversed=reverse.process(ramp,fx.ABOMINATOR)
	check(abs(reversed[0].x-7999.0/8000.0)<0.00001 and reversed[319].x<reversed[0].x,"abominator reverses each half-second chunk")
	var robot=fx.new()
	check(robot.process(ramp,fx.HOLY)!=ramp,"holy scope applies ring modulation")
	check(Global.implants.IMPLANTS[0]!=null,"implant catalog available")
	for implant in Global.implants.IMPLANTS:
		if implant.i_name=="Cortical Scaledown+": check(implant.texture.resource_path=="res://Textures/Menu/Implants/scaledown.png","scaledown restored original sprite")
	voice._clear_sinks()
	yield(barrier("all_done"),"completed")
	print("VOICE_IMPLANT_RESULT host=",HOST," failures=",failures)
	get_tree().quit(1 if failures else 0)

func equip(profile):
	for slot in ["head_implant","torso_implant","arm_implant","leg_implant"]: Global.implants.set(slot,Global.implants.empty_implant)
	for implant in Global.implants.IMPLANTS:
		if implant.i_name==profile:
			var slot="head_implant" if implant.head else ("torso_implant" if implant.torso else ("arm_implant" if implant.arms else "leg_implant"))
			Global.implants.set(slot,implant)

func barrier(stage):
	var prefix="E:/Cruelty/Online/dist/pickup-barrier-"+str(PORT)+"-"+stage+"-"
	var file=File.new()
	file.open(prefix+str(HOST),File.WRITE)
	file.store_string("ready")
	file.close()
	yield(get_tree(),"idle_frame")
	while not file.file_exists(prefix+str(not HOST)):
		yield(get_tree().create_timer(0.05),"timeout")
