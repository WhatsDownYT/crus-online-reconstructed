extends Node

var mp
var failures = 0
var client_id = 0

class SniperWeaponFixture extends Spatial:
	var disabled = true
	var current_weapon = 0
	var damage = [0, 0, 0, 0, 0, 0, 0]

func check(ok, label):
	print("REVISION_CHECK host=", HOST, " ", label, "=", ok)
	var trace = File.new()
	trace.open("E:/Cruelty/Online/development/artifacts/ban-test-progress-" + str(HOST) + ".txt", File.WRITE)
	trace.store_line(label + "=" + str(ok))
	trace.close()
	if not ok: failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func barrier(stage):
	var prefix = "E:/Cruelty/Online/development/artifacts/revision-" + str(PORT) + "-" + stage + "-"
	var file = File.new()
	file.open(prefix + str(HOST), File.WRITE)
	file.store_string("ready")
	file.close()
	yield(get_tree(), "idle_frame")
	while not file.file_exists(prefix + str(not HOST)):
		yield(get_tree().create_timer(0.05), "timeout")

func run():
	yield(get_tree().create_timer(12), "timeout")
	while not is_instance_valid(Global.menu):
		yield(get_tree().create_timer(0.1), "timeout")
	mp = Global.get_node("Multiplayer")
	mp.Voice.test_capture = true
	Global.select_save_slot(1)
	mp.NetworkBridge.set_mode(mp.NetworkBridge.MULTIPLAYER_TYPE.LAN)
	if HOST:
		mp.config.hostPort = PORT
		mp.config.canRespawn = true
		mp.config.selfRespawn = false
		mp.config.reviveLives = 1
		mp.config.dropWeaponsOnDeath = true
		mp.config.spawnInvulnerability = 2.0
		mp.config.helpTimer = 0
		mp.host_server()
	else:
		mp.join_to_server("127.0.0.1", PORT)
	while mp.players.size() < 2:
		yield(get_tree().create_timer(0.1), "timeout")
	for peer in mp.players:
		if peer != 1: client_id = peer
	if not HOST:
		Global.menu.weapon_menu_panel.show()
	if HOST:
		yield(get_tree().create_timer(1), "timeout")
		Global.CURRENT_LEVEL = 1
		mp.game_init(Global.LEVELS[1])
	while Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	Global.player.health = 10000
	yield(get_tree().create_timer(3), "timeout")
	var player = Global.player
	check(not Global.menu.weapon_menu_panel.visible, "mission start closes client weapon panel")
	player.set_process(false)
	player.set_physics_process(false)
	player.start_flag = true
	player.health = 10000
	player.global_transform.origin = Vector3(0, 1000, 0) if HOST else Vector3(0, 1000, 2)
	Global.menu.hide()
	mp.Menu.hide()
	yield(test_community_and_spectating(player), "completed")
	yield(test_live_implant_bans(), "completed")
	yield(test_weapon_bans(player), "completed")
	mp.Eyecam.set_process(false)
	check(Global.settings().has("vsync"), "V-Sync persists in settings")
	var local = mp.NetworkBridge.get_id()
	mp.grant_spawn_protection(local)
	var health = player.health
	player.damage(100, Vector3.ZERO, player.global_transform.origin, Vector3.ZERO)
	check(player.health == health, "spawn protection blocks local damage")
	mp.spawn_protected_until.clear()
	mp.hostSettings.spawnInvulnerability = 0.0
	var voice = mp.Voice
	voice.set_process(false)
	var other = client_id if HOST else 1
	var fx = preload("res://MOD_CONTENT/CruS Online/voice/voice_effects.gd")
	voice.peers[other] = {"effects": fx.ABOMINATOR, "dead": false}
	voice.local_effect_mask = fx.ABOMINATOR
	check((voice.effect_mask(other) & fx.ABOMINATOR) == 0, "inverted speakers hear each other normally")
	voice.peers[other].effects = 0
	check((voice.effect_mask(other) & fx.ABOMINATOR) != 0, "inverted listener reverses upright speaker")
	voice.local_effect_mask = 0
	for implant in Global.implants.IMPLANTS:
		if implant.i_name == "Cortical Scaledown+": Global.implants.head_implant = implant
	yield(barrier("shrink"), "completed")
	yield(get_tree().create_timer(1.0), "timeout")
	var puppet = mp.players[other].puppet
	check(puppet.get_node("Puppet/PlayerModel/Armature").scale.is_equal_approx(Vector3.ONE * 0.1), "remote body is one tenth size")
	check(puppet.get_node("Puppet/PlayerModel/Nickname").global_transform.basis.get_scale().is_equal_approx(Vector3.ONE), "name remains full size")
	Global.implants.head_implant = Global.implants.empty_implant
	var lift = load("res://Scripts/Elevator.gd").new()
	lift.name = "TestLift"
	Global.current_scene.add_child(lift)
	check(lift.move_audio.stream.loop_mode == AudioStreamSample.LOOP_FORWARD and lift.move_audio.stream.loop_end > 0, "elevator audio loops over the sample")
	lift.queue_free()
	yield(barrier("car"), "completed")
	var car = load("res://Entities/Vehicles/New_Car.tscn").instance()
	car.name = "TestPassengerCar"
	Global.current_scene.add_child(car)
	car.global_transform.origin = Vector3(0, 1000, 0)
	car.set_physics_process(false)
	check(car.seat_capacity == 4 and car.seat_positions.size() == 4, "new car has four seats")
	yield(get_tree().create_timer(0.5), "timeout")
	yield(barrier("seat_host"), "completed")
	if HOST: car.player_use()
	yield(get_tree().create_timer(0.5), "timeout")
	yield(barrier("seat_client"), "completed")
	if not HOST: car.player_use()
	yield(get_tree().create_timer(0.7), "timeout")
	check(car.seats[0] == 1 and car.seats[1] == client_id, "driver and passenger assignments match")
	check(player.car == car and car.local_seat == (0 if HOST else 1), "each occupant enters their seat")
	check(car.get_collision_exceptions().has(player) and player.get_collision_exceptions().has(car), "occupants cannot push the car through their player collider")
	check(not player.grab_hand.visible, "vehicle hides interaction indicator")
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(0, 10)
	var old_invert = Global.invert_y
	Global.invert_y = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	car._input(motion)
	check(car.camera_rotation.rotation.x > 0, "vehicle normal vertical look follows camera orientation")
	Global.invert_y = old_invert
	if HOST:
		for peer in [200, 201, 202]:
			var actor = Spatial.new()
			actor.name = str(peer)
			mp.Players.add_child(actor)
			actor.global_transform.origin = car.global_transform.origin
			mp.players[peer] = {"puppet": actor}
			car.request_seat(peer)
		check(car.seats == [1, client_id, 200, 201] and not car.seats.has(202), "car assigns all four seats and rejects a fifth occupant")
		for peer in [200, 201, 202]:
			car.request_exit(peer)
			mp.Players.get_node(str(peer)).queue_free()
			mp.players.erase(peer)
	yield(barrier("seats_checked"), "completed")
	car.eject()
	yield(get_tree().create_timer(0.6), "timeout")
	check(player.car == null and not player.disabled, "each occupant can exit")
	car.queue_free()
	player.global_transform.origin = Vector3(0, 1000, 0) if HOST else Vector3(0, 1000, 2)
	player.health = 10000
	yield(test_shared_features(player), "completed")
	var gun = player.weapon
	gun.weapon1 = 0
	gun.weapon2 = 1
	gun.current_weapon = 0
	gun.magazine_ammo[0] = 12
	gun.ammo[0] = 24
	yield(barrier("host_death"), "completed")
	if HOST: player.instadie()
	yield(get_tree().create_timer(1), "timeout")
	if HOST: check(gun.weapon1 == 0 and gun.weapon2 == 1, "revivable host keeps weapons")
	yield(barrier("host_revive"), "completed")
	if not HOST:
		player.global_transform.origin = mp.players[1].puppet.global_transform.origin + Vector3(0, 0, 2)
		mp.request_player_revive(1)
	yield(get_tree().create_timer(1.5), "timeout")
	check(not mp.died_players.has(1), "client can revive host")
	if HOST:
		check(not player.dead and gun.current_weapon == 0 and not gun.disabled and gun.is_processing(), "host weapon restored after revive")
		check(gun.weapon1 == 0 and gun.weapon2 == 1, "host loadout retained")
		check_revived_weapon(gun)
	player.health = 10000
	player.set_physics_process(false)
	yield(barrier("client_death"), "completed")
	if not HOST: player.instadie()
	yield(get_tree().create_timer(1), "timeout")
	if HOST:
		player.global_transform.origin = mp.players[client_id].puppet.global_transform.origin + Vector3(0, 0, 2)
		mp.request_player_revive(client_id)
	yield(get_tree().create_timer(1.5), "timeout")
	check(not mp.died_players.has(client_id), "host can revive client")
	if not HOST:
		check(gun.current_weapon == 0 and not gun.disabled and gun.is_processing(), "client weapon restored after revive")
		check_revived_weapon(gun)
	yield(barrier("final_client_death"), "completed")
	if not HOST: player.instadie()
	yield(get_tree().create_timer(1), "timeout")
	check(not mp.has_revives_remaining(client_id), "revive limit exhausted")
	if not HOST: check(gun.weapon1 == null and gun.weapon2 == null, "permanent death clears dropped weapons")
	var drops = 0
	for child in Global.current_scene.get_children():
		if str(child.name).begins_with("DeathWeapon_"): drops += 1
	check(drops == 2, "permanent death drops both weapons on both peers")
	yield(barrier("ending"), "completed")
	if HOST:
		Global.CURRENT_LEVEL = 0
		mp.Flow.finish_mission(true)
	yield(get_tree().create_timer(4), "timeout")
	check(is_instance_valid(Global.current_scene) and Global.current_scene.filename == "res://Cutscenes/CutsceneEnd2.tscn", "HQ ending enters cutscene on both peers")
	yield(barrier("house_start"), "completed")
	if HOST:
		mp.config.spawnInvulnerability = 0.0
		Global.CURRENT_LEVEL = 17
		mp.game_init(Global.LEVELS[17])
	while Global.loader != null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[17] or not mp.player_scene_loaded or get_tree().paused:
		yield(get_tree().create_timer(0.1), "timeout")
	yield(get_tree().create_timer(1), "timeout")
	yield(barrier("house_death"), "completed")
	if HOST:
		mp.spawn_protected_until.clear()
		Global.player.instadie()
	yield(get_tree().create_timer(2), "timeout")
	check(mp.died_players.has(1), "House host death completes without crashing")
	yield(barrier("house_done"), "completed")
	if not HOST:
		var menu = Global.menu
		menu.in_game = false
		menu.active_menus = [menu.menu[menu.LEVEL_SELECT]]
		mp.leave_server()
		var found_start = false
		for button in menu.menu[menu.LEVEL_SELECT].get_children():
			if button.has_meta("menu_button_type") and button.get_meta("menu_button_type") == menu.B_MISSION_START:
				found_start = button.visible
		check(found_start and not menu.level_selected, "leaving lobby restores offline Start square immediately")
	print("REVISION_RESULT failures=", failures)
	get_tree().quit(1 if failures else 0)

