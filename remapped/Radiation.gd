extends Particles

onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

export  var damage = 0.4
var damage_elapsed = 0.0

func _ready():
	if not has_meta("crus_damage_source"):
		return
	add_to_group("acr_clouds")
	set_meta("acr_particle_amount", amount)
	if Global.get_node_or_null("ACRCloudBudget") == null:
		var budget = preload("res://MOD_CONTENT/CruS Online/gameplay/radiation_budget.gd").new()
		budget.name = "ACRCloudBudget"
		Global.add_child(budget)
	# Clouds remain dangerous even when their particles are redundant. Limiting
	# emitters avoids multiplying GPU work with every overlapping ACR burst.
	var emitters = get_tree().get_nodes_in_group("acr_visible_clouds")
	if emitters.size() < 32:
		add_to_group("acr_visible_clouds")
	else:
		emitting = false
		amount = 1
		hide()
	if not NetworkBridge.is_world_authority():
		$Area.monitoring = false
		set_physics_process(false)
	# Spread broadphase reads across physics frames rather than doing every
	# cloud in the same burst on the same frame.
	damage_elapsed = float(get_instance_id() % 3) / 30.0

func _physics_process(delta):
	var spray = has_meta("crus_damage_source")
	var ticks = 1
	if spray:
		damage_elapsed += delta
		if damage_elapsed < 0.1: return
		ticks = min(3, int(damage_elapsed * 30.0))
		damage_elapsed -= float(ticks) / 30.0
	var source = NetworkBridge.damage_source_id(self) if spray else 0
	for body in $Area.get_overlapping_bodies():
		var target = NetworkBridge.damage_target_id(body)
		if not spray:
			# Atmosphere checks the matrix on the machine that owns this player.
			if body == Global.player:
				if Global.death: continue
			elif target > 0 or not NetworkBridge.is_world_authority():
				continue
		elif not NetworkBridge.is_world_authority() or source > 0 and target == source:
			continue
		for _tick in range(ticks):
			if body.has_method("player_damage"):
				NetworkBridge.apply_damage(self, body, "player_damage", [damage, Vector3.ZERO, body.global_transform.origin, global_transform.origin, "radiation"])
			elif body.has_method("damage"):
				NetworkBridge.apply_damage(self, body, "damage", [damage, Vector3.ZERO, body.global_transform.origin, global_transform.origin])
