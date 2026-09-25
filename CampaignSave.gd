extends Reference

var active = false
var campaign = {}
var implants = {}
var stock_state = {}
var stocks = []
var menu_weapons = []

const FIELDS = ["WEAPONS_UNLOCKED", "LEVELS_UNLOCKED", "LEVEL_PUNISHED", "BONUS_UNLOCK", "MONEY_ITEMS", "soul_intact", "husk_mode", "hope_discarded", "consecutive_deaths", "money", "DEAD_CIVS", "ending_1", "ending_2", "ending_3", "hell_discovered", "death", "play_time", "LEVEL_TIMES", "LEVEL_TIMES_RAW", "LEVEL_STIMES", "LEVEL_STIMES_RAW", "HELL_TIMES", "HELL_TIMES_RAW", "HELL_STIMES", "HELL_STIMES_RAW", "level_ranks", "level_stock_ranks", "hell_ranks", "hell_stock_ranks", "CURRENT_WEAPONS", "punishment_mode", "chaos_mode", "stock_mode", "CURRENT_LEVEL"]

func copy_value(value):
	return value.duplicate(true) if value is Array or value is Dictionary else value

func variables(object):
	var result = {}
	for property in object.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = object.get(property.name)
			if typeof(value) != TYPE_OBJECT:
				result[property.name] = copy_value(value)
	return result

func restore(object, state):
	for key in state:
		object.set(key, copy_value(state[key]))

func set_mode(global, mode):
	if mode != "cruelty":
		if active:
			return
		for key in FIELDS:
			campaign[key] = copy_value(global.get(key))
		menu_weapons = [global.menu.weapon_1, global.menu.weapon_2]
		implants = variables(global.implants)
		for key in ["head_implant", "torso_implant", "arm_implant", "leg_implant"]:
			if key in global.implants:
				implants[key] = global.implants.get(key)
		stock_state = variables(global.STOCKS)
		stock_state.erase("stocks")
		stocks.clear()
		for stock in global.STOCKS.stocks:
			stocks.append(variables(stock))
		active = true
		return
	if not active:
		return
	var selection = global.menu.current_weapon_select
	for index in range(menu_weapons.size()):
		global.menu.current_weapon_select = index + 1
		global.menu.set_weapon(menu_weapons[index])
	global.menu.current_weapon_select = selection
	menu_weapons.clear()
	restore(global, campaign)
	restore(global.implants, implants)
	restore(global.STOCKS, stock_state)
	for index in range(min(stocks.size(), global.STOCKS.stocks.size())):
		restore(global.STOCKS.stocks[index], stocks[index])
	campaign.clear()
	implants.clear()
	stock_state.clear()
	stocks.clear()
	active = false