func test_community_and_spectating(player):
	var menu = Global.menu
	check(menu.news_panel.tabs.get_tab_count() == 2 and menu.news_panel.tabs.is_tab_disabled(1), "Community has News and placeholder Addons tabs")
	var spectator = mp.Spectator
	var old_mode = mp.hostSettings.gameMode
	var old_teams = mp.CounterOp.teams.duplicate(true)
	var local = mp.NetworkBridge.get_id()
	var other = client_id if HOST else 1
	mp.hostSettings.spectating = true
	mp.hostSettings.gameMode = "counter_op"
	mp.CounterOp.teams[local] = mp.CounterOp.TEAM_OPERATIVES
	mp.CounterOp.teams[other] = mp.CounterOp.TEAM_COUNTER_OPERATIVES
	mp.CounterOp.settings.spectateOpponents = false
	check(spectator.candidates().empty(), "Counter-Opps blocks spectating opponents by default")
	mp.CounterOp.settings.spectateOpponents = true
	check(spectator.candidates().has(other), "host can allow opponent spectating")
	mp.CounterOp.settings.spectateOpponents = false
	mp.CounterOp.teams[other] = mp.CounterOp.TEAM_OPERATIVES
	check(spectator.candidates().has(other), "Counter-Opps allows teammate spectating")
	mp.hostSettings.gameMode = old_mode
	mp.CounterOp.teams = old_teams
	player.dead = true
	player.died = true
	mp.DeathScreen.show()
	spectator._process(0.0)
	check(spectator.button.visible and not spectator.button.disabled, "death screen offers Spectate")
	spectator.start()
	check(spectator.active and spectator.camera.current and not mp.DeathScreen.visible, "Spectate replaces death UI with third-person camera")
	check(not player._gameplay_input_enabled(), "spectator controls cannot move dead player's body")
	spectator.set_physics_process(false)
	spectator._physics_process(0.0)
	var wall = StaticBody.new()
	var shape = CollisionShape.new()
	shape.shape = BoxShape.new()
	shape.shape.extents = Vector3(2, 2, 0.1)
	wall.add_child(shape)
	Global.current_scene.add_child(wall)
	wall.global_transform = Transform(spectator.pivot.global_transform.basis, spectator.pivot.global_transform.origin + spectator.pivot.global_transform.basis.z * 2.0)
	yield(get_tree().create_timer(0.2), "timeout")
	check(spectator.arm.get_hit_length() < spectator.distance, "spectator camera retracts before a wall")
	wall.queue_free()
	spectator.set_physics_process(true)
	var extra_peer = 424242
	var extra_actor = Spatial.new()
	extra_actor.name = str(extra_peer)
	mp.Players.add_child(extra_actor)
	mp.players[extra_peer] = {"nickname": "Spectator test player", "puppet": extra_actor}
	extra_actor.global_transform.origin = player.global_transform.origin + Vector3(2, 0, 0)
	spectator.cycle(1)
	check(spectator.target == extra_peer, "strafe cycling selects another living player")
	spectator.cycle(-1)
	check(spectator.target == other, "reverse strafe cycling returns to previous living player")
	mp.players.erase(extra_peer)
	extra_actor.free()
	spectator.cycle(1)
	check(spectator.target == other, "spectator cycling wraps over living targets")
	for _index in range(30):
		var wheel = InputEventMouseButton.new()
		wheel.button_index = BUTTON_WHEEL_UP
		wheel.pressed = true
		spectator._input(wheel)
	check(spectator.distance == 1.2, "spectator zoom respects minimum distance")
	for _index in range(30):
		var wheel = InputEventMouseButton.new()
		wheel.button_index = BUTTON_WHEEL_DOWN
		wheel.pressed = true
		spectator._input(wheel)
	check(spectator.distance == 8.0, "spectator zoom respects maximum distance")
	mp.died_players.append(other)
	spectator._process(0.0)
	check(not spectator.active and mp.DeathScreen.visible, "last spectated player dying returns to death screen")
	mp.died_players.erase(other)
	spectator.start()
	player.dead = false
	player.died = false
	spectator._process(0.0)
	check(not spectator.active and player.player_view.current, "revival restores normal camera")
	mp.DeathScreen.hide()
	mp.hostSettings.spectating = false
	player.dead = true
	player.died = true
	spectator.start()
	check(not spectator.active, "host can disable spectating")
	player.dead = false
	player.died = false
	mp.hostSettings.spectating = true
	check(not mp.DeathScreen.has_node("ImplantMenu") and not mp.DeathScreen.has_node("ImplantButton"), "death implant picker removed")
	# Keep this a coroutine on the client as well.
	yield(get_tree(), "idle_frame")

