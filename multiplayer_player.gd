extends Spatial

const ActionPolicy = preload("res://MOD_CONTENT/CruS Online/PlayerActionPolicy.gd")

func is_target_action(method):
	return ActionPolicy.is_action(method)

func is_owner_state(method):
	return method in ["_update_puppet", "respawn_puppet", "set_current_weapon",
		"set_is_on_floor", "set_kick", "set_sit", "set_crouch", "set_gravity",
		"shoot_commit", "sync_goop", "sync_implants", "set_flashlight", "_set_death", "hideHelpLabel", "set_orb_attack"]

func validate_network_action(sender, target, method, args):
	if not Multiplayer.players.has(sender) or not Multiplayer.players.has(target):
		return false
	if str(name) != str(target) or get_parent() != Multiplayer.Players:
		return false
	var target_dead = Multiplayer.died_players.has(target)
	if not ActionPolicy.validate(method, args, canDamage, target_dead):
		return false
	if method == "_do_damage":
		if sender != NetworkBridge.get_host_id() and args[5] != sender:
			return false
		if not (sender == NetworkBridge.get_host_id() and args[5] == NetworkBridge.NPC_SOURCE_ID) and not NetworkBridge.damage_allowed(args[5], target):
			return false
	elif method != "_respawn_player" and sender != NetworkBridge.get_host_id() and not NetworkBridge.damage_allowed(sender, target):
		return false
	if method == "_respawn_player":
		return sender == NetworkBridge.get_host_id()
	return true

var weaponsMesh
var currentWeaponId = 0

var weaponHold = false
var playerCrouch = false
var playerOnFloor = true

var playerMovement = [0.0, 0.0]
var playerAim = 0.0
var playerHoldPosition = null

var jumpBlend = 0.0
var movementBlend = [0.0,0.0]
var weaponBlend = 0.0
var playerAimBlend = 0.0
var crouchBlend = 0.0

var sit_blend = 0.0
var player_sitting = false

var death = false
var revive_started = false

var skinPath = "res://Textures/Misc/mainguy_clothes.png"
var nickname = "MT Foxtrot"
var color = "ff0000"

var transform_lerp : Transform

onready var animTree = $Puppet/PlayerModel/AnimTree

onready var Multiplayer = Global.get_node("Multiplayer")
onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")
onready var SteamInit = Global.get_node("Multiplayer/NetworkBridge")

var canDamage = false
var implant_state = {}
var _implant_names = []
var _implant_elapsed = 0.0
var _body_meshes = []
var _body_base_materials = []
var _body_stealth_materials = []
var _body_visual_mode = ""
var _golem_model = null
var _golem_anim = null
var _golem_animation = ""
var _golem_visible = false
var _golem_attack_until = 0

var grapple_pos = null

onready var grapple_point = $GrapplePoint
onready var grapple_start_point = $Puppet/GrappleStartPoint

onready var grapple_orb = preload("res://Entities/grappleorb.tscn")
var grapple_orbs = []

var voice_icon
var voice_icon_elapsed = 0.0
var label_font_ready = false
var label_shadows = {}
var centered_name = ""
var indicator_material = null

