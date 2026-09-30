shader_type spatial;
// Static level surfaces with baked light (blender/realism.py). The live sun adds direct light and shadows;
// the lightmap (second UV set) supplies everything else: sky light, bounce light and soft occlusion.
// Ambient light is disabled here so the sky is not counted twice. Works in the Compatibility renderer.
//
// Two touches that stop big surfaces looking like one repeated tile: large-scale variation from a world-space
// noise (patchy grass, stained concrete), and saw-cut expansion joints on flat concrete (a grid inside the
// plaza, cross cuts along sidewalks), laid out by the level's <level>.look.json.
render_mode ambient_light_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float rough_min : hint_range(0.0, 1.0) = 0.0;   // grass and rough ground never shine like a wet road
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform float normal_scale = 1.0;
uniform sampler2D lightmap : hint_default_black, filter_linear_mipmap;
uniform float lm_range = 2.0;       // the PNG stores sqrt(light / lm_range)
uniform float bake_energy = 1.0;
// Walls get extra baked light. The bake only contains the park, so a wall in shade misses the bounce a real
// street gives it (the houses opposite, the rest of the neighbourhood) and came out near black next to sunlit
// ground; this lifts vertical faces only, leaving the ground's shade and contact shadows as baked.
uniform float wall_fill = 1.0;
// a level of tall blocks (downtown) shades whole streets from the sky the bake sees: a floor under the baked light
// keeps a canyon floor from going black (0 = off)
uniform float shade_floor = 0.0;

uniform sampler2D macro_tex : hint_default_white, filter_linear_mipmap, repeat_enable;   // seamless noise
uniform float macro_amount = 0.0;          // +- brightness from the large-scale noise
uniform vec3 macro_tint = vec3(1.0);       // what the patches drift toward (grass: dry and yellow)
uniform float macro_tint_amount = 0.0;
uniform vec2 joint_grid = vec2(0.0);       // saw cuts every (x, z) metres inside joint_rect; 0 = none
uniform vec4 joint_rect = vec4(0.0);       // min x, min z, max x, max z
uniform float joint_along_x = 0.0;         // elsewhere on flat ground: cross cuts every this many metres along x
uniform float joint_width = 0.006;
// Plywood ramps: 4 x 8 ft sheets with a screw every foot along each edge, and wheel wear streaking down the
// ride direction. UV runs across the ramp (u) and along its profile (v) in texture tiles of `uv_tile` metres.
uniform float uv_tile = 0.0;               // 0 = not plywood
uniform vec2 sheet = vec2(1.22, 2.44);
uniform float wear = 0.0;
// Skated concrete: wheel marks and rubber scuffs, long thin dark streaks in a few directions, heavier in
// patches (where the lines are), fading out in the distance.
uniform float scuff = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// distance (metres) from coord to the nearest multiple of spacing
float to_grid(float coord, float spacing) {
	return abs(fract(coord / spacing + 0.5) - 0.5) * spacing;
}


// 1 on a line every `spacing` metres, antialiased by the screen-space footprint
float cut(float coord, float spacing) {
	float d = abs(fract(coord / spacing + 0.5) - 0.5) * spacing;
	float aa = fwidth(coord);
	return (1.0 - smoothstep(joint_width, joint_width + aa, d)) * clamp(0.04 / max(aa, 0.0001), 0.0, 1.0);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo;
	vec3 col = a.rgb;
	if (macro_amount > 0.0) {
		float n1 = texture(macro_tex, wpos.xz * 0.043).r;
		float n2 = texture(macro_tex, wpos.xz * 0.011 + vec2(0.37, 0.71)).r;
		float n = n1 * 0.6 + n2 * 0.4;
		col *= 1.0 + (n - 0.5) * 2.0 * macro_amount;
		col = mix(col, col * macro_tint, clamp((n2 - 0.45) * 2.2, 0.0, 1.0) * macro_tint_amount);
	}
	float joint = 0.0;
	if (wnorm.y > 0.9) {
		bool in_rect = wpos.x > joint_rect.x && wpos.x < joint_rect.z && wpos.z > joint_rect.y && wpos.z < joint_rect.w;
		if (joint_grid.x > 0.0 && in_rect) {
			joint = max(cut(wpos.x, joint_grid.x), cut(wpos.z, joint_grid.y));
		} else if (joint_along_x > 0.0 && abs(wpos.y) < 0.05) {
			joint = cut(wpos.x, joint_along_x);
		}
	}
	col *= 1.0 - joint * 0.6;
	if (scuff > 0.0 && wnorm.y > 0.9) {
		vec2 p = wpos.xz;
		float patchy = smoothstep(0.35, 0.75, texture(macro_tex, p * 0.018 + vec2(0.61, 0.13)).r);
		float marks = 0.0;
		for (int i = 0; i < 3; i++) {
			float a = float(i) * 1.1 + 0.4;
			vec2 d = vec2(cos(a), sin(a));
			vec2 q = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
			float streak = texture(macro_tex, vec2(q.x * 0.02, q.y * 0.9) + float(i) * 0.37).r;
			marks = max(marks, smoothstep(0.62, 0.8, streak));
		}
		float fadeaway = clamp(0.05 / max(fwidth(p.x), 0.0005), 0.0, 1.0);
		col *= 1.0 - scuff * marks * patchy * fadeaway;
	}
	if (uv_tile > 0.0) {
		vec2 m = UV * uv_tile;                       // metres across / along the sheet
		vec2 fw = fwidth(m) + 0.0005;
		float du = to_grid(m.x, sheet.x);
		float dv = to_grid(m.y, sheet.y);
		float fade = clamp(0.02 / max(fw.x, fw.y), 0.0, 1.0);   // seams and screws melt away in the distance
		float seam = max(1.0 - smoothstep(0.0025, 0.0025 + fw.x, du), 1.0 - smoothstep(0.0025, 0.0025 + fw.y, dv));
		// screws 4 cm in from each edge, one every 30 cm
		float r = 0.0055;
		float along_u = 1.0 - smoothstep(r, r + fw.y, to_grid(m.y + 0.15, 0.305));
		float along_v = 1.0 - smoothstep(r, r + fw.x, to_grid(m.x + 0.15, 0.305));
		float s1 = (1.0 - smoothstep(r, r + fw.x, abs(du - 0.04))) * along_u;
		float s2 = (1.0 - smoothstep(r, r + fw.y, abs(dv - 0.04))) * along_v;
		float screws = max(s1, s2) * fade;
		// wheels: faint dark streaks down the profile, heavier toward the middle of the ramp's width
		float streak = texture(macro_tex, vec2(m.x * 1.7, m.y * 0.06)).r;
		col *= 1.0 - wear * smoothstep(0.45, 0.8, streak);
		col *= 1.0 - seam * 0.3 * fade - screws * 0.28;
	}
	ALBEDO = col;
	vec4 orm = texture(orm_tex, UV);
	ROUGHNESS = max(mix(orm.g * roughness, 1.0, joint), rough_min);
	METALLIC = orm.b * metallic;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	vec3 lm = texture(lightmap, UV2).rgb;
	float vertical = clamp(1.0 - abs(wnorm.y), 0.0, 1.0);
	float fill = mix(1.0, wall_fill, vertical);
	// a face smaller than a lightmap texel (a curb's 12 cm) samples the black around its island: never let
	// a vertical face fall below a little sky light
	vec3 baked = max(lm * lm * lm_range * fill, vec3(max(0.2 * vertical, shade_floor)));
	EMISSION = col * baked * bake_energy;
}