func test_live_implant_bans():
	var menu = Global.menu
	var equipment = menu.get_node("Character_Menu/Character_Container")
	var old_head = Global.implants.head_implant
	var old_purchases = Global.implants.purchased_implants.duplicate()
	var old_bans = mp.config.bannedImplants.duplicate()
	var index = -1
	for item in range(Global.implants.IMPLANTS.size()):
		if Global.implants.IMPLANTS[item].i_name == "Composite Helmet": index = item
	Global.implants.head_implant = Global.implants.IMPLANTS[index]
	if not "Composite Helmet" in Global.implants.purchased_implants:
		Global.implants.purchased_implants.append("Composite Helmet")
	menu.show()
	menu.get_node("Character_Menu").show()
	equipment._populate_page(0)
	equipment._show_implant_info(index)
	equipment._process(0.0)
	yield(barrier("live_ban_open"), "completed")
	if HOST:
		mp.config.bannedImplants = ["Composite Helmet"]
		mp.apply_host_settings()
	yield(get_tree().create_timer(0.5), "timeout")
	equipment._process(0.0)
	var slot = equipment.button_implant_indices.find(index)
	check(equipment.EQUIPMENT_BUTTONS[slot].modulate == Color(1, 0.2, 0.2), "open equipment menu receives live banned tint")
	check(equipment.hover_info.get_node("Name").text == "Composite Helmet (Banned)", "hovered implant tooltip updates on ban without moving mouse")
	check(Global.implants.head_implant == Global.implants.empty_implant and "Composite Helmet" in Global.implants.purchased_implants, "live ban unequips implant but preserves ownership")
	equipment._on_implant_pressed(slot)
	check(Global.implants.head_implant == Global.implants.empty_implant, "live banned implant cannot be equipped")
	yield(barrier("live_ban_checked"), "completed")
	if HOST:
		mp.config.bannedImplants = []
		mp.apply_host_settings()
	yield(get_tree().create_timer(0.5), "timeout")
	equipment._process(0.0)
	check(equipment.EQUIPMENT_BUTTONS[slot].modulate == Color.white and equipment.hover_info.get_node("Name").text == "Composite Helmet", "allowing implant restores open menu icon and tooltip live")
	yield(barrier("live_allow_checked"), "completed")
	if HOST:
		mp.config.bannedImplants = old_bans
		mp.apply_host_settings()
	Global.implants.head_implant = old_head
	Global.implants.purchased_implants = old_purchases
	equipment.hover_info.get_parent().hide()
	menu.get_node("Character_Menu").hide()
	menu.hide()

