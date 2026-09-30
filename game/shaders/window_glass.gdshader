shader_type spatial;
// House windows: a dark interior behind glass that reflects the sky. The reflection is a sky gradient looked up
// along the reflected view ray (horizon haze to zenith blue, a warm glow toward the sun) and grows toward grazing
// angles (Fresnel), so panes change as the camera moves past instead of reading as flat navy panels.
render_mode unshaded, cull_back;

uniform vec3 interior = vec3(0.035, 0.032, 0.03);
uniform vec3 zenith = vec3(0.23, 0.36, 0.6);
uniform vec3 horizon = vec3(0.72, 0.74, 0.76);
uniform vec3 ground = vec3(0.16, 0.16, 0.15);
uniform vec3 sun_dir = vec3(0.76, 0.33, 0.56);   // toward the sun (world)
uniform vec3 sun_tint = vec3(1.0, 0.8, 0.55);

varying vec3 wn;
varying vec3 wpos;

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 v = normalize(wpos - CAMERA_POSITION_WORLD);
	vec3 r = reflect(v, wn);
	vec3 sky = r.y > 0.0 ? mix(horizon, zenith, pow(r.y, 0.6)) : mix(horizon, ground, clamp(-r.y * 4.0, 0.0, 1.0));
	sky += sun_tint * pow(max(dot(r, normalize(sun_dir)), 0.0), 24.0) * 1.4;
	float fres = 0.12 + 0.88 * pow(1.0 - max(dot(-v, wn), 0.0), 4.0);
	// a faint curtain band along the top of each pane, from world height steps (panes sit at storey heights)
	float band = smoothstep(0.02, 0.0, abs(fract(wpos.y / 2.4 + 0.18) - 0.5) - 0.34) * 0.08;
	ALBEDO = mix(interior + vec3(band) * vec3(0.9, 0.85, 0.75), sky, fres);
}