func _ready():
	$Puppet/PlayerModel/Nickname.set_as_toplevel(true)
	$Puppet/PlayerModel/Nickname.global_transform = Transform.IDENTITY
	$Puppet/PlayerModel/Nickname.billboard = SpatialMaterial.BILLBOARD_ENABLED
	$Puppet/PlayerModel/Nickname.horizontal_alignment = Label3D.ALIGN_CENTER
	voice_icon = Sprite3D.new()
	voice_icon.name = "VoiceIndicator"
	voice_icon.billboard = SpatialMaterial.BILLBOARD_ENABLED
	voice_icon.translation = Vector3(0, 0.24, 0)
	voice_icon.hide()
	$Puppet/PlayerModel/Nickname.add_child(voice_icon)
	var proxy = preload("res://MOD_CONTENT/CruS Online/PlayerCollisionProxy.gd").new()
	proxy.name = "GameplayCollision"
	$Puppet.add_child(proxy)
	var pending = [$Puppet/PlayerModel]
	while not pending.empty():
		var child = pending.pop_back()
		pending.append_array(child.get_children())
		if child is PhysicsBody:
			child.set_collision_layer_bit(1, false)
	NetworkBridge.register_rpcs(self, [
		["_update_puppet", NetworkBridge.PERMISSION.ALL],
		["sync_implants", NetworkBridge.PERMISSION.ALL],
		["sync_goop", NetworkBridge.PERMISSION.ALL],
		["respawn_puppet", NetworkBridge.PERMISSION.ALL],
		["set_current_weapon", NetworkBridge.PERMISSION.ALL],
		["_set_toxic", NetworkBridge.PERMISSION.ALL],
		["_set_cancer", NetworkBridge.PERMISSION.ALL],
		["_do_damage", NetworkBridge.PERMISSION.ALL],
		["_drop_weapon", NetworkBridge.PERMISSION.ALL],
		["_set_fire", NetworkBridge.PERMISSION.ALL],
		["_set_death", NetworkBridge.PERMISSION.ALL],
		["set_is_on_floor", NetworkBridge.PERMISSION.ALL],
		["set_kick", NetworkBridge.PERMISSION.ALL],
		["set_orb_attack", NetworkBridge.PERMISSION.ALL],
		["set_sit", NetworkBridge.PERMISSION.ALL],
		["set_crouch", NetworkBridge.PERMISSION.ALL],
		["set_gravity", NetworkBridge.PERMISSION.ALL],
		["set_flashlight", NetworkBridge.PERMISSION.ALL],
		["shoot_commit", NetworkBridge.PERMISSION.ALL],
		["_respawn_player", NetworkBridge.PERMISSION.SERVER],
		["hideHelpLabel", NetworkBridge.PERMISSION.ALL],
		["_set_tranquilize", NetworkBridge.PERMISSION.ALL],
		["_add_velocity", NetworkBridge.PERMISSION.SERVER],
		["_apply_multiplayer_heal", NetworkBridge.PERMISSION.SERVER],
		["_apply_multiplayer_heal_percent", NetworkBridge.PERMISSION.SERVER],
		["_apply_multiplayer_sedative", NetworkBridge.PERMISSION.SERVER]
	])
	
	weaponsMesh = $Puppet/PlayerModel/Armature/Skeleton/RightHand/Weapons.get_children()
	var skinMaterial = SpatialMaterial.new()
	skinMaterial.albedo_texture = load(skinPath)
	_apply_outfit_mesh()
	$Puppet/PlayerModel/Armature/Skeleton/Torso_Mesh.material_override = skinMaterial
	_setup_multiplayer_body_materials()
	$Puppet/PlayerModel/Nickname.text = nickname
	$Puppet/PlayerModel/Nickname.modulate = Color(color)
	var player_indicator = $Puppet/PlayerModel/Armature/Skeleton/Head/PlayerIndicator
	var active_material = player_indicator.get_active_material(0)
	if active_material != null:
		indicator_material = active_material.duplicate()
		player_indicator.material_override = indicator_material
	

	
	rset_config("transform_lerp", MultiplayerAPI.RPC_MODE_REMOTE)
	
	print(int(self.name))
	if int(self.name) == NetworkBridge.get_id():
		Multiplayer.playerPuppet = self
	
	canDamage = false
	$RespawnDamage.start()

remote func _set_death(id, recived_death):
	death = recived_death
	if not death:
		revive_started = false
	else:
		_update_help_label_visibility()
	_update_player_indicator()
	_update_collision_stance()
	
	if death:
		transform_lerp.basis = global_transform.basis
		playerMovement = [0.0, 0.0]
		animTree.set("parameters/DEATH1/active", true)
	else:
		animTree.set("parameters/DEATH1/active", false)
		animTree.active = true

func player_restart():
	_implant_names.clear()
	_set_death(null, false)
	player_sitting = false
	playerCrouch = false
	_update_collision_stance()
	playerMovement = [0.0, 0.0]
	for sound in ["IED1", "IED2", "IED_alert"]:
		get_node("Puppet/PlayerModel/SFX/" + sound).stop()
	$Puppet/PlayerModel/HelpLabel.hide()
	$Puppet/PlayerModel/Armature/Skeleton/Chest/Body.set_collision_layer_bit(8, false)
	$Puppet/PlayerModel/HelpTimer.stop()
	
	canDamage = false
	$RespawnDamage.start()

func play_death_sound():
	$Puppet/PlayerModel/SFX/IED1.play()
	$Puppet/PlayerModel/SFX/IED2.play()
	$Puppet/PlayerModel/SFX/IED_alert.play()

func play_explosion_sound():
	death = true
	$Puppet/PlayerModel/SFX/IED_explosion.play()
	$Puppet/PlayerModel/SFX/IED_alert.stop()
	$Puppet/PlayerModel/SFX/IED1.stop()
	$Puppet/PlayerModel/SFX/IED2.stop()
	$Puppet/PlayerModel/SFX/IED_alert.pitch_scale = 1
	
	animTree.set("parameters/DEATH1/active", true)
	
	_update_help_label_visibility()

func can_respawn():
	if not Multiplayer.can_peer_be_revived(int(name)):
		$Puppet/PlayerModel/HelpLabel.hide()
		$Puppet/PlayerModel/Armature/Skeleton/Chest/Body.set_collision_layer_bit(8, false)
		return
	$Puppet/PlayerModel/HelpLabel.show()
	$Puppet/PlayerModel/HelpLabel.text = "Press [Use] to revive"
	$Puppet/PlayerModel/Armature/Skeleton/Chest/Body.set_collision_layer_bit(8, true)

remote func set_sit(id, recived_value):
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "set_sit", [recived_value])
	else:
		player_sitting = recived_value

