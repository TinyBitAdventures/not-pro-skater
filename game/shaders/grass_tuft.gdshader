shader_type spatial;
// Grass clumps scattered over the lawns (GrassField): crossed cards with blades drawn in a small texture.
// Their normals point up, so they light like the ground they grow from instead of as flat cards. The tips sway
// in the wind; past `fade_start` a clump shrinks into the ground so the edge of the grass never pops.
render_mode cull_disabled;

uniform sampler2D blades : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint = vec3(1.25, 1.2, 1.1);
uniform float fade_start = 32.0;
uniform float fade_end = 44.0;
uniform float sway = 0.035;

varying float shade;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float up = clamp(VERTEX.y / 0.2, 0.0, 1.0);           // 0 at the root, 1 at the tips
	float t = TIME * 1.6;
	float gust = 0.6 + 0.4 * sin(TIME * 0.35 + w.x * 0.05 + w.z * 0.04);
	VERTEX.x += (sin(t + w.x * 0.9 + w.z * 0.4) + 0.35 * sin(t * 2.7 + w.z * 1.3)) * sway * up * up * gust;
	VERTEX.z += cos(t * 0.8 + w.z * 0.7 + w.x * 0.2) * sway * 0.7 * up * up * gust;
	float d = length(CAMERA_POSITION_WORLD - w);
	VERTEX.y *= 1.0 - smoothstep(fade_start, fade_end, d);
	// a little brightness variation clump to clump
	shade = 0.85 + 0.3 * fract(sin(dot(floor(w.xz * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	vec4 b = texture(blades, UV);
	ALBEDO = b.rgb * tint * shade * mix(0.7, 1.0, 1.0 - UV.y);     // a little darker toward the roots
	ALPHA = b.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
