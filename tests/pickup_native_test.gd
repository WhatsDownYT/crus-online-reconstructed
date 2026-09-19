extends Node
var mp
var failures = 0
func check(ok, label):
 print("PICKUP_CHECK host=",HOST," ",label,"=",ok)
 if not ok: failures += 1
func _ready():
 pause_mode = Node.PAUSE_MODE_PROCESS
 call_deferred("run")
func run():
 yield(get_tree().create_timer(6),"timeout")
 mp = Global.get_node("Multiplayer")
 mp.Voice.test_capture = true
 if HOST:
  mp.config.hostPort = PORT
  mp.host_server()
 else:
  mp.join_to_server("127.0.0.1",PORT)
 while mp.players.size()<2:
  yield(get_tree().create_timer(0.1),"timeout")
 if HOST:
  yield(get_tree().create_timer(1),"timeout")
  Global.CURRENT_LEVEL=1
  mp.game_init(Global.LEVELS[1])
 while Global.loader!=null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename != Global.LEVELS[1] or not mp.player_scene_loaded or get_tree().paused:
  yield(get_tree().create_timer(0.1),"timeout")
 Global.player.health=10000
 yield(get_tree().create_timer(8),"timeout")
 for avatar in mp.Players.get_children():
  var label=avatar.get_node("Puppet/PlayerModel/Nickname")
  check(abs(label.get_aabb().position.x+label.get_aabb().size.x*0.5)<0.01,"name geometry centered")
  print("NAME_GEOMETRY ",label.text," align=",label.horizontal_alignment," offset=",label.offset," pixel=",label.pixel_size," box=",label.get_aabb())
 var poses={}
 var pending=[get_node("/root/Level")]
 while not pending.empty():
  var node=pending.pop_back()
  pending.append_array(node.get_children())
  if node.has_method("sync_settled_pose") and node.finished:
   poses[str(node.get_path())]=[node.global_transform.origin.x,node.global_transform.origin.y,node.global_transform.origin.z]
 var file=File.new()
 file.open("E:/Cruelty/Online/dist/pickup-poses-"+str(HOST)+".json",File.WRITE)
 file.store_string(to_json(poses))
 file.close()
 var drop=Global.player.weapon.weapon_drop.instance()
 drop.name="PickupRegression"
 get_node("/root/Level").add_child(drop)
 var actor=Global.player if HOST else mp.Players.get_node("1")
 drop.global_transform.origin=actor.global_transform.origin+Vector3(0,1,0)
 drop.lerp_transform=drop.global_transform
 drop.finished=true
 drop.set_physics_process(false)
 drop.gun.current_weapon=0
 drop.gun.ammo=7
 drop.gun.syncUpdate()
 var weapon=Global.player.weapon
 weapon.weapon1=null
 weapon.weapon2=null
 weapon.current_weapon=null
 yield(get_tree().create_timer(2),"timeout")
 if not HOST:
  drop.gun.player_use()
 yield(get_tree().create_timer(2),"timeout")
 check(drop.gun.current_weapon==null and drop.gun.revision==1,"client pickup removes gun on every peer")
 check(not drop.visible,"consumed drop hidden")
 check(weapon.current_weapon==0 if not HOST else weapon.current_weapon==null,"only requester receives gun")
 if not HOST:
  check(weapon.magazine_ammo[0]==7 and not weapon.has_meta("pending_pickup"),"pickup preserves rounds and unlocks weapon")
 drop.gun.player_use()
 yield(get_tree().create_timer(0.5),"timeout")
 check(drop.gun.revision==1,"stale pickup safely ignored")
 var swapped = make_drop("SwapRegression",1,9)
 yield(get_tree().create_timer(1),"timeout")
 if not HOST:
  swapped.gun.player_use()
 yield(get_tree().create_timer(1),"timeout")
 check(swapped.gun.current_weapon==0 and swapped.gun.ammo==7,"weapon swap replicates replacement gun and magazine")
 if not HOST:
  check(weapon.current_weapon==1 and weapon.magazine_ammo[1]==9,"client receives swapped gun")
 yield(barrier("swap_checked"),"completed")
 if HOST:
  swapped.gun.player_use()
 yield(get_tree().create_timer(1),"timeout")
 check(swapped.gun.current_weapon==null and swapped.removed,"host can collect client replacement once")
 var rounds = make_drop("AmmoRegression",1,5)
 var previous_ammo = weapon.ammo[1]
 yield(get_tree().create_timer(1),"timeout")
 if not HOST:
  rounds.gun.player_use()
 yield(get_tree().create_timer(1),"timeout")
 check(rounds.gun.current_weapon==1 and rounds.gun.ammo==0,"ammo collection drains shared ammo once")
 if not HOST:
  check(weapon.ammo[1]==previous_ammo+5,"ammo collector receives rounds once")
 rounds.gun.request_pickup(mp.NetworkBridge.get_id(),0,1,1,0)
 yield(get_tree().create_timer(0.5),"timeout")
 check(rounds.gun.revision==1,"stale competing pickup cannot duplicate ammo")
 var removed_pose = swapped.global_transform
 swapped.client_set_lerp_transform(1,Transform.IDENTITY,swapped.physics_revision)
 swapped.sync_hold_state(1,0,Transform.IDENTITY,Vector3.ZERO,false,false,swapped.physics_revision)
 check(swapped.global_transform==removed_pose and not swapped.is_physics_processing(),"late physics messages cannot resurrect consumed drop")
 print("PICKUP_RESULT host=",HOST," failures=",failures)
 get_tree().quit(1 if failures else 0)

func make_drop(label, weapon_id, rounds):
 var drop=Global.player.weapon.weapon_drop.instance()
 drop.name=label
 get_node("/root/Level").add_child(drop)
 var actor=Global.player if HOST else mp.Players.get_node("1")
 drop.global_transform.origin=actor.global_transform.origin+Vector3(0,1,0)
 drop.lerp_transform=drop.global_transform
 drop.finished=true
 drop.set_physics_process(false)
 drop.gun.current_weapon=weapon_id
 drop.gun.ammo=rounds
 drop.gun.syncUpdate()
 return drop

func barrier(stage):
 var prefix="E:/Cruelty/Online/dist/pickup-barrier-"+str(PORT)+"-"+stage+"-"
 var file=File.new()
 file.open(prefix+str(HOST),File.WRITE)
 file.store_string("ready")
 file.close()
 yield(get_tree(),"idle_frame")
 while not file.file_exists(prefix+str(not HOST)):
  yield(get_tree().create_timer(0.05),"timeout")
