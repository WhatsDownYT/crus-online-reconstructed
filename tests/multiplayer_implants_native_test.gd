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
  if peer != 1: client_id=peer
 var remote_id=client_id if HOST else 1
 var weapon=Global.player.weapon
 Global.player.set_physics_process(false)
 Global.player.rotation=Vector3.ZERO
 Global.player.rotation_helper.rotation=Vector3.ZERO
 Global.player.global_transform.origin=Vector3(10000,10000,10002) if HOST else Vector3(10000,10000,10000)
 for implant in Global.implants.IMPLANTS:
  if implant.i_name == "First Aid Kit+": Global.implants.arm_implant=implant
 Global.player.health=20
 yield(get_tree().create_timer(2),"timeout")
 Global.menu._refresh_start_buttons()
 check(Global.menu.menu[Global.menu.START].get_child(3).visible and Global.menu.menu[Global.menu.START].get_child(4).visible,"pause menu keeps both exit options")
 yield(barrier("ready"),"completed")
 print("IMPLANT_DIAG host=",HOST," disabled=",weapon.disabled," online_menu=",mp.Menu.visible," consumed=",weapon.item_consumed," died=",Global.player.died," healing=",Global.implants.arm_implant.healing)
 if HOST:
  Input.action_press("Tertiary_Weapon")
  weapon._process(0.016)
 yield(get_tree(),"idle_frame")
 yield(get_tree(),"idle_frame")
 Input.action_release("Tertiary_Weapon")
 yield(get_tree().create_timer(1),"timeout")
 if HOST: check(Global.player.health==70 and weapon.item_consumed,"implant control heals self once")
 yield(barrier("self_checked"),"completed")
 if HOST: Global.player.health=20
 if not HOST:
  weapon._update_first_aid_target()
  check(weapon.first_aid_target==1,"looking at host offers first aid interaction")
  var avatar=mp.Players.get_node("1")
  avatar._update_help_label_visibility()
  check(not avatar.get_node("Puppet/PlayerModel/HelpLabel").visible,"healing has no text prompt")
  print("IMPLANT_RAY origin=",weapon.multiplayer_use_ray.global_transform.origin," endpoint=",weapon.multiplayer_use_ray.global_transform.xform(weapon.multiplayer_use_ray.cast_to)," collider=",weapon.multiplayer_use_ray.get_collider())
  Input.action_press("Use")
  weapon._process(0.016)
 yield(get_tree(),"idle_frame")
 yield(get_tree(),"idle_frame")
 Input.action_release("Use")
 yield(get_tree().create_timer(1),"timeout")
 if HOST: check(Global.player.health==70,"client heals host")
 if not HOST: check(weapon.item_consumed and not weapon.first_aid_pending,"accepted client healing consumes kit")
 yield(barrier("client_healed"),"completed")
 if not HOST: mp.request_multiplayer_heal(1)
 yield(get_tree().create_timer(1),"timeout")
 if HOST: check(Global.player.health==70,"duplicate request does not reuse kit")
 yield(barrier("duplicate_checked"),"completed")
 if HOST:
  mp.first_aid_used.clear()
  weapon.item_consumed=false
  weapon.use_first_aid(client_id)
 yield(get_tree().create_timer(1),"timeout")
 if not HOST: check(Global.player.health==70,"host heals client")
 yield(barrier("host_healed"),"completed")
 var avatar=mp.Players.get_node(str(remote_id))
 avatar.sync_implants(null,["N/A","Stealth Suit+","N/A","N/A"])
 avatar.global_transform.origin=Global.player.global_transform.origin+Vector3(11,0,0)
 avatar._update_multiplayer_body_visuals()
 check(avatar.get_node("Puppet/PlayerModel/Nickname").visible,"stealth name visible within 12 units")
 check(avatar._body_stealth_materials[0].get_shader_param("visibility")==0.5,"stealth suit uses half dither")
 var optical=load("res://Materials/seethrough.tres")
 var material=avatar._body_stealth_materials[0]
 check(material.get_shader_param("optical_color")==optical.albedo_color and material.get_shader_param("optical_refraction")==optical.refraction_scale and material.get_shader_param("optical_roughness")==optical.roughness,"stealth dither retains original shitmen material properties")
 avatar._sync_label_shadows()
 yield(get_tree(),"idle_frame")
 yield(get_tree(),"idle_frame")
 var label=avatar.get_node("Puppet/PlayerModel/Nickname")
 var shadow=avatar.label_shadows.Nickname
 var delta=(shadow.get_aabb().position+shadow.get_aabb().size*0.5)-(label.get_aabb().position+label.get_aabb().size*0.5)
 print("SHADOW_GEOMETRY offset=",delta," pixel_size=",label.pixel_size)
 check(abs(delta.x-2*label.pixel_size)<0.0001 and abs(delta.y+2*label.pixel_size)<0.0001,"nickname shadow geometry sits two pixels down and right")
 label.text="WWW narrow iii"
 yield(get_tree().create_timer(0.2),"timeout")
 delta=(shadow.get_aabb().position+shadow.get_aabb().size*0.5)-(label.get_aabb().position+label.get_aabb().size*0.5)
 check(abs(delta.x-2*label.pixel_size)<0.0001 and abs(delta.y+2*label.pixel_size)<0.0001,"nickname shadow stays aligned after name changes")
 avatar.global_transform.origin=Global.player.global_transform.origin+Vector3(13,0,0)
 avatar._update_multiplayer_body_visuals()
 check(not avatar.get_node("Puppet/PlayerModel/Nickname").visible,"stealth name hidden beyond 12 units")
 check(avatar._body_stealth_materials[0].get_shader_param("visibility")==0.5,"stealth opacity independent of range")
 check(avatar._body_meshes.size()==3,"body effects include glasses")
 var glasses=avatar.get_node("Puppet/PlayerModel/Armature/Skeleton/Head/glasses")
 check(glasses.material_override==avatar._body_stealth_materials[2] and glasses.material_override.get_shader_param("visibility")==0.5,"glasses use optical half dither")
 avatar.sync_implants(null,["N/A","Military Camouflage+","N/A","N/A"])
 avatar._update_multiplayer_body_visuals()
 check(not avatar.get_node("Puppet/PlayerModel/Nickname").visible,"camo name hidden beyond 12 units")
 avatar.global_transform.origin=Global.player.global_transform.origin+Vector3(12,0,0)
 avatar._update_multiplayer_body_visuals()
 check(avatar._body_stealth_materials[0].get_shader_param("visibility")==0.0,"camo body fully hidden at 12 units")
 check(glasses.material_override==avatar._body_stealth_materials[2] and glasses.material_override.get_shader_param("visibility")==0.0,"camo glasses disappear with body")
 for sample in [[9.0,1.0],[10.5,0.5],[12.0,0.0]]:
  avatar.global_transform.origin=Global.player.global_transform.origin+Vector3(sample[0],0,0)
  avatar._update_multiplayer_body_visuals()
  check(abs(avatar._body_stealth_materials[0].get_shader_param("visibility")-sample[1])<0.001,"camo fade at "+str(sample[0]))
 avatar.sync_implants(null,["N/A","N/A","N/A","N/A"])
 avatar.global_transform.origin=Global.player.global_transform.origin+Vector3(13,0,0)
 avatar._update_multiplayer_body_visuals()
 check(not avatar.get_node("Puppet/PlayerModel/Nickname").visible,"ordinary player name hidden beyond 12 units")
 avatar.global_transform.origin=Global.player.global_transform.origin+Vector3(11,0,0)
 avatar._update_multiplayer_body_visuals()
 check(avatar.get_node("Puppet/PlayerModel/Nickname").visible,"ordinary player name visible within 12 units")
 check(glasses.material_override==avatar._body_base_materials[2],"glasses restore their original material")
 yield(check_bayer_render(),"completed")
 yield(barrier("visuals_checked"),"completed")
 if HOST:
  mp.CounterOp.teams={1:mp.CounterOp.TEAM_OPERATIVES,client_id:mp.CounterOp.TEAM_COUNTER_OPERATIVES}
  mp.CounterOp.settings.randomizeTeams=false
  mp.hostSettings.gameMode="counter_op"
  mp.CounterOp.prepare_round()
  mp.Flow.waiting_peers=[client_id]
  check(mp.CounterOp.all_counter_operatives_absent(mp.Flow.waiting_peers),"last counter-operative returning to menu forfeits team")
  mp.Flow.check_team_wipe()
  yield(get_tree().create_timer(0.2),"timeout")
  check(mp.Flow.result_active and mp.Flow.result_winner_team==mp.CounterOp.TEAM_OPERATIVES,"counter-operative departure ends round")
  mp.Flow.clear_result()
  mp.Flow.waiting_peers.clear()
  mp.hostSettings.gameMode="deathmatch"
  mp.Deathmatch.participants=[1,client_id]
  mp.Deathmatch.started=true
  mp.Flow.request_wait(client_id,true)
  check(mp.died_players.has(client_id) and mp.Flow.waiting_peers.has(client_id),"returning client counts as eliminated in deathmatch")
  yield(get_tree().create_timer(0.2),"timeout")
  check(mp.Flow.result_active and mp.Flow.result_winner_team=="deathmatch" and mp.Flow.result_won,"last opponent leaving ends deathmatch")
 yield(barrier("round_checked"),"completed")
 print("IMPLANT_RESULT host=",HOST," failures=",failures)
 get_tree().quit(1 if failures else 0)

