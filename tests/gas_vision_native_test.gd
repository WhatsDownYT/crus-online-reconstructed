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
 var old_head=Global.implants.head_implant
 var head=null
 for implant in Global.implants.IMPLANTS:
  if implant.nightmare:
   head=implant
   break
 check(head!=null,"nightmare implant exists")
 Global.implants.head_implant=head
 Global.player.special_vision=true
 Global.player._refresh_vision()
 yield(get_tree(),"idle_frame")
 yield(get_tree(),"idle_frame")
 print("VISION_STATE ",Global.implants.head_implant.nightmare," ",Global.player.special_vision," ",Global.player.vision_state," ",Global.player.shader_screen.material.get_shader_param("nightmare_vision"))
 check(Global.player.shader_screen.material.get_shader_param("nightmare_vision"),"nightmare goggles activate")
 Global.implants.head_implant=Global.implants.empty_implant
 yield(get_tree(),"idle_frame")
 yield(get_tree(),"idle_frame")
 check(not Global.player.shader_screen.material.get_shader_param("nightmare_vision"),"removing goggles clears nightmare without revive")
 Global.player.shader_screen.material.set_shader_param("nightmare_vision",true)
 Global.player.vision_state=-1
 Global.player._refresh_vision()
 check(not Global.player.shader_screen.material.get_shader_param("nightmare_vision"),"fresh player clears stale shared shader effect")
 Global.implants.head_implant=old_head
 Global.player._refresh_vision()
 yield(barrier("gas_ready"),"completed")
 if HOST:
  var nodes=[get_node("/root/Level")]
  while not nodes.empty():
   var node=nodes.pop_back()
   nodes.append_array(node.get_children())
   if node.has_method("poison_timeout") and node.enabled and not node.dead:
    node.poison_timeout()
    break
 yield(get_tree().create_timer(0.4),"timeout")
 var found=false
 var nodes=[get_node("/root/Level")]
 while not nodes.empty():
  var node=nodes.pop_back()
  nodes.append_array(node.get_children())
  if node.filename==("res://Entities/Bullets/Poison_Gas.tscn" if HOST else "res://MOD_CONTENT/CruS Online/effects/fake_poison_gas.tscn"):
   found=true
   check(node.get_node("Particle").emitting,"death gas emits particles")
   check(not node is Area if not HOST else node is Area,"only host cloud applies damage")
 check(found,"enemy death gas appears on peer")
 check(mp.get_node("SyncLoad/Center/Label").text.begins_with("Online synchronization"),"sync screen renamed")
 yield(barrier("gas_checked"),"completed")
 print("PICKUP_RESULT host=",HOST," failures=",failures)
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
