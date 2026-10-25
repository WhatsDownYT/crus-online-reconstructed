extends Reference

static func required_players(players, dead_players):
	var required = []
	for peer in players:
		if not dead_players.has(peer):
			required.append(peer)
	return required

static func can_exit(objectives_complete, required, present):
	if not objectives_complete or required.empty():
		return false
	for peer in required:
		if not present.has(peer):
			return false
	return true
