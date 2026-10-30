extends Node

const WATCHDOG = "res://MOD_CONTENT/CruS Online/core/crash_watchdog.ps1"
var session_dir = ""

func _ready():
	if OS.get_name() != "Windows":
		return
	session_dir = "user://crash-reports/" + str(OS.get_unix_time()) + "-" + str(OS.get_process_id())
	if Directory.new().make_dir_recursive(session_dir) != OK:
		return
	var source = File.new()
	if source.open(WATCHDOG, File.READ) != OK:
		return
	var script = source.get_as_text()
	source.close()
	if not _write(session_dir + "/watchdog.ps1", script):
		return
	var job = {"pid": OS.get_process_id(), "started": OS.get_unix_time(), "exe": OS.get_executable_path(), "user_dir": ProjectSettings.globalize_path("user://"), "session_dir": ProjectSettings.globalize_path(session_dir)}
	if not _write(session_dir + "/session.json", JSON.print(job)):
		return
	var pid = OS.execute("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass", "-File", ProjectSettings.globalize_path(session_dir + "/watchdog.ps1"), "-SessionPath", ProjectSettings.globalize_path(session_dir + "/session.json")], false)
	if pid < 0:
		print("[CruS crash reporter] Could not start Windows crash watcher")
	else:
		print("[CruS crash reporter] Reports: ", ProjectSettings.globalize_path("user://crash-reports"))

func _exit_tree():
	if not session_dir.empty():
		_write(session_dir + "/clean-exit", "")

func breadcrumb(event):
	if session_dir.empty():
		return
	var file = File.new()
	if not file.file_exists(session_dir + "/transition-trace.txt"):
		if file.open(session_dir + "/transition-trace.txt", File.WRITE) != OK:
			return
		file.close()
	if file.open(session_dir + "/transition-trace.txt", File.READ_WRITE) != OK:
		return
	file.seek_end()
	file.store_line(str(OS.get_ticks_msec()) + " " + str(event))
	file.flush()
	file.close()

func _write(path, value):
	var file = File.new()
	if file.open(path, File.WRITE) != OK:
		return false
	file.store_string(value)
	var result = file.get_error() == OK
	file.close()
	return result
