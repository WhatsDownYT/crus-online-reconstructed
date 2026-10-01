extends Control

const PROFILE_STORE = preload("res://MOD_CONTENT/CruS Online/ProfileStore.gd")
const PLAYER_MODEL_SCENE = preload("res://MOD_CONTENT/CruS Online/player_model/player_model.tscn")
const FONT_PATH = "res://Fonts/gamefont(1).ttf"
const HEADER_FONT_PATH = "res://Fonts/MingLiU-ExtB-01.ttf"
const OUTFITS = [
	{"name": "Default", "path": "res://Textures/Misc/mainguy_clothes.png"},
	{"name": "Worker", "path": "res://Textures/NPC/Enemy_Worker.png"},
	{"name": "Nude (FREE???)", "path": "res://Textures/NPC/Enemy_Nude.png"},
	{"name": "Cultist", "path": "res://Textures/NPC/cultist_civilian.png"},
	{"name": "Boss guy", "path": "res://Textures/NPC/bosssguy_clothes.png"},
	{"name": "Assassin", "path": "res://Textures/NPC/Enemy_Assassin.png"},
	{"name": "Assassin (Alt)", "path": "res://Textures/NPC/Enemy_Assassin_Alt.png"},
	{"name": "Civilian", "path": "res://Textures/NPC/Enemy_Civilian2.png"},
	{"name": "Cop", "path": "res://Textures/NPC/Enemy_Cop1.png"},
	{"name": "Kevin", "path": "res://Textures/NPC/Enemy_Kevin.png"},
	{"name": "CEO", "path": "res://Textures/NPC/Objective_CEO.png"}
]
const OUTFIT_SCENES = {
	"res://Textures/NPC/Enemy_Worker.png": "res://Entities/Enemies/E_Civilian_Worker.tscn",
	"res://Textures/NPC/Enemy_Nude.png": "res://Entities/Enemies/E_Civilian_Nude.tscn",
	"res://Textures/NPC/cultist_civilian.png": "res://Entities/Enemies/E_Civilian_Cultist_1.tscn",
	"res://Textures/NPC/bosssguy_clothes.png": "res://Entities/Enemies/E_Boss_Life.tscn",
	"res://Textures/NPC/Enemy_Assassin.png": "res://Entities/Enemies/E_Assassin.tscn",
	"res://Textures/NPC/Enemy_Assassin_Alt.png": "res://Entities/Enemies/E_Assassin_Weak.tscn",
	"res://Textures/NPC/Enemy_Civilian2.png": "res://Entities/Enemies/E_Civilian2.tscn",
	"res://Textures/NPC/Enemy_Cop1.png": "res://Entities/Enemies/E_Cop_Shotgun.tscn",
	"res://Textures/NPC/Enemy_Kevin.png": "res://Entities/Enemies/E_Kevin.tscn",
	"res://Textures/NPC/Objective_CEO.png": "res://Entities/Enemies/Obj_CEO.tscn"
}

var profile_store = PROFILE_STORE.new()
var initialized = false
var multiplayer_node = null
var title_font
var header_font
var body_font
var value_font
var center_panel
var right_panel
var online_mode_select
var name_edit
var color_swatch
var color_controls
var color_sliders = {}
var preview_holder
var preview_viewport
var preview_world
var preview_scene_root
var preview_camera
var preview_mask_camera
var preview_model
var preview_display
var preview_mask_viewport
var preview_mask_model
var preview_mask_display
var preview_spin = 0.0
var stat_labels = {}
var profile_labels = {}
var selected_outfit_index = 0
var color_syncing = false

func _ready():
	name = "StatisticsScreen"
	mouse_filter = MOUSE_FILTER_STOP
	rect_size = Vector2(1280, 720)
	rect_scale = Vector2(0.88, 0.88)
	rect_position = Vector2(76.8, 43.2)
	hide()
	set_process(false)

func open():
	multiplayer_node = Global.get_node_or_null("Multiplayer")
	if not initialized:
		_build_ui()
		_build_preview()
		initialized = true
	_load_current_profile()
	_refresh()
	show()
	set_process(true)
	raise()

func go():
	hide()
	set_process(false)

func _process(delta):
	if not visible or preview_model == null:
		return
	preview_spin += delta * 0.45
	var angle = sin(preview_spin) * 0.9
	preview_camera.translation = Vector3(sin(angle) * 2.45, 1.12, cos(angle) * 2.45)
	preview_camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	preview_mask_camera.global_transform = preview_camera.global_transform

