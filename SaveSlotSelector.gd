extends CanvasLayer

const PROFILE_SCENE = preload("res://MOD_CONTENT/CruS Online/player_model/player_model.tscn")
const BODY_FONT = "res://Fonts/gamefont(1).ttf"
const NAME_FONT = "res://Fonts/MingLiU-ExtB-01.ttf"
const MASTERY_KEYS = ["s_rank", "hope_eradicated", "punishment", "chaos", "extravagance", "stripped"]
const TRIAGON_MARKERS = ["Raymond Shocktroop Tactical received.", "$1000000 received.", "Golem Exosystem received."]
const ONLINE_IMPLANTS = ["Pneumatic Merit Pump", "Surveillance Eyecam", "Surveillance Eyecam PRO MAX", "Military Camouflage+", "Stealth Suit+", "ZZzzz Special Sedative Grenade+", "First Aid Kit+", "Cursed Torch+", "Augmented Arms+"]
const OUTFITS = {
	"res://Textures/Misc/mainguy_clothes.png": "Default",
	"res://Textures/NPC/Enemy_Worker.png": "Worker",
	"res://Textures/NPC/Enemy_Nude.png": "Nude (FREE???)",
	"res://Textures/NPC/cultist_civilian.png": "Cultist",
	"res://Textures/NPC/bosssguy_clothes.png": "Boss guy",
	"res://Textures/NPC/Enemy_Assassin.png": "Assassin",
	"res://Textures/NPC/Enemy_Assassin_Alt.png": "Assassin (Alt)",
	"res://Textures/NPC/Enemy_Civilian2.png": "Civilian",
	"res://Textures/NPC/Enemy_Cop1.png": "Cop",
	"res://Textures/NPC/Enemy_Kevin.png": "Kevin",
	"res://Textures/NPC/Objective_CEO.png": "CEO"
}
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
const NUMBER_TEXTURES = [
	"res://Maps/textures/office/1.png",
	"res://Maps/textures/office/2.png",
	"res://Maps/textures/office/3.png",
	"res://Maps/textures/office/4.png"
]

var root
var stats_panel
var stats_values = {}
var name_label
var avatar
var avatar_viewport
var avatar_camera
var preview_world_environment
var preview_base_environment
var preview_light
var preview_rain = false
var preview_time = 0.0
var body_values = {}
var implant_icons = {}
var weapon_icons = []
var tooltip_panel
var buttons = []
var hover_slot = 0
var body_font
var title_font
var name_font

func _ready():
	layer = 90
	body_font = _font(17)
	title_font = _font(25)
	name_font = _font(20, NAME_FONT)
	preview_rain = rand_range(0, 100) > 90
	root = Control.new()
	root.rect_size = Vector2(1280, 720)
	root.rect_scale = Vector2(float(Global.resolution[0]) / 1280.0, float(Global.resolution[1]) / 720.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_preview()
	_build_buttons()
	_build_tooltip()
	stats_panel.hide()
	set_process(true)

func _process(delta):
	if stats_panel.visible and avatar_camera != null:
		preview_time += delta * 0.45
		var angle = sin(preview_time) * 0.9
		avatar_camera.translation = Vector3(sin(angle) * 2.45, 1.12, cos(angle) * 2.45)
		avatar_camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
		var environment = preview_world_environment.environment
		if environment != null and environment.background_sky != null:
			environment.background_sky_rotation.y += 0.05 * delta
	if tooltip_panel != null and tooltip_panel.visible:
		tooltip_panel.rect_position = root.get_local_mouse_position() + Vector2(50, 20)
		tooltip_panel.rect_position.x = clamp(tooltip_panel.rect_position.x, 0, 1280 - tooltip_panel.rect_size.x - 20)
		tooltip_panel.rect_position.y = clamp(tooltip_panel.rect_position.y, 0, 720 - tooltip_panel.rect_size.y - 20)

func _font(size, path = BODY_FONT):
	var font = DynamicFont.new()
	font.font_data = load(path)
	font.size = size
	font.use_filter = true
	return font

func _panel(parent, position, size, tint = Color(0.48, 0.02, 0.43, 0.83)):
	var panel = Panel.new()
	panel.rect_position = position
	panel.rect_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxTexture.new()
	style.texture = load("res://Textures/Menu/background_1.png")
	style.region_rect = Rect2(0, 0, 256, 256)
	style.margin_left = 10
	style.margin_right = 10
	style.margin_top = 10
	style.margin_bottom = 10
	style.modulate_color = tint
	panel.add_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent, text, position, size, color = Color(1, 1, 1), font = null):
	var label = Label.new()
	label.text = text
	label.rect_position = position
	label.rect_size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_font_override("font", font if font != null else body_font)
	label.add_color_override("font_color", color)
	label.add_color_override("font_color_shadow", Color(0, 0, 0))
	label.add_constant_override("shadow_offset_x", 1)
	label.add_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label

