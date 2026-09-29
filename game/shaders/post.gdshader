shader_type canvas_item;

// Screen grade drawn over the 3D view (under the HUD): a touch more saturation and contrast,
// a warm tint and a soft vignette. Cheap, and it makes the flat colours feel lit rather than printed.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float saturation = 1.12;
uniform float contrast = 1.06;
uniform float vignette = 0.30;
uniform vec3 tint : source_color = vec3(1.0, 0.985, 0.95);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	vec2 uv = SCREEN_UV - 0.5;
	float v = smoothstep(0.32, 0.92, length(uv * vec2(1.0, 0.9)));
	c *= 1.0 - vignette * v;
	COLOR = vec4(c, 1.0);
}
