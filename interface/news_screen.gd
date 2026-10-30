extends Control

const POSTS = [
	{"date": "09/13/26", "full_date": "September 13, 2026", "time": "14:30", "title": "New update is out!", "body": "This is a placeholder as well. Blah blah blah. I'm gonna put a lot of text here just so you can see it wrap a few times, yeah yeah yeah yeah yeah yeah oh yeah oh yeah oh yeah also this is testing image capabilities", "image": true},
	{"date": "08/05/26", "full_date": "August 5, 2026", "time": "18:00", "title": "Welcome to News", "body": "This is a placeholder post. Later on, Patreon posts from the PurgaTeam patreon will be filtered into here.\nStuff like updates to the mod, level or weapon contests, just general contests who knows, etc, will be posted there.\nSo just plenty of community stuff!", "image": false}
]

var entry_buttons = []
var entry_labels = []
var article_scroll
var article_content
var news_content
var tabs
var frame

func _ready():
	name = "NewsScreen"
	rect_position = Vector2(270, 92)
	rect_size = Vector2(920, 560)
	mouse_filter = MOUSE_FILTER_STOP
	_build()
	_select_post(0)
	hide()

func _build():
	frame = Panel.new()
	frame.rect_size = rect_size
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	var frame_style = get_parent().get_node("Settings").get_stylebox("panel").duplicate()
	if frame_style is StyleBoxFlat:
		frame_style.set_border_width_all(0)
	frame.add_stylebox_override("panel", frame_style)
	add_child(frame)
	tabs = TabContainer.new()
	tabs.name = "CommunityTabs"
	tabs.rect_position = Vector2(0, 0)
	tabs.rect_size = rect_size
	tabs.theme = load("res://Menu/menu_theme.tres")
	tabs.tab_align = TabContainer.ALIGN_RIGHT
	tabs.add_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(tabs)
	news_content = Control.new()
	news_content.name = "News"
	tabs.add_child(news_content)
	var addons = Control.new()
	addons.name = "Addons"
	tabs.add_child(addons)
	tabs.set_tab_disabled(1, true)

	var list_panel = _panel(Vector2(758, 12), Vector2(150, 506))
	var list_scroll = ScrollContainer.new()
	list_scroll.rect_position = Vector2.ZERO
	list_scroll.rect_size = Vector2(150, 506)
	list_scroll.add_stylebox_override("bg", StyleBoxEmpty.new())
	list_panel.add_child(list_scroll)
	var list = VBoxContainer.new()
	list.rect_min_size.x = 132
	list.add_constant_override("separation", 6)
	list_scroll.add_child(list)
	for i in range(POSTS.size()):
		var button = Button.new()
		button.rect_min_size = Vector2(132, 64)
		button.theme = load("res://Menu/menu_theme.tres")
		button.connect("pressed", self, "_select_post", [i])
		list.add_child(button)
		entry_buttons.append(button)
		var entry = Label.new()
		entry.text = POSTS[i].date + "\n" + POSTS[i].time
		entry.align = Label.ALIGN_CENTER
		entry.valign = Label.VALIGN_CENTER
		entry.anchor_right = 1.0
		entry.anchor_bottom = 1.0
		entry.mouse_filter = MOUSE_FILTER_IGNORE
		entry.add_font_override("font", _game_font(14))
		entry.add_color_override("font_color", Color(1, 0, 0))
		entry.add_color_override("font_color_shadow", Color(0, 0, 0))
		entry.add_constant_override("shadow_offset_x", 1)
		entry.add_constant_override("shadow_offset_y", 1)
		button.add_child(entry)
		entry_labels.append(entry)

	var article_panel = _panel(Vector2(12, 12), Vector2(738, 506))
	article_scroll = ScrollContainer.new()
	article_scroll.rect_position = Vector2.ZERO
	article_scroll.rect_size = Vector2(738, 506)
	article_scroll.add_stylebox_override("bg", StyleBoxEmpty.new())
	article_panel.add_child(article_scroll)
	var article_padding = MarginContainer.new()
	article_padding.add_constant_override("margin_left", 10)
	article_padding.add_constant_override("margin_top", 9)
	article_padding.add_constant_override("margin_right", 10)
	article_padding.add_constant_override("margin_bottom", 9)
	article_scroll.add_child(article_padding)
	article_content = VBoxContainer.new()
	article_content.rect_min_size.x = 690
	article_content.size_flags_horizontal = SIZE_EXPAND_FILL
	article_content.add_constant_override("separation", 15)
	article_padding.add_child(article_content)
	list_panel.name = "PostList"
	article_panel.name = "Article"
	news_content.connect("resized", self, "_layout_content")
	call_deferred("_layout_content")