func check_bayer_render():
 var viewport=Viewport.new()
 viewport.size=Vector2(16,16)
 viewport.own_world=true
 viewport.render_target_update_mode=Viewport.UPDATE_ALWAYS
 add_child(viewport)
 var environment=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color.black
 environment.environment.ambient_light_color=Color.white
 environment.environment.ambient_light_energy=1
 viewport.add_child(environment)
 var camera=Camera.new()
 camera.projection=Camera.PROJECTION_ORTHOGONAL
 camera.size=2
 camera.translation=Vector3(0,0,1)
 viewport.add_child(camera)
 camera.current=true
 var quad=MeshInstance.new()
 quad.mesh=QuadMesh.new()
 quad.mesh.size=Vector2(2,2)
 viewport.add_child(quad)
 for shader_name in ["player_stealth_dither","player_stealth_optical_dither"]:
  var material=ShaderMaterial.new()
  material.shader=load("res://MOD_CONTENT/CruS Online/effects/"+shader_name+".shader")
  material.set_shader_param("albedo_color",Color.white)
  material.set_shader_param("use_albedo_texture",false)
  material.set_shader_param("optical_color",Color.white)
  material.set_shader_param("optical_metallic",0.0)
  material.set_shader_param("optical_transmission",Color.black)
  quad.material_override=material
  for amount in [0.25,0.5]:
   material.set_shader_param("visibility",amount)
   yield(VisualServer,"frame_post_draw")
   yield(VisualServer,"frame_post_draw")
   var image=viewport.get_texture().get_data()
   image.lock()
   var count=0
   var periodic=true
   for y in range(16):
    for x in range(16):
     var on=image.get_pixel(x,y).r>0.1
     if on: count+=1
     if on!=(image.get_pixel(x%4,y%4).r>0.1): periodic=false
   image.unlock()
   print("BAYER_RENDER shader=",shader_name," visibility=",amount," count=",count," periodic=",periodic)
   check(count==int(amount*256) and periodic,"rendered Bayer coverage and four-pixel repeat: "+shader_name+" "+str(amount))
 viewport.queue_free()
 yield(get_tree(),"idle_frame")

func barrier(stage):
 var prefix="E:/Cruelty/Online/dist/pickup-barrier-"+str(PORT)+"-"+stage+"-"
 var file=File.new()
 file.open(prefix+str(HOST),File.WRITE)
 file.store_string("ready")
 file.close()
 yield(get_tree(),"idle_frame")
 while not file.file_exists(prefix+str(not HOST)):
  yield(get_tree().create_timer(0.05),"timeout")