func test_weapon_bans(player):
	var menu = Global.menu
	var online = get_tree().get_nodes_in_group("MultiplayerMenu")[0]
	online._ensure_counterop_settings_tab()
	online._normalize_settings_lists()
	var protection = online.get_node("CenterContainer/TabContainer/Host/VBoxContainer/SpawnInvulnerability/Time")
	var capacity = online.get_node("CenterContainer/TabContainer/Host/VBoxContainer/MaxPlayers/CountEdit")
	check(protection.theme == capacity.theme and protection.align == capacity.align and protection.rect_min_size.x == capacity.rect_min_size.x, "spawn protection input matches Max Players visuals")
	check(protection.get_parent().get_child(0).text == "Spawn invulnerability:" and protection.is_connected("mouse_entered", online, "_host_tooltip_entered"), "spawn protection label and tooltip match host settings")
	for path in ["CenterContainer/TabContainer/Host/VBoxContainer", "CrueltySettings/VBoxContainer", "CounterOpSettings/VBoxContainer", "DeathmatchSettings/VBoxContainer", "CenterContainer/TabContainer/VC/VBoxContainer"]:
		var box = online.get_node(path)
		var consistent = box.get_constant("separation") == online.SETTINGS_ROW_GAP
		for row in box.get_children():
			if row is HBoxContainer: consistent = consistent and not bool(row.size_flags_vertical & Control.SIZE_EXPAND)
		check(consistent, "consistent Online parameter spacing: " + path)
	mp.CounterOp.attach_menu(menu)
	mp.CounterOp._position_team_button()
	for button in menu.menu[menu.LEVEL_SELECT].get_children():
		if button.has_meta("menu_button_type") and button.get_meta("menu_button_type") == menu.B_STOCKS:
			check(mp.CounterOp.team_button.rect_position == menu._level_select_position(button) + Vector2(menu.button_size.x, 0), "team switcher sits right of Stock Market")
	online._sync_implant_tab()
	var panel = online.get_node("CenterContainer/TabContainer/Implants")
	var tabs = panel.get_parent()
	check(tabs.get_tab_title(panel.get_index()) == "Bans", "implant rules tab renamed Bans")
	panel.update()
	yield(get_tree(), "idle_frame")
	check(abs(panel.category_buttons[0].rect_size.x - panel.category_buttons[1].rect_size.x) < 0.1, "Bans category buttons have equal width")
	var old_purchases = Global.implants.purchased_implants.duplicate()
	var hidden_key = ""
	for implant in Global.implants.IMPLANTS:
		if implant.hidden and implant.i_name != "House":
			hidden_key = implant.i_name
			Global.implants.purchased_implants.erase(hidden_key)
			break
	if hidden_key != "":
		panel.refresh()
		panel.hover_implant(panel.displayed.find(hidden_key))
		check(menu.hover_info.get_node("Name").text == "???" and menu.hover_info.get_node("Hint").text == "???", "undiscovered implant name and description masked in Bans")
	var old_unlocks = Global.WEAPONS_UNLOCKED.duplicate()
	Global.WEAPONS_UNLOCKED[28] = false
	Global.WEAPONS_UNLOCKED[0] = true
	Global.WEAPONS_UNLOCKED[1] = true
	panel.select_kind("weapons")
	var hidden_weapon = panel.displayed.find(mp.weapon_ban_id(28))
	panel.hover_implant(hidden_weapon)
	check(menu.hover_info.get_node("Name").text == "???" and menu.hover_info.get_node("Hint").text == "???" and menu.hover_info.get_node("Image").texture == panel.entries[hidden_weapon].texture, "undiscovered weapon keeps icon but masks tooltip")
	check(panel.entries.size() == Global.WEAPONS_UNLOCKED.size(), "Bans includes vanilla and installed custom weapons")
	var registry = Global.get_node("WeaponRegistry")
	for index in registry.definitions:
		check(mp.weapon_ban_id(index) == registry.id_for(index), "custom weapon bans use stable package ID")
	var old_bans = mp.config.bannedWeapons.duplicate()
	var old_menu = menu.active_menus.duplicate()
	menu.active_menus = [menu.menu[menu.WEAPON_SELECT]]
	menu.weapon_1 = 0
	menu.weapon_2 = 1
	var gun = player.weapon
	gun.orb = false
	gun.weapon1 = 0
	gun.weapon2 = 1
	gun.current_weapon = 0
	yield(barrier("weapon_ban_ready"), "completed")
	if HOST: panel.apply_bans([mp.weapon_ban_id(0)])
	yield(get_tree().create_timer(0.5), "timeout")
	check(mp.is_weapon_banned(0) and gun.weapon1 == null and gun.current_weapon == 1, "live weapon ban removes equipped weapon on host and client")
	check(Global.WEAPONS_UNLOCKED[0] and not Global.CURRENT_WEAPONS[0], "weapon ban preserves unlock but removes loadout selection")
	check(menu._weapon_button_for_index(0).disabled and menu._weapon_button_for_index(0).modulate == Color(1, 0.2, 0.2), "weapon menu displays live ban")
	gun.set_weapon(0)
	check(gun.current_weapon == 1, "banned weapon cannot be equipped through weapon API")
	var pickup = load("res://Entities/Objects/Gun_Pickup.tscn").instance()
	pickup.name = "BannedWeaponPickup"
	Global.current_scene.add_child(pickup)
	pickup.set_physics_process(false)
	pickup.global_transform.origin = player.global_transform.origin + Vector3(0, 0, 1)
	var pickup_model = pickup.gun
	yield(barrier("banned_pickup_ready"), "completed")
	if HOST: pickup_model.request_pickup(client_id, pickup_model.revision, 0, null, 0)
	yield(get_tree().create_timer(0.2), "timeout")
	check(pickup_model.revision == 0 and pickup_model.current_weapon == 0, "host rejects banned weapon pickup")
	yield(barrier("ban_both_ready"), "completed")
	if HOST: panel.apply_bans([mp.weapon_ban_id(0), mp.weapon_ban_id(1)])
	yield(get_tree().create_timer(0.5), "timeout")
	check(gun.weapon1 == null and gun.weapon2 == null and gun.current_weapon == null, "banning both weapons safely leaves player unarmed")
	yield(barrier("weapon_ban_checked"), "completed")
	if HOST: panel.allow_all()
	yield(get_tree().create_timer(0.5), "timeout")
	check(not mp.is_weapon_banned(0) and menu._weapon_button_for_index(0).modulate != Color(1, 0.2, 0.2), "allowing weapon clears menu ban live")
	if HOST:
		panel.controls.get_node("LineEdit").text = "Test Weapon Bans"
		panel.save_preset()
		check(mp.config.weaponBanPresets.has("Test Weapon Bans"), "weapon ban presets save independently")
		mp.config.weaponBanPresets.erase("Test Weapon Bans")
		mp.config.bannedWeapons = old_bans
		mp.apply_host_settings()
	pickup.queue_free()
	Global.WEAPONS_UNLOCKED = old_unlocks
	Global.implants.purchased_implants = old_purchases
	gun.weapon1 = 0
	gun.weapon2 = 1
	gun.current_weapon = 0
	menu.active_menus = old_menu
	panel.select_kind("implants")
	panel.hide_implant_hover()
	mp.enforce_weapon_bans()

