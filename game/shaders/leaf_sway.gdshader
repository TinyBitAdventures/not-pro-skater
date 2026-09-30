shader_type spatial;
// Tree leaf cards (blender/trees.py): alpha-cut, two-sided, swaying in the wind. The sway grows with height
// above the tree's base and varies by position, so no two trees move together. Shadows sway with them.
// Leaves let light through (backlight), so a crown against the sun glows instead of going flat; each tree gets
// its own slight shade of green, and the cut-out edges are smoothed by alpha to coverage (MSAA).
render_mode cull_disabled, alpha_to_coverage;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_scissor = 0.45;
uniform float sway = 0.07;
uniform float speed = 1.2;
uniform float translucency = 0.32;

varying vec3 tree_tint;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float amt = sway * smoothstep(1.2, 6.0, VERTEX.y);
	float t = TIME * speed;
	VERTEX.x += (sin(t + w.x * 0.35 + w.z * 0.21) + 0.4 * sin(t * 2.3 + w.y)) * amt;
	VERTEX.z += cos(t * 0.8 + w.z * 0.3 + w.x * 0.1) * amt * 0.7;
	VERTEX.y += sin(t * 1.7 + w.x + w.z) * amt * 0.25;
	// a per-tree tint from where the tree stands (cards of one tree share it: coarse cells)
	vec2 cell = floor(w.xz / 9.0);
	float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	tree_tint = mix(vec3(0.86, 0.94, 0.8), vec3(1.0, 0.97, 0.78), h);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	ALBEDO = a.rgb * tree_tint;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ALPHA_ANTIALIASING_EDGE = 0.25;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_tex, 0));
	ROUGHNESS = 0.75;
	SPECULAR = 0.35;
	BACKLIGHT = a.rgb * tree_tint * translucency;
}
