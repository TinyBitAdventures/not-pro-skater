shader_type spatial;
// Tree leaf cards (blender/trees.py): alpha-cut, two-sided, swaying in the wind. The sway grows with height
// above the tree's base and varies by position, so no two trees move together. Shadows sway with them.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_scissor = 0.45;
uniform float sway = 0.07;
uniform float speed = 1.2;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float amt = sway * smoothstep(1.2, 6.0, VERTEX.y);
	float t = TIME * speed;
	VERTEX.x += (sin(t + w.x * 0.35 + w.z * 0.21) + 0.4 * sin(t * 2.3 + w.y)) * amt;
	VERTEX.z += cos(t * 0.8 + w.z * 0.3 + w.x * 0.1) * amt * 0.7;
	VERTEX.y += sin(t * 1.7 + w.x + w.z) * amt * 0.25;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	ALBEDO = a.rgb;
	ALPHA = a.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = 0.75;
}
