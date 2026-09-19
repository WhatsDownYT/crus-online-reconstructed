extends Reference

static func resolve(catalog, names):
	if typeof(names) != TYPE_ARRAY or names.size() != 4:
		return null
	var slots = ["head", "torso", "arms", "legs"]
	var result = {"stealth": false, "camo": 0.0, "cursed_torch": false}
	for index in range(4):
		if typeof(names[index]) != TYPE_STRING:
			return null
		if names[index] == "N/A":
			continue
		var found = false
		for implant in catalog:
			if implant.i_name == names[index] and implant.get(slots[index]):
				found = true
				if index == 1:
					result.stealth = implant.stealth
					result.camo = implant.camo
				if index == 2:
					result.cursed_torch = implant.cursed_torch
				break
		if not found:
			return null
	return result
