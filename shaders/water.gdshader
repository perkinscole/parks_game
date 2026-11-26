shader_type spatial;
// Water: moving ripples that catch the sun, sky reflection at grazing angles,
// clear shallows shading to deep blue, and a soft foam line at the shore.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform vec3 shallow : source_color = vec3(0.07, 0.2, 0.2);
uniform vec3 deep : source_color = vec3(0.012, 0.055, 0.11);
uniform vec3 sky_col : source_color = vec3(0.5, 0.65, 0.85);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float waves(vec2 p) {
	return texture(noise_tex, p * 0.31 + TIME * vec2(0.021, 0.013)).r
		+ texture(noise_tex, p * 0.83 - TIME * vec2(0.017, 0.031)).r * 0.5
		+ texture(noise_tex, p * 2.3 + TIME * vec2(0.04, -0.02)).r * 0.2;
}

void fragment() {
	// ripples
	float e = 0.06;
	float hx = waves(wpos.xz + vec2(e, 0.0)) - waves(wpos.xz - vec2(e, 0.0));
	float hz = waves(wpos.xz + vec2(0.0, e)) - waves(wpos.xz - vec2(0.0, e));
	vec3 n = normalize(vec3(-hx * 0.55, 1.0, -hz * 0.55));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// how much water lies between the surface and the bed
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 bed = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	bed.xyz /= bed.w;
	float thickness = max(VERTEX.z - bed.z, 0.0);
	float t = clamp(thickness * 1.6, 0.0, 1.0);

	vec3 col = mix(shallow, deep, t);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_col, fres * 0.6);
	float foam = (1.0 - smoothstep(0.0, 0.05, thickness)) * (0.5 + 0.5 * texture(noise_tex, wpos.xz * 1.9 + TIME * 0.03).r);
	col = mix(col, vec3(0.7, 0.76, 0.78), foam * 0.4);

	ALBEDO = col;
	ALPHA = clamp(mix(0.6, 0.97, t) + fres * 0.4 + foam * 0.2, 0.0, 1.0);
	ROUGHNESS = 0.035;
	METALLIC = 0.0;
	SPECULAR = 0.85;
}
