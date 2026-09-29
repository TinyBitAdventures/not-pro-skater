shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

// See-through chain-link: diamond wires in world space. Every fence in the park runs along X or Z,
// so (x + z) is the distance along the fence either way.
uniform vec4 albedo : source_color = vec4(0.78, 0.82, 0.88, 1.0);
uniform float cell = 0.2;
uniform float wire = 0.07;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = wpos.x + wpos.z;
	float u = (along + wpos.y) / cell;
	float v = (along - wpos.y) / cell;
	float du = abs(fract(u) - 0.5);
	float dv = abs(fract(v) - 0.5);
	float w = max(smoothstep(0.5 - wire, 0.5, du), smoothstep(0.5 - wire, 0.5, dv));
	ALBEDO = albedo.rgb;
	ALPHA = w * 0.9;
}
