extends Reference

# Only strip authored pickups, before the scene enters the tree. Death drops
# are created later and still follow the lobby's death-drop setting.
static func strip(scene):
	var pending = [scene]
	var pickups = []
	while not pending.empty():
		var node = pending.pop_back()
		var script = node.get_script()
		var path = script.resource_path if script != null else ""
		if path.ends_with("/weapon_pickup_new.gd") and not node.menu or path.ends_with("/Implant_Object.gd"):
			var root = node.get_parent() if node.get_parent() is PhysicsBody else node
			if not pickups.has(root): pickups.append(root)
		else:
			pending.append_array(node.get_children())
	for pickup in pickups:
		if is_instance_valid(pickup) and pickup != scene:
			pickup.get_parent().remove_child(pickup)
			pickup.free()
