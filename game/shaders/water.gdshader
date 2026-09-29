shader_type spatial;
render_mode unshaded;

#include "res://shaders/occlude.gdshaderinc"

// Toon water: banded colour, drifting light ripple lines and a few glints. Unshaded on purpose:
// flat, readable and cheap. Far water melts into the haze like everything else.
uniform vec4 albedo : source_color = vec4(0.31, 0.76, 0.97, 1.0);
uniform vec4 haze_color : source_color = vec4(0.56, 0.83, 1.0, 1.0);

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float w = sin(p.x * 1.1 + TIME * 0.8) + sin(p.y * 1.5 - TIME * 1.0) + sin((p.x + p.y) * 0.7 + TIME * 0.5);
	float ripple = smoothstep(1.5, 1.72, w);
	float deep = 0.5 + 0.5 * sin(p.x * 0.35 + p.y * 0.25 + TIME * 0.2);
	vec3 c = mix(albedo.rgb * 0.8, albedo.rgb, deep);
	c = mix(c, vec3(1.0), ripple * 0.5);
	float glint = step(0.987, hash21(floor(p * 5.0) + floor(TIME * 2.0)));
	c += glint * 0.55;
	ALBEDO = mix(c, haze_color.rgb, haze_factor(wpos) * 0.92);
}
