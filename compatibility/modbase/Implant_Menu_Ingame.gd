extends HBoxContainer

var EQUIPMENT_BUTTONS:Array
enum {HEAD, TORSO, LEG, ARM}
var IMPLANTS
var confirmed = false
var cancel = false
var hover_info
var debug = true
var prev_footstep = null
var orbarms: PackedScene
var orig_env = {}

func _purchase_key(index):
	var implant = IMPLANTS[index]
	return implant.custom_id if not implant.custom_id.empty() else implant.i_name

func update_implant_slots():
	if _online_blocked():
		return
	$TextureRect / Head_Button.texture_normal = Global.implants.head_implant.texture
	$TextureRect / Torso_Button.texture_normal = Global.implants.torso_implant.texture
	$TextureRect / Arm_Button.texture_normal = Global.implants.arm_implant.texture
	$TextureRect / Leg_Button.texture_normal = Global.implants.leg_implant.texture

func reset_implants_state():
	if _online_blocked():
		return
	var gp = Global.player
	var imenu = gp.get_parent().get_node("Stock_Menu/Character_Container/Implant_Menu")
	var leg_implant = Global.implants.leg_implant
	var arm_implant = Global.implants.arm_implant
	var head_implant = Global.implants.head_implant
	var torso_implant = Global.implants.torso_implant


	if arm_implant.regen_ammo:
		gp.weapon.regentimer1 = Timer.new()
		gp.weapon.add_child(gp.weapon.regentimer1)
		gp.weapon.regentimer1.one_shot = true
		gp.weapon.regentimer1.connect("timeout", gp.weapon, "regen_timeout1")
		gp.weapon.regentimer2 = Timer.new()
		add_child(gp.weapon.regentimer2)
		gp.weapon.regentimer2.one_shot = true
		gp.weapon.regentimer2.connect("timeout", gp.weapon, "regen_timeout2")
	else:
		if is_instance_valid(gp.weapon.regentimer1):
			gp.weapon.regentimer1.queue_free()
		if is_instance_valid(gp.weapon.regentimer2):
			gp.weapon.regentimer2.queue_free()


	gp.weapon.IM2.clear()


	gp.weapon.kicktimer = 51
	gp.weapon.kickflag = false
	gp.friction_disabled = false


	if !is_instance_valid(gp.get_node_or_null("NV")):
		gp.add_child(load(Mod.get_node("CruS Mod Base").modpath + "/scenes/NV.tscn").instance())
	gp.get_node("NV").hide()
	gp.hazmat = false
	if head_implant.nightvision or head_implant.nightmare or head_implant.holy:
		gp.get_node("NV").show()
	gp.shader_screen.material.set_shader_param("scope", head_implant.nightvision)
	gp.shader_screen.material.set_shader_param("nightmare_vision", head_implant.nightmare)
	gp.shader_screen.material.set_shader_param("holy_mode", head_implant.holy)


	var player_gpos = Vector3.ZERO + gp.global_transform.origin
	if Global.implants.head_implant.shrink:
		gp.get_parent().scale = Vector3(0.1, 0.1, 0.1)
	else:
		gp.get_parent().scale = Vector3(1, 1, 1)
	gp.global_transform.origin = player_gpos
















































	gp.jump_bonus = leg_implant.jump_bonus + torso_implant.jump_bonus + head_implant.jump_bonus + arm_implant.jump_bonus


	if gp.weapon.has_node("orbarms"):
		gp.weapon.get_node("orbarms").hide()
		gp.health = clamp(gp.health, 0, 100)
		gp.UI.set_health(gp.health)
		gp.get_node("Foot_Step").stream = load("res://Sfx/wood01.wav")
		match Global.player.weapon.held_weapon:
			1:
				gp.weapon.current_weapon = gp.weapon.weapon1
			2:
				gp.weapon.current_weapon = gp.weapon.weapon2
		if torso_implant.orbsuit:
			gp.orb = true
		else:
			gp.orb = false
		gp.weapon.orb = gp.orb
		if gp.orb:
			gp.weapon.get_node("orbarms").show()
			gp.weapon.weapon1 = null
			gp.weapon.weapon2 = null
			gp.weapon.current_weapon = null
			gp.weapon.anim.stop()
			gp.weapon.anim.play("Nogun", - 1, 100)
			gp.health = 200
			gp.UI.set_health(gp.health)
			gp.jump_bonus += 3
			gp.speed_bonus += 1
			print("orb walk ", gp.get_node("Foot_Step").stream.resource_path)
			if gp.get_node("Foot_Step").stream.resource_path != "res://Sfx/orbwalk.wav":
				prev_footstep = gp.get_node("Foot_Step").stream
			gp.get_node("Foot_Step").stream = load("res://Sfx/orbwalk.wav")

	gp.speed_bonus = leg_implant.speed_bonus + torso_implant.speed_bonus + head_implant.speed_bonus + arm_implant.speed_bonus
	if Global.husk_mode:
		gp.speed_bonus += 0.25
	if Global.death:
		gp.speed_bonus += 0.1
	gp.armor = clamp(leg_implant.armor + torso_implant.armor + head_implant.armor + arm_implant.armor, 0.5, 1.0)


	if leg_implant.toxic_shield or torso_implant.toxic_shield or arm_implant.toxic_shield or head_implant.toxic_shield or gp.orb:
		gp.hazmat = true


	if torso_implant.terror:
		gp.terrorsuit.show()
		gp.UI.hide()
		gp.shader_screen.material.set_shader_param("scope", true)
	else:
		gp.terrorsuit.hide()
		gp.UI.show()
		gp.shader_screen.material.set_shader_param("scope", head_implant.nightvision)


	if arm_implant.cursed_torch and !Global.hope_discarded:
		Global.set_hope()
	elif !Global.hope_discarded:
		gp.curse_torch.hide()
		gp.curse_torch.light_energy = 0

