extends Reference

static func alive(candidate, local_player, local_id, dead_players):
	if not is_instance_valid(candidate):
		return false
	if candidate == local_player:
		return not candidate.get("died") and not candidate.get("dead") and not dead_players.has(local_id)
	var puppet = candidate.get_parent()
	if not is_instance_valid(puppet) or not puppet.has_method("is_owner_state"):
		return false
	var peer_id = int(puppet.name)
	return peer_id != local_id and not puppet.death and not dead_players.has(peer_id)

static func matches(collider, target):
	return is_instance_valid(collider) and is_instance_valid(target) and (collider == target or target.is_a_parent_of(collider))
