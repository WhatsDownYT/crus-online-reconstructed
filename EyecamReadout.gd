extends Control

const GREEN = Color(0, 1, 0)
var labels = []
var icons = []
var previews = []
var weapon_ids = [null, null]
var background
var typing = 0.0
var complete = false
var pro = false
var font
var details_typing = 0.0
var matrix_value

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = Global.UI.get_node("UI_HBOX/TextureRect/Health").get_font("font").duplicate()
	if font is DynamicFont:
		font.size = 19
		font.extra_spacing_char = -1
		font.extra_spacing_top = 0
		font.extra_spacing_bottom = 0
		font.outline_size = 0
	background = ColorRect.new()
	background.color = Color.black
	background.rect_position = Vector2.ZERO
	background.rect_size = Vector2(271, 128)
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	for y in [0, 22, 44, 89, 111]:
		var label = Label.new()
		label.mouse_filter = MOUSE_FILTER_IGNORE
		label.rect_position = Vector2(0, y)
		label.add_font_override("font", font)
		label.add_color_override("font_color", GREEN)
		label.add_color_override("font_color_shadow", Color.black)
		label.add_constant_override("shadow_offset_x", 1)
		label.add_constant_override("shadow_offset_y", 1)
		add_child(label)
		labels.append(label)
	matrix_value = labels[4].duplicate()
	matrix_value.rect_position.x = font.get_string_size("MATRIX : ").x
	add_child(matrix_value)
	for slot in range(4):
		var shadow = ColorRect.new()
		shadow.color = GREEN
		shadow.rect_size = Vector2(51, 51)
		shadow.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(shadow)
		var icon = TextureRect.new()
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.rect_size = Vector2(51, 51)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(icon)
		icons.append([icon, shadow])

func _make_previews():
	if not previews.empty(): return
	for slot in range(2):
		var source = Global.menu.get_node("Weapon" + str(slot + 1) + "_Viewport")
		var viewport = source.duplicate()
		viewport.name = "ScanWeapon" + str(slot)
		viewport.set_script(null)
		viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
		add_child(viewport)
		var image = TextureRect.new()
		image.expand = true
		image.rect_position = Vector2(slot * 137, 145)
		image.rect_size = Vector2(137, 68)
		image.mouse_filter = MOUSE_FILTER_IGNORE
		image.texture = viewport.get_texture()
		add_child(image)
		previews.append([viewport, image])

func display(bounds, data, ready, hijack, delta):
	pro = hijack
	typing += delta * 130.0
	rect_position = bounds.position + Vector2(bounds.size.x + 11, 0)
	var heading = "HIJACKING BIOLOGICAL SYSTEMS" if pro else "ANALYZING BIOLOGICAL DATABASE"
	labels[0].text = heading.substr(0, int(typing))
	labels[1].text = "...".substr(0, max(0, int(typing) - heading.length()))
	complete = ready and not pro and not data.empty()
	background.rect_size.y = 128 if complete else 42
	var strings = ["MERIT : $" + str(data.get("money", 0)), "HEALTH : " + str(data.get("health", 0)), "MATRIX : " + ("DEATH" if data.get("death_mode", false) else "LIFE")]
	if complete: details_typing += delta * 160.0
	var remaining = int(details_typing)
	for index in range(3):
		labels[index + 2].visible = complete
		labels[index + 2].text = "MATRIX : " if index == 2 else strings[index]
		labels[index + 2].visible_characters = max(0, remaining)
		remaining -= strings[index].length()
	matrix_value.visible = complete
	matrix_value.text = "DEATH" if data.get("death_mode", false) else "LIFE"
	matrix_value.visible_characters = max(0, int(details_typing) - strings[0].length() - strings[1].length() - 9)
	matrix_value.add_color_override("font_color", Color(1, 0, 1) if data.get("death_mode", false) else GREEN)
	var names = data.get("implants", [])
	for slot in range(4):
		var icon = icons[slot][0]
		var shadow = icons[slot][1]
		icon.visible = complete
		shadow.visible = complete
		icon.rect_position = Vector2(-bounds.size.x - 77, slot * 57)
		shadow.rect_position = icon.rect_position + Vector2(1, 1)
		if complete:
			icon.texture = Global.implants.empty_implant.texture
			if slot < names.size():
				for implant in Global.implants.IMPLANTS:
					if implant.i_name == names[slot]:
						icon.texture = implant.texture
						break
	if complete:
		_make_previews()
	var weapons = data.get("weapons", [null, null])
	for slot in range(previews.size()):
		var viewport = previews[slot][0]
		var gun = viewport.get_node("Weapon")
		var weapon_id = weapons[slot] if slot < weapons.size() else null
		var shown = complete and weapon_id != null and weapon_id >= 0 and weapon_id < gun.MESH.size()
		previews[slot][1].visible = shown
		viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS if shown else Viewport.UPDATE_DISABLED
		for index in range(gun.MESH.size()):
			gun.MESH[index].visible = shown and index == weapon_id
		if shown: gun.rotation.y += delta
	var debug_capture = Global.get_node_or_null("DebugCapture")
	visible = not (is_instance_valid(debug_capture) and debug_capture.ui_hidden) and (not pro or Engine.get_idle_frames() % 2 == 0)

func conceal():
	hide()
	for preview in previews:
		preview[0].render_target_update_mode = Viewport.UPDATE_DISABLED