func _input(event):
	if visible and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		if name_edit.has_focus() and not name_edit.get_global_rect().has_point(event.global_position):
			name_edit.release_focus()
		if color_controls.visible and not color_controls.get_global_rect().has_point(event.global_position) and not color_swatch.get_global_rect().has_point(event.global_position):
			color_controls.hide()

func _build_ui():
	title_font = _font(29)
	header_font = _font(20, HEADER_FONT_PATH)
	body_font = _font(17)
	value_font = _font(17)
	rect_size = Vector2(1280, 720)
	center_panel = _panel(Vector2(93, 24), Vector2(540, 660))
	right_panel = _panel(Vector2(647, 24), Vector2(540, 660))
	add_child(center_panel)
	add_child(right_panel)
	_build_center_panel()
	_build_right_panel()

func _build_center_panel():
	var title = _section_title("PROFILE")
	title.rect_position = Vector2(12, 10)
	center_panel.add_child(title)
	name_edit = LineEdit.new()
	name_edit.rect_position = Vector2(12, 44)
	name_edit.rect_size = Vector2(center_panel.rect_size.x - 68, 32)
	name_edit.max_length = 15
	name_edit.align = LineEdit.ALIGN_CENTER
	name_edit.add_font_override("font", body_font)
	name_edit.add_color_override("font_color", Color(0.95, 0.93, 0.82))
	name_edit.add_color_override("cursor_color", Color(0.0, 1.0, 0.0))
	name_edit.add_stylebox_override("normal", _slot_style())
	name_edit.add_stylebox_override("focus", _slot_style(Color(0.04, 0.58, 0.12)))
	name_edit.connect("text_entered", self, "_on_name_committed")
	name_edit.connect("focus_exited", self, "_on_name_focus_exited")
	center_panel.add_child(name_edit)
	color_swatch = ColorRect.new()
	color_swatch.rect_position = Vector2(center_panel.rect_size.x - 44, 44)
	color_swatch.rect_size = Vector2(32, 32)
	color_swatch.mouse_filter = MOUSE_FILTER_STOP
	color_swatch.connect("gui_input", self, "_on_color_swatch_input")
	center_panel.add_child(color_swatch)
	color_controls = Panel.new()
	color_controls.rect_position = Vector2(12, 80)
	color_controls.rect_size = Vector2(center_panel.rect_size.x - 24, 112)
	color_controls.add_stylebox_override("panel", _slot_style())
	center_panel.add_child(color_controls)
	for component in ["R", "G", "B"]:
		var index = ["R", "G", "B"].find(component)
		var caption = _label(component, body_font, Color(1, 1, 1))
		caption.rect_position = Vector2(10, 6 + index * 34)
		caption.rect_size = Vector2(24, 28)
		color_controls.add_child(caption)
		var slider = HSlider.new()
		slider.rect_position = Vector2(40, 6 + index * 34)
		slider.rect_size = Vector2(color_controls.rect_size.x - 52, 28)
		slider.min_value = 0
		slider.max_value = 255
		slider.step = 1
		slider.connect("value_changed", self, "_on_color_changed")
		color_controls.add_child(slider)
		color_sliders[component] = slider
	color_controls.hide()
	preview_holder = Panel.new()
	preview_holder.rect_position = Vector2(12, 82)
	preview_holder.rect_size = Vector2(center_panel.rect_size.x - 24, 561)
	preview_holder.add_stylebox_override("panel", _slot_style())
	center_panel.add_child(preview_holder)
	preview_display = TextureRect.new()
	preview_display.rect_size = preview_holder.rect_size
	preview_display.expand = true
	preview_display.stretch_mode = TextureRect.STRETCH_SCALE
	preview_display.mouse_filter = MOUSE_FILTER_STOP
	preview_display.connect("gui_input", self, "_on_preview_input")
	preview_display.connect("mouse_exited", self, "_on_preview_exited")
	preview_holder.add_child(preview_display)
	preview_holder.rect_clip_content = true
	preview_mask_display = TextureRect.new()
	preview_mask_display.rect_size = preview_holder.rect_size
	preview_mask_display.expand = true
	preview_mask_display.stretch_mode = TextureRect.STRETCH_SCALE
	preview_mask_display.mouse_filter = MOUSE_FILTER_IGNORE
	var outline_material = ShaderMaterial.new()
	outline_material.shader = load("res://MOD_CONTENT/CruS Online/effects/statistics_outline.shader")
	preview_mask_display.material = outline_material
	preview_holder.add_child(preview_mask_display)
	_build_body_overlay()

