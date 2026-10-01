shader_type canvas_item;

uniform bool selected = false;

void fragment() {
	if (!selected) {
		COLOR = vec4(0.0);
	} else {
		vec2 pixel = TEXTURE_PIXEL_SIZE * 3.0;
		float center = texture(TEXTURE, UV).a;
		float outside = max(texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
		outside = max(outside, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
		outside = max(outside, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
		outside = max(outside, texture(TEXTURE, UV + pixel).a);
		outside = max(outside, texture(TEXTURE, UV - pixel).a);
		outside = max(outside, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
		outside = max(outside, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
		COLOR = vec4(0.0, 1.0, 0.0, (1.0 - step(0.5, center)) * step(0.5, outside));
	}
}
