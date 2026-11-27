shader_type spatial;
render_mode cull_disabled;
// Ground material. Colour comes from a per-tile biome map and is then broken
// up the way real ground is: patchy dry grass and bare soil, rock with strata
// and cracks on steep or high ground, snow that settles on ledges, and
// trails / roads that wear into the surface. A bump map gives small-scale
// relief so the sun picks out texture.

uniform sampler2D tile_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D path_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D bump_tex : hint_normal, filter_linear_mipmap, repeat_enable;
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
	TANGENT = normalize(cross(NORMAL, vec3(0.0, 0.0, 1.0)));
	BINORMAL = normalize(cross(NORMAL, TANGENT));
}

float tri(vec3 p, vec3 w, float scale) {
	// noise projected from three sides, so cliffs are not smeared
	return texture(noise_tex, p.zy * scale).r * w.x + texture(noise_tex, p.xz * scale).r * w.y + texture(noise_tex, p.xy * scale).r * w.z;
}

void fragment() {
	vec2 uv = wpos.xz / map_size;
	float n_micro = texture(noise_tex, wpos.xz * 3.3).r;
	float n_fine = texture(noise_tex, wpos.xz * 0.9).r;
	float n_mid = texture(noise_tex, wpos.xz * 0.13 + vec2(0.31, 0.77)).r;
	float n_big = texture(noise_tex, wpos.xz * 0.021 + vec2(0.6, 0.1)).r;
	float n_alt = texture(noise_tex, wpos.zx * 0.11 + vec2(0.5, 0.2)).r;

	// biome colour, with wobbly borders so biomes do not follow the grid
	vec2 warp = (vec2(n_mid, n_alt) - 0.5) * 2.4 / map_size;
	vec4 tile = texture(tile_tex, clamp(uv + warp, vec2(0.002), vec2(0.998)));
	float o = max(max(-uv.x, uv.x - 1.0), max(-uv.y, uv.y - 1.0));
	float outside = smoothstep(0.0, 0.04, o);
	float far_out = smoothstep(0.0, 0.3, o + (n_big - 0.5) * 0.12);
	vec3 base = mix(tile.rgb, mix(vec3(0.035, 0.06, 0.03), vec3(0.08, 0.11, 0.05), n_big), far_out);
	float desert = tile.a * (1.0 - far_out);

	// living ground is never one colour: straw-dry patches, bare soil, darker damp hollows
	float green = clamp((base.g - max(base.r, base.b)) * 9.0, 0.0, 1.0);
	base = mix(base, base * vec3(1.5, 1.25, 0.7), green * smoothstep(0.45, 0.85, n_mid) * (0.45 + dryness * 0.4));
	vec3 soil = vec3(0.075, 0.055, 0.036) * (0.6 + 0.8 * n_fine);
	base = mix(base, soil, green * smoothstep(0.6, 0.82, n_alt * 0.55 + n_micro * 0.45) * 0.5);
	base *= 0.66 + 0.68 * n_big;
	base *= 0.82 + 0.36 * n_mid;
	base *= 0.72 + 0.56 * n_micro;
	base = mix(base, base * vec3(1.3, 1.0, 0.5), autumn * green * (1.0 - desert));

	// rock: strata, cracks and lichen; shows on steep ground and above the alpine zone
	float slope = 1.0 - wnrm.y;
	vec3 bw = pow(abs(wnrm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	float r1 = tri(wpos, bw, 0.33);
	float r2 = tri(wpos, bw, 1.7);
	float strata = texture(noise_tex, vec2(wpos.y * 0.2 + n_big * 1.6 + n_mid * 0.5, (wpos.x + wpos.z) * 0.02)).r;
	vec3 grey = mix(vec3(0.15, 0.14, 0.13), vec3(0.045, 0.045, 0.05), r1);
	grey = mix(grey, vec3(0.17, 0.145, 0.115), smoothstep(0.5, 0.85, strata) * 0.3);
	grey = mix(grey, vec3(0.09, 0.105, 0.05), smoothstep(0.68, 0.9, n_mid) * 0.3);
	vec3 red = mix(vec3(0.33, 0.1, 0.04), vec3(0.15, 0.04, 0.02), r1);
	red = mix(red, vec3(0.42, 0.2, 0.1), smoothstep(0.5, 0.8, strata) * 0.6);
	vec3 rock = mix(grey, red, desert);
	rock *= 0.55 + 0.9 * r2;
	rock *= mix(1.0, 0.5, smoothstep(0.42, 0.25, r2));
	float rocky = smoothstep(0.08, 0.22, slope + (r2 - 0.5) * 0.14);
	rocky = max(rocky, smoothstep(12.0, 15.5, wpos.y + (n_mid - 0.5) * 3.5 + (r2 - 0.5) * 2.0) * 0.9 * (1.0 - desert));
	vec3 col = mix(base, rock, rocky);

	// beaches and lake beds
	float beach = 1.0 - smoothstep(0.03, 0.25, wpos.y + (n_mid - 0.5) * 0.15);
	col = mix(col, vec3(0.3, 0.25, 0.16) * (0.7 + 0.6 * n_micro), beach);
	if (wpos.y < 0.0) {
		col = mix(vec3(0.2, 0.2, 0.13), vec3(0.01, 0.03, 0.05), clamp(-wpos.y * 0.5, 0.0, 1.0));
	}

	// trails, worn ground around buildings, gravel shoulders and asphalt
	vec3 pm = texture(path_tex, uv).rgb * (1.0 - outside);
	float edge = (n_fine - 0.5) * 0.5 + (n_mid - 0.5) * 0.3;
	vec3 dirt = mix(vec3(0.075, 0.048, 0.027), vec3(0.17, 0.115, 0.065), n_mid) * (0.6 + 0.8 * n_micro);
	dirt = mix(dirt, red * 1.4, desert * 0.6);
	float worn = smoothstep(0.05, 0.5, pm.r + pm.b * 0.7 + edge * 0.5);
	float trail = smoothstep(0.4, 0.62, pm.r + edge);
	float pad = smoothstep(0.3, 0.65, pm.b + edge);
	// laid stone (built trail): pale slabs with dark joints
	float paved = smoothstep(0.45, 0.6, min(pm.r, pm.b) + edge * 0.3);
	pad *= 1.0 - smoothstep(0.2, 0.5, pm.r);
	col = mix(col, mix(col, dirt, 0.5), worn);
	col = mix(col, dirt, max(trail, pad * 0.85));
	vec2 slab = fract(wpos.xz * vec2(7.0, 7.0) + vec2(floor(wpos.z * 7.0) * 0.5, 0.0));
	float joint = smoothstep(0.0, 0.1, slab.x) * smoothstep(0.0, 0.12, slab.y);
	vec3 stone = mix(vec3(0.3, 0.29, 0.27), vec3(0.46, 0.45, 0.42), n_mid) * (0.75 + 0.5 * n_micro) * mix(0.55, 1.0, joint);
	col = mix(col, stone, paved);
	float shoulder = smoothstep(0.12, 0.45, pm.g + edge * 0.6);
	float road = smoothstep(0.5, 0.6, pm.g + (n_fine - 0.5) * 0.06);
	vec3 gravel = vec3(0.14, 0.13, 0.115) * (0.5 + 1.0 * n_micro);
	vec3 asphalt = vec3(0.017, 0.018, 0.02) * (0.6 + 0.9 * n_micro) + 0.006 * n_mid;
	col = mix(col, gravel, shoulder);
	col = mix(col, asphalt, road);

	// snow settles on ledges and gentle ground, and drifts unevenly
	float amount = smoothstep(snowline - 1.0, snowline + 4.0, wpos.y + (n_big - 0.5) * 8.0 + (r1 - 0.5) * 3.5);
	float lie = smoothstep(0.5, 0.82, wnrm.y + (r2 - 0.5) * 0.3);
	float ground_snow = snow_all * step(0.04, wpos.y) * (1.0 - road * 0.8) * (1.0 - trail * 0.55) * (1.0 - desert * 0.75);
	float snow = max(amount * (1.0 - desert), ground_snow) * lie;
	vec3 snow_col = mix(vec3(0.55, 0.64, 0.8), vec3(0.83, 0.86, 0.91), smoothstep(0.6, 0.95, wnrm.y));
	snow_col *= 0.92 + 0.12 * n_micro;
	col = mix(col, snow_col, snow);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.5, max(snow, road * 0.35));
	SPECULAR = 0.2;
	vec3 bump = mix(texture(bump_tex, wpos.xz * 0.5).rgb, texture(bump_tex, wpos.xz * 2.1).rgb, 0.45);
	NORMAL_MAP = bump;
	NORMAL_MAP_DEPTH = mix(1.1, 2.6, rocky) * (1.0 - snow * 0.65) * (1.0 - road * 0.85);
}