func _build_preview():
	stats_panel = _panel(root, Vector2(42, 55), Vector2(850, 608))
	var fields = [
		["completion", "Completion"], ["money", "Money"], ["playtime", "Playtime"], ["kills", "Kills"], ["deaths", "Deaths"],
		["weapons", "Weapons"], ["equipment", "Equipment"], ["fish", "Fish Found"],
		["parts", "Body Parts"], ["goals", "Goals"], ["player_kills", "Player Kills"],
		["online_equipment", "Online Equipment"], ["wins", "Total Wins"], ["losses", "Total Losses"],
		["dm_wins", "Deathmatch Wins"], ["dm_losses", "Deathmatch Losses"],
		["op_wins", "Counter-Opps Wins"], ["op_losses", "Counter-Opps Losses"]
	]
	var stats_background = _panel(stats_panel, Vector2(16, 17), Vector2(467, 574), Color(0.34, 0, 0.29, 0.7))
	for index in range(fields.size()):
		var row_y = 4 + index * 32
		_label(stats_background, fields[index][1], Vector2(8, row_y), Vector2(296, 24))
		var value = _label(stats_background, "--", Vector2(318, row_y), Vector2(137, 24), Color(0, 1, 0))
		value.align = Label.ALIGN_RIGHT
		value.clip_text = true
		stats_values[fields[index][0]] = value
	var portrait = _panel(stats_panel, Vector2(503, 50), Vector2(319, 525), Color(0.4, 0, 0.35, 0.78))
	name_label = _label(stats_panel, "MT Foxtrot", Vector2(503, 18), Vector2(319, 28), Color(1, 0, 1), name_font)
	name_label.align = Label.ALIGN_CENTER
	var display = TextureRect.new()
	display.rect_position = Vector2(4, 5)
	display.rect_size = portrait.rect_size - Vector2(8, 10)
	display.expand = true
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(display)
	avatar_viewport = Viewport.new()
	avatar_viewport.size = Vector2(620, 1040)
	avatar_viewport.usage = Viewport.USAGE_3D
	avatar_viewport.own_world = true
	avatar_viewport.msaa = Viewport.MSAA_4X
	avatar_viewport.render_target_v_flip = true
	avatar_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	portrait.add_child(avatar_viewport)
	var world = World.new()
	avatar_viewport.world = world
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky = PanoramaSky.new()
	sky.panorama = load("res://Textures/sky3.png")
	environment.background_sky = sky
	environment.background_color = Color(0.54902, 0.309804, 0.164706)
	environment.fog_color = environment.background_color
	environment.ambient_light_color = Color(0.54902, 0.309804, 0.164706)
	environment.ambient_light_sky_contribution = 0.0
	environment.ambient_light_energy = 0.75
	preview_base_environment = environment.duplicate(true)
	preview_world_environment = WorldEnvironment.new()
	preview_world_environment.environment = environment
	avatar_viewport.add_child(preview_world_environment)
	preview_light = DirectionalLight.new()
	preview_light.rotation_degrees = Vector3(-48, 28, 0)
	preview_light.light_energy = 0.9
	avatar_viewport.add_child(preview_light)
	avatar_camera = Camera.new()
	avatar_camera.fov = 45
	avatar_camera.translation = Vector3(0, 1.12, 2.45)
	avatar_viewport.add_child(avatar_camera)
	avatar_camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
	avatar_camera.current = true
	display.texture = avatar_viewport.get_texture()
	var body_fields = [["armor", "Armor"], ["speed", "Speed"], ["jump", "Jump"], ["matrix", "Matrix"]]
	for index in range(body_fields.size()):
		var y = 12 + index * 28
		_label(portrait, body_fields[index][1], Vector2(12, y), Vector2(140, 24))
		var value = _label(portrait, "--", Vector2(147, y), Vector2(160, 24), Color(0, 1, 0))
		value.align = Label.ALIGN_RIGHT
		body_values[body_fields[index][0]] = value
	_label(portrait, "Outfit", Vector2(12, portrait.rect_size.y - 36), Vector2(94, 24))
	body_values["outfit"] = _label(portrait, "Default", Vector2(106, portrait.rect_size.y - 36), Vector2(201, 24), Color(0, 1, 0))
	body_values["outfit"].align = Label.ALIGN_RIGHT
	avatar = PROFILE_SCENE.instance()
	avatar.translation = Vector3(0, 0.9, 0)
	avatar.rotation_degrees = Vector3(0, 180, 0)
	avatar_viewport.add_child(avatar)
	var animation = avatar.get_node_or_null("Anim")
	if animation != null and animation.has_animation("Idle"):
		animation.play("Idle")
	var weapons = avatar.get_node_or_null("Armature/Skeleton/RightHand/Weapons")
	if weapons != null:
		weapons.visible = false
	var indicator = avatar.get_node_or_null("Armature/Skeleton/Head/PlayerIndicator")
	if indicator != null:
		indicator.visible = false
	for index in range(4):
		var slot = ["head", "torso", "arm", "leg"][index]
		var icon = _loadout_icon(portrait, Vector2(12, 126 + index * 55), Vector2(46, 46))
		implant_icons[slot] = icon
	for index in range(2):
		var position = Vector2(247, 126 + index * 70)
		var icon = _loadout_icon(portrait, position, Vector2(60, 60))
		weapon_icons.append(icon)

