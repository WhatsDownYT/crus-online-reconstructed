extends Control

const DURATION = 15.0
const SLOTS = ["head_implant", "torso_implant", "arm_implant", "leg_implant"]
var remaining = 0.0
var elapsed = 0.0
var kind = ""
var value = -1
var affected = ""
var original = null
var blocked = null
var mission = null
var font

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 90
	font = Global.UI.get_node("UI_HBOX/TextureRect/Health").get_font("font").duplicate() if is_instance_valid(Global.UI) else load("res://Fonts/mingliut.tres").duplicate()
	if font is DynamicFont:
		font.outline_size = 0
		font.extra_spacing_char = 0
		font.extra_spacing_top = 0
		font.extra_spacing_bottom = 0
	hide()

func weapon_jammed(weapon_id):
	return remaining > 0 and kind == "weapon" and weapon_id == value

func apply(category, index):
	if not get_parent()._available(): return
	if category == "implant" and (index < 0 or index >= SLOTS.size()): return
	if category == "weapon" and not index in [Global.player.weapon.weapon1, Global.player.weapon.weapon2]: return
	clear()
	kind = category
	value = index
	mission = Global.current_scene
	if kind == "implant":
		original = Global.implants.get(SLOTS[value])
		if original.i_name == "N/A":
			kind = ""
			return
		affected = original.i_name.to_lower()
		blocked = Global.implants.disabled_copy(original)
		Global.implants.set(SLOTS[value], blocked)
		_refresh_implants()
	else:
		var menu = Global.menu.menu[Global.menu.WEAPON_SELECT]
		affected = menu.get_child(value + 1).name.to_lower() if menu.get_child_count() > value + 1 else "weapon"
		if Global.player.weapon.current_weapon == value:
			Global.player.weapon.anim.stop()
			var audio = Global.player.weapon.audio[value]
			if audio is Array:
				for sound in audio:
					if is_instance_valid(sound): sound.stop()
			elif is_instance_valid(audio):
				audio.stop()
			Global.player.weapon.flash_light_switch = false
			if is_instance_valid(Global.player.weapon.fishing_hook):
				Global.player.weapon.fishing_hook.queue_free()
				Global.player.weapon.fishing_hook = null
	remaining = DURATION
	elapsed = 0.0
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	show()
	update()

func _refresh_implants():
	if not is_instance_valid(Global.player) or not Global.player.is_inside_tree(): return
	var health = Global.player.health
	Global.player.update_implants()
	Global.player.health = health
	Global.player.UI.set_health(health)
	var position = Global.player.global_transform.origin
	Global.player.get_parent().scale = Vector3.ONE * (0.1 if Global.implants.head_implant.shrink else 1.0)
	Global.player.global_transform.origin = position
	var weapon = Global.player.weapon
	if not Global.implants.arm_implant.grapple:
		weapon.grapple_flag = false
		for orb in Global.player.grapple_orbs:
			if is_instance_valid(orb): orb.queue_free()
		Global.player.grapple_orbs = []
	if not Global.implants.arm_implant.multiplayer_augmented_arms and weapon.holding_multiplayer_player:
		Global.get_node("Multiplayer").request_player_release(Vector3.ZERO)

func clear():
	if original != null and blocked != null and value >= 0 and value < SLOTS.size():
		if Global.implants.get(SLOTS[value]) == blocked:
			Global.implants.set(SLOTS[value], original)
			_refresh_implants()
	original = null
	blocked = null
	kind = ""
	value = -1
	remaining = 0.0
	elapsed = 0.0
	hide()
	update()

func _process(delta):
	if remaining <= 0: return
	if mission != Global.current_scene or not get_parent()._available():
		clear()
		return
	remaining = max(0.0, remaining - delta)
	elapsed += delta
	if remaining <= 0:
		clear()
	else:
		update()

func _draw():
	if remaining <= 0: return
	var capture = Global.get_node_or_null("DebugCapture")
	if is_instance_valid(capture) and capture.ui_hidden: return
	var size = get_viewport_rect().size
	var factor = size.y / 720.0
	var red = Color(1, 0, 0)
	for index in range(3):
		var intervals = [0.27, 0.39, 0.53]
		if int((elapsed + index * 0.13) / intervals[index]) % 2 == 0:
			var inset = Vector2((17 + index * 22) * factor, (9 + index * 13) * factor)
			var frame = Rect2(inset, size - inset * 2)
			draw_rect(Rect2(frame.position + Vector2(1, 1), frame.size), Color.black, false, 1.0)
			draw_rect(frame, red, false, 1.0)
	var panel = Rect2(Vector2(80, 46) * factor, Vector2(size.x * 0.432, size.y - 94 * factor))
	if font is DynamicFont: font.size = max(1, int(24 * factor))
	var lines = ["HIJACKING IN PROGRESS", "...", "AFFECTED : " + affected, "", "UNAUTHORIZED USAGE OF AFFECTED EQUIPMENT AFTER", "SECURITY INTERVENTION MAY BE INTERPRETED AS", "MALICIOUS COMPLIANCE AND WILL BE REPORTED", "TO LOCAL AUTHORITIES."]
	var characters = int(elapsed * 160)
	if Engine.get_idle_frames() % 2 == 0:
		for index in range(lines.size()):
			var position = panel.position + Vector2(0, (17 + index * 29) * factor)
			var text = lines[index].substr(0, max(0, characters))
			draw_string(font, position + Vector2(1, 1), text, Color.black)
			draw_string(font, position, text, red)
			characters -= lines[index].length()
	var footer_position = Vector2(panel.position.x, panel.end.y - 5 * factor)
	draw_string(font, footer_position + Vector2(1, 1), "SECURITY, REDEFINED", Color.black)
	draw_string(font, footer_position, "SECURITY, REDEFINED", red)
