extends DirectionalLight

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")
onready var Flow = Global.get_node("Multiplayer").Flow

var t = 0
var time = 12
onready  var env:WorldEnvironment = get_parent().get_node("WorldEnvironment")
var init_fog = Color(0, 0, 0)
var init_energy = 1
export  var min_light:float = 0
var init_energy_ambient:float = 1
onready  var audio_player:AudioStreamPlayer = AudioStreamPlayer.new()

export  var darkness = false

export  var permanight = false
var init_sky_color
onready  var musicbus = AudioServer.get_bus_index("Music")

func _ready():
	NetworkBridge.register_rpcs(self, [["storm_flash", NetworkBridge.PERMISSION.SERVER], ["sync_hour", NetworkBridge.PERMISSION.SERVER]])
	if NetworkBridge.check_connection():
		Global.rain = Flow.world.get("rain", false)
	else:
		Global.rain = rand_range(0, 100) > 90 or Global.implants.head_implant.fishing_bonus
	add_child(audio_player)
	audio_player.stream = load("res://Sfx/sfx100v2_thunder_02.ogg")

	init_energy = light_energy
	init_energy_ambient = env.environment.ambient_light_energy
	if not Global.rain or _hope_weather():
		init_fog = env.base_environment.fog_color if env.has_method("_apply_world_style") and env.base_environment != null else env.environment.fog_color
		init_sky_color = env.base_environment.background_color if env.has_method("_apply_world_style") and env.base_environment != null else env.environment.background_color
	else :
		if Global.CURRENT_LEVEL != Global.L_SWAMP:
			env.environment.fog_depth_begin = 0
			env.environment.fog_depth_end = 100
			env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
		init_fog = Color(0.6, 0.6, 0.6)
		init_sky_color = Color(0.6, 0.6, 0.6)
		env.environment.background_mode = 1
func _physics_process(delta):
	if not darkness:
		light_energy = lerp(light_energy, init_energy, clamp(delta * 30, 0, 1))
	
		
		
	if _hope_weather():
		return 

	
	if darkness:
		if Global.player.global_transform.origin.y < - 0.5:
			AudioServer.set_bus_volume_db(musicbus, lerp(AudioServer.get_bus_volume_db(musicbus), - 80, 0.05))
			light_energy = lerp(light_energy, 0, 0.2)
			env.environment.ambient_light_energy = lerp(env.environment.ambient_light_energy, 0, 0.2)
			env.environment.fog_color = lerp(env.environment.fog_color, Color(0, 0, 0), 0.2)
			return 
		elif not is_equal_approx(env.environment.ambient_light_energy, init_energy_ambient):
			AudioServer.set_bus_volume_db(musicbus, lerp(AudioServer.get_bus_volume_db(musicbus), Global.music_volume, 0.05))
			if not Global.rain:
				light_energy = lerp(light_energy, init_energy, 0.2)
			else :
				light_energy = lerp(light_energy, init_energy, delta * 30)
			env.environment.ambient_light_energy = lerp(env.environment.ambient_light_energy, init_energy_ambient, 0.2)
			env.environment.fog_color = lerp(env.environment.fog_color, init_fog, 0.2)
	
	if fmod(t, 60) != 0 and t != 0:
		t += 1
		return 
		
	t += 1
	if NetworkBridge.is_world_authority() and rand_range(0, 100) > 95 and Global.rain and not darkness:
		var pitch = 0.5 + rand_range(0, 0.5)
		storm_flash(null, pitch)
		NetworkBridge.n_rpc(self, "storm_flash", [pitch])
	if NetworkBridge.check_connection():
		if NetworkBridge.is_world_authority() and Flow.world.get("hour", -1) != OS.get_time().hour:
			sync_hour(null, OS.get_time().hour)
			NetworkBridge.n_rpc(self, "sync_hour", [Flow.world.hour])
		time = Flow.world.get("hour", 12)
	else:
		time = OS.get_time().hour

	if time == 0:
		time = 24
	var t_norm = (time - 0) / (24 - 0)
	t_norm = wrapf(t_norm, 0, 1)
	var dist:float = abs(12 - time)
	var t_norm_light:float = (dist - 0) / (12 - 0)
	t_norm_light = clamp(t_norm_light, 0, 0.95)
	t_norm_light = 1 - t_norm_light
	env.environment.fog_color = Color(init_fog.r * t_norm_light, init_fog.g * t_norm_light, init_fog.b * t_norm_light)
	env.environment.background_color = env.environment.fog_color
	if not permanight:
		env.environment.background_energy = clamp(t_norm_light, min_light, 1)
		
	t_norm_light = clamp(t_norm_light + 0.5, 0.8, 1)
	light_color = Color(t_norm_light, t_norm_light, 1)
	
	
	

	t_norm = wrapf(((t_norm - 0.5) * PI * 2) - PI / 2, - PI, PI)
	
	
func thunder():
	audio_player.pitch_scale = 0.5 + rand_range(0, 0.5)
	if not audio_player.playing:
		audio_player.play()

puppet func sync_hour(id, hour):
	Flow.world.hour = hour

puppet func storm_flash(id, pitch):
	light_energy = 100
	yield(get_tree().create_timer(2), "timeout")
	if is_instance_valid(audio_player) and not audio_player.playing:
		audio_player.pitch_scale = pitch
		audio_player.play()

func _hope_weather():
	return Flow.world.get("difficulty", {}).get("hope_discarded", Global.hope_discarded) if NetworkBridge.check_connection() else Global.hope_discarded
