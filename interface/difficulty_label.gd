extends Reference

static func describe(soul, husk, hope, punishment, chaos):
	var difficulty = "Flesh Automaton"
	if hope:
		difficulty = "Hope Eradicated"
	elif husk:
		difficulty = "Power In Misery"
	elif soul:
		difficulty = "Divine Light"
	if punishment:
		difficulty += " + Punishment"
	if chaos:
		difficulty += " + Chaos"
	return "Host difficulty: " + difficulty