func _build_body_overlay():
	var title = _section_title("BODY")
	title.rect_position = Vector2(12, 10)
	preview_holder.add_child(title)
	var y = 40
	stat_labels.armor = _body_row(y, "ARMOR")
	y += 28
	stat_labels.speed = _body_row(y, "MOVE SPEED")
	y += 28
	stat_labels.speed_bonus = _body_row(y, "SPEED")
	y += 28
	stat_labels.jump = _body_row(y, "JUMP")
	y += 28
	stat_labels.matrix = _body_row(y, "MATRIX")

func _body_row(y, title):
	var left = _label(title, body_font, Color(0.96, 0.96, 0.92))
	left.rect_position = Vector2(12, y)
	left.rect_size = Vector2(190, 24)
	left.add_color_override("font_color_shadow", Color(0, 0, 0))
	left.add_constant_override("shadow_offset_x", 1)
	left.add_constant_override("shadow_offset_y", 1)
	preview_holder.add_child(left)
	var right = _label("--", value_font, Color(0.1, 1, 0.1))
	right.rect_position = Vector2(preview_holder.rect_size.x - 192, y)
	right.rect_size = Vector2(180, 24)
	right.align = Label.ALIGN_RIGHT
	right.add_color_override("font_color_shadow", Color(0, 0, 0))
	right.add_constant_override("shadow_offset_x", 1)
	right.add_constant_override("shadow_offset_y", 1)
	preview_holder.add_child(right)
	return right

func _build_right_panel():
	var title = _section_title("STATS")
	title.rect_position = Vector2(12, 10)
	right_panel.add_child(title)
	var y = 42
	profile_labels.completion = _stat_row(right_panel, y, "COMPLETION")
	y += 32
	profile_labels.money = _stat_row(right_panel, y, "MONEY")
	profile_labels.money.rect_position.x = 96
	profile_labels.money.rect_size.x = right_panel.rect_size.x - 126
	y += 32
	profile_labels.deaths = _stat_row(right_panel, y, "DEATHS")
	y += 32
	profile_labels.dead_civs = _stat_row(right_panel, y, "KILLS")
	y += 32
	profile_labels.play_time = _stat_row(right_panel, y, "PLAYTIME")
	y += 32
	profile_labels.weapons = _stat_row(right_panel, y, "WEAPONS")
	y += 32
	profile_labels.equipment = _stat_row(right_panel, y, "EQUIPMENT")
	y += 32
	profile_labels.fish = _stat_row(right_panel, y, "FISH COLLECTED")
	y += 32
	profile_labels.organs = _stat_row(right_panel, y, "BODY PARTS")
	y += 32
	profile_labels.goals = _stat_row(right_panel, y, "GOALS")
	y += 42
	var online_title = _section_title("ONLINE STATS")
	online_title.rect_position = Vector2(12, y)
	right_panel.add_child(online_title)
	y += 32
	online_mode_select = OptionButton.new()
	online_mode_select.rect_position = Vector2(10, y)
	online_mode_select.rect_size = Vector2(right_panel.rect_size.x - 20, 32)
	online_mode_select.add_item("TOTAL")
	online_mode_select.add_item("DEATHMATCH")
	online_mode_select.add_item("COUNTER-OPPS")
	online_mode_select.select(0)
	var lobby_type = multiplayer_node.get_node_or_null("Menu/CenterContainer/TabContainer/Host/VBoxContainer/LobbyType/TypeSelect")
	if lobby_type != null:
		online_mode_select.theme = lobby_type.theme
	online_mode_select.add_font_override("font", body_font)
	online_mode_select.add_color_override("font_color", Color(0.1, 1, 0.1))
	online_mode_select.add_stylebox_override("normal", _slot_style())
	online_mode_select.add_stylebox_override("hover", _slot_style(Color(0.1, 1, 0.1)))
	online_mode_select.add_stylebox_override("pressed", _slot_style(Color(0.1, 1, 0.1)))
	online_mode_select.connect("item_selected", self, "_on_online_mode_selected")
	right_panel.add_child(online_mode_select)
	y += 38
	profile_labels.player_kills = _stat_row(right_panel, y, "PLAYER KILLS")
	y += 32
	profile_labels.wins = _stat_row(right_panel, y, "WINS")
	y += 32
	profile_labels.losses = _stat_row(right_panel, y, "LOSSES")

