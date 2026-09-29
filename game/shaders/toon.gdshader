shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/occlude.gdshaderinc"

// Flat-colour cel shading: three bands (shadow / mid / lit), no specular, optional world-space
// grid lines and patchy noise so big flat surfaces still read as grass, concrete or asphalt.
uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform float fade_enabled = 1.0;
uniform float emission = 0.0;
uniform float noise_scale = 0.0;
uniform float noise_amount = 0.06;
uniform float grid_scale = 0.0;
uniform float grid_width = 0.05;
uniform float grid_amount = 0.12;
uniform float band_mid = 0.5;
uniform float band_lit = 1.0;

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
	if (fade_enabled > 0.5 && occluded(wpos, FRAGCOORD.xy)) {
		discard;
	}
	vec3 c = albedo.rgb;
	if (noise_scale > 0.0) {
		float n = hash21(floor(wpos.xz * noise_scale));
		c *= 1.0 + (n - 0.5) * 2.0 * noise_amount;
	}
	if (grid_scale > 0.0) {
		vec2 g = abs(fract(wpos.xz / grid_scale + 0.5) - 0.5) * grid_scale;
		float line = 1.0 - smoothstep(grid_width * 0.5, grid_width * 0.5 + 0.03, min(g.x, g.y));
		c *= 1.0 - line * grid_amount;
	}
	ALBEDO = c;
	EMISSION = albedo.rgb * emission;
	ROUGHNESS = 1.0;
}

void light() {
	float nl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(0.02, 0.07, nl) * band_mid + smoothstep(0.42, 0.48, nl) * (band_lit - band_mid);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
}