func test_shared_features(player):
	var pickup_scene = Spatial.new()
	var gun_pickup = load("res://Entities/Objects/Gun_Pickup.tscn").instance()
	pickup_scene.add_child(gun_pickup)
	var implant_pickup = KinematicBody.new()
	var implant_area = load("res://Entities/Physics_Objects/Implant_Object.gd").new()
	implant_pickup.add_child(implant_area)
	pickup_scene.add_child(implant_pickup)
	var decoration = Spatial.new()
	pickup_scene.add_child(decoration)
	preload("res://MOD_CONTENT/CruS Online/gameplay/competitive_pickups.gd").strip(pickup_scene)
	check(pickup_scene.get_child_count() == 1 and pickup_scene.get_child(0) == decoration, "competitive cleanup removes authored guns and implants but leaves scenery")
	pickup_scene.free()
	var policy = preload("res://MOD_CONTENT/CruS Online/gameplay/spiritual_door_policy.gd")
	check(policy.allows({}, "hope_discarded", Vector3.ZERO, Vector3.ONE, true) and not policy.allows({}, "hope_discarded", Vector3.ZERO, Vector3.ONE * 10, true), "competitive difficulty doors ignore matrix but retain reach limits")
	var other = client_id if HOST else 1
	var avatar = mp.players[other].puppet
	var original_implants = avatar.implant_state.duplicate(true)
	avatar.implant_state["golem_exosystem"] = true
	avatar._update_golem_visual()
	var scan_camera = Camera.new()
	Global.current_scene.add_child(scan_camera)
	scan_camera.global_transform.origin = avatar.global_transform.origin + Vector3(0, 1.3, -5)
	scan_camera.look_at(avatar.global_transform.origin + Vector3.UP * 1.3, Vector3.UP)
	var bounds = mp.Eyecam._bounds(scan_camera, other)
	check(bounds.size.x > 0 and bounds.size.y > 0, "eyecam resolves visible golem model bounds")
	mp.Eyecam._show_readout(other, bounds, true, false, 0.1)
	check(mp.Eyecam.readouts.has(other), "golem scan creates biological readout")
	avatar.implant_state = original_implants
	avatar._update_golem_visual()
	scan_camera.queue_free()
	var clouds = []
	for index in range(40):
		var cloud = load("res://Entities/Bullets/Radiation.tscn").instance()
		cloud.set_meta("crus_damage_source", client_id)
		Global.current_scene.add_child(cloud)
		cloud.set_physics_process(false)
		cloud.global_transform.origin = player.global_transform.origin + Vector3(index + 20, 0, 0)
		clouds.append(cloud)
	var budget = Global.get_node("ACRCloudBudget")
	budget._process(0.3)
	var emitting = 0
	for cloud in clouds:
		if cloud.emitting: emitting += 1
	check(emitting == 32 and clouds[0].emitting and not clouds.back().emitting, "ACR budget renders nearest 32 clouds and retains all damage areas")
	check(clouds.back().get_node("Area").monitoring == HOST, "only host monitors ACR damage overlaps")
	for cloud in clouds: cloud.free()
	yield(test_pause_camera_target(player), "completed")
	check(mp.Commands.resolve_npc("New_Car") == "res://Entities/Vehicles/New_Car.tscn", "spawn resolves vehicles")
	var field = load("res://Entities/Bullets/Radiation.tscn").instance()
	field.name = "TestRadiation"
	field.set_meta("crus_damage_source", client_id)
	Global.current_scene.add_child(field)
	field.global_transform.origin = Vector3(0, 1000, 1)
	field.set_physics_process(false)
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	player.health = 10000
	mp.hostSettings.friendlyFire = true
	yield(barrier("radiation_owner"), "completed")
	if HOST: field._physics_process(0.1)
	yield(get_tree().create_timer(0.5), "timeout")
	check(player.health < 10000 if HOST else player.health == 10000, "client spray hurts other player but not its owner")
	player.health = 10000
	mp.hostSettings.friendlyFire = false
	yield(barrier("radiation_friendly"), "completed")
	if HOST: field._physics_process(0.1)
	yield(get_tree().create_timer(0.5), "timeout")
	check(player.health == 10000, "spray respects disabled friendly fire")
	field.remove_meta("crus_damage_source")
	field.get_node("Area").monitoring = true
	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	var previous_matrix = Global.death
	Global.death = not HOST
	player.health = 10000
	field._physics_process(1.0 / 30.0)
	check(player.health < 10000 if HOST else player.health == 10000, "atmosphere uses each player's own matrix")
	Global.death = previous_matrix
	mp.hostSettings.friendlyFire = true
	field.queue_free()
	var menu = Global.menu
	menu.in_game = false
	menu.active_menus = [menu.menu[menu.LEVEL_SELECT]]
	menu.active_element = menu.get_node("Level_Info_Grid")
	menu.online_navigation_active = false
	menu.show()
	if HOST:
		menu.level_selected = true
		Global.CURRENT_LEVEL = 2
	mp.CounterOp._process(0)
	yield(barrier("selected_level"), "completed")
	yield(get_tree().create_timer(0.7), "timeout")
	if not HOST:
		menu._update_waiting_menu()
		mp.CounterOp._update_overlay()
		check(mp.host_selected_level == 2 and mp.CounterOp.selected_level_button.visible, "client sees host's live mission portrait")
		check(menu.get_node("Level_Info_Grid").visible, "client gets selected mission sidebar")
		var description = menu.get_node("Level_Info_Grid/HBoxContainer/Description_Scroll/Description")
		check(description.visible_characters >= 0 and description.visible_characters < description.text.length(), "client handler types mission dialogue")
		mp.CounterOp._selected_level_hover()
		check(menu.hover_info.get_node("Name").visible and not menu.hover_info.get_node("Hint").visible, "client mission tooltip uses title layout")
		menu.menu_changing = true
		menu.get_node("Level_Info_Grid").hide()
		menu._update_waiting_menu()
		check(not menu.get_node("Level_Info_Grid").visible, "client sidebar stays hidden while navigating away")
		menu.menu_changing = false
		check(not menu.get_node("Level_Info_Grid/Level_Info_Vbox/Time_Panel/VBoxContainer/Punishment_Mode").visible, "client cannot change mission difficulty toggles")
	yield(barrier("preview_checked"), "completed")
	menu.in_game = true
	menu.hide()
	Global.CURRENT_LEVEL = 1
	var triagon = load("res://snake.tscn").instance()
	triagon.name = "TestTriagon"
	var pending = [triagon]
	var head = null
	while not pending.empty():
		var child = pending.pop_back()
		pending.append_array(child.get_children())
		if child.get_script() != null and child.get_script().resource_path.ends_with("snakehead.gd"):
			head = child
			break
	check(head != null, "triagon uses networked head script")
	if head != null:
		head.line = "native triagon reward " + str(PORT)
	Global.current_scene.add_child(triagon)
	triagon.global_transform.origin = Vector3(20, 1000, 0)
	yield(barrier("triagon_ready"), "completed")
	yield(get_tree().create_timer(0.6), "timeout")
	if not HOST and head != null: head.damage(3000, Vector3.UP, head.global_transform.origin, player.global_transform.origin)
	yield(get_tree().create_timer(1), "timeout")
	check(Global.DEAD_CIVS.has("native triagon reward " + str(PORT)), "client kill grants Triagon reward to both players")
	var head_gibs = 0
	for child in Global.current_scene.get_children():
		if str(child.name).begins_with("TriagonHead_"): head_gibs += 1
	check(head_gibs == 1, "falling Triagon head exists on both peers")
	yield(barrier("triagon_checked"), "completed")
	triagon.queue_free()
	player.health = 10000