func _process(delta):
	_update_player_indicator()
	_update_golem_visual()
	_update_multiplayer_body_visuals()
	_update_local_hold_position()
	if not label_font_ready:
		_apply_label_font()
	voice_icon_elapsed += delta
	if voice_icon_elapsed >= 0.1:
		voice_icon_elapsed = 0.0
		_update_voice_icon()
	weaponBlend = lerp(weaponBlend, float(!weaponHold), delta * 4.0)
	crouchBlend = lerp(crouchBlend, float(playerCrouch), delta * 4.0)
	jumpBlend = lerp(jumpBlend, abs(float(playerOnFloor) - 1), delta * 4.0)
	sit_blend = lerp(sit_blend, float(player_sitting) * 2.0, delta * 4.0)
	
	movementBlend[0] = lerp(movementBlend[0],playerMovement[0],0.1)
	movementBlend[1] = lerp(movementBlend[1],playerMovement[1],0.1)
	playerAimBlend = lerp(playerAimBlend,playerAim,0.1)
	
	animTree.set("parameters/LEGS_BLEND/blend_amount", clamp(jumpBlend - sit_blend, -1, 1))
	animTree.set("parameters/STANDMOVE_AMOUNT/blend_amount", movementBlend[0] * -1)
	animTree.set("parameters/CROUCHMOVE_AMOUNT/blend_amount", movementBlend[0] * -1)
	animTree.set("parameters/RUN_FORWARD_DIRECTION/blend_amount", movementBlend[1])
	animTree.set("parameters/RUN_BACKWARD_DIRECTION/blend_amount", movementBlend[1] * -1)
	animTree.set("parameters/MOVE_BLEND/blend_amount",crouchBlend)
	animTree.set("parameters/LOOK_DIRECTION/blend_amount", playerAim)
	animTree.set("parameters/ARMS_BLEND/blend_amount", weaponBlend)
	
	if not global_transform.is_equal_approx(transform_lerp):
		global_transform = global_transform.interpolate_with(transform_lerp, clamp(delta * 10.0, 0, 1))
	
	var name_height = 2.55 if implant_state.get("golem_exosystem", false) else (2.15 if not playerCrouch else 1.45)
	$Puppet/PlayerModel/Nickname.global_transform.origin = $Puppet.global_transform.origin + Vector3(0, name_height, 0)
	if label_font_ready and centered_name != $Puppet/PlayerModel/Nickname.text:
		centered_name = $Puppet/PlayerModel/Nickname.text
		call_deferred("_center_nickname")
	if not $Puppet/PlayerModel/HelpTimer.is_stopped():
		$Puppet/PlayerModel/HelpLabel.text =  "Wait " + str(floor($Puppet/PlayerModel/HelpTimer.time_left * 10.0)/10.0) + " to revive"
	_update_help_label_visibility()
	_sync_label_shadows()
	
	if $Puppet/PlayerModel/SFX/IED_alert.playing:
		$Puppet/PlayerModel/SFX/IED_alert.pitch_scale += 0.025

func _update_help_label_visibility():
	var eligible = death and Multiplayer.can_peer_be_revived(int(name))
	var body = $Puppet/PlayerModel/Armature/Skeleton/Chest/Body
	var timer = $Puppet/PlayerModel/HelpTimer
	$Puppet/PlayerModel/HelpLabel.visible = eligible
	if not eligible:
		body.set_collision_layer_bit(8, false)
		return
	if not revive_started:
		revive_started = true
		if float(Multiplayer.hostSettings.get("helpTimer", 15)) > 0:
			timer.start(float(Multiplayer.hostSettings.get("helpTimer", 15)))
	if timer.is_stopped():
		can_respawn()
	else:
		body.set_collision_layer_bit(8, false)

func _update_player_indicator():
	var indicator = $Puppet/PlayerModel/Armature/Skeleton/Head/PlayerIndicator
	var target = int(name)
	if Multiplayer.Deathmatch.is_active():
		indicator.visible = not death and not Multiplayer.died_players.has(target) and not Multiplayer.Flow.waiting_peers.has(target)
		indicator.material_override = preload("res://Materials/See_Through_Red.tres")
		return
	indicator.material_override = indicator_material
	if not Multiplayer.CounterOp.should_show_player_indicator(NetworkBridge.get_id(), target):
		indicator.hide()
		return
	if Multiplayer.died_players.has(target):
		if not Multiplayer.can_peer_be_revived(target):
			indicator.hide()
			return
		indicator.show()
		if indicator_material is SpatialMaterial:
			indicator_material.albedo_color = Color(0.5, 0.5, 0.5, 1)
		return
	indicator.show()
	if indicator_material is SpatialMaterial:
		indicator_material.albedo_color = Color(0, 1, 0.0156863, 1)

