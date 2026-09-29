// Dithered see-through hole around the skater for anything standing between the camera and them.
// The camera is orthographic, so "in front of the skater" is just a dot product with the view direction.
global uniform vec3 player_pos;
global uniform vec3 view_dir;
global uniform vec3 focus_pos;   // camera focus: distance haze is measured from here

// Atmospheric haze: far scenery (houses, hills, the ground plane's edge) melts into the sky colour.
const float HAZE_START = 42.0;
const float HAZE_END = 120.0;

float haze_factor(vec3 wp) {
	return smoothstep(HAZE_START, HAZE_END, length(wp.xz - focus_pos.xz));
}

const float HOLE_R0 = 1.0;
const float HOLE_R1 = 1.7;

bool occluded(vec3 wpos, vec2 frag) {
	vec3 chest = player_pos + vec3(0.0, 0.9, 0.0);
	vec3 u = wpos - chest;
	float along = dot(u, view_dir);
	float dist = length(u - view_dir * along);
	float in_front = 1.0 - smoothstep(-1.6, -0.4, along);
	float tall = smoothstep(player_pos.y + 0.25, player_pos.y + 0.6, wpos.y);
	float hole = (1.0 - smoothstep(HOLE_R0, HOLE_R1, dist)) * in_front * tall;
	float noise = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
	return hole > noise;
}
