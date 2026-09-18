extends Reference



const ACTIONS = {"_do_damage": 5, "_set_tranquilize": 0, "_set_cancer": 0,
	"_set_toxic": 0, "_drop_weapon": 0, "_set_fire": 1, "_respawn_player": 0}

static func is_action(method):
	return ACTIONS.has(method)

static func finite_vector(value):
	return typeof(value) == TYPE_VECTOR3 and not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y) and not is_nan(value.z) and not is_inf(value.z)

static func validate(method, args, can_damage, dead):
	if not ACTIONS.has(method) or args.size() != ACTIONS[method]:
		return false
	if method == "_respawn_player":
		return dead
	if dead or not can_damage:
		return false
	if method == "_do_damage":
		if not typeof(args[0]) in [TYPE_INT, TYPE_REAL] or is_nan(args[0]) or is_inf(args[0]) or args[0] < 0 or args[0] > 10000:
			return false
		if not finite_vector(args[1]) or not finite_vector(args[2]) or not finite_vector(args[3]):
			return false
		return args[4] == null or typeof(args[4]) == TYPE_INT or args[4] in ["fire", "gas", "radiation"]
	if method == "_set_fire":
		return typeof(args[0]) == TYPE_BOOL
	return true
