shader_type canvas_item;
// A soft darkening toward the corners of the screen (drawn over the 3D view, under the HUD).
uniform float strength = 0.28;
uniform float start = 0.45;

void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * vec2(1.0, 0.82);
	float d = length(p) * 1.414;
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(start, 1.05, d) * strength);
}
