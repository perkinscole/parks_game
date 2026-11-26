shader_type spatial;
render_mode cull_disabled, shadows_disabled;
// Falling water: streaks of white water racing down the sheet, breaking
// into foam at the lip and the foot.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 sky_col : source_color = vec3(0.6, 0.72, 0.85);

void fragment() {
	// UV.x across the fall, UV.y from lip (0) to pool (1); UV2.x is the steepness
	float steep = UV2.x;
	float speed = mix(0.35, 1.5, steep);
	float a = texture(noise_tex, vec2(UV.x * 0.9, UV.y * 0.35 - TIME * speed * 0.45)).r;
	float b = texture(noise_tex, vec2(UV.x * 2.3 + 0.37, UV.y * 0.8 - TIME * speed * 0.8)).r;
	float streak = smoothstep(0.5, 0.85, a * 0.6 + b * 0.55);
	float edge = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x);
	float foam = clamp(streak * (0.2 + 0.75 * steep) + smoothstep(0.86, 1.0, UV.y) * 0.7, 0.0, 1.0);
	vec3 water = mix(vec3(0.1, 0.3, 0.38), sky_col, 0.25);
	ALBEDO = mix(water, vec3(0.86, 0.92, 0.96), foam);
	ROUGHNESS = mix(0.12, 0.6, foam);
	SPECULAR = 0.6;
	ALPHA = edge * mix(0.75, 1.0, foam) * smoothstep(0.0, 0.04, UV.y);
}
