extends Reference

static func allows(enabled, source, target):
	return enabled or source <= 0 or target <= 0 or source == target