func _build_preview():
	preview_viewport = Viewport.new()
	preview_viewport.size = preview_holder.rect_size * 2
	preview_viewport.usage = Viewport.USAGE_3D
	preview_viewport.msaa = Viewport.MSAA_4X
	preview_viewport.own_world = true
	preview_viewport.render_target_v_flip = true
	preview_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	preview_holder.add_child(preview_viewport)
	preview_world = World.new()
	preview_viewport.world = preview_world
	preview_scene_root = Spatial.new()
	preview_viewport.add_child(preview_scene_root)
	var environment = Environment.new()
	var sky = PanoramaSky.new()
	sky.panorama = load("res://Textures/sky3.png")
	environment.background_mode = Environment.BG_SKY
	environment.background_sky = sky
	environment.ambient_light_color = Color(0.54902, 0.309804, 0.164706)
	environment.ambient_light_sky_contribution = 0.0
	environment.ambient_light_energy = 0.75
	var world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	preview_scene_root.add_child(world_environment)
	var light = DirectionalLight.new()
	light.rotation_degrees = Vector3(-48, 28, 0)
	light.light_energy = 0.9
	preview_scene_root.add_child(light)
	preview_camera = Camera.new()
	preview_camera.fov = 45
	preview_scene_root.add_child(preview_camera)
	preview_camera.translation = Vector3(0, 1.12, 2.45)
	preview_camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	preview_camera.current = true
	preview_display.texture = preview_viewport.get_texture()
	_build_mask_preview()
	_rebuild_preview_model()

func _build_mask_preview():
	preview_mask_viewport = Viewport.new()
	preview_mask_viewport.size = preview_viewport.size
	preview_mask_viewport.usage = Viewport.USAGE_3D
	preview_mask_viewport.own_world = true
	preview_mask_viewport.transparent_bg = true
	preview_mask_viewport.render_target_v_flip = true
	preview_mask_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	preview_holder.add_child(preview_mask_viewport)
	preview_mask_viewport.world = World.new()
	preview_mask_camera = Camera.new()
	preview_mask_camera.fov = preview_camera.fov
	preview_mask_camera.translation = preview_camera.translation
	preview_mask_viewport.add_child(preview_mask_camera)
	preview_mask_camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	preview_mask_camera.current = true
	preview_mask_display.texture = preview_mask_viewport.get_texture()

func _panel(position, size):
	var panel = Panel.new()
	panel.rect_position = position
	panel.rect_size = size
	var style = StyleBoxTexture.new()
	style.texture = load("res://Textures/Menu/background_1.png")
	style.region_rect = Rect2(0, 0, 256, 256)
	style.margin_left = 10
	style.margin_right = 10
	style.margin_top = 10
	style.margin_bottom = 10
	style.modulate_color = Color(0.52, 0.0, 0.72, 0.67)
	panel.add_stylebox_override("panel", style)
	return panel

func _slot_style(border = Color(0.2, 0.2, 0.2, 0.7)):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.56)
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	return style

func _panel_style(bg, border, width):
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	return style

func _font(size, path = FONT_PATH):
	var font = DynamicFont.new()
	font.font_data = load(path)
	font.size = size
	font.use_filter = true
	return font

func _label(text, font, color):
	var label = Label.new()
	label.text = text
	label.add_font_override("font", font)
	label.add_color_override("font_color", color)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	return label

func _section_title(text):
	var label = _label(text, header_font, Color(0.12, 1.0, 0.18))
	label.rect_size = Vector2(320, 24)
	return label

func _stat_row(parent, y, title):
	var row = Panel.new()
	row.add_stylebox_override("panel", _slot_style())
	row.rect_position = Vector2(10, y)
	row.rect_size = Vector2(parent.rect_size.x - 20, 30)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var left = _label(title, body_font, Color(0.86, 0.85, 0.82))
	left.rect_position = Vector2(8, 6)
	left.rect_size = Vector2(row.rect_size.x * 0.5 - 8, 22)
	row.add_child(left)
	var right = _label("--", value_font, Color(0.12, 1.0, 0.18))
	right.rect_position = Vector2(row.rect_size.x * 0.5, 6)
	right.rect_size = Vector2(row.rect_size.x * 0.5 - 12, 22)
	right.align = Label.ALIGN_RIGHT
	right.clip_text = true
	row.add_child(right)
	return right

