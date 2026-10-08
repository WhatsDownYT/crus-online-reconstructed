extends Node

var failures = 0

func check(condition, label):
	print("LOADOUT_CHECK ", label, "=", condition)
	if not condition:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(5), "timeout")
	Global.select_save_slot(2)
	Global.WEAPONS_UNLOCKED[2] = true
	Global.WEAPONS_UNLOCKED[3] = true
	var menu = Global.menu
	menu.current_weapon_select = 1
	menu.set_weapon(2)
	menu.current_weapon_select = 2
	menu.set_weapon(3)
	var head = null
	var arms = null
	for implant in Global.implants.IMPLANTS:
		if head == null and implant.head:
			head = implant
		if arms == null and implant.arms:
			arms = implant
	check(head != null and arms != null, "test implants exist")
	if head != null and arms != null:
		Global.implants.purchased_implants.append(head.i_name)
		Global.implants.purchased_implants.append(arms.i_name)
		Global.implants.head_implant = head
		Global.implants.arm_implant = arms
	Global.save_game()
	var file = File.new()
	check(file.open(Global.slot_path("savegame.save"), File.READ) == OK, "slot file written")
	var saved = parse_json(file.get_as_text())
	file.close()
	print("LOADOUT_SAVED_WEAPONS ", saved.get("selected_weapons", []))
	check(int(saved.get("selected_weapons", [0, 0])[0]) == 2 and int(saved.get("selected_weapons", [0, 0])[1]) == 3, "weapon indices stored")
	check(saved.get("equipped_implants", {}).get("head", "") == head.i_name, "implant name stored")
	menu.current_weapon_select = 1
	menu.set_weapon(0)
	menu.current_weapon_select = 2
	menu.set_weapon(1)
	Global.implants.head_implant = Global.implants.empty_implant
	Global.implants.arm_implant = Global.implants.empty_implant
	Global.load_game()
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	check(menu.weapon_1 == 2 and menu.weapon_2 == 3, "weapon loadout restored")
	check(Global.implants.head_implant == head and Global.implants.arm_implant == arms, "implants restored")
	var selector = load("res://MOD_CONTENT/CruS Online/SaveSlotSelector.gd").new()
	add_child(selector)
	selector._show_slot(2)
	check(selector.weapon_icons[0].texture != null and selector.weapon_icons[1].texture != null, "weapon icons displayed")
	check(selector.implant_icons["head"].texture == head.texture and selector.implant_icons["arm"].texture == arms.texture, "implant icons displayed")
	yield(get_tree(), "idle_frame")
	var preview = get_viewport().get_texture().get_data()
	preview.flip_y()
	preview.save_png("res://save_loadout_preview.png")
	print("SAVE_LOADOUT_TEST_RESULT failures=", failures)
	get_tree().quit(1 if failures else 0)