func set_grapple_orbs():
	grapple_point.global_transform.origin = grapple_pos
	var distance = grapple_start_point.global_transform.origin.distance_to(grapple_point.global_transform.origin)
	var orb_res = 4
	

	var wanted_orbs = int(distance) * orb_res
	if grapple_orbs.size() < wanted_orbs:
		for i in range(min(orb_res, wanted_orbs - grapple_orbs.size())):
			var new_grapple_orb = grapple_orb.instance()
			add_child(new_grapple_orb)
			grapple_orbs.append(new_grapple_orb)
	elif grapple_orbs.size() > wanted_orbs:
		for i in range(min(orb_res, grapple_orbs.size() - wanted_orbs)):
			grapple_orbs.pop_back().queue_free()
	var rope_direction = (grapple_start_point.global_transform.origin - grapple_point.global_transform.origin).normalized()
	for index in range(grapple_orbs.size()):
		var orb = grapple_orbs[index]
		var o_scale = (sin(OS.get_ticks_msec() * 0.002 - index) * 0.5 + 2) * 0.5
		orb.scale = Vector3(o_scale, o_scale, o_scale)
		orb.global_transform.origin = grapple_start_point.global_transform.origin - rope_direction * index / orb_res

func delete_grapple_orbs():
	for orb in grapple_orbs:
		orb.queue_free()
	grapple_orbs = []

func _physics_process(delta):
	if int(name) == NetworkBridge.get_id():
		_implant_elapsed += delta
		if _implant_elapsed >= 0.5:
			_implant_elapsed = 0.0
			var implants = Global.implants
			var names = []
			for slot in [implants.head_implant, implants.torso_implant, implants.arm_implant, implants.leg_implant]:
				names.append("N/A" if slot.jammed else slot.i_name)
			if names != _implant_names:
				_implant_names = names
				sync_implants(null, names)
				NetworkBridge.n_rpc(self, "sync_implants", [names])
	if int(self.name) != NetworkBridge.get_id():
		if grapple_pos != null and not death:
			set_grapple_orbs()
		else:
			delete_grapple_orbs()
	
	if NetworkBridge.check_connection():
		if int(self.name) == NetworkBridge.get_id() and is_instance_valid(Global.player) and is_instance_valid(Global.player.get("weapon")):
			var hold_position = Global.player.global_transform.origin
			if is_instance_valid(Global.player.weapon) and is_instance_valid(Global.player.weapon.hold_pos):
				hold_position = Global.player.weapon.hold_pos.global_transform.origin
			playerHoldPosition = hold_position
			NetworkBridge.n_rpc_unreliable(self, "_update_puppet", [Global.player.global_transform, [Global.player.cmd.forward_move,Global.player.cmd.right_move], Global.player.rotation_helper.rotation.x, grapple_pos, hold_position])
			hide()

remote func _update_puppet(id, recivedTransform, recivedPlayerMovement, recivedPlayerAim, recived_grapple_pos = null, recived_hold_position = null):
	if death:
		recivedTransform.basis = transform_lerp.basis
		recivedPlayerMovement = [0.0, 0.0]
		recivedPlayerAim = playerAim
	if int(self.name) != NetworkBridge.get_id():
		transform_lerp = recivedTransform
		if NetworkBridge.is_world_authority():
			global_transform = recivedTransform
		playerMovement = recivedPlayerMovement
		playerAim = recivedPlayerAim
		
		grapple_pos = recived_grapple_pos
		if typeof(recived_hold_position) == TYPE_VECTOR3 and not is_nan(recived_hold_position.x) and not is_nan(recived_hold_position.y) and not is_nan(recived_hold_position.z) and not is_inf(recived_hold_position.x) and not is_inf(recived_hold_position.y) and not is_inf(recived_hold_position.z) and recived_hold_position.distance_to(recivedTransform.origin) <= 3.0:
			playerHoldPosition = recived_hold_position
	
	if NetworkBridge.n_is_network_master(self):
		NetworkBridge.n_rpc_unreliable(self, "_update_puppet", [recivedTransform, recivedPlayerMovement, recivedPlayerAim, grapple_pos, playerHoldPosition])

remote func respawn_puppet(id):
	death = false
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "respawn_puppet")
	else:
		animTree.set("parameters/DEATH1/active", false)
		animTree.active = true

remote func set_current_weapon(id, value):
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "set_current_weapon", [value])
	else:
		if value == null:
			weaponHold = true
			weaponsMesh[currentWeaponId].hide()
		else:
			weaponHold = false
			weaponsMesh[currentWeaponId].hide()
			weaponsMesh[value].show()
			weaponsMesh[value].get_child(0).hide()
			currentWeaponId = value

remote func set_is_on_floor(id, value):
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "set_is_on_floor", [value])
	else:
		playerOnFloor = value

remote func set_kick(id):
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "set_kick")
	else:
		animTree.set("parameters/KICK/active", true)
		_golem_attack_until = OS.get_ticks_msec() + 450

remote func set_orb_attack(id):
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "set_orb_attack")
	else:
		_golem_attack_until = OS.get_ticks_msec() + 450

remote func _set_cancer(id):
	Global.player.cancer()

remote func set_crouch(id, value):
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "set_crouch", [value])
	else:
		playerCrouch = value
		_update_collision_stance()

remote func set_gravity(id, value):
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "set_gravity", [value])
	else:
		if value > 0:
			$Puppet/PlayerModel.rotation.z = deg2rad(0)
		else:
			$Puppet/PlayerModel.rotation.z = deg2rad(180)

