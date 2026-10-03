extends Node

const DATA_PATH = "res://MOD_CONTENT/CruS Online/achievements/achievements.json"
const SAVE_NAME = "crus_online_goals.save"
const MASTERY_KEYS = ["s_rank", "hope_eradicated", "punishment", "chaos", "extravagance", "stripped"]
const STATE_CHECK_INTERVAL = 0.25
const TRIAGON_MARKERS = ["Raymond Shocktroop Tactical received.", "$1000000 received.", "Golem Exosystem received."]
const FULLY_PEELED_ID = "fully_peeled"
const ONLINE_IMPLANTS = ["Pneumatic Merit Pump", "Surveillance Eyecam", "Surveillance Eyecam PRO MAX", "Military Camouflage+", "Stealth Suit+", "ZZzzz Special Sedative Grenade+", "First Aid Kit+", "Cursed Torch+", "Augmented Arms+"]

var entries_by_level = {}
var entries_by_id = {}
var unlocked = {}
var mastery = {}
var discovered = {}
var state_check_time = 0.0

func _ready():
	name = "AchievementGoals"
	pause_mode = Node.PAUSE_MODE_PROCESS
	var file = File.new()
	if file.open(DATA_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
			for entry in parsed.result.get("achievements", []):
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var id = str(entry.get("id", ""))
				if not id.empty():
					entries_by_id[id] = entry
				if not entry.has("level"):
					continue
				var level = int(entry.level)
				if not entries_by_level.has(level):
					entries_by_level[level] = []
				entries_by_level[level].append(entry)
	_load_slot_progress()
	for level in entries_by_level:
		for entry in entries_by_level[level]:
			if entry.get("category", "") != "mastery":
				continue
			var id = str(entry.get("id", ""))
			var old_id = "steam_" + id.substr(8, id.length() - 8) + "_stylish_rank"
			if unlocked.has(old_id):
				var progress = mastery_for(level)
				progress["extravagance"] = true
				mastery[str(level)] = progress
	call_deferred("evaluate_progress")

func reload_slot():
	unlocked.clear()
	mastery.clear()
	discovered.clear()
	_load_slot_progress()
	var preview = Global.get_node_or_null("AchievementPreview")
	if preview != null:
		preview.reset_notifications()
	evaluate_progress()

func _load_slot_progress():
	var file = File.new()
	if file.open(Global.slot_path(SAVE_NAME), File.READ) == OK:
		var saved = JSON.parse(file.get_as_text())
		file.close()
		if saved.error == OK and typeof(saved.result) == TYPE_DICTIONARY:
			for id in saved.result.get("unlocked", []):
				unlocked[str(id)] = true
			var saved_mastery = saved.result.get("mastery", {})
			if typeof(saved_mastery) == TYPE_DICTIONARY:
				mastery = saved_mastery
			var saved_discovered = saved.result.get("discovered", {})
			if typeof(saved_discovered) == TYPE_DICTIONARY:
				discovered = saved_discovered

func _process(delta):
	state_check_time += delta
	if state_check_time < STATE_CHECK_INTERVAL:
		return
	state_check_time = 0.0
	evaluate_progress()

func level_beaten(level):
	level = int(level)
	if level < 0 or level >= Global.LEVEL_TIMES_RAW.size():
		return false
	return Global.LEVEL_TIMES_RAW[level] < 99999999 or Global.HELL_TIMES_RAW[level] < 99999999

func is_hidden(entry):
	return entry.get("secret", false) and not unlocked.has(str(entry.get("id", ""))) and not level_beaten(entry.get("level", -1))

func should_show_entry(entry):
	var id = str(entry.get("id", ""))
	if id == "synaptic_cascade":
		return Global.hell_discovered or unlocked.has(id)
	if id == "suffering_for_aeons":
		return Global.ending_3 or unlocked.has(id)
	return true

func mastery_for(level):
	var saved = mastery.get(str(int(level)), {})
	var result = {}
	for key in MASTERY_KEYS:
		result[key] = saved.get(key, false)
	return result

func known_condition(key):
	if key == "hope_eradicated" and Global.hell_discovered:
		return true
	if key == "chaos" and Global.ending_3:
		return true
	if key == "extravagance" and Global.implants != null:
		if Global.implants.purchased_implants.has("Extravagant Suit") or (Global.implants.torso_implant != null and Global.implants.torso_implant.i_name == "Extravagant Suit"):
			return true
	if discovered.get(key, false):
		return true
	for level in mastery:
		if mastery[level].get(key, false):
			return true
	return false

func mark_discovered(key):
	if Global.campaign_save.active or discovered.get(key, false):
		return
	discovered[key] = true
	_save_progress()

func clear_progress():
	unlocked.clear()
	mastery.clear()
	discovered.clear()
	var directory = Directory.new()
	if directory.file_exists(Global.slot_path(SAVE_NAME)):
		directory.remove(Global.slot_path(SAVE_NAME))
	var preview = Global.get_node_or_null("AchievementPreview")
	if preview != null:
		preview.reset_notifications()

func _stripped():
	if Global.implants == null:
		return false
	for slot in [Global.implants.head_implant, Global.implants.arm_implant, Global.implants.leg_implant]:
		if slot == null or slot.i_name != "N/A":
			return false
	var torso = Global.implants.torso_implant
	return torso != null and torso.i_name in ["N/A", "Extravagant Suit"]

func _s_rank(level):
	var threshold = Global.HELL_RANK_S[level] if Global.hope_discarded else Global.LEVEL_RANK_S[level]
	if Global.stock_mode:
		threshold = Global.HELL_SRANK_S[level] if Global.hope_discarded else Global.LEVEL_SRANK_S[level]
	return Global.level_time_raw < threshold

func _award(entry, earned):
	var id = str(entry.get("id", ""))
	if id.empty() or unlocked.has(id):
		return false
	unlocked[id] = true
	var reward = int(entry.get("reward", 0))
	Global.money += reward
	if reward > 0 and is_instance_valid(Global.UI):
		Global.UI.notify("$" + str(reward) + " deposited", Color(1, 1, 0))
	earned.append(id)
	return true

func _award_id(id, earned):
	if not entries_by_id.has(id):
		return false
	return _award(entries_by_id[id], earned)

func _campaign_levels():
	var levels = []
	for level in entries_by_level:
		for entry in entries_by_level[level]:
			if entry.get("category", "") == "campaign":
				levels.append(int(level))
				break
	levels.sort()
	return levels

func _all_mastery_condition(key):
	var levels = _campaign_levels()
	if levels.empty():
		return false
	for level in levels:
		if not mastery_for(level).get(key, false):
			return false
	return true

func _all_stock_assets_found(asset_type):
	if Global.STOCKS == null or Global.STOCKS.stocks.empty():
		return false
	var found = Global.STOCKS.FISH_FOUND if asset_type == "fish" else Global.STOCKS.ORGANS_FOUND
	var required = {}
	for stock in Global.STOCKS.stocks:
		if str(stock.asset_type) != asset_type:
			continue
		var key = str(stock.ticker) if asset_type == "fish" else str(stock.s_name)
		required[key] = true
	if required.empty():
		return false
	for key in required:
		if found.find(key) == -1:
			return false
	return true

func _all_weapons_unlocked():
	if Global.WEAPONS_UNLOCKED.empty():
		return false
	for value in Global.WEAPONS_UNLOCKED:
		if not value:
			return false
	return true

func _all_purchasable_implants_owned():
	if Global.implants == null or Global.implants.IMPLANTS.empty():
		return false
	var required = 0
	for implant in Global.implants.IMPLANTS:
		if implant == null:
			continue
		var implant_name = str(implant.i_name)
		if implant_name in ["N/A", "House"] or ONLINE_IMPLANTS.has(implant_name):
			continue
		required += 1
		if Global.implants.purchased_implants.find(implant_name) == -1:
			return false
	return required > 0

func _triagons_complete():
	for marker in TRIAGON_MARKERS:
		if Global.DEAD_CIVS.find(marker) == -1:
			return false
	return true

func _all_regular_achievements_unlocked():
	var required = 0
	for id in entries_by_id:
		if id == FULLY_PEELED_ID:
			continue
		var entry = entries_by_id[id]
		if entry.get("category", "") == "mastery":
			continue
		required += 1
		if not unlocked.has(id):
			return false
	return required > 0

func _evaluate_global_conditions(earned):
	var changed = false
	if Global.death:
		changed = _award_id("soul_emulation", earned) or changed
	if Global.money >= 1000000:
		changed = _award_id("financial_ascension", earned) or changed
	if Global.DEAD_CIVS.find("Limit Chancellor") != -1:
		changed = _award_id("open_your_eyes", earned) or changed
	if _all_mastery_condition("hope_eradicated"):
		changed = _award_id("synaptic_cascade", earned) or changed
	if _all_mastery_condition("s_rank"):
		changed = _award_id("eternal_malice", earned) or changed
	if _all_mastery_condition("punishment"):
		changed = _award_id("entrapment", earned) or changed
	if _all_mastery_condition("chaos"):
		changed = _award_id("suffering_for_aeons", earned) or changed
	if _all_mastery_condition("extravagance"):
		changed = _award_id("beauty_of_life", earned) or changed
	if _triagons_complete():
		changed = _award_id("the_unholy_trinity", earned) or changed
	if _all_stock_assets_found("part"):
		changed = _award_id("biological_traversal", earned) or changed
	if _all_stock_assets_found("fish"):
		changed = _award_id("catch_of_the_day", earned) or changed
	if _all_weapons_unlocked():
		changed = _award_id("the_first_transaction", earned) or changed
	if _all_purchasable_implants_owned():
		changed = _award_id("metabolic_abomination", earned) or changed
	if _all_regular_achievements_unlocked():
		changed = _award_id(FULLY_PEELED_ID, earned) or changed
	return changed

func _backfill_saved_missions(earned):
	var changed = false
	for level in entries_by_level:
		if not level_beaten(level):
			continue
		var progress = mastery_for(level)
		var saved_conditions = {
			"s_rank": (Global.LEVEL_TIMES_RAW[level] < Global.LEVEL_RANK_S[level]
				or Global.HELL_TIMES_RAW[level] < Global.HELL_RANK_S[level]
				or Global.LEVEL_STIMES_RAW[level] < Global.LEVEL_SRANK_S[level]
				or Global.HELL_STIMES_RAW[level] < Global.HELL_SRANK_S[level]),
			"hope_eradicated": Global.HELL_TIMES_RAW[level] < 99999999 or Global.HELL_STIMES_RAW[level] < 99999999,
			"punishment": Global.LEVEL_PUNISHED[level]
		}
		for key in saved_conditions:
			if saved_conditions[key] and not progress[key]:
				progress[key] = true
				changed = true
		mastery[str(level)] = progress
		for entry in entries_by_level[level]:
			if entry.get("category", "") == "campaign":
				changed = _award(entry, earned) or changed
		var complete = true
		for key in MASTERY_KEYS:
			if not progress[key]:
				complete = false
				break
		if complete:
			for entry in entries_by_level[level]:
				if entry.get("category", "") == "mastery":
					changed = _award(entry, earned) or changed
	return changed

func evaluate_progress():
	if not Global.save_slot_selected or Global.campaign_save.active:
		return
	var earned = []
	var changed = false
	if Global.ending_3 and not discovered.get("chaos", false):
		discovered["chaos"] = true
		changed = true
	changed = _backfill_saved_missions(earned) or changed
	changed = _evaluate_global_conditions(earned) or changed
	if not changed:
		return
	_save_progress()
	_notify_earned(earned)

func record_mission_win(level):
	level = int(level)
	if Global.campaign_save.active or not entries_by_level.has(level):
		return
	var progress = mastery_for(level)
	var conditions = {
		"s_rank": _s_rank(level),
		"hope_eradicated": Global.hope_discarded,
		"punishment": Global.punishment_mode,
		"chaos": Global.chaos_mode,
		"extravagance": Global.implants != null and Global.implants.torso_implant != null and Global.implants.torso_implant.i_name == "Extravagant Suit",
		"stripped": _stripped()
	}
	var changed = false
	for key in MASTERY_KEYS:
		if conditions[key] and not progress[key]:
			progress[key] = true
			changed = true
		if key in ["hope_eradicated", "chaos", "extravagance"] and conditions[key] and not discovered.get(key, false):
			discovered[key] = true
			changed = true
	mastery[str(level)] = progress
	var earned = []
	for entry in entries_by_level[level]:
		if entry.get("category", "") == "mastery":
			continue
		changed = _award(entry, earned) or changed
	var complete = true
	for key in MASTERY_KEYS:
		if not progress[key]:
			complete = false
	if complete:
		for entry in entries_by_level[level]:
			if entry.get("category", "") == "mastery":
				changed = _award(entry, earned) or changed
	if Global.enemy_count_total > 0 and Global.enemy_count == 0:
		changed = _award_id("controlled_depopulation", earned) or changed
	changed = _evaluate_global_conditions(earned) or changed
	if not changed:
		return
	_save_progress()
	_notify_earned(earned)

func _notify_earned(earned):
	var preview = Global.get_node_or_null("AchievementPreview")
	if preview == null:
		return
	for id in earned:
		preview.show_achievement(id)

func _save_progress():
	var file = File.new()
	if file.open(Global.slot_path(SAVE_NAME), File.WRITE) == OK:
		file.store_line(to_json({"unlocked": unlocked.keys(), "mastery": mastery, "discovered": discovered}))
		file.close()
