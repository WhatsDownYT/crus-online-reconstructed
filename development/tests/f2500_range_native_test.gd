extends Node

var failures = 0

func check(value, label):
	print("F2500_RANGE_CHECK ", label, " = ", value)
	if not value:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6.0), "timeout")
	var index = -1
	for candidate in range(Global.LEVELS.size()):
		if str(Global.LEVELS[candidate]).ends_with("f2500_test_range.tscn"):
			index = candidate
			break
	check(index >= 0, "test range is available in mission list")
	if index >= 0:
		Global.CURRENT_LEVEL = index
		Global.goto_scene(Global.LEVELS[index])
		var deadline = OS.get_ticks_msec() + 20000
		while (Global.loader != null or not is_instance_valid(Global.current_scene) or not str(Global.current_scene.filename).ends_with("f2500_test_range.tscn")) and OS.get_ticks_msec() < deadline:
			yield(get_tree().create_timer(0.1), "timeout")
		check(is_instance_valid(Global.current_scene) and str(Global.current_scene.filename).ends_with("f2500_test_range.tscn"), "test range scene enters gameplay")
		if is_instance_valid(Global.current_scene):
			var gun = Global.current_scene.get_node_or_null("QodotMap/entity_3_Herschel_F2500_SWAT/Body/Rotation_Helper/Weapon")
			check(gun != null and gun.current_weapon == Global.get_node("WeaponRegistry").index_for("herschel:f2500"), "SWAT resolves its weapon ID during scene initialization")
	print("F2500_RANGE_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
