extends Node

func _init():
	# Modloader can reach us before the Online pack is mounted here
	var loader = Global.get_node_or_null("/root/Mod")
	if loader != null and loader.has_node("CruS Mod Base") and loader.has_node("CruS Online"):
		for pack in loader.get_node("CruS Online").packs:
			ProjectSettings.load_resource_pack(pack)
	ProjectSettings.set_setting("debug/gdscript/warnings/enable", true)
	var weapon_registry = preload("res://MOD_CONTENT/CruS Online/weapons/weapon_registry.gd").new()
	weapon_registry.name = "WeaponRegistry"
	Global.add_child(weapon_registry)
	weapon_registry.load_installed_weapons()
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/network/multiplayer.tscn").instance())
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/interface/death_screen.tscn").instance())
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/achievements/achievement_preview.gd").new())
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/achievements/achievement_goals.gd").new())
	var capture = preload("res://MOD_CONTENT/CruS Online/core/debug_capture.gd").new()
	capture.name = "DebugCapture"
	Global.add_child(capture)
	Global.get_node("Menu").add_child(preload("res://MOD_CONTENT/CruS Online/interface/menu.tscn").instance())




