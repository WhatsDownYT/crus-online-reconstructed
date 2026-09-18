extends Reference



var enabled = false
var totals = {}
var rates = {}
var rpc_methods = {}
var rset_properties = {}
var last_sample = 0
var previous = {}
var processing_usec = 0
var worst_processing_usec = 0
var warnings = {}

func count(key, amount = 1):
	totals[key] = totals.get(key, 0) + amount

func traffic(direction, size, reliable):
	count(direction + "_packets")
	count(direction + "_bytes", size)
	count(direction + ("_reliable" if reliable else "_unreliable"))

func operation(kind, label):
	var table = rpc_methods if kind == "rpc" else rset_properties
	if table.has(label) or table.size() < 256:
		table[label] = table.get(label, 0) + 1

func frame(elapsed):
	processing_usec = elapsed
	worst_processing_usec = max(worst_processing_usec, elapsed)
	count("processing_usec", elapsed)

func warn(key, detail):
	count("warning_" + key)
	if not enabled:
		return
	var now = OS.get_ticks_msec()
	if now - warnings.get(key, -5000) >= 5000:
		warnings[key] = now
		push_warning("[CruS network] %s: %s" % [key, detail])

func sample():
	var now = OS.get_ticks_msec()
	var elapsed = now - last_sample
	if elapsed >= 1000:
		for key in totals:
			rates[key] = (totals[key] - previous.get(key, 0)) * 1000.0 / elapsed
		previous = totals.duplicate()
		last_sample = now
	return {"totals": totals.duplicate(), "per_second": rates.duplicate(),
		"rpc_methods": rpc_methods.duplicate(), "rset_properties": rset_properties.duplicate(),
		"processing_usec": processing_usec, "worst_processing_usec": worst_processing_usec}