func do_damage(damage, collision_n, collision_p, shooter_pos, weapon_type = null):
	if canDamage:
		var source_id = NetworkBridge.damage_source_context
		if NetworkBridge.damage_allowed(source_id, int(name)):
			NetworkBridge.n_rpc_id(self, int(self.name), "_do_damage", [damage, collision_n, collision_p, shooter_pos, weapon_type, source_id])

remote func _do_damage(id, damage, collision_n, collision_p, shooter_pos, weapon_type, source_id):
	var sender = NetworkBridge.request_sender(id)
	if sender != NetworkBridge.get_host_id() and source_id != sender:
		return
	if not (sender == NetworkBridge.get_host_id() and source_id == NetworkBridge.NPC_SOURCE_ID) and not NetworkBridge.damage_allowed(source_id, NetworkBridge.get_id()):
		return
	var damager_id = source_id if source_id > 0 and source_id != NetworkBridge.NPC_SOURCE_ID else null
	Global.player.set_last_damager_id(damager_id, weapon_type)
	Global.player.damage(damage, collision_n, collision_p, shooter_pos)

func set_tranquilize():
	NetworkBridge.n_rpc_id(self, int(self.name), "_set_tranquilize")

remote func _set_tranquilize(id):
	Global.player.set_tranquilize()

func set_grapple(recived_position):
	grapple_pos = recived_position

func set_toxic():
	NetworkBridge.n_rpc_id(self, int(self.name), "_set_toxic")

remote func _set_toxic(id):
	Global.player.set_toxic()

func set_cancer():
	NetworkBridge.n_rpc_id(self, int(self.name), "_set_cancer")

func drop_weapon():
	NetworkBridge.n_rpc_id(self, int(self.name), "_drop_weapon")

remote func _drop_weapon(id):
	Input.action_press("drop")

func set_fire(value):
	NetworkBridge.n_rpc_id(self, int(self.name), "_set_fire", [value])

remote func _set_fire(id, value):
	Global.player.fakeFire.emitting = value

func respawn_player():
	Multiplayer.request_player_revive(int(name))

remote func _respawn_player(id):
	if NetworkBridge.request_sender(id) != NetworkBridge.get_host_id():
		return
	if Global.player.died:
		Global.get_node('DeathScreen').respawn(true)
		hideHelpLabel()
		NetworkBridge.n_rpc(self, "hideHelpLabel")

remote func hideHelpLabel(id = null):
	$Puppet/PlayerModel/HelpSound.play()
	$Puppet/PlayerModel/HelpLabel.hide()
	
	canDamage = false
	$RespawnDamage.start()

func setup_puppet(id):
	$Puppet/PlayerModel/Armature/Skeleton/Chest/Body.set_meta("puppetId", id)

func shoot_play(pitch, soundId = 0):
	NetworkBridge.n_rpc(self, "shoot_commit", [pitch, soundId])

func flashlight(state):
	NetworkBridge.n_rpc(self, "set_flashlight", [state])

remote func set_flashlight(id, state):
	$Puppet/PlayerModel/Armature/Skeleton/RightHand/Weapons/Flashlight_Mesh/SpotLight.visible = state

remote func shoot_commit(id, pitch, soundId):
	var weapon_mesh = weaponsMesh[currentWeaponId]
	weapon_mesh.get_child(0).show()
	var sound_index = 1 + int(soundId)
	if sound_index < 1 or sound_index >= weapon_mesh.get_child_count():
		sound_index = 1
	if sound_index >= 1 and sound_index < weapon_mesh.get_child_count():
		var sound = weapon_mesh.get_child(sound_index)
		if sound is AudioStreamPlayer or sound is AudioStreamPlayer3D:
			sound.pitch_scale = max(0.1, pitch)
			sound.play()
	$FlashBuffer.start()

func flash_hide():
	for mesh in weaponsMesh:
		if mesh.get_child_count() > 0:
			mesh.get_child(0).hide()

func canDamageSet():
	canDamage = true

remote func sync_implants(id, names):
	if names is Array:
		names = names.duplicate()
		for index in range(names.size()):
			if Multiplayer.is_implant_banned(names[index]):
				names[index] = "N/A"
	var state = preload("res://MOD_CONTENT/CruS Online/ImplantNetwork.gd").resolve(Global.implants.IMPLANTS, names)
	if state != null:
		implant_state = state
		_refresh_multiplayer_body_materials()
		_update_golem_visual()

