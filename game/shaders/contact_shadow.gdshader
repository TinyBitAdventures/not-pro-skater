shader_type spatial;
// Soft ambient occlusion under the board (SkaterFx): an elliptical falloff drawn from the quad's UVs, dark out to
// about the wheels and fading to nothing at the quad's edge (a centre-weighted falloff hid under the deck).
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform float strength = 0.5;

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.3, 1.0, d)) * strength;
}
