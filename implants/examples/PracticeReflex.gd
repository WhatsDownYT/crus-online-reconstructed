extends Reference

var equip_count = 0
var unequip_count = 0
var process_count = 0

# Example hook: the definition supplies the actual movement bonus. This
# callback can add visual or audio feedback without modifying the base player.
func on_equip(player, _implant):
	equip_count += 1
	if is_instance_valid(player) and is_instance_valid(player.UI):
		player.UI.notify("Practice Reflex active", Color(0, 1, 0))

func on_unequip(_player, _implant):
	unequip_count += 1

func on_process(_player, _implant, _delta):
	process_count += 1
