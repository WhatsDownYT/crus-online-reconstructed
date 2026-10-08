extends Node

var failures = 0

func check(value, label):
	print("IMPLANT_API_CHECK ", label, " = ", value)
	if not value:
		failures += 1

func _ready():
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6.0), "timeout")
	var registry = Global.get_node_or_null("ImplantRegistry")
	check(registry != null, "registry initialized")
	if registry == null:
		get_tree().quit(1)
		return
	var before = Global.implants.IMPLANTS.size()
	var definition = load("res://MOD_CONTENT/CruS Online/implants/examples/PracticeReflex.tres")
	check(definition != null, "example definition loaded")
	check(registry.implant_for("example:practice_reflex") != null, "source mission enables bundled example")
	registry.finalize()
	var mission_file = File.new()
	check(mission_file.open("user://levels/Implant Test Range/level.json", File.READ) == OK, "source mission installed")
	var mission_meta = parse_json(mission_file.get_as_text())
	mission_file.close()
	var verifier = load("res://MOD_CONTENT/CruS Online/compatibility/modbase/level_verifier.gd").new()
	check(verifier.check_json(mission_meta).empty(), "mission dependency is satisfied")
	var missing_meta = mission_meta.duplicate(true)
	missing_meta.required_implants = ["missing:test_implant"]
	check(not verifier.check_json(missing_meta).empty(), "mission rejects missing implant")
	verifier.free()
	var level_scene = load("user://levels/Implant Test Range/ImplantTestRange.tscn")
	check(level_scene != null, "test mission scene loads")
	if level_scene != null:
		var level = level_scene.instance()
		check(level.has_node("QodotMap/entity_1_Player") and level.has_node("QodotMap/entity_2_Practice_Reflex_Implant") and level.has_node("QodotMap/entity_3_Herschel_F2500_SWAT"), "test mission places player, pickup, and hostile")
		check(level.get_node("QodotMap/entity_3_Herschel_F2500_SWAT/Body/Rotation_Helper/Weapon").current_weapon == 29, "hostile wields F2500")
		level.free()
	var implant = registry.implant_for("example:practice_reflex")
	check(implant != null and Global.implants.IMPLANTS.size() == before, "catalog registered once")
	check(not registry._source_level_declares_implant("Missing Test Range", "example:practice_reflex"), "missing source mission blocks registration")
	if implant != null:
		Global.implants.purchased_implants.erase("example:practice_reflex")
		check(implant.legs and implant.speed_bonus == 1.0 and implant.price == 1000, "slot, stat and price applied")
		check(implant.hidden and not Global.implants.purchased_implants.has("example:practice_reflex"), "discoverable implant starts hidden and unowned")
		var pickup = load("res://MOD_CONTENT/CruS Online/implants/examples/PracticeReflexPickup.tscn").instance()
		check(pickup != null and pickup.get_node("Area")._purchase_key() == "example:practice_reflex", "map pickup instantiates with stable implant ID")
		var menu = Global.menu.get_node("Character_Menu/Character_Container")
		check(pickup.get_node("Area")._grant() == implant, "pickup grants registered implant")
		check(Global.implants.purchased_implants.has("example:practice_reflex"), "pickup discovers without payment")
		check(not menu._implant_is_undiscovered(implant), "discovery reveals menu entry")
		check(Global.save().implants_unlocked.has("example:practice_reflex"), "discovery persists in save data")
		Global.implants.purchased_implants.erase("example:practice_reflex")
		pickup.free()
		var fgd = load("res://addons/qodot/game-definitions/fgd/qodot_fgd.tres")
		var point_found = false
		for point in fgd.entity_definitions:
			if point.get("classname") == "Practice_Reflex_Implant":
				point_found = true
		check(point_found, "TrenchBroom point class registered")
		check(menu._page_implant_indices(2).has(Global.implants.IMPLANTS.find(implant)), "custom page lists implant")
		check(menu._purchase_key(implant) == "example:practice_reflex", "purchase key is stable ID")
		var ingame_menu = load("res://MOD_CONTENT/CruS Online/compatibility/modbase/Implant_Menu_Ingame.gd").new()
		ingame_menu.IMPLANTS = Global.implants.IMPLANTS
		check(ingame_menu._purchase_key(Global.implants.IMPLANTS.find(implant)) == "example:practice_reflex", "Mod Base menu uses stable purchase ID")
		ingame_menu.free()
		var state = preload("res://MOD_CONTENT/CruS Online/ImplantNetwork.gd").resolve(Global.implants.IMPLANTS, ["N/A", "N/A", "N/A", implant.i_name])
		check(state != null and state.custom_implants.has("example:practice_reflex"), "equipped ID resolves for peers")
		Global.implants.purchased_implants.append(menu._purchase_key(implant))
		check(Global.save().implants_unlocked.has("example:practice_reflex"), "purchase persists in save data")
		Global.implants.purchased_implants.erase("example:practice_reflex")
		registry._call_behavior(implant, "on_equip", [null, implant])
		check(registry.behaviors["example:practice_reflex"].equip_count == 1, "behavior hook invoked")
		var catalog_size = Global.implants.IMPLANTS.size()
		for extra_index in range(62):
			var extra = Global.implants.create_custom_implant()
			extra.custom_id = "example:page_" + str(extra_index)
			extra.i_name = "Page Example " + str(extra_index)
			Global.implants.IMPLANTS.append(extra)
		check(menu._available_pages().size() == 4 and menu._page_implant_indices(3).size() == 1, "custom catalog spans multiple pages")
		Global.implants.IMPLANTS.resize(catalog_size)
	print("IMPLANT_API_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