func _loadout_icon(parent, position, size):
	var backing = ColorRect.new()
	backing.rect_position = position + Vector2(2, 2)
	backing.rect_size = size
	backing.color = Color(0, 0.6, 0, 0.85)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backing)
	var icon = TextureRect.new()
	icon.rect_position = position
	icon.rect_size = size
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _update_loadout_preview(campaign):
	var equipped = campaign.get("equipped_implants", {})
	if not equipped is Dictionary:
		equipped = {}
	var empty_texture = load("res://Textures/Menu/Empty_Slot.png")
	for slot in implant_icons:
		var key = str(equipped.get(slot, ""))
		var texture = empty_texture
		for implant in Global.implants.IMPLANTS:
			if implant != null and not key.empty() and (implant.custom_id == key or implant.i_name == key):
				texture = implant.texture
				break
		implant_icons[slot].texture = texture
	var weapons = campaign.get("selected_weapons", [0, 1])
	if not weapons is Array or weapons.size() != 2:
		weapons = [0, 1]
	for index in range(2):
		var weapon_index = -1
		if weapons[index] is String:
			var registry = Global.get_node_or_null("WeaponRegistry")
			if registry != null:
				weapon_index = registry.index_for(weapons[index])
		elif weapons[index] is int or weapons[index] is float:
			weapon_index = int(weapons[index])
		var button = Global.menu._weapon_button_for_index(weapon_index)
		weapon_icons[index].texture = button.texture_normal if button != null else empty_texture

func _build_buttons():
	var grid = GridContainer.new()
	grid.columns = 1
	grid.rect_position = Vector2(1070, 204)
	grid.add_constant_override("vseparation", 0)
	grid.add_constant_override("hseparation", 0)
	root.add_child(grid)
	for index in range(4):
		var button = TextureButton.new()
		button.name = "Save Slot " + str(index + 1)
		button.rect_min_size = Global.menu.button_size
		button.rect_size = Global.menu.button_size
		button.expand = true
		button.texture_normal = load(NUMBER_TEXTURES[index])
		button.texture_hover = load("res://Textures/Menu/hover.png")
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.connect("mouse_entered", self, "_show_slot", [index + 1])
		button.connect("mouse_exited", self, "_leave_slot")
		button.connect("pressed", self, "_choose_slot", [index + 1])
		grid.add_child(button)
		buttons.append(button)

func _build_tooltip():
	tooltip_panel = Global.menu.get_node("Hover_Panel").duplicate()
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.get_node("Hover_Info/Image").hide()
	tooltip_panel.get_node("Hover_Info/Hint").hide()
	root.add_child(tooltip_panel)
	tooltip_panel.hide()

func _leave_slot():
	hover_slot = 0
	stats_panel.hide()
	tooltip_panel.hide()

func _read_json(path):
	var file = File.new()
	if not file.file_exists(path) or file.open(path, File.READ) != OK:
		return {}
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	return parsed.result if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY else {}

