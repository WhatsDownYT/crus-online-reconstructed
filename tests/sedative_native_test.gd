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

 var client_id=0
 for peer in mp.players:
  if peer!=1: client_id=peer
 var player=Global.player
 player.set_physics_process(false)
 player.start_flag=true
 player.health=10000
 player.tranquilize_timer.stop()
 player.multiplayer_sedative_time=0
 player.remove_tranquilize()
 var cloud=null
 if HOST:
  cloud=load("res://Entities/Bullets/Sleep_Gas.tscn").instance()
  cloud.collision_layer=0
  cloud.collision_mask=0
  cloud.name="SedativeRegression"
  get_node("/root/Level").add_child(cloud)
  cloud.set_physics_process(false)
 set_arms("ZZzzz Special Sedative Grenade")
 yield(get_tree().create_timer(1),"timeout")
 yield(barrier("normal_ready"),"completed")
 if HOST:
  cloud.set_meta("crus_damage_source",1)
  cloud._on_Explosion_body_entered(mp.Players.get_node(str(client_id)).get_node("Puppet/GameplayCollision"))
  cloud.set_meta("crus_damage_source",client_id)
  cloud._on_Explosion_body_entered(player)
 yield(get_tree().create_timer(0.5),"timeout")
 check(not player.tranquilize_flag and not player.UI.sleep and player.multiplayer_sedative_time==0,"normal sedative grenade does not sedate another player")
 yield(barrier("normal_checked"),"completed")
 set_arms("ZZzzz Special Sedative Grenade+")
 yield(get_tree().create_timer(1),"timeout")
 yield(barrier("plus_ready"),"completed")
 if HOST:
  cloud.set_meta("crus_damage_source",1)
  cloud._on_Explosion_body_entered(mp.Players.get_node(str(client_id)).get_node("Puppet/GameplayCollision"))
  cloud.set_meta("crus_damage_source",client_id)
  cloud._on_Explosion_body_entered(player)
 yield(get_tree().create_timer(0.5),"timeout")
 check(player.multiplayer_sedative_time==10 and player.tranquilize_flag and player.UI.sleep,"plus grenade applies matching ten-second sleep and distortion on host/client")
 check(player.shader_screen.material.get_shader_param("intro"),"distortion enabled on recipient")
 check(player.tranquilize_timer.is_stopped(),"plus does not start the old fifteen-second timer")
 player.tranquilize_mul=8
 player.set_move_speed()
 var slowed_speed=player.move_speed
 player._update_multiplayer_sedative(9.9)
 check(player.UI.sleep and player.tranquilize_flag and player.multiplayer_sedative_time>0,"all plus effects remain before ten seconds")
 player._update_multiplayer_sedative(0.1)
 check(not player.UI.sleep and not player.tranquilize_flag and player.multiplayer_sedative_time==0,"sleep and slowdown end at ten seconds")
 check(not player.shader_screen.material.get_shader_param("intro") and player.tranquilize_mul==0 and player.move_speed>slowed_speed,"distortion and slowdown recover together")
 yield(barrier("expiry_checked"),"completed")
 if HOST:
  cloud.set_meta("crus_damage_source",1)
  cloud._on_Explosion_body_entered(player)
 yield(get_tree().create_timer(0.3),"timeout")
 check(player.multiplayer_sedative_time==0 and not player.UI.sleep,"plus thrower immunity preserved")
 yield(barrier("self_checked"),"completed")
 for implant in Global.implants.IMPLANTS:
  if implant.i_name=="CSIJ Level V Biosuit": Global.implants.torso_implant=implant
 yield(get_tree().create_timer(1),"timeout")
 yield(barrier("immune_ready"),"completed")
 if HOST:
  cloud.set_meta("crus_damage_source",1)
  cloud._on_Explosion_body_entered(mp.Players.get_node(str(client_id)).get_node("Puppet/GameplayCollision"))
  cloud.set_meta("crus_damage_source",client_id)
  cloud._on_Explosion_body_entered(player)
 yield(get_tree().create_timer(0.3),"timeout")
 check(player.multiplayer_sedative_time==0 and not player.UI.sleep,"biosuit immunity preserved")
 player.set_tranquilize()
 player.set_multiplayer_sedative(10)
 player._update_multiplayer_sedative(10)
 check(player.tranquilize_flag and player.UI.sleep and not player.shader_screen.material.get_shader_param("intro"),"independent tranquilizer hit survives plus effect expiry")
 player.tranquilize_timer.stop()
 player.remove_tranquilize()
 yield(barrier("all_checked"),"completed")
 print("SEDATIVE_RESULT host=",HOST," failures=",failures)
 get_tree().quit(1 if failures else 0)

func set_arms(label):
 for implant in Global.implants.IMPLANTS:
  if implant.i_name==label: Global.implants.arm_implant=implant

func barrier(stage):
 var prefix="E:/Cruelty/Online/dist/pickup-barrier-"+str(PORT)+"-"+stage+"-"
 var file=File.new()
 file.open(prefix+str(HOST),File.WRITE)
 file.store_string("ready")
 file.close()
 yield(get_tree(),"idle_frame")
 while not file.file_exists(prefix+str(not HOST)):
  yield(get_tree().create_timer(0.05),"timeout")
