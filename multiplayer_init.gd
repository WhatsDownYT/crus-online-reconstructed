extends Node

func _init():
	var loader = Global.get_node_or_null("/root/Mod")
	if loader != null and loader.has_node("CruS Mod Base") and loader.has_node("CruS Online"):
		for pack in loader.get_node("CruS Online").packs:
			ProjectSettings.load_resource_pack(pack)
	ProjectSettings.set_setting("debug/gdscript/warnings/enable", true)
	
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/multiplayer.tscn").instance())
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/death_screen.tscn").instance())
	var capture = preload("res://MOD_CONTENT/CruS Online/DebugCapture.gd").new()
	capture.name = "DebugCapture"
	Global.add_child(capture)
	Global.get_node("Menu").add_child(preload("res://MOD_CONTENT/CruS Online/menu.tscn").instance())




