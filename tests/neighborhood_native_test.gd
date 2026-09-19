extends Node
var failures=0
var mp
func check(ok,label):
 print("NEIGHBORHOOD_CHECK host=",HOST," ",label,"=",ok)
 if not ok: failures+=1
func _ready():
 pause_mode=Node.PAUSE_MODE_PROCESS
 call_deferred("run")
func run():
 yield(get_tree().create_timer(6),"timeout")
 mp=Global.get_node("Multiplayer")
 mp.Voice.test_capture=true
 check(mp.Menu.get_node_or_null("VersionWarning")==null,"boot warning removed")
 mp.NetworkBridge.debug=true
 if HOST:
  mp.config.hostPort=PORT
  mp.hostSettings.shareDifficulty=true
  mp.host_server()
 else:
  mp.join_to_server("127.0.0.1",PORT)
 while mp.players.size()<2:
  yield(get_tree().create_timer(0.1),"timeout")
 yield(get_tree().create_timer(2),"timeout")
 var count=mp.NetworkBridge.rpc_debug_list.get("sync_difficulty",0)
 yield(get_tree().create_timer(2),"timeout")
 check(mp.NetworkBridge.rpc_debug_list.get("sync_difficulty",0)==count,"unchanged difficulty does not broadcast every frame")
 if HOST:
  var before=mp.NetworkBridge.rpc_debug_list.get("sync_difficulty",0)
  for i in range(120):
   mp.Flow._process(0)
  check(mp.NetworkBridge.rpc_debug_list.get("sync_difficulty",0)==before,"equal difficulty dictionaries remain quiet for 120 polls")
  var chaos=Global.chaos_mode
  Global.chaos_mode=not chaos
  mp.Flow._process(0)
  check(mp.NetworkBridge.rpc_debug_list.get("sync_difficulty",0)==before+1,"real difficulty change publishes immediately once")
  Global.chaos_mode=chaos
  mp.Flow._process(0)
 for path in ["res://Levels/Level2.tscn","res://Levels/Level1.tscn","res://Levels/Level2.tscn"]:
  if HOST:
   Global.CURRENT_LEVEL=Global.LEVELS.find(path)
   mp.game_init(path)
  yield(get_tree().create_timer(0.5),"timeout")
  while Global.loader!=null or not is_instance_valid(Global.current_scene) or Global.current_scene.filename!=path or not mp.player_scene_loaded or get_tree().paused:
   yield(get_tree().create_timer(0.1),"timeout")
  Global.player.health=10000
  yield(get_tree().create_timer(3),"timeout")
  check(not mp.get_node("SyncLoad").visible,"synchronization completes "+path)
  check(mp.get_node("SyncLoad/Center/Label").text=="Online synchronization\nPlease wait\n\n(2/2)","loaded count reaches 2/2 "+path)
  print("NEIGHBORHOOD_LOADED ",path," fps=",Engine.get_frames_per_second())
  yield(barrier(str(Global.CURRENT_LEVEL)+str(mp.SteamNetwork.scene_epoch)),"completed")
 print("NEIGHBORHOOD_RESULT host=",HOST," failures=",failures)
 get_tree().quit(1 if failures else 0)
func barrier(stage):
 var prefix="E:/Cruelty/Online/dist/neighborhood-barrier-"+str(PORT)+"-"+stage+"-"
 var file=File.new()
 file.open(prefix+str(HOST),File.WRITE)
 file.store_string("ready")
 file.close()
 yield(get_tree(),"idle_frame")
 while not file.file_exists(prefix+str(not HOST)):
  yield(get_tree().create_timer(0.05),"timeout")
