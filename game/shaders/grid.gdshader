shader_type spatial;
// Greybox surface: a flat tone with a world-space triplanar grid (thin lines every 1 m, thick every 5 m),
// so speed, height and distance read at a glance. Works in the Compatibility renderer.

uniform vec3 base_color : source_color = vec3(0.62);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float line_1m : hint_range(0.0, 1.0) = 0.16;
uniform float line_5m : hint_range(0.0, 1.0) = 0.3;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid(vec2 p, float width) {
	vec2 d = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(1e-4));
	return 1.0 - clamp(min(d.x, d.y) / width, 0.0, 1.0);
}

float tri(vec3 p, vec3 w, float width) {
	return grid(p.zy, width) * w.x + grid(p.xz, width) * w.y + grid(p.xy, width) * w.z;
}

void fragment() {
	vec3 n = abs(wnrm);
	vec3 w = n / max(n.x + n.y + n.z, 1e-4);
	float g1 = tri(wpos, w, 1.0);
	float g5 = tri(wpos / 5.0, w, 1.6);
	ALBEDO = base_color * (1.0 - line_1m * g1 - line_5m * g5);
	ROUGHNESS = roughness;
}
