shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float alpha : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.05, 0.07, 0.16);
	ALPHA = alpha * (1.0 - smoothstep(0.3, 1.0, d));
}