func _multi_row(parent, y, title):
	var row = Panel.new()
	row.add_stylebox_override("panel", _slot_style())
	row.rect_position = Vector2(10, y)
	row.rect_size = Vector2(parent.rect_size.x - 20, 44)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var left = _label(title, body_font, Color(0.86, 0.85, 0.82))
	left.rect_position = Vector2(8, 4)
	left.rect_size = Vector2(84, 18)
	row.add_child(left)
	var right = _label("--", body_font, Color(0.12, 1.0, 0.18))
	right.rect_position = Vector2(92, 4)
	right.rect_size = Vector2(row.rect_size.x - 100, 36)
	right.valign = Label.VALIGN_CENTER
	right.autowrap = true
	row.add_child(right)
	return right

func _load_current_profile():
	if multiplayer_node == null:
		return
	var current_name = str(multiplayer_node.playerInfo.get("nickname", "MT Foxtrot")).strip_edges()
	if current_name.empty():
		current_name = "MT Foxtrot"
	name_edit.text = current_name
	selected_outfit_index = _outfit_index_from_path(str(multiplayer_node.playerInfo.get("skinPath", OUTFITS[0].path)))
	var color = Color(multiplayer_node.playerInfo.get("color", "#ff0000"))
	color_syncing = true
	color_sliders.R.value = color.r8
	color_sliders.G.value = color.g8
	color_sliders.B.value = color.b8
	color_syncing = false
	color_swatch.color = color
	color_controls.hide()
	if preview_mask_display != null:
		preview_mask_display.material.set_shader_param("selected", false)
	_rebuild_preview_model()

func _refresh():
	if multiplayer_node == null:
		return
	_update_stat_values()
	_update_profile_values()
	_sync_online_menu_preview()

func _update_stat_values():
	var implants = Global.implants
	var head = implants.head_implant
	var torso = implants.torso_implant
	var arm = implants.arm_implant
	var leg = implants.leg_implant
	var speed_bonus = head.speed_bonus + torso.speed_bonus + arm.speed_bonus + leg.speed_bonus
	var jump_bonus = head.jump_bonus + torso.jump_bonus + arm.jump_bonus + leg.jump_bonus
	var armor_mul = head.armor * torso.armor * arm.armor * leg.armor
	var armor_text = _format_armor(armor_mul)
	stat_labels.armor.text = armor_text
	stat_labels.speed.text = str(9 + speed_bonus)
	stat_labels.speed_bonus.text = "%+d" % int(speed_bonus)
	stat_labels.jump.text = str(8 + jump_bonus)
	stat_labels.matrix.text = "DEATH" if Global.death else "LIFE"
	stat_labels.matrix.add_color_override("font_color", Color(1, 0, 1) if Global.death else Color(0, 1, 0))

func _update_profile_values():
	var goals = Global.get_node_or_null("AchievementGoals")
	var goal_count = 0
	var goal_total = 0
	if goals != null:
		goal_total = goals.entries_by_id.size()
		for id in goals.entries_by_id:
			if goals.unlocked.has(id):
				goal_count += 1
	profile_labels.completion.text = str(_completion_percentage(goals)) + "%"
	var money_text = "$" + str(Global.money)
	profile_labels.money.text = money_text
	var money_width = value_font.get_string_size(money_text).x
	var money_size = 17 if money_width <= profile_labels.money.rect_size.x else max(10, int(17 * profile_labels.money.rect_size.x / money_width))
	profile_labels.money.add_font_override("font", value_font if money_size == 17 else _font(money_size))
	profile_labels.deaths.text = str(Global.total_deaths)
	profile_labels.dead_civs.text = str(Global.total_kills)
	profile_labels.play_time.text = _format_time(Global.play_time)
	profile_labels.weapons.text = "%d / %d" % [_count_true(Global.WEAPONS_UNLOCKED), Global.WEAPONS_UNLOCKED.size()]
	profile_labels.equipment.text = "%d / %d" % [Global.implants.purchased_implants.size(), Global.implants.IMPLANTS.size()]
	var fish = _collection_progress("fish")
	var organs = _collection_progress("part")
	profile_labels.fish.text = "%d / %d" % fish
	profile_labels.organs.text = "%d / %d" % organs
	profile_labels.goals.text = "%d / %d" % [goal_count, goal_total]
	var online = multiplayer_node.OnlineStats.values
	profile_labels.player_kills.text = str(online.player_kills)
	_update_online_results()

