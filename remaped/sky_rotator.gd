extends WorldEnvironment
export  var rotation_speed = 0.05
export  var z = false

var min_fog_end
var min_fog_begin
var helltexture = preload("res://Textures/sky10.png")
var helltexture2 = preload("res://Textures/sky11.png")

var base_environment
var world_style = []

func _ready():
	base_environment = environment.duplicate(true)
	_apply_world_style()

func _apply_world_style():
	environment = base_environment.duplicate(true)
	var mp = Global.get_node("Multiplayer")
	var online = mp.NetworkBridge.check_connection()
	var hope = mp.Flow.world.get("difficulty", {}).get("hope_discarded", Global.hope_discarded) if online else Global.hope_discarded
	var ending_two = mp.Flow.world.get("ending_2", Global.ending_2) if online else Global.ending_2
	world_style = [hope, ending_two]
	if hope and Global.CURRENT_LEVEL != 18:
		environment.background_sky.panorama = helltexture
		environment.fog_color = Color(1, 0, 0)
		if ending_two:
			environment.fog_color = Color(0, 1, 0)
			environment.background_sky.panorama = helltexture2
		environment.background_color = environment.fog_color
	if Global.reflections:
		environment.ss_reflections_enabled = true
	else :
		environment.ss_reflections_enabled = false
	min_fog_end = environment.fog_depth_end
	min_fog_begin = environment.fog_depth_begin
	environment.fog_depth_begin = clamp(Global.draw_distance / 2, 0, min_fog_begin)
	environment.fog_depth_end = clamp(Global.draw_distance, 0, min_fog_end)
	if Global.draw_distance < 60:
		var image:Image = environment.background_sky.panorama.get_data()
		image.lock()
		var color = image.get_pixel(0, 0)
		var size = image.get_size()
		for p in range(1000):
			color = color.blend(image.get_pixel((p * 37) % int(size.x), (p * 53) % int(size.y)))
		environment.fog_color = color
	if Global.draw_distance <= 30:
		environment.background_mode = 1
		environment.background_color = environment.fog_color
func _physics_process(delta):
	var mp = Global.get_node("Multiplayer")
	if mp.NetworkBridge.check_connection():
		var state = [mp.Flow.world.get("difficulty", {}).get("hope_discarded", Global.hope_discarded), mp.Flow.world.get("ending_2", Global.ending_2)]
		if state != world_style:
			_apply_world_style()
	if z:
		environment.background_sky_rotation.x += rotation_speed * delta
		return 
	environment.background_sky_rotation.y += rotation_speed * delta
