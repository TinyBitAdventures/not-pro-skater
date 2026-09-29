class_name IsoCamera
extends Camera3D
## Orthographic isometric follow camera. Yaw snaps in 90 degree steps (Q / E); pitch is true isometric.

const TRUE_ISO_PITCH: float = 35.264

var pitch_deg: float = TRUE_ISO_PITCH
var yaw_target: float = deg_to_rad(45.0)
var yaw: float = deg_to_rad(45.0)
var target: Node3D = null
var focus: Vector3 = Vector3.ZERO
var look_ahead: Vector3 = Vector3.ZERO
var ortho_size: float = 22.0
var distance: float = 90.0
var outline_px: float = 2.2
var follow_speed: float = 5.0
var follow_heading: bool = false     # swing around so the skater rides "up" the screen
var yaw_offset: float = 0.0          # extra turn from Q / E while following

const FOLLOW_DEAD: float = 0.38      # radians of heading error before the camera starts to swing
const FOLLOW_GAIN: float = 2.0
const FOLLOW_MAX: float = 1.7

## The sun; its shadow range follows the camera's depth slab (see _apply).
var shadow_light: DirectionalLight3D = null


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	current = true
	_apply()


func snap_yaw(dir: int) -> void:
	if follow_heading:
		yaw_offset += dir * PI * 0.5
	else:
		yaw_target += dir * PI * 0.5


func face_heading(sk: Skater) -> void:
	var h: Vector3 = Vector3(sk.hdg.x, 0.0, sk.hdg.z)
	if h.length() > 0.1:
		yaw = atan2(-h.x, -h.z) + yaw_offset
		yaw_target = yaw


func jump_to(p: Vector3) -> void:
	focus = p
	_apply()


func _follow(dt: float) -> void:
	var sk: Skater = target as Skater
	if sk == null or sk.state == Skater.State.AIR or sk.state == Skater.State.BAIL:
		return
	var h: Vector3 = Vector3(sk.hdg.x, 0.0, sk.hdg.z)
	if h.length() < 0.35 or sk.velocity.length() < 1.5:
		return
	var want: float = atan2(-h.x, -h.z) + yaw_offset
	var err: float = angle_difference(yaw, want)
	var excess: float = maxf(0.0, absf(err) - FOLLOW_DEAD) * signf(err)
	yaw += clampf(excess * FOLLOW_GAIN, -FOLLOW_MAX, FOLLOW_MAX) * dt
	yaw_target = yaw


func _process(delta: float) -> void:
	if follow_heading:
		_follow(delta)
	else:
		yaw = lerp_angle(yaw, yaw_target, 1.0 - exp(-9.0 * delta))
	if target != null:
		var want: Vector3 = target.global_position + look_ahead
		if target is Skater:
			want.y = (target as Skater).cam_y
		focus = focus.lerp(want, 1.0 - exp(-follow_speed * delta))
	_apply()


func _apply() -> void:
	size = ortho_size
	# Orthographic and pitched 35 degrees: only a slab around the focus can be on screen. Keeping near/far and
	# the sun's shadow range tight makes the 4096 shadow map cover ~1/3 of the metres (about 2x sharper).
	var half_depth: float = ortho_size * 0.8 + 12.0
	if not is_equal_approx(far, distance + half_depth):
		near = maxf(0.5, distance - half_depth)
		far = distance + half_depth
		if shadow_light != null:
			shadow_light.directional_shadow_max_distance = far
	var b: Basis = Basis.from_euler(Vector3(-deg_to_rad(pitch_deg), yaw, 0.0))
	global_transform = Transform3D(b, focus + b.z * distance)
	var fwd: Vector3 = -b.z
	Toon.set_view_dir(fwd)
	Toon.set_focus_pos(focus)
	Toon.set_haze_depth(ortho_size * 0.5 / sin(deg_to_rad(pitch_deg)))
	var vp_h: float = float(get_window().size.y) if is_inside_tree() else 900.0
	Toon.set_outline_width(outline_px * ortho_size / maxf(vp_h, 200.0))
