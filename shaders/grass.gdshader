shader_type spatial;
render_mode cull_disabled;
// Grass tufts: lit like the ground they stand on, darker at the roots,
// swaying a little in the wind.

uniform vec3 tint = vec3(1.0);
uniform float snow = 0.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bend = UV.y * UV.y;
	float gust = sin(TIME * 1.5 + wp.x * 1.1 + wp.z * 1.6) * 0.03 + sin(TIME * 3.1 + wp.x * 2.9 - wp.z * 1.3) * 0.012;
	VERTEX.x += gust * bend;
	VERTEX.z += gust * 0.6 * bend;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2)) * tint;
	c *= mix(0.55, 1.5, UV.y);
	c = mix(c, c * vec3(1.25, 1.2, 0.7), UV.y * 0.5); // sunlit, slightly yellow tips
	c = mix(c, vec3(0.8, 0.84, 0.9), snow * smoothstep(0.2, 0.8, UV.y));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