func _ready():
	if _online_blocked():
		return
	yield (get_tree(), "idle_frame")
	$ConfirmationDialog.get_cancel().connect("pressed", self, "_on_Cancel_Pressed")
	$TextureRect / Arm_Button.connect("pressed", self, "_slot_button_pressed", [ARM])
	$TextureRect / Arm_Button.connect("mouse_entered", self, "_slot_button_entered", [ARM])
	$TextureRect / Leg_Button.connect("pressed", self, "_slot_button_pressed", [LEG])
	$TextureRect / Leg_Button.connect("mouse_entered", self, "_slot_button_entered", [LEG])
	$TextureRect / Head_Button.connect("pressed", self, "_slot_button_pressed", [HEAD])
	$TextureRect / Head_Button.connect("mouse_entered", self, "_slot_button_entered", [HEAD])
	$TextureRect / Torso_Button.connect("pressed", self, "_slot_button_pressed", [TORSO])
	$TextureRect / Torso_Button.connect("mouse_entered", self, "_slot_button_entered", [TORSO])
	hover_info = get_parent().get_parent().get_parent().get_node("Hover_Panel/Hover_Info")
	IMPLANTS = Global.implants.IMPLANTS
	for b in range(64):
		var new_button = TextureButton.new()
		$Equip_Grid.add_child(new_button)
		if b < IMPLANTS.size():
			new_button.name = IMPLANTS[b].i_name
			new_button.texture_normal = IMPLANTS[b].texture
			if !debug and Global.implants.purchased_implants.find(_purchase_key(b)) == - 1:
				new_button.modulate = Color(1, 0, 0)
				if IMPLANTS[b].hidden:
					new_button.modulate = Color(1, 1, 1)
					new_button.texture_normal = load("res://Textures/Menu/mystery.png")
		else:
			new_button.name = "n/a"
			new_button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
		new_button.rect_size = Vector2(64, 64)
		new_button.expand = true

		new_button.connect("pressed", self, "_on_implant_pressed", [b])
		new_button.connect("mouse_entered", self, "_on_mouse_entered", [b])
		new_button.connect("mouse_exited", self, "_on_mouse_exited", [b])
		new_button.size_flags_horizontal = SIZE_EXPAND_FILL
		new_button.size_flags_vertical = SIZE_EXPAND_FILL
		new_button.stretch_mode = TextureButton.STRETCH_SCALE
		EQUIPMENT_BUTTONS.append(new_button)
		reset_implants_state()

func clear_equips():
	if _online_blocked():
		return
	Global.implants.head_implant = Global.implants.empty_implant
	Global.implants.leg_implant = Global.implants.empty_implant
	Global.implants.arm_implant = Global.implants.empty_implant
	Global.implants.torso_implant = Global.implants.empty_implant
	$TextureRect / Head_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
	$TextureRect / Torso_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
	$TextureRect / Leg_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
	$TextureRect / Arm_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")

