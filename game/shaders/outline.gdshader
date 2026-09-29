shader_type spatial;
render_mode unshaded, cull_front;

#include "res://shaders/occlude.gdshaderinc"

// Inverted-hull outline. Hard-edged low-poly meshes tear if you push along their face normals, so
// Toon bakes smoothed normals into COLOR and we push along those instead.
uniform vec4 line_color : source_color = vec4(0.09, 0.11, 0.19, 1.0);
uniform float width = 0.05;
uniform float fade_enabled = 1.0;
uniform float haze_amount = 1.0;
uniform vec4 haze_color : source_color = vec4(0.56, 0.83, 1.0, 1.0);

varying vec3 wpos;

void vertex() {
	vec3 n = COLOR.rgb * 2.0 - 1.0;
	if (dot(n, n) < 0.01) {
		n = NORMAL;
	}
	VERTEX += normalize(n) * width;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (fade_enabled > 0.5 && occluded(wpos, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = mix(line_color.rgb, haze_color.rgb, haze_factor(wpos) * haze_amount * 0.9);
}