func _apply_outfit_mesh():
	var outfit_scenes = {
		"res://Textures/NPC/Enemy_Worker.png": "res://Entities/Enemies/E_Civilian_Worker.tscn",
		"res://Textures/NPC/Enemy_Nude.png": "res://Entities/Enemies/E_Civilian_Nude.tscn",
		"res://Textures/NPC/cultist_civilian.png": "res://Entities/Enemies/E_Civilian_Cultist_1.tscn",
		"res://Textures/NPC/bosssguy_clothes.png": "res://Entities/Enemies/E_Boss_Life.tscn",
		"res://Textures/NPC/Enemy_Assassin.png": "res://Entities/Enemies/E_Assassin.tscn",
		"res://Textures/NPC/Enemy_Assassin_Alt.png": "res://Entities/Enemies/E_Assassin_Weak.tscn",
		"res://Textures/NPC/Enemy_Civilian2.png": "res://Entities/Enemies/E_Civilian2.tscn",
		"res://Textures/NPC/Enemy_Cop1.png": "res://Entities/Enemies/E_Cop_Shotgun.tscn",
		"res://Textures/NPC/Enemy_Kevin.png": "res://Entities/Enemies/E_Kevin.tscn",
		"res://Textures/NPC/Objective_CEO.png": "res://Entities/Enemies/Obj_CEO.tscn",
		"res://Textures/NPC/Elsa.png": "res://Entities/Enemies/Elsa.tscn"
	}
	if not outfit_scenes.has(skinPath):
		return
	var scene = load(outfit_scenes[skinPath])
	if scene == null:
		return
	var source = scene.instance()
	var source_skeleton = source.get_node_or_null("Nemesis/Armature/Skeleton")
	var source_torso = source.get_node_or_null("Nemesis/Armature/Skeleton/Torso_Mesh")
	var target_skeleton = $Puppet/PlayerModel/Armature/Skeleton
	if source_skeleton != null and source_torso != null and source_skeleton.get_bone_count() == target_skeleton.get_bone_count():
		var compatible = true
		for bone in range(target_skeleton.get_bone_count()):
			if source_skeleton.get_bone_name(bone) != target_skeleton.get_bone_name(bone):
				compatible = false
				break
		if compatible:
			var target_torso = target_skeleton.get_node("Torso_Mesh")
			target_torso.mesh = source_torso.mesh
			target_torso.skin = source_torso.skin
	source.free()

func _update_golem_visual():
	var equipped = implant_state.get("golem_exosystem", false)
	if equipped and _golem_model == null:
		_golem_model = load("res://Imported_Mesh/orbot.glb").instance()
		_golem_model.name = "GolemModel"
		$Puppet.add_child(_golem_model)
		_golem_model.translation = Vector3(0, 1.0, 0)
		_golem_model.rotation.y = PI
		_golem_anim = _golem_model.get_node_or_null("AnimationPlayer")
		var torso = _golem_model.get_node_or_null("Armature/Skeleton/Torso_Mesh")
		if torso != null:
			torso.material_override = load("res://Materials/rod.tres")
	if equipped != _golem_visible:
		_golem_visible = equipped
		if _golem_model != null:
			_golem_model.visible = equipped
		var skeleton = $Puppet/PlayerModel/Armature/Skeleton
		skeleton.get_node("Torso_Mesh").visible = not equipped
		skeleton.get_node("Head_Mesh").visible = not equipped
		skeleton.get_node("Head/glasses").visible = not equipped
		skeleton.get_node("RightHand/Weapons").visible = not equipped
	if not equipped or _golem_anim == null:
		_golem_animation = ""
		return
	var next_animation = "Death1" if death else ("Attack" if OS.get_ticks_msec() < _golem_attack_until else ("Run" if abs(playerMovement[0]) + abs(playerMovement[1]) > 0.15 else "Idle"))
	if next_animation != _golem_animation and _golem_anim.has_animation(next_animation):
		_golem_animation = next_animation
		_golem_anim.play(next_animation)

func _setup_multiplayer_body_materials():
	var shader = preload("res://MOD_CONTENT/CruS Online/effects/player_stealth_dither.shader")
	for path in ["Puppet/PlayerModel/Armature/Skeleton/Head_Mesh", "Puppet/PlayerModel/Armature/Skeleton/Torso_Mesh", "Puppet/PlayerModel/Armature/Skeleton/Head/glasses"]:
		var mesh = get_node_or_null(path)
		if not is_instance_valid(mesh):
			continue
		_body_meshes.append(mesh)
		_body_base_materials.append(mesh.material_override)
		var source = mesh.material_override
		if source == null:
			source = mesh.get_active_material(0)
		var material = ShaderMaterial.new()
		material.shader = shader
		var texture = null
		if source is SpatialMaterial:
			texture = source.albedo_texture
			material.set_shader_param("albedo_color", source.albedo_color)
			material.set_shader_param("surface_roughness", source.roughness)
			material.set_shader_param("surface_metallic", source.metallic)
			material.set_shader_param("surface_specular", source.metallic_specular)
		elif source == null:
			texture = load(skinPath)
		material.set_shader_param("use_albedo_texture", texture != null)
		material.set_shader_param("albedo_texture", texture)
		material.set_shader_param("visibility", 1.0)
		_body_stealth_materials.append(material)

