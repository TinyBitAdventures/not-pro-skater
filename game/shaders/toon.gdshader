shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/occlude.gdshaderinc"

// Flat-colour cel shading: three bands (shadow / mid / lit), no specular. Big flat surfaces get world-space
// grid lines and patchy noise; walls get a contact-shadow gradient near the ground; drifting cloud shadows
// and distance haze tie the whole park together; grass gets tufts and tiny flowers.
uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec4 haze_color : source_color = vec4(0.56, 0.83, 1.0, 1.0);
uniform float fade_enabled = 1.0;
uniform float emission = 0.0;
uniform float noise_scale = 0.0;
uniform float noise_amount = 0.06;
uniform float grid_scale = 0.0;
uniform float grid_width = 0.05;
uniform float grid_amount = 0.12;
uniform float band_mid = 0.5;
uniform float band_lit = 1.0;
uniform float ao_strength = 0.30;
uniform float ao_height = 0.9;
uniform float cloud_shadow = 0.13;
uniform float grass_detail = 0.0;
uniform float haze_amount = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cloud_mask(vec2 p) {
	p = p * 0.03 + vec2(TIME * 0.02, TIME * 0.008);
	float n = vnoise(p) * 0.65 + vnoise(p * 2.3 + 7.0) * 0.35;
	return smoothstep(0.5, 0.78, n);
}

vec3 grass_marks(vec3 c, vec3 wp) {
	vec2 g = wp.xz * 3.0;
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash21(cell);
	float fade = 1.0 - smoothstep(0.35, 0.7, fwidth(g.x) * 4.0);
	if (h > 0.962) {
		vec3 fc = vec3(1.0, 0.97, 0.9);
		if (h > 0.99) {
			fc = vec3(1.0, 0.9, 0.4);
		} else if (h > 0.98) {
			fc = vec3(1.0, 0.55, 0.75);
		} else if (h > 0.97) {
			fc = vec3(0.7, 0.6, 1.0);
		}
		float r = length(f);
		c = mix(c, pow(fc, vec3(2.2)), (1.0 - smoothstep(0.1, 0.17, r)) * fade);
	} else if (h > 0.78 && h < 0.9) {
		float arm = abs(abs(f.x) - (0.2 - f.y * 0.55));
		float tuft = (1.0 - smoothstep(0.0, 0.06, arm)) * step(-0.28, f.y) * step(f.y, 0.22);
		c *= 1.0 - 0.22 * tuft * fade;
	}
	return c;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	if (grass_detail > 0.0) {
		c = grass_marks(c, wpos);
	}
	// contact shadow: walls darken toward the ground
	float side = 1.0 - smoothstep(0.35, 0.75, abs(wnrm.y));
	float ao = mix(1.0 - ao_strength, 1.0, smoothstep(0.0, ao_height, wpos.y - 0.05));
	c *= mix(1.0, ao, side);
	// cloud shadows drift across everything
	c *= 1.0 - cloud_shadow * cloud_mask(wpos.xz);
	// distance haze (added as emission so it is not darkened by the light bands)
	float hz = haze_factor(wpos) * haze_amount;
	ALBEDO = c * (1.0 - hz);
	EMISSION = albedo.rgb * emission + haze_color.rgb * hz * 0.92;
	ROUGHNESS = 1.0;
}

void light() {
	float nl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(0.02, 0.07, nl) * band_mid + smoothstep(0.42, 0.48, nl) * (band_lit - band_mid);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
}