func _slot_button_pressed(type):
	if _online_blocked():
		return
	match type:
		HEAD:
			$Unequip.play()
			hover_info.get_parent().hide()
			EQUIPMENT_BUTTONS[IMPLANTS.find(Global.implants.head_implant)].modulate = Color(1, 1, 1, 1)
			Global.implants.head_implant = Global.implants.empty_implant
			$TextureRect / Head_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")

		TORSO:
			$Unequip.play()
			EQUIPMENT_BUTTONS[IMPLANTS.find(Global.implants.torso_implant)].modulate = Color(1, 1, 1, 1)
			Global.implants.torso_implant = Global.implants.empty_implant
			$TextureRect / Torso_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
		LEG:
			$Unequip.play()
			EQUIPMENT_BUTTONS[IMPLANTS.find(Global.implants.leg_implant)].modulate = Color(1, 1, 1, 1)
			Global.implants.leg_implant = Global.implants.empty_implant
			$TextureRect / Leg_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
		ARM:
			$Unequip.play()
			EQUIPMENT_BUTTONS[IMPLANTS.find(Global.implants.arm_implant)].modulate = Color(1, 1, 1, 1)
			Global.implants.arm_implant = Global.implants.empty_implant
			$TextureRect / Arm_Button.texture_normal = load("res://Textures/Menu/Empty_Slot.png")
	reset_implants_state()

func _slot_button_entered(type):
	if _online_blocked():
		return
	match type:
		HEAD:
			if Global.implants.head_implant != Global.implants.empty_implant:
				hover_info.get_parent().show()
				_on_mouse_entered(IMPLANTS.find(Global.implants.head_implant))
		TORSO:
			if Global.implants.torso_implant != Global.implants.empty_implant:
				hover_info.get_parent().show()
				_on_mouse_entered(IMPLANTS.find(Global.implants.torso_implant))
		ARM:
			if Global.implants.arm_implant != Global.implants.empty_implant:
				hover_info.get_parent().show()
				_on_mouse_entered(IMPLANTS.find(Global.implants.arm_implant))
		LEG:
			if Global.implants.leg_implant != Global.implants.empty_implant:
				hover_info.get_parent().show()
				_on_mouse_entered(IMPLANTS.find(Global.implants.leg_implant))

func update_buttons():
	if _online_blocked():
		return
	for i in range(min(IMPLANTS.size(), EQUIPMENT_BUTTONS.size())):
		if !debug and IMPLANTS[i].hidden and Global.implants.purchased_implants.find(_purchase_key(i)) != - 1:
			EQUIPMENT_BUTTONS[i].texture_normal = IMPLANTS[i].texture
		elif Global.implants.purchased_implants.find(_purchase_key(i)) == - 1:
			EQUIPMENT_BUTTONS[i].modulate = Color(1, 0, 0)
		if Global.implants.purchased_implants.find(_purchase_key(i)) != - 1 and EQUIPMENT_BUTTONS[i].modulate != Color(0.5, 0.5, 0.5):
			EQUIPMENT_BUTTONS[i].modulate = Color(1, 1, 1)

func _on_mouse_entered(i):
	if _online_blocked():
		return
	if i < IMPLANTS.size():
		if !debug and IMPLANTS[i].hidden and Global.implants.purchased_implants.find(_purchase_key(i)) == - 1:
			hover_info.get_node("Image").show()
			hover_info.get_parent().raise()
			hover_info.get_node("Name").text = "???"
			hover_info.get_node("Hint").text = "Somewhere in this world something is waiting for you."
			hover_info.get_node("Image").texture = load("res://Textures/Menu/mystery.png")
			hover_info.get_parent().show()
			return
		hover_info.get_node("Image").show()
		hover_info.get_parent().raise()
		hover_info.get_node("Name").text = IMPLANTS[i].i_name
		hover_info.get_node("Image").texture = IMPLANTS[i].texture
		var infotext = IMPLANTS[i].explanation
		hover_info.get_node("Hint").text = ""
		if IMPLANTS[i].head:
			hover_info.get_node("Hint").text += "Slot: Head\n"
		if IMPLANTS[i].torso:
			hover_info.get_node("Hint").text += "Slot: Chest\n"
		if IMPLANTS[i].legs:
			hover_info.get_node("Hint").text += "Slot: Legs\n"
		if IMPLANTS[i].arms:
			hover_info.get_node("Hint").text += "Slot: Arms\n"
		if !debug and Global.implants.purchased_implants.find(_purchase_key(i)) == - 1:
			hover_info.get_node("Hint").text += "$" + str(IMPLANTS[i].price) + "\n"
		hover_info.get_node("Hint").show()
		hover_info.get_node("Hint").text += infotext + "\n"
		if IMPLANTS[i].armor != 1:
			hover_info.get_node("Hint").text += "Armor: " + str(100 - IMPLANTS[i].armor * 100, "%") + "\n"
		if IMPLANTS[i].speed_bonus != 0:
			hover_info.get_node("Hint").text += "Speed: " + str(IMPLANTS[i].speed_bonus) + "\n"
		if IMPLANTS[i].jump_bonus != 0:
			hover_info.get_node("Hint").text += "Jump bonus: " + str(IMPLANTS[i].jump_bonus) + "\n"
		hover_info.get_parent().show()

