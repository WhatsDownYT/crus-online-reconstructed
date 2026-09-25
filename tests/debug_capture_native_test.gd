extends Node

var failures = 0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func check(value, label):
	print("CAPTURE_CHECK ", label, "=", value)
	if not value:
		failures += 1

func key(code):
	var event = InputEventKey.new()
	event.scancode = code
	event.pressed = true
	return event

func run():
	yield(get_tree().create_timer(6), "timeout")
	var capture = Global.get_node("DebugCapture")
	var previous_player = Global.player
	var previous_in_game = Global.menu.in_game
	var fake_player = Spatial.new()
	fake_player.name = "CaptureTestPlayer"
	Global.add_child(fake_player)
	var hud = Control.new()
	hud.name = "UI"
	fake_player.add_child(hud)
	var screen_effect = ColorRect.new()
	screen_effect.name = "Shader_Screen"
	fake_player.add_child(screen_effect)
	Global.player = fake_player
	Global.menu.in_game = true
	capture._process(0)
	capture._input(key(KEY_F8))
	check(capture.ui_hidden and hud.modulate.a == 0.0, "F8 hides HUD")
	check(Global.menu.modulate.a == 0.0, "F8 hides menu overlays")
	capture._input(key(KEY_F8))
	check(not capture.ui_hidden and hud.modulate.a == 1.0, "F8 restores HUD")
	capture._input(key(KEY_F9))
	check(capture.world_black and capture.black_rect.visible and capture.black_layer.layer == -1, "F9 black layer below UI")
	check(not screen_effect.visible, "F9 prevents screen shader from tinting black")
	capture._input(key(KEY_F8))
	check(capture.black_rect.visible and hud.modulate.a == 0.0, "Toggles work together")
	Global.menu.in_game = false
	capture._process(0)
	check(not capture.ui_hidden and not capture.world_black and hud.modulate.a == 1.0 and not capture.black_rect.visible and screen_effect.visible, "Leaving level resets both")
	Global.player = previous_player
	Global.menu.in_game = previous_in_game
	fake_player.queue_free()
	print("CAPTURE_TEST_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