func _on_online_mode_selected(_index):
	_update_online_results()

func _update_online_results():
	if multiplayer_node == null:
		return
	var online = multiplayer_node.OnlineStats.values
	var wins = 0
	var losses = 0
	match online_mode_select.selected:
		1:
			wins = online.deathmatch_wins
			losses = online.deathmatch_losses
		2:
			wins = online.counter_op_wins
			losses = online.counter_op_losses
		_:
			wins = online.deathmatch_wins + online.counter_op_wins
			losses = online.deathmatch_losses + online.counter_op_losses
	profile_labels.wins.text = str(wins)
	profile_labels.losses.text = str(losses)

func _collection_progress(kind):
	var required = {}
	for stock in Global.STOCKS.stocks:
		if str(stock.asset_type) == kind:
			var key = str(stock.ticker) if kind == "fish" else str(stock.s_name)
			required[key] = true
	var found = Global.STOCKS.FISH_FOUND if kind == "fish" else Global.STOCKS.ORGANS_FOUND
	var collected = 0
	for key in required:
		if found.has(key):
			collected += 1
	return [collected, required.size()]

func _completion_percentage(goals):
	if goals == null:
		return 0
	var totals = {"base": 0, "mastery": 0, "online": 0}
	var earned = totals.duplicate()
	for id in goals.entries_by_id:
		var category = str(goals.entries_by_id[id].get("category", "extras"))
		var tier = category if category in ["mastery", "online"] else "base"
		totals[tier] += 1
		if goals.unlocked.has(id):
			earned[tier] += 1
	if totals.base == 0:
		return 0
	var percent = 100.0 * earned.base / totals.base
	if earned.base == totals.base and totals.mastery > 0:
		percent += 50.0 * earned.mastery / totals.mastery
		if earned.mastery == totals.mastery and totals.online > 0:
			percent += 50.0 * earned.online / totals.online
	return int(round(percent))

func _on_name_committed(_text):
	_save_profile()

func _on_name_focus_exited():
	if visible:
		_save_profile()

func _on_outfit_pressed():
	selected_outfit_index = (selected_outfit_index + 1) % OUTFITS.size()
	_rebuild_preview_model()
	_save_profile(false)

func _on_preview_input(event):
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var mask = preview_mask_viewport.get_texture().get_data()
	var pixel = event.position * preview_mask_viewport.size / preview_display.rect_size
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= mask.get_width() or pixel.y >= mask.get_height():
		return
	mask.lock()
	var hit = mask.get_pixelv(Vector2(int(pixel.x), int(pixel.y))).a > 0.5
	mask.unlock()
	preview_mask_display.material.set_shader_param("selected", hit)
	if hit and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		_on_outfit_pressed()

func _on_preview_exited():
	preview_mask_display.material.set_shader_param("selected", false)

func _on_color_swatch_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		color_controls.visible = not color_controls.visible
		if color_controls.visible:
			color_controls.raise()

func _on_color_changed(_value):
	if color_syncing or multiplayer_node == null:
		return
	var color = Color(color_sliders.R.value / 255.0, color_sliders.G.value / 255.0, color_sliders.B.value / 255.0)
	color_swatch.color = color
	multiplayer_node.playerInfo.color = color.to_html(false)
	_save_profile(false)

func _save_profile(refresh_preview := true):
	if multiplayer_node == null:
		return
	var nickname = name_edit.text.strip_edges()
	if nickname.empty():
		nickname = "MT Foxtrot"
		name_edit.text = nickname
	multiplayer_node.playerInfo.nickname = nickname
	multiplayer_node.playerInfo.skinPath = OUTFITS[selected_outfit_index].path
	multiplayer_node.playerInfo.color = color_swatch.color.to_html(false)
	profile_store.save_data("player.save", multiplayer_node.playerInfo)
	multiplayer_node.refresh_local_profile()
	if refresh_preview:
		_refresh()
	else:
		_sync_online_menu_preview()