func _layout_content():
	frame.rect_position = Vector2(0, news_content.rect_position.y)
	frame.rect_size = Vector2(rect_size.x, max(0, rect_size.y - frame.rect_position.y))
	var height = max(0, news_content.rect_size.y - 24)
	var list = news_content.get_node("PostList")
	list.rect_position = Vector2(news_content.rect_size.x - 162, 12)
	list.rect_size = Vector2(150, height)
	list.get_child(0).rect_size = list.rect_size
	var article = news_content.get_node("Article")
	article.rect_size = Vector2(max(0, news_content.rect_size.x - 182), height)
	article_scroll.rect_size = article.rect_size
	article_content.rect_min_size.x = max(0, article.rect_size.x - 48)

func _panel(position, size):
	var panel = Panel.new()
	panel.rect_position = position
	panel.rect_size = size
	panel.add_stylebox_override("panel", load("res://MOD_CONTENT/CruS Online/assets/interface/redpanel.tres"))
	news_content.add_child(panel)
	return panel

func _font(size):
	var font = DynamicFont.new()
	font.font_data = load("res://Fonts/MingLiU-ExtB-01.ttf")
	font.size = size
	return font

func _game_font(size):
	var font = DynamicFont.new()
	font.font_data = load("res://Fonts/gamefont(1).ttf")
	font.size = size
	return font

func _image_texture(path):
	var source = Image.new()
	if source.load(path) != OK:
		return null
	var texture = ImageTexture.new()
	texture.create_from_image(source, 0)
	return texture

func _label(value, size, color):
	var label = Label.new()
	label.text = value
	label.rect_min_size.x = 690
	label.autowrap = true
	label.add_font_override("font", _font(size))
	label.add_color_override("font_color", color)
	article_content.add_child(label)
	return label

func _select_post(index):
	for i in range(entry_labels.size()):
		entry_labels[i].add_color_override("font_color", Color(0, 1, 0) if i == index else Color(1, 0, 0))
	for child in article_content.get_children():
		article_content.remove_child(child)
		child.queue_free()
	var post = POSTS[index]
	_label(post.full_date + " @ " + post.time, 20, Color(0, 1, 0))
	_label(post.title.to_upper(), 36, Color(1, 1, 1))
	_label(post.body, 22, Color(1, 1, 1))
	if post.image:
		var image = TextureRect.new()
		image.rect_min_size = Vector2(246, 291)
		image.texture = _image_texture("res://MOD_CONTENT/CruS Online/assets/interface/softproducts.png")
		image.expand = true
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		article_content.add_child(image)
		_label("More news and updates will be posted here.", 20, Color(1, 1, 1))
	else:
		var spacer = Control.new()
		spacer.rect_min_size.y = 260
		spacer.mouse_filter = MOUSE_FILTER_IGNORE
		article_content.add_child(spacer)
	var reply = RichTextLabel.new()
	reply.rect_min_size = Vector2(690, 34)
	reply.bbcode_enabled = true
	reply.scroll_active = false
	reply.add_font_override("normal_font", _font(20))
	reply.bbcode_text = "[url=https://www.patreon.com/]View & reply on Patreon[/url]"
	reply.connect("meta_clicked", self, "_open_link")
	article_content.add_child(reply)
	article_scroll.scroll_vertical = 0

func _open_link(url):
	OS.shell_open(str(url))

func come():
	show()
	raise()

func go():
	hide()
