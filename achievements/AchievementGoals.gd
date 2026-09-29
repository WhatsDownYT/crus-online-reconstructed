extends Node

const DATA_PATH = "res://MOD_CONTENT/CruS Online/achievements/achievements.json"
const SAVE_PATH = "user://crus_online_goals.save"
const MASTERY_KEYS = ["s_rank", "hope_eradicated", "punishment", "chaos", "extravagance", "stripped"]

var entries_by_level = {}
var unlocked = {}
var mastery = {}
var discovered = {}

func _ready():
	name = "AchievementGoals"
	var file = File.new()
	if file.open(DATA_PATH, File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
			for entry in parsed.result.get("achievements", []):
				if typeof(entry) != TYPE_DICTIONARY or not entry.has("level"):
					continue
				var level = int(entry.level)
				if not entries_by_level.has(level):
					entries_by_level[level] = []
				entries_by_level[level].append(entry)
	if file.open(SAVE_PATH, File.READ) == OK:
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

func level_beaten(level):
	level = int(level)
	if level < 0 or level >= Global.LEVEL_TIMES_RAW.size():
		return false
	return Global.LEVEL_TIMES_RAW[level] < 99999999 or Global.HELL_TIMES_RAW[level] < 99999999

func is_hidden(entry):
	return entry.get("secret", false) and not unlocked.has(str(entry.get("id", ""))) and not level_beaten(entry.get("level", -1))

func mastery_for(level):
	var saved = mastery.get(str(int(level)), {})
	var result = {}
	for key in MASTERY_KEYS:
		result[key] = saved.get(key, false)
	return result

func known_condition(key):
	if key == "hope_eradicated" and Global.hell_discovered:
		return true
	if key == "chaos" and Global.chaos_mode:
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
	if directory.file_exists(SAVE_PATH):
		directory.remove(SAVE_PATH)
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
	Global.money += int(entry.get("reward", 0))
	earned.append(id)
	return true

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
	if not changed:
		return
	_save_progress()
	var preview = Global.get_node_or_null("AchievementPreview")
	if preview != null:
		for id in earned:
			preview.show_achievement(id)

func _save_progress():
	var file = File.new()
	if file.open(SAVE_PATH, File.WRITE) == OK:
		file.store_line(to_json({"unlocked": unlocked.keys(), "mastery": mastery, "discovered": discovered}))
		file.close()
