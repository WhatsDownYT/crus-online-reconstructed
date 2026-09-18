extends Spatial



const SegmentScript = preload("res://MOD_CONTENT/CruS Online/CancerSegment.gd")
const MAX_GROWTH_PER_FRAME = 64
const MAX_DAMAGE_PER_FRAME = 128
var segment_scene = preload("res://Cancerball.tscn")
var gib_scenes = [preload("res://Entities/Physics_Objects/Chest_Gib.tscn"),
	preload("res://Entities/Physics_Objects/Leg_Gib.tscn"),
	preload("res://Entities/Physics_Objects/Arm_Gib.tscn"),
	preload("res://Entities/Physics_Objects/Head_Gib.tscn")]
onready var NetworkBridge = get_parent().get_node("NetworkBridge")
var epoch = 0
var next_id = 1
var last_spawn_id = 0
var entities = {}
var growth = []
var hits = []
var growth_sound

func _ready():
	pause_mode = Node.PAUSE_MODE_STOP
	NetworkBridge.register_rpcs(self, [
		["spawn_segment", NetworkBridge.PERMISSION.SERVER],
		["remove_segment", NetworkBridge.PERMISSION.SERVER],
		["deform_segment", NetworkBridge.PERMISSION.SERVER],
		["spawn_gib", NetworkBridge.PERMISSION.SERVER],
		["remove_npc", NetworkBridge.PERMISSION.SERVER],
		["request_damage", NetworkBridge.PERMISSION.ALL]
	])

func reset(new_epoch):
	epoch = new_epoch
	growth.clear()
	hits.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	entities.clear()

func _allocate_id():
	var result = next_id
	next_id += 1
	return result

func _send(method, args):
	if NetworkBridge.check_connection():
		NetworkBridge.n_rpc(self, method, args)

func convert_npc(soul, position):
	if not NetworkBridge.is_world_authority() or soul.dead or not soul.enabled or soul.cancer_immunity or soul.armor > 0:
		return false
	var source_path = soul.get_path()
	soul.remove_objective()
	soul.dead = true
	soul.enabled = false
	for i in range(6):
		var direction = (Vector3.UP * 0.4).rotated(Vector3.FORWARD, rand_range(-PI, PI))
		direction = direction.rotated(Vector3.LEFT, rand_range(-PI, PI))
		direction = direction.rotated(Vector3.UP, rand_range(-PI, PI))
		_create_segment(0, Transform(Basis(), position), direction, 1, Vector3.ONE)
	_send("remove_npc", [epoch, source_path])
	remove_npc(null, epoch, source_path)
	return true

puppet func remove_npc(_sender, event_epoch, source_path):
	if event_epoch != epoch or typeof(source_path) != TYPE_NODE_PATH:
		return
	var npc = get_node_or_null(source_path)
	if npc == null or not npc.has_method("remove_objective"):
		return
	npc.dead = true
	npc.enabled = false
	npc.hide()
	npc.queue_free()

func _create_segment(parent_id, pose, direction, depth, mesh_scale):
	var identifier = _allocate_id()
	spawn_segment(null, epoch, identifier, parent_id, pose, direction, depth, mesh_scale)
	_send("spawn_segment", [epoch, identifier, parent_id, pose, direction, depth, mesh_scale])
	return identifier

puppet func spawn_segment(_sender, event_epoch, identifier, parent_id, pose, direction, depth, mesh_scale):
	if event_epoch != epoch or typeof(identifier) != TYPE_INT or identifier <= last_spawn_id or entities.has(identifier):
		return
	if typeof(parent_id) != TYPE_INT or typeof(depth) != TYPE_INT or depth < 1 or depth > 11:
		return
	if typeof(pose) != TYPE_TRANSFORM or typeof(direction) != TYPE_VECTOR3 or typeof(mesh_scale) != TYPE_VECTOR3:
		return
	var parent_node = self if parent_id == 0 else entities.get(parent_id)
	if not is_instance_valid(parent_node) or (parent_id != 0 and parent_node.pending_removal):
		return
	var segment = segment_scene.instance()
	segment.set_script(SegmentScript)
	segment.name = "Cancer#" + str(identifier)
	segment.controller = self
	segment.entity_id = identifier
	segment.parent_id = parent_id
	segment.count = depth
	segment.damaged_count = depth
	segment.dir = direction
	segment.transform = parent_node.global_transform.affine_inverse() * pose
	entities[identifier] = segment
	last_spawn_id = identifier
	next_id = max(next_id, identifier + 1)
	segment.connect("tree_exiting", self, "_unregister", [identifier])
	parent_node.add_child(segment)
	growth_sound = segment.get_node("Audio").stream
	segment.get_node("MeshInstance").scale = mesh_scale
	if parent_id != 0:
		parent_node.child_id = identifier
	if NetworkBridge.is_world_authority() and depth <= 10:
		growth.append(identifier)

func _unregister(identifier):
	entities.erase(identifier)

