extends Area



onready var NetworkBridge = Global.get_node("Multiplayer/NetworkBridge")

enum WEAPON{W_PISTOL, W_SMG, W_TRANQ, W_BLACKJACK, W_SHOTGUN, W_ROCKET_LAUNCHER, W_SNIPER, W_AR, W_SILENCED_SMG, W_NAMBU, W_GAS, W_MG3, W_AUTOSHOTGUN, W_MAUSER, W_BORE, W_MKR, W_RADIATOR, W_FLASHLIGHT, W_ZIPPY, W_AN94, W_VAG72, W_STEYR, W_DNA, W_ROD, W_FLAMETHROWER, W_SKS, W_NAILER, W_SHOCK, W_LIGHT}
onready var MESH = [$Pistol_Mesh, $SMG_Mesh, $Tranq_Mesh, $Baton_Mesh, $Shotgun_Mesh, $RL_Mesh, $Sniper_Mesh, $AR_Mesh, $S_SMG_Mesh, $Nambu_Mesh, $Gas_Mesh, $MG3_Mesh, $Autoshotgun_Mesh, $Mauser_Mesh, $Bore_Mesh, $MKR_Mesh, $Rad_Mesh, $Flashlight_Mesh, $Zippy_Mesh, $AN94_Mesh, $VAG72_Mesh, $Steyr_Mesh, $DNA_Mesh, $Rod_Mesh, $FT_Mesh, $SKS_Mesh, $Nailer_Mesh, $SHOCK_Mesh, $Light_Mesh]
export (WEAPON) var current_weapon = 0
export  var menu = false
var ammo = 0



var revision = 0
var pending = false
var applied_revision = -1

func _valid_weapon(value):
	return typeof(value) == TYPE_INT and value >= 0 and value < MESH.size()

func syncUpdate(_id = null):
	for mesh in MESH:
		mesh.hide()
	if _valid_weapon(current_weapon):
		MESH[current_weapon].show()

func _ready():
	NetworkBridge.register_rpcs(self, [
		["request_pickup", NetworkBridge.PERMISSION.ALL],
		["request_state", NetworkBridge.PERMISSION.ALL],
		["sync_state", NetworkBridge.PERMISSION.SERVER],
		["commit_pickup", NetworkBridge.PERMISSION.SERVER],
		["reject_pickup", NetworkBridge.PERMISSION.SERVER]
	])
	syncUpdate()
	if not menu and _valid_weapon(current_weapon):
		ammo = Global.player.weapon.MAX_MAG_AMMO[current_weapon]
		Global.get_node("Multiplayer").connect("scene_loaded", self, "_request_state")
		call_deferred("_request_state")

func _request_state():
	if NetworkBridge.check_connection() and not NetworkBridge.is_world_authority():
		NetworkBridge.request_host(self, "request_state")

master func request_state(id):
	if NetworkBridge.is_world_authority():
		NetworkBridge.n_rpc_id(self, NetworkBridge.request_sender(id), "sync_state", [current_weapon, ammo, revision])

puppet func sync_state(_id, weapon, rounds, version):
	if version < revision or weapon != null and not _valid_weapon(weapon):
		return
	revision = version
	current_weapon = weapon
	ammo = rounds
	syncUpdate()
	if current_weapon == null:
		collision_layer = 0
		collision_mask = 0
		get_parent()._remove(null)

func player_use():
	if menu or pending or not _valid_weapon(current_weapon) or not is_instance_valid(Global.player) or Global.player.dead:
		return
	var weapon = Global.player.weapon
	if weapon.has_meta("pending_pickup"):
		return
	if weapon.current_weapon != current_weapon and current_weapon in [weapon.weapon1, weapon.weapon2]:
		return
	if weapon.current_weapon == current_weapon and (ammo <= 0 or current_weapon in [WEAPON.W_RADIATOR, WEAPON.W_BLACKJACK, WEAPON.W_BORE, WEAPON.W_FLASHLIGHT, WEAPON.W_ROD]):
		return
	pending = true
	weapon.set_meta("pending_pickup", self)
	var rounds = weapon.magazine_ammo[weapon.current_weapon] if weapon.current_weapon != null else 0
	NetworkBridge.request_host(self, "request_pickup", [revision, current_weapon, weapon.current_weapon, rounds])

master func request_pickup(id, version, expected, replacement, rounds):
	if not NetworkBridge.is_world_authority():
		return
	id = NetworkBridge.request_sender(id)
	var actor = NetworkBridge.get_peer_actor(id)
	if menu or not _valid_weapon(current_weapon) or version != revision or expected != current_weapon or actor == null or actor.global_transform.origin.distance_to(global_transform.origin) > 6.0 or (replacement != null and not _valid_weapon(replacement)) or typeof(rounds) != TYPE_INT or rounds < 0 or rounds > 10000:
		_reject(id)
		return
	var ammo_only = replacement == current_weapon
	if ammo_only and (ammo <= 0 or current_weapon in [WEAPON.W_RADIATOR, WEAPON.W_BLACKJACK, WEAPON.W_BORE, WEAPON.W_FLASHLIGHT, WEAPON.W_ROD]):
		_reject(id)
		return
	var picked_weapon = current_weapon
	var picked_ammo = ammo
	var next_weapon = current_weapon if ammo_only else replacement
	var next_ammo = 0 if ammo_only else rounds
	var next_revision = revision + 1
	commit_pickup(null, id, picked_weapon, picked_ammo, ammo_only, next_weapon, next_ammo, next_revision)
	NetworkBridge.n_rpc(self, "commit_pickup", [id, picked_weapon, picked_ammo, ammo_only, next_weapon, next_ammo, next_revision])

func _reject(peer):
	if peer == NetworkBridge.get_id():
		reject_pickup(null)
	else:
		NetworkBridge.n_rpc_id(self, peer, "reject_pickup")

puppet func reject_pickup(_id):
	pending = false
	if is_instance_valid(Global.player) and Global.player.weapon.has_meta("pending_pickup") and Global.player.weapon.get_meta("pending_pickup") == self:
		Global.player.weapon.remove_meta("pending_pickup")

puppet func commit_pickup(_id, peer, picked_weapon, picked_ammo, ammo_only, next_weapon, next_ammo, version):
	if version <= applied_revision or version < revision or not _valid_weapon(picked_weapon):
		return
	applied_revision = version
	if peer == NetworkBridge.get_id() and pending and is_instance_valid(Global.player):
		var weapon = Global.player.weapon
		reject_pickup(null)
		if ammo_only:
			weapon.add_ammo(picked_ammo, picked_weapon, self)
		else:
			weapon.magazine_ammo[picked_weapon] = picked_ammo
			weapon.set_weapon(picked_weapon)
			weapon.set_UI_ammo()
			weapon.player_weapon.show()
	sync_state(null, next_weapon, next_ammo, version)
