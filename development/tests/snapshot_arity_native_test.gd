extends Node

const Snapshots = preload("res://network_snapshots.gd")

func _ready():
	var owner = Reference.new()
	var snapshots = Snapshots.new(owner)
	var pose = [Transform.IDENTITY, [0.0, 0.0], 0.0, null, Vector3.ZERO]
	var valid = snapshots.valid_value("_update_puppet", pose, false)
	var missing_hold = snapshots.valid_value("_update_puppet", pose.slice(0, 3), false)
	var invalid_hold = snapshots.valid_value("_update_puppet", [Transform.IDENTITY, [0.0, 0.0], 0.0, null, "bad"], false)
	print("SNAPSHOT_ARITY_RESULT valid=", valid, " missing_hold=", missing_hold, " invalid_hold=", invalid_hold)
	var vehicle = snapshots.valid_value("request_vehicle_pose", [Transform.IDENTITY, 12.5], false) and snapshots.valid_value("sync_vehicle_pose", [Transform.IDENTITY, -3.0], false)
	var triagon = snapshots.valid_value("sync_triagon_pose", [Transform.IDENTITY], false) and snapshots.valid_value("sync_triagon_attack", [true, false, 2500, Vector3.ONE, true], false)
	var rejects_bad = not snapshots.valid_value("sync_triagon_attack", [true, false, 2500, "bad", true], false) and not snapshots.valid_value("request_vehicle_pose", [Transform.IDENTITY, "fast"], false)
	print("VEHICLE_TRIAGON_SNAPSHOTS vehicle=", vehicle, " triagon=", triagon, " invalid_rejected=", rejects_bad)
	var combat = snapshots.valid_value("health", 1.25, true) and snapshots.valid_value("armor", 0, true) and not snapshots.valid_value("health", "bad", true) and not snapshots.valid_value("health", INF, true)
	print("COMBAT_SNAPSHOTS valid=", combat)
	get_tree().quit(0 if valid and not missing_hold and not invalid_hold and vehicle and triagon and rejects_bad and combat else 1)
