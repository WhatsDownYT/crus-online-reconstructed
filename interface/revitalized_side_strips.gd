extends Control

const HEADER_PATH = "res://MOD_CONTENT/CruS Online/branding/header.png"
const STRIP_WIDTH = 385.0

var left_images = []
var right_images = []
var offset = 0.0

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	rect_size = Vector2(1280, 720)
	mouse_filter = MOUSE_FILTER_IGNORE
	var source = Image.new()
	if source.load(HEADER_PATH) != OK:
		return
	var header = ImageTexture.new()
	header.create_from_image(source, 0)
	_make_strip(0, left_images, header)
	_make_strip(1222, right_images, header)

func _make_strip(x, images, header):
	var strip = Control.new()
	strip.rect_position = Vector2(x, 0)
	strip.rect_size = Vector2(58, 720)
	strip.rect_clip_content = true
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(strip)
	for _index in range(4):
		var image = TextureRect.new()
		image.texture = header
		image.expand = true
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.rect_size = Vector2(STRIP_WIDTH, 58)
		image.rect_rotation = 90
		image.mouse_filter = MOUSE_FILTER_IGNORE
		strip.add_child(image)
		images.append(image)

func _process(delta):
	if not is_visible_in_tree():
		return
	offset = fposmod(offset + delta * 55.0, STRIP_WIDTH)
	for index in range(left_images.size()):
		left_images[index].rect_position = Vector2(58, index * STRIP_WIDTH - STRIP_WIDTH + offset)
		right_images[index].rect_position = Vector2(58, index * STRIP_WIDTH - offset)
