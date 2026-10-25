extends Reference

const FIELDS = ["soul_intact", "husk_mode", "hope_discarded"]
const MAX_REACH = 6.0

static func capture(player_global):
	return {"soul_intact": player_global.soul_intact,
		"husk_mode": player_global.husk_mode,
		"hope_discarded": player_global.hope_discarded}

static func allows(state, requirement, actor_position, door_position):
	if typeof(state) != TYPE_DICTIONARY or state.size() != FIELDS.size() or not requirement in FIELDS:
		return false
	var active = 0
	for field in FIELDS:
		if not state.has(field) or typeof(state[field]) != TYPE_BOOL:
			return false
		active += int(state[field])

	if active > 1 or not state[requirement]:
		return false
	var distance = actor_position.distance_to(door_position)
	return not is_nan(distance) and not is_inf(distance) and distance <= MAX_REACH
