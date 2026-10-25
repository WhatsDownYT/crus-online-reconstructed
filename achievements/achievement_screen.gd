extends Control

var achievement = {}
var icon
var title_font
var name_font
var detail_font
var fitted_name_font
var name_lines = []

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	title_font = _font(42)
	name_font = _font(32)
	detail_font = _font(22)
	_update_name_layout()
	update()

func _font(size):
	var font = DynamicFont.new()
	font.font_data = load("res://Fonts/MingLiU-ExtB-01.ttf")
	font.size = size
	font.use_filter = true
	return font

func set_achievement(value):
	achievement = value
	var path = str(value.get("icon", ""))
	icon = load(path) if not path.empty() and ResourceLoader.exists(path) else null
	if icon == null and not path.empty():
		var file = File.new()
		if file.open(path, File.READ) == OK:
			var image = Image.new()
			if image.load_png_from_buffer(file.get_buffer(file.get_len())) == OK:
				var texture = ImageTexture.new()
				texture.create_from_image(image)
				icon = texture
			file.close()
	_update_name_layout()
	update()

func _update_name_layout():
	if name_font == null: return
	fitted_name_font = name_font
	name_lines = _wrapped_name(str(achievement.get("name", "")), fitted_name_font, 184)
	while name_lines.size() * fitted_name_font.get_height() > 182 and fitted_name_font.size > 18:
		fitted_name_font = _font(fitted_name_font.size - 2)
		name_lines = _wrapped_name(str(achievement.get("name", "")), fitted_name_font, 184)

func _centered_text(font, value, bounds, baseline, color, shadow):
	var width = font.get_string_size(value).x
	var x = bounds.position.x + (bounds.size.x - width) * 0.5
	if shadow:
		draw_string(font, Vector2(x + 3, baseline + 3), value, Color(0, 1, 0))
	draw_string(font, Vector2(x, baseline), value, color)

func _wrapped_name(value, font, width):
	var lines = []
	for paragraph in value.split("\n", true):
		var line = ""
		for word in paragraph.split(" ", false):
			var candidate = word if line.empty() else line + " " + word
			if font.get_string_size(candidate).x <= width:
				line = candidate
				continue
			if not line.empty():
				lines.append(line)
				line = ""
			var piece = ""
			for character in word:
				if not piece.empty() and font.get_string_size(piece + character).x > width:
					lines.append(piece)
					piece = ""
				piece += character
			line = piece
		lines.append(line)
	return lines

func _draw():
	draw_rect(Rect2(Vector2.ZERO, rect_size), Color.white)
	if achievement.empty(): return
	_centered_text(title_font, "GOAL", Rect2(12, 0, 232, 0), 82, Color(1, 0, 1), true)
	_centered_text(title_font, "REACHED!", Rect2(12, 0, 232, 0), 151, Color(1, 0, 1), true)
	var icon_rect = Rect2(31, 193, 194, 194)
	draw_rect(Rect2(icon_rect.position + Vector2(5, 5), icon_rect.size), Color(0, 1, 0))
	if icon != null:
		draw_texture_rect(icon, icon_rect, false)
	var line_height = fitted_name_font.get_height()
	var baseline = icon_rect.position.y + (icon_rect.size.y - line_height * name_lines.size()) * 0.5 + fitted_name_font.get_ascent()
	for line in name_lines:
		_centered_text(fitted_name_font, line, Rect2(36, 0, 184, 0), baseline, Color.black, true)
		baseline += line_height
	var words = str(achievement.get("description", "")).split(" ", false)
	var lines = []
	var line = ""
	for word in words:
		var next = word if line.empty() else line + " " + word
		if not line.empty() and detail_font.get_string_size(next).x > 204:
			lines.append(line)
			line = word
		else:
			line = next
	if not line.empty(): lines.append(line)
	for i in range(min(4, lines.size())):
		_centered_text(detail_font, lines[i], Rect2(22, 0, 212, 0), 437 + i * 27, Color.black, false)