func _on_mouse_exited(i):
	if _online_blocked():
		return
	hover_info.get_node("Image").hide()
	hover_info.get_parent().hide()

func _on_implant_pressed(i):
	if _online_blocked():
		return
	if i < IMPLANTS.size():
		if !debug and IMPLANTS[i].hidden and Global.implants.purchased_implants.find(_purchase_key(i)) == - 1:
			return
		if !debug and Global.implants.purchased_implants.find(_purchase_key(i)) == - 1:
			cancel = false
			if Global.money >= IMPLANTS[i].price:
				$ConfirmationDialog.popup(Rect2(get_global_mouse_position(), Vector2(256, 128)))
				$ConfirmationDialog.dialog_text = "Do you want to purchase " + IMPLANTS[i].i_name + " for $" + str(IMPLANTS[i].price) + "?"
				while confirmed == false and cancel == false:
					yield (get_tree(), "idle_frame")
				confirmed = false
				if cancel == true:
					cancel = false
					return
				cancel = false
				var m = Global.money
				Global.money -= IMPLANTS[i].price
				if Global.money < 0:
					Global.money = m
					return
				if IMPLANTS[i].i_name == "House":
					Global.BONUS_UNLOCK.append("House")
				EQUIPMENT_BUTTONS[i].modulate = Color(1, 1, 1)
				$TextureRect / Money.text = str("$", Global.money)
				Global.implants.purchased_implants.append(_purchase_key(i))
				Global.save_game()
			return

		$Equip.play()
		if IMPLANTS[i].head:
			if Global.implants.head_implant != Global.implants.empty_implant:
				_slot_button_pressed(HEAD)
			Global.implants.head_implant = IMPLANTS[i]
			EQUIPMENT_BUTTONS[i].modulate = Color(0.5, 0.5, 0.5)
			$TextureRect / Head_Button.texture_normal = IMPLANTS[i].texture
		elif IMPLANTS[i].torso:
			if Global.implants.torso_implant != Global.implants.empty_implant:
				_slot_button_pressed(TORSO)
			Global.implants.torso_implant = IMPLANTS[i]
			EQUIPMENT_BUTTONS[i].modulate = Color(0.5, 0.5, 0.5)
			$TextureRect / Torso_Button.texture_normal = IMPLANTS[i].texture
		elif IMPLANTS[i].legs:
			if Global.implants.leg_implant != Global.implants.empty_implant:
				_slot_button_pressed(LEG)
			Global.implants.leg_implant = IMPLANTS[i]
			EQUIPMENT_BUTTONS[i].modulate = Color(0.5, 0.5, 0.5)
			$TextureRect / Leg_Button.texture_normal = IMPLANTS[i].texture
		elif IMPLANTS[i].arms:
			if Global.implants.arm_implant != Global.implants.empty_implant:
				_slot_button_pressed(ARM)
			Global.implants.arm_implant = IMPLANTS[i]
			EQUIPMENT_BUTTONS[i].modulate = Color(0.5, 0.5, 0.5)
			$TextureRect / Arm_Button.texture_normal = IMPLANTS[i].texture
		reset_implants_state()

func _process(delta):
	if _online_blocked():
		return
	if Input.is_action_just_pressed("ui_cancel"):
		cancel = true
	if is_visible():
		var scale = Vector2(get_parent().rect_size.x / 384, get_parent().rect_size.y / 384)
		var btn_size = Vector2(24, 32) * scale
		$TextureRect / Head_Button.rect_size = btn_size
		$TextureRect / Torso_Button.rect_size = btn_size
		$TextureRect / Arm_Button.rect_size = btn_size
		$TextureRect / Leg_Button.rect_size = btn_size
		$TextureRect / Head_Button.rect_position = Vector2(84, 20) * scale
		$TextureRect / Torso_Button.rect_position = Vector2(84, 72) * scale
		$TextureRect / Arm_Button.rect_position = Vector2(42, 140) * scale
		$TextureRect / Leg_Button.rect_position = Vector2(42, 278) * scale


func _on_ConfirmationDialog_confirmed():
	if _online_blocked():
		return
	confirmed = true
func _on_Cancel_Pressed():
	if _online_blocked():
		return
	cancel = true


func _online_blocked():
	var online = Global.get_node_or_null("Multiplayer")
	return online != null and is_instance_valid(online.Extensions) and not online.Extensions.resetting_cheats and online.Extensions.online_selected()
