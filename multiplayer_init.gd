extends Node

func _init():
	var loader = Global.get_node_or_null("/root/Mod")
	if loader != null and loader.has_node("CruS Mod Base") and loader.has_node("CruS Online"):
		for pack in loader.get_node("CruS Online").packs:
			ProjectSettings.load_resource_pack(pack)
	ProjectSettings.set_setting("debug/gdscript/warnings/enable", true)
	var weapon_registry = preload("res://MOD_CONTENT/CruS Online/WeaponRegistry.gd").new()
	weapon_registry.name = "WeaponRegistry"
	Global.add_child(weapon_registry)
	weapon_registry.load_bundled_weapons()
	var implant_registry = preload("res://MOD_CONTENT/CruS Online/ImplantRegistry.gd").new()
	implant_registry.name = "ImplantRegistry"
	Global.add_child(implant_registry)
	implant_registry.load_bundled_implants()
	
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/multiplayer.tscn").instance())
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/death_screen.tscn").instance())
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/achievements/AchievementPreview.gd").new())
	Global.add_child(preload("res://MOD_CONTENT/CruS Online/achievements/AchievementGoals.gd").new())
	var capture = preload("res://MOD_CONTENT/CruS Online/DebugCapture.gd").new()
	capture.name = "DebugCapture"
	Global.add_child(capture)
	Global.get_node("Menu").add_child(preload("res://MOD_CONTENT/CruS Online/menu.tscn").instance())




