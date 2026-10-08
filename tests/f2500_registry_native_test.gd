extends Node

var failures = 0

func check(value, label):
	print("F2500_CHECK ", label, " = ", value)
	if not value:
		failures += 1

func _ready():
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6.0), "timeout")
	var registry = Global.get_node_or_null("WeaponRegistry")
	check(registry != null, "registry exists")
	if registry == null:
		get_tree().quit(1)
		return
	registry.finalize()
	var index = registry.index_for("herschel:f2500")
	check(index == 29, "packaged weapon registered after vanilla weapons")
	var definition = registry.definition_for(index)
	check(definition != null and definition.magazine_size == 30 and definition.starting_reserve == 135 and definition.damage == 15, "F2500 definition loaded")
	check(definition != null and definition.icon != null and definition.fire_sound != null and definition.launcher_sound != null, "F2500 art and audio packaged")
	check(definition != null and definition.world_model != null and definition.view_model != null and definition.remote_model != null, "F2500 view models packaged")
	check(Global.WEAPONS_UNLOCKED.size() >= 30 and Global.WEAPONS_UNLOCKED[index], "test weapon unlocked")
	check(Global.menu.custom_weapon_buttons.size() == 1, "custom weapon menu button added")
	if Global.menu.custom_weapon_buttons.size() > 0:
		Global.menu._weapon_detail_button(Global.menu.custom_weapon_buttons[0])
		check(Global.menu.weapon_menu_portrait.texture == definition.icon, "large portrait uses menu icon")
	check(Global.menu.weapon_page_label != null, "weapon page label exists")
	check(Global.menu.get_node("Weapon1_Viewport/Weapon").MESH.size() >= 30, "first preview model registered")
	check(Global.menu.get_node("Weapon2_Viewport/Weapon").MESH.size() >= 30, "second preview model registered")
	if definition != null and definition.world_model != null:
		var packaged_model = definition.world_model.instance()
		check(Global.menu.get_node("Weapon1_Viewport/Weapon").MESH[index].mesh == packaged_model.mesh, "preview uses bundled mesh")
		packaged_model.free()
	check(InputMap.has_action("Shoot_Secondary") and InputMap.get_action_list("Shoot_Secondary").size() > 0, "secondary weapon action exists")
	var aim_parent = Spatial.new()
	add_child(aim_parent)
	var aim_ray = RayCast.new()
	aim_ray.cast_to = Vector3(0, 0, 2000)
	aim_parent.add_child(aim_ray)
	aim_parent.rotation = Vector3(0.35, 1.2, 0)
	var behavior = definition.behavior.new()
	var direction = behavior.launch_direction(aim_ray)
	check(direction.dot(aim_ray.global_transform.basis.z.normalized()) > 0.999, "launcher follows rotated rifle aim")
	aim_parent.free()
	var grenade = load("res://MOD_CONTENT/CruS Online/weapons/herschel_f2500/F2500Grenade.tscn")
	check(grenade != null, "packaged grenade scene loads")
	var pickup_scene = load("res://MOD_CONTENT/CruS Online/weapons/herschel_f2500/F2500Pickup.tscn")
	check(pickup_scene != null, "packaged pickup scene loads")
	if pickup_scene != null:
		var pickup = pickup_scene.instance()
		check(pickup.get_node("Area").current_weapon == index, "map pickup uses F2500 runtime ID")
		pickup.free()
	var swat_scene = load("res://MOD_CONTENT/CruS Online/weapons/herschel_f2500/F2500SWAT.tscn")
	check(swat_scene != null, "packaged SWAT scene loads")
	if swat_scene != null:
		var swat = swat_scene.instance()
		check(swat.get_node("Body/Rotation_Helper/Weapon").current_weapon == index, "SWAT uses F2500")
		swat.free()
	var fgd = load("res://addons/qodot/game-definitions/fgd/qodot_fgd.tres")
	var has_weapon_point = false
	var has_swat_point = false
	for entity in fgd.entity_definitions:
		if entity.get("classname") == "Herschel_F2500":
			has_weapon_point = true
		if entity.get("classname") == "Herschel_F2500_SWAT":
			has_swat_point = true
	check(has_weapon_point, "TrenchBroom F2500 point registered")
	check(has_swat_point, "TrenchBroom F2500 SWAT point registered")
	print("F2500_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