func _sync_online_menu_preview():
	for panel in get_tree().get_nodes_in_group("MultiplayerMenu"):
		var nickname_field = panel.get_node_or_null("CenterContainer/TabContainer/Player/VBoxContainer/Nickname/NicknameEdit")
		if nickname_field != null:
			nickname_field.text = str(multiplayer_node.playerInfo.nickname)
		var color_field = panel.get_node_or_null("CenterContainer/TabContainer/Player/VBoxContainer/Color/ColorRect")
		if color_field != null:
			color_field.color = color_swatch.color
		var skin_node = panel.get_node_or_null("CenterContainer/TabContainer/Player/VBoxContainer/Skin")
		if skin_node != null and skin_node.has_method("set_texture"):
			skin_node.set_texture(multiplayer_node.playerInfo.skinPath)

func _rebuild_preview_model():
	if preview_scene_root == null:
		return
	if preview_model != null and is_instance_valid(preview_model):
		preview_model.queue_free()
	if preview_mask_model != null and is_instance_valid(preview_mask_model):
		preview_mask_model.queue_free()
	preview_model = PLAYER_MODEL_SCENE.instance()
	preview_model.translation = Vector3(0, 0.9, 0)
	preview_model.rotation_degrees = Vector3(0, 180, 0)
	preview_scene_root.add_child(preview_model)
	_apply_preview_outfit()
	var animation_player = preview_model.get_node_or_null("Anim")
	if animation_player != null and animation_player.has_animation("Idle"):
		animation_player.play("Idle")
	var weapons = preview_model.get_node_or_null("Armature/Skeleton/RightHand/Weapons")
	if weapons != null:
		weapons.visible = false
	var indicator = preview_model.get_node_or_null("Armature/Skeleton/Head/PlayerIndicator")
	if indicator != null:
		indicator.visible = false
	preview_mask_model = preview_model.duplicate()
	preview_mask_viewport.add_child(preview_mask_model)
	var mask_material = SpatialMaterial.new()
	mask_material.flags_unshaded = true
	mask_material.albedo_color = Color(1, 1, 1, 1)
	_mask_materials(preview_mask_model, mask_material)
	var mask_weapons = preview_mask_model.get_node_or_null("Armature/Skeleton/RightHand/Weapons")
	if mask_weapons != null:
		mask_weapons.visible = false
	var mask_indicator = preview_mask_model.get_node_or_null("Armature/Skeleton/Head/PlayerIndicator")
	if mask_indicator != null:
		mask_indicator.visible = false

func _mask_materials(node, material):
	if node is MeshInstance:
		if node.name == "Torso_Mesh":
			node.material_override = material
		else:
			node.visible = false
	for child in node.get_children():
		_mask_materials(child, material)

func _apply_preview_outfit():
	if preview_model == null:
		return
	var path = OUTFITS[selected_outfit_index].path
	var torso = preview_model.get_node_or_null("Armature/Skeleton/Torso_Mesh")
	if torso != null:
		var material = SpatialMaterial.new()
		material.albedo_texture = load(path)
		torso.material_override = material
	if OUTFIT_SCENES.has(path):
		var source_scene = load(OUTFIT_SCENES[path])
		if source_scene != null:
			var source = source_scene.instance()
			var source_skeleton = source.get_node_or_null("Nemesis/Armature/Skeleton")
			var source_torso = source.get_node_or_null("Nemesis/Armature/Skeleton/Torso_Mesh")
			var target_skeleton = preview_model.get_node_or_null("Armature/Skeleton")
			if source_skeleton != null and source_torso != null and target_skeleton != null and source_skeleton.get_bone_count() == target_skeleton.get_bone_count():
				var compatible = true
				for bone in range(target_skeleton.get_bone_count()):
					if source_skeleton.get_bone_name(bone) != target_skeleton.get_bone_name(bone):
						compatible = false
						break
				if compatible:
					var target_torso = target_skeleton.get_node_or_null("Torso_Mesh")
					if target_torso != null:
						target_torso.mesh = source_torso.mesh
						target_torso.skin = source_torso.skin
			source.free()

func _outfit_index_from_path(path):
	for index in range(OUTFITS.size()):
		if OUTFITS[index].path == path:
			return index
	return 0

func _count_true(values):
	var total = 0
	for value in values:
		if value:
			total += 1
	return total

func _format_time(value):
	var seconds = int(value)
	return "%02d:%02d:%02d" % [int(seconds / 3600), int((seconds % 3600) / 60), seconds % 60]

func _format_armor(armor_mul):
	return str(int(round(armor_mul * 100.0))) + "%"
