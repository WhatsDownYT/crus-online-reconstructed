extends Node

var failures = 0

func check(value, label):
	print("IMPLANT_GAME_CHECK host=", HOST, " ", label, " = ", value)
	if not value:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6.0), "timeout")
	var registry = Global.get_node("ImplantRegistry")
	check(registry.implant_for("example:practice_reflex") != null, "source mission enables example")
	registry.finalize()
	var implant = registry.implant_for("example:practice_reflex")
	Global.implants.purchased_implants.erase("example:practice_reflex")
	Global.implants.leg_implant = implant
	var test_level = "user://levels/Implant Test Range/ImplantTestRange.tscn"
	var test_index = Global.LEVELS.find(test_level)
	check(test_index >= 0, "test range registered in mission list")
	if test_index < 0:
		get_tree().quit(1)
		return
	Global.CURRENT_LEVEL = test_index
	Global.goto_scene(test_level)
	var deadline = OS.get_ticks_msec() + 30000
	while (Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != test_level or get_tree().paused) and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.1), "timeout")
	check(is_instance_valid(Global.player), "mission loaded")
	if is_instance_valid(Global.player):
		Global.menu.in_game = true
		check(Global.current_scene.has_node("QodotMap/entity_2_Practice_Reflex_Implant") and Global.current_scene.has_node("QodotMap/entity_3_Herschel_F2500_SWAT"), "test range spawns pickup and hostile")
		yield(get_tree().create_timer(0.3), "timeout")
		check(Global.implants.leg_implant == implant and Global.player._implant_speed_bonus() >= 1.0, "custom movement modifier applied")
		var behavior = registry.behaviors["example:practice_reflex"]
		check(behavior.equip_count > 0 and behavior.process_count > 0, "equip and process hooks ran")
		Global.implants.leg_implant = Global.implants.empty_implant
		yield(get_tree().create_timer(0.1), "timeout")
		check(behavior.unequip_count > 0, "unequip hook ran")
		Global.implants.purchased_implants.erase("example:practice_reflex")
		var pickup = load("res://MOD_CONTENT/CruS Online/implants/examples/PracticeReflexPickup.tscn").instance()
		Global.current_scene.add_child(pickup)
		yield(get_tree(), "idle_frame")
		check(not menu_entry_revealed(implant), "implant starts undiscovered in mission")
		pickup.get_node("Area").player_use()
		check(Global.implants.purchased_implants.has("example:practice_reflex") and menu_entry_revealed(implant), "pickup discovers implant in mission")
		check(Global.save().implants_unlocked.has("example:practice_reflex"), "mission discovery saved")
	print("IMPLANT_GAME_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func menu_entry_revealed(implant):
	var menu = Global.menu.get_node("Character_Menu/Character_Container")
	return not menu._implant_is_undiscovered(implant)