func check_revived_weapon(gun):
	gun.timer.stop()
	gun.magazine_ammo[0] = 12
	gun.ammo[0] = 24
	Input.action_press("mouse_1")
	gun.shoot()
	Input.action_release("mouse_1")
	check(gun.magazine_ammo[0] == 11, "revived firearm fires")
	gun.reload()
	check(gun.magazine_ammo[0] == 12 and gun.ammo[0] == 23, "revived firearm reloads")

func test_pause_camera_target(player):
	var gun = player.weapon
	var point = Position3D.new()
	Global.current_scene.add_child(point)
	point.global_transform.origin = player.global_transform.origin + Vector3.UP * 8
	gun.grapple_point = point
	gun.grapple_flag = true
	player.player_velocity = Vector3.ZERO
	Global.menu.in_game = true
	Global.menu.show()
	gun._process(0.1)
	check(gun._controls_blocked() and player.player_velocity != Vector3.ZERO, "paused online menu preserves existing grapple pulling")
	gun.grapple_flag = false
	gun.grapple_point = null
	point.queue_free()
	Global.menu.hide()
	var camera_area = load("res://psychocamera.gd").new()
	var camera = Camera.new()
	camera.name = "Camera"
	var weapon = SniperWeaponFixture.new()
	weapon.name = "Weapon"
	var ray = RayCast.new()
	ray.name = "RayCast"
	weapon.add_child(ray)
	camera.add_child(weapon)
	camera_area.add_child(camera)
	Global.current_scene.add_child(camera_area)
	camera_area.set_process(false)
	camera_area._on_Area_body_entered(mp.players[client_id if HOST else 1].puppet)
	check(not camera.current and not player.weapon.disabled, "another player cannot activate local sniper camera")
	camera_area._on_Area_body_entered(player)
	check(camera.current and player.weapon.disabled, "local player activates sniper camera")
	player.died = true
	camera_area._process(0.1)
	check(not camera.current and weapon.disabled and player.weapon.disabled, "death releases sniper camera and disables its weapon")
	player.died = false
	camera_area._on_Area_body_exited(player)
	check(player.player_view.current and not player.weapon.disabled, "local sniper camera releases controls")
	camera_area.queue_free()
	var npc = load("res://Entities/Enemies/E_Boss_Life.tscn").instance()
	npc.name = "TestHQTarget"
	npc.npc_name = "Native test HQ target " + str(PORT)
	npc.objective = true
	Global.current_scene.add_child(npc)
	npc.body.global_transform.origin = Vector3(30, 1000, 0)
	npc.body.set_physics_process(false)
	if is_instance_valid(npc.weapon) and "disabled" in npc.weapon: npc.weapon.disabled = true
	yield(barrier("hq_target_ready"), "completed")
	if HOST: npc.check_npc(client_id)
	yield(get_tree().create_timer(0.6), "timeout")
	if HOST:
		npc.health = 0
		npc.dead = true
		npc._physics_process(0.5)
	yield(get_tree().create_timer(0.7), "timeout")
	check(npc.dead and npc.health <= 0, "HQ target health and death repair agree on both peers")
	yield(barrier("hq_target_checked"), "completed")
	npc._complete_objective()
	npc._remove_population()
	npc.queue_free()
