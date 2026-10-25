extends Node

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(5.0), "timeout")
	var credits_menu = Global.get_node("Multiplayer/Menu")
	credits_menu._setup_credit_logos()
	var sections = credits_menu.credits_overlay.get_node("VBoxContainer/Scroll/Sections")
	var logo = sections.get_node("Reconstructed").get_child(0).texture
	var expected = Image.new()
	var old_file = File.new()
	var good = sections.get_child_count() == 2 and logo != null and expected.load("res://MOD_CONTENT/CruS Online/branding/logo.png") == OK and not old_file.file_exists("res://MOD_CONTENT/CruS Online/crus_online_reconstructed_logo.png")
	if good:
		good = logo.get_data().get_data() == expected.get_data()
	print("CREDITS_TEST_RESULT failures=", 0 if good else 1)
	get_tree().quit(0 if good else 1)