func _profile_path(slot, file):
	if slot == 1:
		return "user://mod_config/crus_online/" + file
	return Global.slot_path_for(slot, "profile/" + file)

func _show_slot(slot):
	hover_slot = slot
	tooltip_panel.get_node("Hover_Info/Name").text = "Save Slot " + str(slot)
	tooltip_panel.rect_size = Vector2.ZERO
	tooltip_panel.show()
	if not File.new().file_exists(Global.slot_path_for(slot, "savegame.save")):
		stats_panel.hide()
		return
	stats_panel.show()
	var campaign = _read_json(Global.slot_path_for(slot, "savegame.save"))
	if campaign.empty():
		stats_panel.hide()
		return
	_apply_preview_environment(campaign)
	var stock = _read_json(Global.slot_path_for(slot, "stocks.save"))
	var goals = _read_json(Global.slot_path_for(slot, "crus_online_goals.save"))
	var online = _read_json(_profile_path(slot, "stats.save"))
	var profile = _read_json(_profile_path(slot, "player.save"))
	var name = str(profile.get("nickname", "MT Foxtrot")).strip_edges()
	name_label.text = name if not name.empty() else "MT Foxtrot"
	name_label.add_color_override("font_color", Color(str(profile.get("color", "ff00ff"))))
	var outfit = str(profile.get("skinPath", "res://Textures/Misc/mainguy_clothes.png"))
	body_values["armor"].text = "100%"
	body_values["speed"].text = "+0"
	body_values["jump"].text = "8"
	body_values["matrix"].text = "DEATH" if bool(campaign.get("death", false)) else "LIFE"
	body_values["matrix"].add_color_override("font_color", Color(1, 0, 1) if bool(campaign.get("death", false)) else Color(0, 1, 0))
	body_values["outfit"].text = OUTFITS.get(outfit, outfit.get_file().get_basename())
	_apply_outfit(outfit)
	_update_loadout_preview(campaign)
	var earned = goals.get("unlocked", [])
	if not earned is Array:
		earned = []
	var goal_file = _read_json("res://MOD_CONTENT/CruS Online/achievements/achievements.json")
	var goal_ids = {}
	for entry in goal_file.get("achievements", []):
		if entry is Dictionary and str(entry.get("id", "")) != "":
			goal_ids[str(entry.id)] = true
	var goal_total = goal_ids.size()
	var goal_owned = 0
	for id in earned:
		if goal_ids.has(str(id)):
			goal_owned += 1
	var weapons = campaign.get("weapons_unlocked", [true, true, true, true])
	if not weapons is Array:
		weapons = [true, true, true, true]
	var implants = campaign.get("implants_unlocked", [])
	if not implants is Array:
		implants = []
	var equipment_total = 0
	var online_equipment_total = 0
	var online_equipment_owned = 0
	var equipment_owned = 0
	for item in Global.implants.IMPLANTS:
		if item == null or str(item.i_name) in ["N/A", "House"]:
			continue
		if not item.custom_id.empty():
			continue
		if ONLINE_IMPLANTS.has(str(item.i_name)):
			online_equipment_total += 1
			if implants.has(item.i_name):
				online_equipment_owned += 1
		else:
			equipment_total += 1
			if implants.has(item.i_name):
				equipment_owned += 1
	var fish_total = 0
	var part_total = 0
	for item in Global.STOCKS.stocks:
		if item.asset_type == "fish":
			fish_total += 1
		elif item.asset_type == "part":
			part_total += 1
	var fish = stock.get("fish_found", [])
	var parts = stock.get("org_found", [])
	if not fish is Array:
		fish = []
	if not parts is Array:
		parts = []
	var seconds = int(campaign.get("play_time", 0)) / 1000
	var dm_wins = int(online.get("deathmatch_wins", 0))
	var dm_losses = int(online.get("deathmatch_losses", 0))
	var op_wins = int(online.get("counter_op_wins", 0))
	var op_losses = int(online.get("counter_op_losses", 0))
	var values = {
		"money": "$" + str(campaign.get("money", 0)),
		"completion": "%.1f%%" % _completion_percentage(campaign, stock, goals, goal_file),
		"playtime": "%02d:%02d:%02d" % [int(seconds / 3600), int((seconds % 3600) / 60), seconds % 60],
		"kills": str(campaign.get("total_kills", 0)), "deaths": str(campaign.get("total_deaths", 0)),
		"weapons": str(_count_true(weapons)) + " / " + str(Global.WEAPONS_UNLOCKED.size()),
		"equipment": str(equipment_owned) + " / " + str(equipment_total),
		"online_equipment": str(online_equipment_owned) + " / " + str(online_equipment_total),
		"fish": str(fish.size()) + " / " + str(fish_total), "parts": str(parts.size()) + " / " + str(part_total),
		"goals": str(goal_owned) + " / " + str(goal_total),
		"player_kills": str(online.get("player_kills", 0)),
		"wins": str(dm_wins + op_wins), "losses": str(dm_losses + op_losses),
		"dm_wins": str(dm_wins), "dm_losses": str(dm_losses),
		"op_wins": str(op_wins), "op_losses": str(op_losses)
	}
	for key in values:
		stats_values[key].text = values[key]