func _refresh_multiplayer_body_materials():
	var mode = "distance_hide" if implant_state.get("multiplayer_camo", false) else ("half_dither" if implant_state.get("multiplayer_stealth", false) else "")
	if mode == _body_visual_mode:
		return
	_body_visual_mode = mode
	for index in range(_body_meshes.size()):
		if mode in ["distance_hide", "half_dither"]:
			var material = _body_stealth_materials[index]
			if mode == "half_dither":
				material.shader = preload("res://MOD_CONTENT/CruS Online/effects/player_stealth_optical_dither.shader")
				var optical = preload("res://Materials/seethrough.tres")
				material.set_shader_param("optical_color", optical.albedo_color)
				material.set_shader_param("optical_metallic", optical.metallic)
				material.set_shader_param("optical_specular", optical.metallic_specular)
				material.set_shader_param("optical_roughness", optical.roughness)
				material.set_shader_param("optical_transmission", optical.transmission)
				material.set_shader_param("optical_refraction", optical.refraction_scale)
			else:
				material.shader = preload("res://MOD_CONTENT/CruS Online/effects/player_stealth_dither.shader")
			_body_meshes[index].material_override = material
		else:
			_body_meshes[index].material_override = _body_base_materials[index]

func _update_multiplayer_body_visuals():
	if int(name) == NetworkBridge.get_id() or not is_instance_valid(Global.player):
		return
	var distance = Global.player.global_transform.origin.distance_to(global_transform.origin)
	$Puppet/PlayerModel/Nickname.visible = distance <= 12.0
	if _body_visual_mode == "":
		return
	var visibility = 0.5 if _body_visual_mode == "half_dither" else clamp((12.0 - distance) / 3.0, 0.0, 1.0)
	for material in _body_stealth_materials:
		material.set_shader_param("visibility", visibility)

func _update_local_hold_position():
	if int(name) != NetworkBridge.get_id() or not is_instance_valid(Global.player):
		return
	var holder = Multiplayer.held_by(int(name))
	if holder == 0:
		return
	var holder_actor = NetworkBridge.get_peer_actor(holder)
	if not is_instance_valid(holder_actor):
		return
	var hold_position = null
	if "playerHoldPosition" in holder_actor and typeof(holder_actor.playerHoldPosition) == TYPE_VECTOR3:
		if holder_actor.playerHoldPosition.distance_to(holder_actor.global_transform.origin) <= 3.0:
			hold_position = holder_actor.playerHoldPosition
	if hold_position == null:
		hold_position = holder_actor.global_transform.origin - holder_actor.global_transform.basis.z.normalized() * 1.142 + Vector3.UP * 1.481
	Global.player.global_transform.origin = hold_position - Vector3.UP * 0.918484
	Global.player.player_velocity = Vector3.ZERO

func apply_multiplayer_heal(amount):
	if not NetworkBridge.is_world_authority():
		return
	if int(name) == NetworkBridge.get_id():
		_apply_heal(amount)
	else:
		NetworkBridge.n_rpc_id(self, int(name), "_apply_multiplayer_heal", [amount])

remote func _apply_multiplayer_heal(id, amount):
	if NetworkBridge.check_connection() and NetworkBridge.request_sender(id) != NetworkBridge.get_host_id():
		return
	_apply_heal(amount)

func _apply_heal(amount):
	if typeof(amount) in [TYPE_INT, TYPE_REAL] and amount > 0 and amount <= 100 and int(name) == NetworkBridge.get_id() and is_instance_valid(Global.player):
		Global.player.add_health(float(amount))

func apply_multiplayer_heal_percent(percent):
	if not NetworkBridge.is_world_authority():
		return
	if int(name) == NetworkBridge.get_id():
		_apply_multiplayer_heal_percent(null, percent)
	else:
		NetworkBridge.n_rpc_id(self, int(name), "_apply_multiplayer_heal_percent", [percent])

puppet func _apply_multiplayer_heal_percent(id, percent):
	if NetworkBridge.check_connection() and NetworkBridge.request_sender(id) != NetworkBridge.get_host_id():
		return
	if not (typeof(percent) in [TYPE_INT, TYPE_REAL]) or percent <= 0 or percent > 0.5 or int(name) != NetworkBridge.get_id() or not is_instance_valid(Global.player):
		return
	var max_health = 200.0 if Global.player.orb else 100.0
	Global.player.add_health(max_health * float(percent))

func set_multiplayer_sedative(source_id):
	if not NetworkBridge.is_world_authority() or int(source_id) == int(name) or implant_state.get("sedative_immune", false):
		return
	if int(name) == NetworkBridge.get_id():
		_apply_sedative(source_id)
	else:
		NetworkBridge.n_rpc_id(self, int(name), "_apply_multiplayer_sedative", [int(source_id)])

remote func _apply_multiplayer_sedative(id, source_id):
	if NetworkBridge.check_connection() and NetworkBridge.request_sender(id) != NetworkBridge.get_host_id():
		return
	_apply_sedative(source_id)

func _apply_sedative(source_id):
	if int(source_id) == NetworkBridge.get_id() or int(name) != NetworkBridge.get_id() or not is_instance_valid(Global.player):
		return
	if Global.implants.torso_implant.terror or Global.implants.torso_implant.orbsuit:
		return
	Global.player.set_multiplayer_sedative(10.0)

