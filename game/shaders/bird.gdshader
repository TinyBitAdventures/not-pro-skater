shader_type spatial;
// Distant birds (Birds): flat dark silhouettes; the wings rotate about the body by INSTANCE_CUSTOM.r.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 color = vec3(0.09, 0.09, 0.1);

void vertex() {
	float side = UV.x;
	if (abs(side) > 0.5) {
		float ang = INSTANCE_CUSTOM.r * side;
		float x = VERTEX.x;
		VERTEX.x = x * cos(ang);
		VERTEX.y = abs(x) * sin(INSTANCE_CUSTOM.r);
	}
}

void fragment() {
	ALBEDO = color;
}
