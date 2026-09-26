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
 for implant in Global.implants.IMPLANTS:
  if implant.i_name == "Augmented Arms+":
   Global.implants.arm_implant = implant
 Global.player.global_transform.origin = Vector3(0, 20, 0) if HOST else Vector3(1,20,0)
 Global.player.set_physics_process(false)
 yield(get_tree().create_timer(2),"timeout")
 var client_id = 0
 for peer in mp.players:
  if peer != 1: client_id = peer
 if not HOST:
  mp.request_player_hold(1)
 yield(get_tree().create_timer(1),"timeout")
 check(mp.held_target(client_id)==1,"client hold recorded on both peers")
 if HOST: check(Global.player.multiplayer_held,"host is held by client")
 yield(barrier("client_held"),"completed")
 if not HOST: mp.request_player_release(Vector3.ZERO)
 yield(get_tree().create_timer(1),"timeout")
 check(mp.held_target(client_id)==0,"client release recorded on both peers")
 yield(barrier("client_released"),"completed")
 if HOST: mp.request_player_hold(client_id)
 yield(get_tree().create_timer(1),"timeout")
 check(mp.held_target(1)==client_id,"host hold recorded on both peers")
 if not HOST: check(Global.player.multiplayer_held,"client is held by host")
 yield(barrier("host_held"),"completed")
 if HOST: mp.request_player_release(Vector3(10,5,0))
 yield(get_tree().create_timer(1),"timeout")
 check(mp.held_target(1)==0,"host throw releases on both peers")
 if not HOST: check(Global.player.player_velocity==Vector3(10,5,0),"thrown client receives velocity")
 yield(barrier("host_released"),"completed")
 var drop=Global.player.weapon.weapon_drop.instance()
 drop.name="ArmsRegression"
 get_node("/root/Level").add_child(drop)
 var actor=Global.player if not HOST else mp.Players.get_node(str(client_id))
 drop.global_transform.origin=actor.global_transform.origin+Vector3(0,1,0)
 drop.lerp_transform=drop.global_transform
 drop.finished=true
 drop.set_physics_process(false)
 yield(get_tree().create_timer(1),"timeout")
 print("ARMS_DIAG host=",HOST," usable=",drop.usable," distance=",actor.global_transform.origin.distance_to(drop.global_transform.origin)," float_member=",20.0 in [0,20])
 yield(barrier("prop_created"),"completed")
 if not HOST: drop.player_use()
 yield(get_tree().create_timer(1),"timeout")
 check(drop.held and drop.holdId==client_id,"client prop hold synchronized")
 if not HOST: check(Global.player.weapon.holding,"client weapon holds prop")
 yield(barrier("prop_held"),"completed")
 if not HOST and drop.held: drop.release_held(drop.global_transform.origin,Vector3.ZERO,Vector3.ZERO,false)
 yield(get_tree().create_timer(1),"timeout")
 check(not drop.held,"client prop release synchronized")
 print("ARMS_RESULT host=",HOST," failures=",failures)
 get_tree().quit(1 if failures else 0)

func barrier(stage):
 var prefix="E:/Cruelty/Online/dist/pickup-barrier-"+str(PORT)+"-"+stage+"-"
 var file=File.new()
 file.open(prefix+str(HOST),File.WRITE)
 file.store_string("ready")
 file.close()
 yield(get_tree(),"idle_frame")
 while not file.file_exists(prefix+str(not HOST)):
  yield(get_tree().create_timer(0.05),"timeout")
