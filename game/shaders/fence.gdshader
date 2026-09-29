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

// Anti-aliased wire coverage: `x` is |fract(u) - 0.5| (0.5 on the wire centre), `px` the pixel footprint in
// the same units. Wires thinner than a pixel fade out instead of shimmering.
float wire_cov(float x, float px) {
	float hw = max(wire, 0.5 * px);
	float cov = clamp((x - (0.5 - hw)) / px + 0.5, 0.0, 1.0);
	return cov * clamp(wire / hw, 0.0, 1.0);
}

void fragment() {
	float along = wpos.x + wpos.z;
	float u = (along + wpos.y) / cell;
	float v = (along - wpos.y) / cell;
	float w = max(wire_cov(abs(fract(u) - 0.5), fwidth(u)), wire_cov(abs(fract(v) - 0.5), fwidth(v)));
	ALBEDO = albedo.rgb;
	ALPHA = w * 0.9;
}
