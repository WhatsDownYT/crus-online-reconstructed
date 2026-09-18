extends Reference

static func finite_vector(value):
	return typeof(value) == TYPE_VECTOR3 and not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y) and not is_nan(value.z) and not is_inf(value.z)

static func release_velocity(kicked, backwards, player_velocity, throw_bonus, mass):


	if not kicked:
		return Vector3.ZERO
	return player_velocity - (20 + throw_bonus - mass) * backwards.normalized()

static func valid_release(position, actor_position, backwards, player_velocity, kicked):
	if typeof(kicked) != TYPE_BOOL or not finite_vector(position) or not finite_vector(backwards) or not finite_vector(player_velocity):
		return false
	if position.distance_to(actor_position) > 6.0 or player_velocity.length() > 1000:
		return false
	return not kicked or backwards.length() > 0.001 and backwards.length() <= 1.01