func _process(_delta):
	if not NetworkBridge.is_world_authority():
		return
	var pending_growth = []
	for i in range(min(growth.size(), MAX_GROWTH_PER_FRAME)):
		pending_growth.append(growth.pop_front())
	for identifier in pending_growth:
		var segment = entities.get(identifier)
		if not is_instance_valid(segment) or segment.pending_removal:
			continue
		var direction = segment.dir.rotated(Vector3.UP, rand_range(-0.5, 0.5))
		direction = direction.rotated(Vector3.FORWARD, rand_range(-0.5, 0.5))
		direction = direction.rotated(Vector3.LEFT, rand_range(-0.5, 0.5))
		var pose = segment.global_transform
		pose.origin += direction
		var scale_value = cos(segment.count) * 0.6 + 2
		_create_segment(identifier, pose, direction, segment.count + 1, Vector3.ONE * scale_value)
	var pending_hits = []
	for i in range(min(hits.size(), MAX_DAMAGE_PER_FRAME)):
		pending_hits.append(hits.pop_front())
	for identifier in pending_hits:
		_damage_step(identifier)

func request_hit(identifier, amount, normal, point, shooter_position):
	if NetworkBridge.is_world_authority():


		_queue_hit(identifier, amount, normal, point, shooter_position)
	else:
		NetworkBridge.request_host(self, "request_damage", [epoch, identifier, amount, normal, point, shooter_position])

master func request_damage(sender, event_epoch, identifier, amount, normal, point, shooter_position):
	if not NetworkBridge.is_world_authority() or event_epoch != epoch:
		return
	sender = NetworkBridge.request_sender(sender)
	if NetworkBridge.get_peer_actor(sender) == null or not entities.has(identifier):
		return
	_queue_hit(identifier, amount, normal, point, shooter_position)

func _queue_hit(identifier, amount, normal, point, shooter_position):
	if not entities.has(identifier):
		return
	if not typeof(amount) in [TYPE_INT, TYPE_REAL] or is_nan(amount) or is_inf(amount) or amount < 0 or amount > 10000:
		return
	for value in [normal, point, shooter_position]:
		if typeof(value) != TYPE_VECTOR3 or is_nan(value.length_squared()) or is_inf(value.length_squared()):
			return
	if not hits.has(identifier):
		hits.append(identifier)

func _damage_step(identifier):
	var segment = entities.get(identifier)
	if not is_instance_valid(segment) or segment.pending_removal:
		return
	var child = entities.get(segment.child_id)
	if is_instance_valid(child) and not child.pending_removal:
		child.damaged_count = segment.count
		if not hits.has(child.entity_id):
			hits.append(child.entity_id)
		var mesh_scale = Vector3.ONE * (sin(child.count) * 0.2 + 1)
		deform_segment(null, epoch, child.entity_id, mesh_scale)
		_send("deform_segment", [epoch, child.entity_id, mesh_scale])
	else:
		var parent_segment = entities.get(segment.parent_id)
		if is_instance_valid(parent_segment) and parent_segment.count >= parent_segment.damaged_count:
			parent_segment.damaged_count = segment.damaged_count
			if not hits.has(parent_segment.entity_id):
				hits.append(parent_segment.entity_id)
			if segment.count % 3 == 0:
				var gib_id = _allocate_id()
				var model = randi() % gib_scenes.size()
				var velocity = Vector3(rand_range(-10, 10), rand_range(-10, 10), rand_range(-10, 10))
				spawn_gib(null, epoch, gib_id, model, segment.global_transform, velocity)
				_send("spawn_gib", [epoch, gib_id, model, segment.global_transform, velocity])
		destroy_segment(identifier)

puppet func deform_segment(_sender, event_epoch, identifier, mesh_scale):
	if event_epoch == epoch and entities.has(identifier) and typeof(mesh_scale) == TYPE_VECTOR3:
		entities[identifier].get_node("MeshInstance").scale = mesh_scale

func destroy_segment(identifier):
	if not NetworkBridge.is_world_authority() or not entities.has(identifier):
		return
	_send("remove_segment", [epoch, identifier])
	remove_segment(null, epoch, identifier)

puppet func remove_segment(_sender, event_epoch, identifier):
	if event_epoch != epoch or not entities.has(identifier):
		return
	var segment = entities[identifier]
	segment.pending_removal = true
	var parent_segment = entities.get(segment.parent_id)
	if is_instance_valid(parent_segment):
		parent_segment.child_id = 0

	segment.get_parent().remove_child(segment)
	segment.queue_free()

puppet func spawn_gib(_sender, event_epoch, identifier, model, pose, velocity):
	if event_epoch != epoch or typeof(identifier) != TYPE_INT or identifier <= last_spawn_id or typeof(model) != TYPE_INT or model < 0 or model >= gib_scenes.size():
		return
	var gib_name = "CancerGib#" + str(identifier)
	if has_node(NodePath(gib_name)) or typeof(pose) != TYPE_TRANSFORM or typeof(velocity) != TYPE_VECTOR3:
		return
	var gib = gib_scenes[model].instance()
	gib.name = gib_name
	gib.transform = global_transform.affine_inverse() * pose
	gib.velocity = velocity
	add_child(gib)
	if growth_sound != null:
		var sound = AudioStreamPlayer3D.new()
		sound.stream = growth_sound
		sound.unit_db = -18.686
		sound.unit_size = 23.6
		sound.max_db = -9.534
		sound.bus = "SFX"
		add_child(sound)
		sound.global_transform = pose
		sound.connect("finished", sound, "queue_free")
		sound.play()
	last_spawn_id = identifier
	next_id = max(next_id, identifier + 1)
