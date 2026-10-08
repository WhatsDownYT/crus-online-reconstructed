extends Resource
class_name OnlineWeaponDefinition

# Stable identity is saved; existing gameplay RPCs still use runtime indices.
export(String) var weapon_id = ""
export(String) var display_name = ""
export(String, MULTILINE) var description = ""
export(String, MULTILINE) var gameplay_description = ""
export(String) var weapon_type = ""
export(String) var ammunition_name = ""
export(String) var weight_name = "Medium"
export(int) var magazine_size = 1
export(int) var starting_reserve = 0
export(int) var maximum_total_rounds = 1
export(int) var damage = 0
export(bool) var armor_piercing = false
export(float) var accuracy = 0.0
export(float) var reload_time = 2.0
export(int) var launcher_magazine_size = 0
export(int) var launcher_starting_reserve = 0
export(int) var launcher_maximum_total = 0
export(int) var launcher_vest_reserve = 0
export(Texture) var icon
export(PackedScene) var world_model
export(PackedScene) var view_model
export(PackedScene) var remote_model
export(PackedScene) var shell_scene
export(PackedScene) var decal_scene
export(AudioStream) var fire_sound
export(AudioStream) var launcher_sound
export(Script) var behavior
export(String) var icon_path = ""
export(String) var idle_animation = ""
export(String) var fire_animation = ""
export(String) var view_slot = ""
export(int) var borrowed_model_index = -1
export(bool) var unlocked_by_default = false
