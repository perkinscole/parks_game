shader_type spatial;
render_mode cull_disabled;
// Ground material: biome colour from a per-tile map, broken up with noise,
// with rock on steep slopes, beaches, snow, and trails / roads that blend
// into the ground with worn, uneven edges.

uniform sampler2D tile_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D path_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size = vec2(160.0, 120.0);
uniform float snowline = 24.0;
uniform float snow_all = 0.0;
uniform float autumn = 0.0;
uniform float dryness = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = wpos.xz / map_size;
	float n_fine = texture(noise_tex, wpos.xz * 0.9).r;
	float n_mid = texture(noise_tex, wpos.xz * 0.13 + vec2(0.31, 0.77)).r;
	float n_big = texture(noise_tex, wpos.xz * 0.021 + vec2(0.6, 0.1)).r;
	float n_alt = texture(noise_tex, wpos.zx * 0.11 + vec2(0.5, 0.2)).r;

	// biome colour, with wobbly borders so biomes do not follow the grid
	vec2 warp = (vec2(n_mid, n_alt) - 0.5) * 2.2 / map_size;
	vec4 tile = texture(tile_tex, clamp(uv + warp, vec2(0.002), vec2(0.998)));
	float o = max(max(-uv.x, uv.x - 1.0), max(-uv.y, uv.y - 1.0));
	float outside = smoothstep(0.0, 0.04, o);
	// beyond the edge, fade gradually from the park's own ground into wild forest
	float far_out = smoothstep(0.0, 0.3, o + (n_big - 0.5) * 0.12);
	vec3 base = mix(tile.rgb, mix(vec3(0.05, 0.11, 0.05), vec3(0.13, 0.2, 0.08), n_big), far_out);
	float desert = tile.a * (1.0 - far_out);
	base *= 0.74 + 0.5 * n_big;
	base *= 0.84 + 0.32 * n_mid;
	base *= 0.9 + 0.2 * n_fine;
	base = mix(base, base * vec3(1.25, 1.0, 0.55), autumn * (1.0 - desert));
	base = mix(base, base * vec3(1.2, 1.02, 0.6), dryness * 0.6 * (1.0 - desert));

	// bare rock where it is steep, with strata bands
	float slope = 1.0 - wnrm.y;
	float band = texture(noise_tex, vec2(wpos.y * 0.3 + n_big * 0.4, n_mid * 0.2)).r;
	vec3 grey = mix(vec3(0.13, 0.12, 0.115), vec3(0.055, 0.052, 0.052), n_mid);
	vec3 red = mix(vec3(0.3, 0.085, 0.035), vec3(0.16, 0.04, 0.02), n_mid);
	vec3 rock = mix(grey, red, desert) * (0.7 + 0.6 * band);
	float rocky = smoothstep(0.09, 0.23, slope + (n_fine - 0.5) * 0.1);
	vec3 col = mix(base, rock, rocky);

	// beaches and lake beds
	float beach = 1.0 - smoothstep(0.03, 0.25, wpos.y + (n_mid - 0.5) * 0.15);
	col = mix(col, vec3(0.36, 0.3, 0.19) * (0.8 + 0.4 * n_fine), beach);
	if (wpos.y < 0.0) {
		col = mix(vec3(0.2, 0.2, 0.13), vec3(0.01, 0.03, 0.05), clamp(-wpos.y * 0.5, 0.0, 1.0));
	}

	// trails, worn ground around buildings, gravel shoulders and asphalt
	vec3 pm = texture(path_tex, uv).rgb * (1.0 - outside);
	float edge = (n_fine - 0.5) * 0.5 + (n_mid - 0.5) * 0.3;
	vec3 dirt = mix(vec3(0.085, 0.052, 0.028), vec3(0.2, 0.135, 0.075), n_mid) * (0.75 + 0.5 * n_fine);
	dirt = mix(dirt, red * 1.5, desert * 0.6);
	float worn = smoothstep(0.05, 0.5, pm.r + pm.b * 0.7 + edge * 0.5);
	float trail = smoothstep(0.4, 0.62, pm.r + edge);
	float pad = smoothstep(0.3, 0.65, pm.b + edge);
	col = mix(col, mix(col, dirt, 0.5), worn);
	col = mix(col, dirt, max(trail, pad * 0.85));
	float shoulder = smoothstep(0.12, 0.45, pm.g + edge * 0.6);
	float road = smoothstep(0.5, 0.6, pm.g + (n_fine - 0.5) * 0.06);
	vec3 gravel = vec3(0.16, 0.145, 0.125) * (0.6 + 0.8 * n_fine);
	vec3 asphalt = vec3(0.016, 0.017, 0.019) * (0.7 + 0.7 * n_fine) + 0.006 * n_mid;
	col = mix(col, gravel, shoulder);
	col = mix(col, asphalt, road);

	// snow: permanent on the high peaks, everywhere in winter
	float cap = smoothstep(snowline, snowline + 5.0, wpos.y + (n_big - 0.5) * 9.0 + (n_mid - 0.5) * 2.5);
	float lie = 1.0 - smoothstep(0.3, 0.58, slope + (n_fine - 0.5) * 0.12);
	float ground_snow = snow_all * step(0.04, wpos.y) * (1.0 - road * 0.8) * (1.0 - trail * 0.55) * (1.0 - desert * 0.75);
	float snow = max(cap * (1.0 - desert), ground_snow) * lie;
	col = mix(col, vec3(0.8, 0.85, 0.92) * (0.93 + 0.1 * n_mid), snow);

	ALBEDO = col;
	ROUGHNESS = mix(0.96, 0.6, max(snow, road * 0.35));
	SPECULAR = 0.2;
}
