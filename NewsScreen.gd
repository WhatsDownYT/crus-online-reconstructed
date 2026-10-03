extends Control

func _ready():
	name = "NewsScreen"
	rect_position = Vector2(320, 92)
	rect_size = Vector2(720, 480)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background = ColorRect.new()
	background.color = Color(0.12, 0.015, 0.015, 0.92)
	background.rect_size = rect_size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var title = Label.new()
	title.text = "NEWS"
	title.rect_position = Vector2(24, 18)
	title.add_color_override("font_color", Color(0, 1, 0))
	var font = DynamicFont.new()
	font.font_data = load("res://Fonts/MingLiU-ExtB-01.ttf")
	font.size = 26
	title.add_font_override("font", font)
	add_child(title)
	var empty = Label.new()
	empty.text = "No news available."
	empty.rect_position = Vector2(24, 70)
	empty.add_color_override("font_color", Color(1, 1, 1))
	add_child(empty)
	hide()

func come():
	show()

func go():
	hide()
