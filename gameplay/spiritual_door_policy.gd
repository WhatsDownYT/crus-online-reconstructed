extends Reference

const FIELDS = ["soul_intact", "husk_mode", "hope_discarded"]
const MAX_REACH = 6.0

static func capture(player_global):
	return {"soul_intact": player_global.soul_intact,
		"husk_mode": player_global.husk_mode,
		"hope_discarded": player_global.hope_discarded}

static func competitive(mp):
	return mp.NetworkBridge.check_connection() and mp.hostSettings.get("gameMode", "cruelty") in ["deathmatch", "counter_op"]

static func allows(state, requirement, actor_position, door_position, ignore_difficulty = false):
	var distance = actor_position.distance_to(door_position)
	if is_nan(distance) or is_inf(distance) or distance > MAX_REACH: return false
	if ignore_difficulty: return true
	if typeof(state) != TYPE_DICTIONARY or state.size() != FIELDS.size() or not requirement in FIELDS:
		return false
	var active = 0
	for field in FIELDS:
		if not state.has(field) or typeof(state[field]) != TYPE_BOOL:
			return false
		active += int(state[field])

	if active > 1 or not state[requirement]:
		return false
	return not is_nan(distance) and not is_inf(distance) and distance <= MAX_REACH