func _completion_percentage(campaign, stock, goals, goal_file):
	var entries = {}
	var campaign_levels = {}
	for entry in goal_file.get("achievements", []):
		if not entry is Dictionary:
			continue
		entries[str(entry.get("id", ""))] = entry
		if entry.get("category", "") == "campaign" and entry.has("level"):
			campaign_levels[str(entry.level)] = true
	var unlocked = goals.get("unlocked", [])
	if not unlocked is Array:
		unlocked = []
	var mastery = goals.get("mastery", {})
	if not mastery is Dictionary:
		mastery = {}
	var totals = {"base": 0.0, "mastery": 0.0, "online": 0.0}
	var earned = {"base": 0.0, "mastery": 0.0, "online": 0.0}
	for id in entries:
		var entry = entries[id]
		var category = str(entry.get("category", "extras"))
		var tier = category if category in ["mastery", "online"] else "base"
		totals[tier] += 1.0
		earned[tier] += _goal_progress_fraction(id, entry, entries, campaign_levels, unlocked, mastery, campaign, stock)
	if totals.base == 0:
		return 0.0
	var percent = 100.0 * earned.base / totals.base
	if earned.base >= totals.base - 0.0001 and totals.mastery > 0:
		percent += 50.0 * earned.mastery / totals.mastery
		if earned.mastery >= totals.mastery - 0.0001 and totals.online > 0:
			percent += 50.0 * earned.online / totals.online
	return percent

func _goal_progress_fraction(id, entry, entries, campaign_levels, unlocked, mastery, campaign, stock):
	if unlocked.has(id):
		return 1.0
	match id:
		"synaptic_cascade":
			return _mastery_condition_progress(campaign_levels, mastery, "hope_eradicated")
		"eternal_malice":
			return _mastery_condition_progress(campaign_levels, mastery, "s_rank")
		"entrapment":
			return _mastery_condition_progress(campaign_levels, mastery, "punishment")
		"suffering_for_aeons":
			return _mastery_condition_progress(campaign_levels, mastery, "chaos")
		"beauty_of_life":
			return _mastery_condition_progress(campaign_levels, mastery, "extravagance")
		"the_unholy_trinity":
			var found = 0
			var dead_npcs = campaign.get("dead_npcs", [])
			if not dead_npcs is Array:
				dead_npcs = []
			for marker in TRIAGON_MARKERS:
				if dead_npcs.has(marker):
					found += 1
			return float(found) / float(TRIAGON_MARKERS.size())
		"biological_traversal":
			return _collection_fraction(stock, "part")
		"catch_of_the_day":
			return _collection_fraction(stock, "fish")
		"the_first_transaction":
			var weapons = campaign.get("weapons_unlocked", [])
			if not weapons is Array:
				weapons = []
			return float(max(0, _count_true(weapons) - 4)) / float(max(1, Global.WEAPONS_UNLOCKED.size() - 4))
		"metabolic_abomination":
			return _equipment_fraction(campaign)
		"fully_peeled":
			var total = 0
			var completed = 0
			for other_id in entries:
				if other_id == "fully_peeled" or entries[other_id].get("category", "") == "mastery":
					continue
				total += 1
				if unlocked.has(other_id):
					completed += 1
			return float(completed) / float(max(1, total))
	if str(entry.get("category", "")) == "mastery" and entry.has("level"):
		var progress = mastery.get(str(int(entry.level)), {})
		var completed = 0
		for key in MASTERY_KEYS:
			if progress.get(key, false):
				completed += 1
		return float(completed) / float(MASTERY_KEYS.size())
	return 0.0

