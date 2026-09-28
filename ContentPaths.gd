extends Reference

const MAX_FILES = 8192
const MAX_FILE_BYTES = 536870912
const MAX_TOTAL_BYTES = 2147483648
const MAX_GROUPS = 256

static func safe_relative(path):
	if typeof(path) != TYPE_STRING or path.empty() or path.length() > 240 or path.begins_with("/") or path.ends_with("/") or "\\" in path or ":" in path:
		return false
	for part in path.split("/", false):
		if part.empty() or part in [".", ".."] or part.ends_with(".") or part.ends_with(" "):
			return false
		for character in ["<", ">", "\"", "|", "?", "*"]:
			if character in part:
				return false
		for index in part.length():
			if part.ord_at(index) < 32:
				return false
		var stem = part.get_basename().to_upper()
		if stem in ["CON", "PRN", "AUX", "NUL"] or (stem.length() == 4 and stem.substr(0, 3) in ["COM", "LPT"] and stem.substr(3, 1) in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]):
			return false
	return not "//" in path

static func safe_file(path):
	return safe_relative(path) and not path.get_extension().to_lower() in ["exe", "dll", "com", "bat", "cmd", "ps1", "lnk", "url", "vbs", "msi", "scr", "sys"]

static func valid_hash(value):
	if typeof(value) != TYPE_STRING or value.length() != 64:
		return false
	for index in value.length():
		var character = value.substr(index, 1)
		if not character in "0123456789abcdef":
			return false
	return true

static func validate(manifest):
	if typeof(manifest) != TYPE_DICTIONARY or manifest.get("protocol") != 1 or typeof(manifest.get("groups")) != TYPE_ARRAY or manifest.groups.size() > MAX_GROUPS:
		return "Invalid host content manifest."
	if JSON.print(manifest).length() > 524288:
		return "Host content manifest is too large."
	var paths = {}
	var groups = {}
	var total = 0
	var count = 0
	for group in manifest.groups:
		if typeof(group) != TYPE_DICTIONARY or not group.get("kind", "") in ["mods", "levels"] or not safe_relative(group.get("folder", "")) or "/" in group.folder:
			return "Invalid content folder."
		if typeof(group.get("name")) != TYPE_STRING or group.name.empty() or group.name.length() > 128 or typeof(group.get("version")) != TYPE_STRING or group.version.length() > 128:
			return "Invalid content metadata."
		if group.kind == "mods" and (group.name.to_lower() == "crus online" or group.folder.to_lower() == "crus online"):
			return "The host cannot replace CruS Online through content downloads."
		var root = group.kind + "/" + group.folder
		if groups.has(root.to_lower()) or typeof(group.get("files")) != TYPE_ARRAY or group.files.empty():
			return "Duplicate or empty content folder."
		groups[root.to_lower()] = true
		var metadata_found = false
		for entry in group.files:
			if typeof(entry) != TYPE_DICTIONARY or not safe_file(entry.get("path", "")) or not valid_hash(entry.get("sha256")) or typeof(entry.get("size")) != TYPE_INT or entry.size < 0 or entry.size > MAX_FILE_BYTES:
				return "Invalid content file."
			var path = root + "/" + entry.path
			if paths.has(path.to_lower()):
				return "Duplicate content file."
			paths[path.to_lower()] = true
			metadata_found = metadata_found or entry.path == ("mod.json" if group.kind == "mods" else "level.json")
			total += entry.size
			count += 1
			if count > MAX_FILES or total > MAX_TOTAL_BYTES:
				return "Host content exceeds the download limit."
		if not metadata_found:
			return "Content metadata is missing."
	return ""
