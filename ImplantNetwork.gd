extends Reference

static func resolve(catalog, names):
	if typeof(names) != TYPE_ARRAY or names.size() != 4:
		return null
	var slots = ["head", "torso", "arms", "legs"]
	var result = {
		"stealth": false,
		"camo": 0.0,
		"cursed_torch": false,
		"multiplayer_camo": false,
		"multiplayer_stealth": false,
		"multiplayer_sedative": false,
		"multiplayer_first_aid": false,
		"multiplayer_cursed_torch": false,
		"multiplayer_augmented_arms": false,
		"sedative_immune": false,
		"golem_exosystem": false,
		"eyecam_pro": false,
		"merit_pump": false,
		"custom_implants": []
	}
	for index in range(4):
		if typeof(names[index]) != TYPE_STRING:
			return null
		if names[index] == "N/A":
			continue
		var found = false
		for implant in catalog:
			if implant.i_name == names[index] and implant.get(slots[index]):
				found = true
				if not implant.custom_id.empty():
					result.custom_implants.append(implant.custom_id)
				if index == 0:
					result.eyecam_pro = implant.i_name == "Surveillance Eyecam PRO MAX"
				if index == 1:
					result.stealth = implant.stealth
					result.camo = implant.camo
					result.multiplayer_camo = implant.multiplayer_camo
					result.multiplayer_stealth = implant.multiplayer_stealth
					result.sedative_immune = implant.terror or implant.orbsuit
					result.golem_exosystem = implant.orbsuit
				if index == 2:
					result.merit_pump = implant.i_name == "Pneumatic Merit Pump"
					result.cursed_torch = implant.cursed_torch
					result.multiplayer_sedative = implant.multiplayer_sedative
					result.multiplayer_first_aid = implant.multiplayer_first_aid
					result.multiplayer_cursed_torch = implant.multiplayer_cursed_torch
					result.multiplayer_augmented_arms = implant.multiplayer_augmented_arms
				break
		if not found:
			return null
	return result
