extends PanelContainer

var window_drag_enabled = true
var _dragging = false

func _ready():
	var title = get_node_or_null("VBoxContainer/Label")
	if title != null:
		title.mouse_filter = Control.MOUSE_FILTER_STOP
		title.connect("gui_input", self, "_title_input")

func _title_input(event):
	if window_drag_enabled and event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()

func _input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		_dragging = false
	if _dragging and window_drag_enabled and visible and event is InputEventMouseMotion:
		var parent_transform = get_parent().get_global_transform_with_canvas()
		rect_position += parent_transform.affine_inverse().basis_xform(event.relative)
		fit_in_parent()

func fit_in_parent():
	if not window_drag_enabled or not get_parent() is Control:
		return
	var available = get_parent().rect_size - rect_size * rect_scale
	rect_position = Vector2(clamp(rect_position.x, 0, max(0, available.x)), clamp(rect_position.y, 0, max(0, available.y)))