func _update_collision_stance():
	var proxy = get_node_or_null("Puppet/GameplayCollision")
	if proxy != null:
		proxy.update_stance()

puppet func _add_velocity(id, velocity):
	if int(name) == NetworkBridge.get_id() and ActionPolicy.finite_vector(velocity) and velocity.length() <= 2000 and is_instance_valid(Global.player):
		Global.player.player_velocity += velocity

func _update_voice_icon():
	var voice = Global.get_node("Multiplayer").get_node_or_null("VoiceChat")
	if voice == null or not is_instance_valid(voice_icon):
		return
	var peer = int(name)
	voice_icon.visible = voice.is_talking(peer)
	voice_icon.texture = voice.TALK_ICON
	voice_icon.pixel_size = 0.22 / voice_icon.texture.get_height()
	voice_icon.modulate = Color(0.35, 0.35, 0.35) if voice.is_muted(peer) else Color.white

func _apply_label_font():
	if not is_instance_valid(Global.UI):
		return
	var health_label = Global.UI.get_node_or_null("UI_HBOX/TextureRect/Health")
	if health_label != null:
		var font = health_label.get_font("font").duplicate()
		if font is DynamicFont:
			font.outline_size = 0
			var ammo = Global.UI.get_node_or_null("Ammovbox/HBoxContainer/Ammo")
			if ammo != null and ammo.get_font("font") is DynamicFont:
				font.extra_spacing_char = ammo.get_font("font").extra_spacing_char
			else:
				font.extra_spacing_char = -2
		for label in [$Puppet/PlayerModel/Nickname, $Puppet/PlayerModel/HelpLabel]:
			label.font = font
			label.horizontal_alignment = Label3D.ALIGN_CENTER
			label.offset = Vector2.ZERO
			var shadow = label.duplicate(0)
			for child in shadow.get_children():
				shadow.remove_child(child)
				child.free()
			shadow.name = label.name + "Shadow"
			shadow.font = font
			shadow.billboard = label.billboard
			shadow.pixel_size = label.pixel_size
			shadow.horizontal_alignment = Label3D.ALIGN_CENTER
			shadow.render_priority = -1
			shadow.modulate = Color.black
			label.get_parent().add_child(shadow)
			shadow.set_as_toplevel(label.is_set_as_toplevel())
			label_shadows[label.name] = shadow
		label_font_ready = true
		centered_name = ""

func _sync_label_shadows():
	if not label_font_ready:
		return
	for label in [$Puppet/PlayerModel/Nickname, $Puppet/PlayerModel/HelpLabel]:
		var shadow = label_shadows.get(label.name)
		if not is_instance_valid(shadow):
			continue
		shadow.text = label.text
		shadow.visible = label.visible
		shadow.global_transform = label.global_transform
	call_deferred("_align_label_shadows")

func _align_label_shadows():
	for label in [$Puppet/PlayerModel/Nickname, $Puppet/PlayerModel/HelpLabel]:
		var shadow = label_shadows.get(label.name)
		if not is_instance_valid(shadow):
			continue
		var label_bounds = label.get_aabb()
		var shadow_bounds = shadow.get_aabb()
		var label_center = label_bounds.position + label_bounds.size * 0.5
		var shadow_center = shadow_bounds.position + shadow_bounds.size * 0.5
		var correction = Vector2(label_center.x - shadow_center.x, label_center.y - shadow_center.y) / label.pixel_size + Vector2(2, -2)
		if correction.length_squared() > 0.001:
			shadow.offset += correction

func _center_nickname():
	var label = $Puppet/PlayerModel/Nickname
	var bounds = label.get_aabb()
	label.offset.x -= (bounds.position.x + bounds.size.x * 0.5) / label.pixel_size

remote func sync_goop(id, position, yaw, burst):
	if not NetworkBridge.request_sender(id) in [int(name), NetworkBridge.get_host_id()] or typeof(burst) != TYPE_BOOL or not typeof(yaw) in [TYPE_INT, TYPE_REAL]: return
	if not is_instance_valid(Global.current_scene) or not is_instance_valid(Global.player): return
	if position != null:
		if typeof(position) != TYPE_VECTOR3 or position.distance_to(global_transform.origin) > 15.0: return
		var decal = preload("res://Entities/Decals/FleshDecal2.tscn").instance()
		decal.name = "OnlineGoop"
		Global.current_scene.add_child(decal)
		decal.global_transform.origin = position
		decal.rotation.y = yaw
	if burst:
		var source = Global.player.get_node_or_null("Particles")
		if not is_instance_valid(source): return
		var particles = source.duplicate(0)
		particles.name = "OnlineGunkBurst"
		particles.emitting = false
		Global.current_scene.add_child(particles)
		particles.global_transform = global_transform * source.transform
		particles.one_shot = true
		particles.restart()
		particles.emitting = true
		get_tree().create_timer(particles.lifetime + 0.5).connect("timeout", particles, "queue_free")
