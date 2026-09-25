extends Spatial

const ActionPolicy = preload("res://MOD_CONTENT/CruS Online/PlayerActionPolicy.gd")

func is_target_action(method):
	return ActionPolicy.is_action(method)

func is_owner_state(method):
	return method in ["_update_puppet", "respawn_puppet", "set_current_weapon",
		"set_is_on_floor", "set_kick", "set_sit", "set_crouch", "set_gravity",
		"shoot_commit", "sync_implants", "set_flashlight", "_set_death", "hideHelpLabel"]

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

var jumpBlend = 0.0
var movementBlend = [0.0,0.0]
var weaponBlend = 0.0
var playerAimBlend = 0.0
var crouchBlend = 0.0

var sit_blend = 0.0
var player_sitting = false

var death = false

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

var grapple_pos = null

onready var grapple_point = $GrapplePoint
onready var grapple_start_point = $Puppet/GrappleStartPoint

onready var grapple_orb = preload("res://Entities/grappleorb.tscn")
var grapple_orbs = []

var voice_icon
var voice_icon_elapsed = 0.0
var label_font_ready = false
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
		["set_sit", NetworkBridge.PERMISSION.ALL],
		["set_crouch", NetworkBridge.PERMISSION.ALL],
		["set_gravity", NetworkBridge.PERMISSION.ALL],
		["set_flashlight", NetworkBridge.PERMISSION.ALL],
		["shoot_commit", NetworkBridge.PERMISSION.ALL],
		["_respawn_player", NetworkBridge.PERMISSION.SERVER],
		["hideHelpLabel", NetworkBridge.PERMISSION.ALL],
		["_set_tranquilize", NetworkBridge.PERMISSION.ALL],
		["_add_velocity", NetworkBridge.PERMISSION.SERVER]
	])
	
	weaponsMesh = $Puppet/PlayerModel/Armature/Skeleton/RightHand/Weapons.get_children()
	var skinMaterial = SpatialMaterial.new()
	skinMaterial.albedo_texture = load(skinPath)
	$Puppet/PlayerModel/Armature/Skeleton/Torso_Mesh.material_override = skinMaterial
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
	
	if Multiplayer.can_peer_be_revived(int(name)):
		$Puppet/PlayerModel/HelpTimer.wait_time = Multiplayer.hostSettings.helpTimer
		$Puppet/PlayerModel/HelpLabel.show()
		$Puppet/PlayerModel/HelpTimer.start()
	else:
		$Puppet/PlayerModel/HelpTimer.stop()
		$Puppet/PlayerModel/HelpLabel.hide()
		$Puppet/PlayerModel/Armature/Skeleton/Chest/Body.set_collision_layer_bit(8, false)

func can_respawn():
	if not Multiplayer.can_peer_be_revived(int(name)):
		$Puppet/PlayerModel/HelpLabel.hide()
		$Puppet/PlayerModel/Armature/Skeleton/Chest/Body.set_collision_layer_bit(8, false)
		return
	$Puppet/PlayerModel/HelpLabel.text = "Press [Use] to revive"
	$Puppet/PlayerModel/Armature/Skeleton/Chest/Body.set_collision_layer_bit(8, true)

remote func set_sit(id, recived_value):
	if int(self.name) == NetworkBridge.get_id():
		NetworkBridge.n_rpc(self, "set_sit", [recived_value])
	else:
		player_sitting = recived_value

func _process(delta):
	_update_player_indicator()
	if not label_font_ready:
		_apply_label_font()
	voice_icon_elapsed += delta
	if voice_icon_elapsed >= 0.1:
		voice_icon_elapsed = 0.0
		_update_voice_icon()
	weaponBlend = lerp(weaponBlend, float(!weaponHold), delta * 4.0)
	crouchBlend = lerp(crouchBlend, floor(playerCrouch), delta * 4.0)
	jumpBlend = lerp(jumpBlend, abs(floor(playerOnFloor) - 1), delta * 4.0)
	sit_blend = lerp(sit_blend, floor(player_sitting) * 2.0, delta * 4.0)
	
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
	
	$Puppet/PlayerModel/Nickname.global_transform.origin = $Puppet.global_transform.origin + Vector3(0, 2.15 if not playerCrouch else 1.45, 0)
	if label_font_ready and centered_name != $Puppet/PlayerModel/Nickname.text:
		centered_name = $Puppet/PlayerModel/Nickname.text
		call_deferred("_center_nickname")
	if not $Puppet/PlayerModel/HelpTimer.is_stopped():
		$Puppet/PlayerModel/HelpLabel.text =  "Wait " + str(floor($Puppet/PlayerModel/HelpTimer.time_left * 10.0)/10.0) + " to revive"
	
	if $Puppet/PlayerModel/SFX/IED_alert.playing:
		$Puppet/PlayerModel/SFX/IED_alert.pitch_scale += 0.025

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
			var names = [implants.head_implant.i_name, implants.torso_implant.i_name, implants.arm_implant.i_name, implants.leg_implant.i_name]
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
		if int(self.name) == NetworkBridge.get_id() and is_instance_valid(Global.player):
			NetworkBridge.n_rpc_unreliable(self, "_update_puppet", [Global.player.global_transform, [Global.player.cmd.forward_move,Global.player.cmd.right_move], Global.player.rotation_helper.rotation.x, grapple_pos])
			hide()

remote func _update_puppet(id, recivedTransform, recivedPlayerMovement, recivedPlayerAim, recived_grapple_pos = null):
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
	
	if NetworkBridge.n_is_network_master(self):
		NetworkBridge.n_rpc_unreliable(self, "_update_puppet", [recivedTransform, recivedPlayerMovement, recivedPlayerAim, grapple_pos])

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
			font.outline_size = 2
			font.outline_color = Color.black
			var ammo = Global.UI.get_node_or_null("Ammovbox/HBoxContainer/Ammo")
			if ammo != null and ammo.get_font("font") is DynamicFont:
				font.extra_spacing_char = ammo.get_font("font").extra_spacing_char
			else:
				font.extra_spacing_char = -2
		for label in [$Puppet/PlayerModel/Nickname, $Puppet/PlayerModel/HelpLabel]:
			label.font = font
			label.outline_modulate = Color.black
			label.horizontal_alignment = Label3D.ALIGN_CENTER
			label.offset = Vector2.ZERO
		label_font_ready = true
		centered_name = ""

func _center_nickname():
	var label = $Puppet/PlayerModel/Nickname
	var bounds = label.get_aabb()
	label.offset.x -= (bounds.position.x + bounds.size.x * 0.5) / label.pixel_size
