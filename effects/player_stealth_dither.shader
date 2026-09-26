shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture : hint_albedo;
uniform vec4 albedo_color : hint_color = vec4(1.0);
uniform bool use_albedo_texture = true;
uniform float surface_roughness = 0.8;
uniform float surface_metallic = 0.0;
uniform float surface_specular = 0.5;
uniform float visibility : hint_range(0.0, 1.0) = 1.0;

float dither_value(vec2 position) {
	ivec2 cell = ivec2(mod(floor(position), 4.0));
	vec4 row;
	if (cell.y == 0) {
		row = vec4(0.0, 8.0, 2.0, 10.0);
	} else if (cell.y == 1) {
		row = vec4(12.0, 4.0, 14.0, 6.0);
	} else if (cell.y == 2) {
		row = vec4(3.0, 11.0, 1.0, 9.0);
	} else {
		row = vec4(15.0, 7.0, 13.0, 5.0);
	}
	float value = row.x;
	if (cell.x == 1) {
		value = row.y;
	} else if (cell.x == 2) {
		value = row.z;
	} else if (cell.x == 3) {
		value = row.w;
	}
	return (value + 0.5) / 16.0;
}

void fragment() {
	vec4 tex = albedo_color;
	if (use_albedo_texture) {
		tex *= texture(albedo_texture, UV);
	}
	if (tex.a < 0.5 || dither_value(FRAGCOORD.xy) >= visibility) {
		discard;
	}
	ALBEDO = tex.rgb;
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
	SPECULAR = surface_specular;
}
