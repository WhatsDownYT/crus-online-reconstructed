extends Reference


var directory_path = "user://mod_config/crus_online"
var last_error = ""

func load_data(filename):
	if not filename in ["player.save", "config.save"]:
		return null
	var path = directory_path.plus_file(filename)
	var data = _read_dictionary(path)
	if data == null:
		data = _read_dictionary(path + ".bak")
	return data

func _read_dictionary(path):
	var file = File.new()
	if not file.file_exists(path) or file.open(path, File.READ) != OK:
		return null
	var parsed = JSON.parse(file.get_as_text())
	file.close()
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
		return null
	return parsed.result

func save_data(filename, data):
	last_error = ""
	if not filename in ["player.save", "config.save"] or typeof(data) != TYPE_DICTIONARY:
		last_error = "Invalid mod settings file or data"
		return false
	var directory = Directory.new()
	var error = directory.make_dir_recursive(directory_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		last_error = "Cannot create mod settings directory: " + str(error)
		return false
	var path = directory_path.plus_file(filename)
	var temporary = path + ".tmp"
	var backup = path + ".bak"
	var file = File.new()
	error = file.open(temporary, File.WRITE)
	if error != OK:
		last_error = "Cannot open mod settings temporary file: " + str(error)
		return false
	file.store_string(to_json(data))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		last_error = "Cannot write mod settings: " + str(error)
		return false

	if directory.file_exists(path):
		if _read_dictionary(path) != null:
			if directory.file_exists(backup) and directory.remove(backup) != OK:
				last_error = "Cannot rotate mod settings backup"
				return false
			error = directory.rename(path, backup)
		else:
			error = directory.rename(path, path + ".corrupt-" + str(OS.get_unix_time()))
		if error != OK:
			last_error = "Cannot preserve previous mod settings: " + str(error)
			return false
	error = directory.rename(temporary, path)
	if error != OK:
		last_error = "Cannot install mod settings: " + str(error)
		return false
	return true

func merge_defaults(defaults, saved):
	var result = defaults.duplicate(true)
	if typeof(saved) != TYPE_DICTIONARY:
		return result
	for key in defaults:
		if not saved.has(key):
			continue
		var expected = typeof(defaults[key])
		var actual = typeof(saved[key])
		if expected == actual or expected in [TYPE_INT, TYPE_REAL] and actual in [TYPE_INT, TYPE_REAL]:
			result[key] = saved[key]
	return result
