shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 optical_color : hint_color;
uniform float optical_metallic = 1.0;
uniform float optical_specular = 1.0;
uniform float optical_roughness = 0.04;
uniform vec4 optical_transmission : hint_color;
uniform float optical_refraction = 0.34;
uniform float visibility : hint_range(0.0, 1.0) = 0.5;

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
	if (dither_value(FRAGCOORD.xy) >= visibility) {
		discard;
	}
	METALLIC = optical_metallic;
	SPECULAR = optical_specular;
	ROUGHNESS = optical_roughness;
	TRANSMISSION = optical_transmission.rgb;
	vec2 refraction_uv = SCREEN_UV - NORMAL.xy * optical_refraction;
	float refraction_amount = 1.0 - optical_color.a;
	EMISSION = textureLod(SCREEN_TEXTURE, refraction_uv, ROUGHNESS * 8.0).rgb * refraction_amount;
	ALBEDO = optical_color.rgb * (1.0 - refraction_amount);
	ALPHA = 1.0;
}