func _mastery_condition_progress(campaign_levels, mastery, key):
	if campaign_levels.empty():
		return 0.0
	var completed = 0
	for level in campaign_levels:
		if mastery.get(level, {}).get(key, false):
			completed += 1
	return float(completed) / float(campaign_levels.size())

func _collection_fraction(stock, kind):
	var required = {}
	for item in Global.STOCKS.stocks:
		if str(item.asset_type) == kind:
			required[str(item.ticker) if kind == "fish" else str(item.s_name)] = true
	var found = stock.get("fish_found" if kind == "fish" else "org_found", [])
	if not found is Array:
		found = []
	var collected = 0
	for key in required:
		if found.has(key):
			collected += 1
	return float(collected) / float(max(1, required.size()))

func _equipment_fraction(campaign):
	var purchased = campaign.get("implants_unlocked", [])
	if not purchased is Array:
		purchased = []
	var owned = 0
	var total = 0
	for implant in Global.implants.IMPLANTS:
		if implant == null:
			continue
		if not implant.custom_id.empty():
			continue
		var implant_name = str(implant.i_name)
		if implant_name in ["N/A", "House"] or ONLINE_IMPLANTS.has(implant_name):
			continue
		total += 1
		if purchased.has(implant_name):
			owned += 1
	return float(owned) / float(max(1, total))

func _apply_preview_environment(campaign):
	var environment = preview_base_environment.duplicate(true)
	preview_world_environment.environment = environment
	if bool(campaign.get("hope", false)):
		environment.background_sky.panorama = load("res://Textures/sky11.png" if bool(campaign.get("ending_2", false)) else "res://Textures/sky10.png")
		environment.fog_color = Color(0, 1, 0) if bool(campaign.get("ending_2", false)) else Color(1, 0, 0)
		environment.background_color = environment.fog_color
		preview_light.light_color = Color(1, 1, 1)
		return
	if preview_rain:
		environment.fog_depth_begin = 0
		environment.fog_depth_end = 100
		environment.ambient_light_color = Color(0.6, 0.6, 0.6)
		environment.fog_color = Color(0.6, 0.6, 0.6)
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = environment.fog_color
	var hour = int(OS.get_time().hour)
	if hour == 0:
		hour = 24
	var light_amount = 1.0 - clamp(float(abs(12 - hour)) / 12.0, 0.0, 0.95)
	var base_fog = environment.fog_color
	environment.fog_color = Color(base_fog.r * light_amount, base_fog.g * light_amount, base_fog.b * light_amount)
	if environment.background_mode == Environment.BG_COLOR:
		environment.background_color = environment.fog_color
	environment.background_energy = clamp(light_amount, 0.0, 1.0)
	var light_color = clamp(light_amount + 0.5, 0.8, 1.0)
	preview_light.light_color = Color(light_color, light_color, 1.0)

func _apply_outfit(path):
	if not ResourceLoader.exists(path):
		path = "res://Textures/Misc/mainguy_clothes.png"
	var torso = avatar.get_node_or_null("Armature/Skeleton/Torso_Mesh")
	if torso == null:
		return
	var base_model = PROFILE_SCENE.instance()
	var base_torso = base_model.get_node_or_null("Armature/Skeleton/Torso_Mesh")
	if base_torso != null:
		torso.mesh = base_torso.mesh
		torso.skin = base_torso.skin
	base_model.free()
	var material = SpatialMaterial.new()
	material.albedo_texture = load(path)
	torso.material_override = material
	if not OUTFIT_SCENES.has(path):
		return
	var source = load(OUTFIT_SCENES[path]).instance()
	var source_skeleton = source.get_node_or_null("Nemesis/Armature/Skeleton")
	var source_torso = source.get_node_or_null("Nemesis/Armature/Skeleton/Torso_Mesh")
	var target_skeleton = avatar.get_node_or_null("Armature/Skeleton")
	if source_skeleton != null and source_torso != null and target_skeleton != null and source_skeleton.get_bone_count() == target_skeleton.get_bone_count():
		var compatible = true
		for bone in range(target_skeleton.get_bone_count()):
			if source_skeleton.get_bone_name(bone) != target_skeleton.get_bone_name(bone):
				compatible = false
				break
		if compatible:
			torso.mesh = source_torso.mesh
			torso.skin = source_torso.skin
	source.free()

func _count_true(values):
	var total = 0
	for value in values:
		if value:
			total += 1
	return total

func _choose_slot(slot):
	Global.select_save_slot(slot)
	Global.get_node("Multiplayer").goto_menu_host()
