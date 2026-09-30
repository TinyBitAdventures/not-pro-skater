class_name ChaseCamera
extends Camera3D
## Third-person perspective camera behind the skater.
##
## - Swings behind the direction of TRAVEL (not the board), so air spins never spin the view.
## - In the air it holds its heading and only half follows the jump height, so the arc reads as height.
## - Vert air: it moves out in front of the wall at about coping height and frames the lip low in the shot with
##   the skater rising above it; after the landing it swings round behind again.
## - Looks a little ahead along the velocity; the field of view opens up with speed and kicks on a pop.
## - A ray from the skater pulls it in front of any wall behind.

const WORLD_MASK: int = 1

var target: Skater = null
var distance: float = 4.4
var height: float = 1.65
var look_height: float = 1.05
var fov_base: float = 68.0
var fov_fast: float = 80.0
var yaw_rate: float = 4.5          # how quickly it swings behind the travel direction (1/s)
var follow_rate: float = 10.0      # how tightly the position follows (1/s)
var shake: float = 0.0

var _yaw: float = 0.0
var _pos: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0
var _fov_kick: float = 0.0
var _vert_hold: bool = false
var _vert_anchor: Vector3 = Vector3.ZERO
var _vert_lip: Vector3 = Vector3.ZERO
var vert_back: float = 4.8         # how far out from the wall the vert shot sits
var vert_rise: float = 0.2         # and how far above the lip
var vert_side: float = 2.8         # and how far to the side along the coping
var min_distance: float = 1.7      # closer than this to the rider (a wall behind), rise over instead
var _swing_boost: float = 0.0      # extra swing speed just after a vert landing
var _was_state: int = -1


func _ready() -> void:
	current = true
	fov = fov_base
	near = 0.05
	far = 600.0


func attach(sk: Skater) -> void:
	target = sk
	sk.sfx.connect(func(kind: String) -> void:
		if kind == "ollie":
			_fov_kick = 5.0)
	sk.landed.connect(func(air: float) -> void:
		if air > 1.0:
			shake = maxf(shake, clampf((air - 1.0) * 0.35, 0.0, 0.3)))
	snap_behind()


## Jump straight to the resting spot behind the skater (after a warp or respawn).
func snap_behind() -> void:
	if target == null:
		return
	var d: Vector3 = _travel_dir()
	_yaw = atan2(-d.x, -d.z)
	_ground_y = target.global_position.y
	_vert_hold = false
	var r: Dictionary = _desired()
	_pos = r["pos"]
	_look = r["look"]
	_apply()


func _travel_dir() -> Vector3:
	var v: Vector3 = target.velocity
	v.y = 0.0
	if v.length() > 2.0:
		return v.normalized()
	var h: Vector3 = Vector3(target.hdg.x, 0.0, target.hdg.z)
	return h.normalized() if h.length() > 0.1 else Vector3(0, 0, -1)


func _desired() -> Dictionary:
	var sk: Skater = target
	var focus: Vector3 = sk.rider_position()      # in a bail: the rider, not the board rolling away
	if sk.state == Skater.State.AIR:
		focus.y = lerpf(_ground_y, focus.y, 0.55)
	var v_h: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z)
	var ahead: Vector3 = (v_h * 0.22).limit_length(2.6)
	var back: Vector3 = Vector3(sin(_yaw), 0.0, cos(_yaw))
	var look: Vector3 = focus + Vector3.UP * look_height + ahead
	var pos: Vector3 = focus + back * distance + Vector3.UP * height
	if sk.vert_air and _vert_hold:
		pos = _vert_anchor
		look = _vert_lip.lerp(sk.global_position + Vector3.UP * 0.8, 0.5)
		return {"pos": _collide(look, pos), "look": look}
	return {"pos": _clear_of_rider(focus, look, _collide(look, pos)), "look": look}


## A wall close behind pulls the camera in; closer than min_distance it would end up inside the rider.
## Instead it rises up and over (looking down past the head), and never sits within the body.
func _clear_of_rider(focus: Vector3, look: Vector3, pos: Vector3) -> Vector3:
	var d: float = pos.distance_to(look)
	if d < min_distance:
		var back: Vector3 = Vector3(pos.x - look.x, 0.0, pos.z - look.z)
		back = back.normalized() if back.length() > 0.01 else Vector3(sin(_yaw), 0.0, cos(_yaw))
		var over: Vector3 = look + back * maxf(d, 0.35) + Vector3.UP * (min_distance - d + 0.6)
		pos = _collide(look, over)
	var axis: Vector3 = Vector3(pos.x - focus.x, 0.0, pos.z - focus.z)
	if axis.length() < 0.55 and pos.y < focus.y + 2.1:
		pos = _collide(look, Vector3(pos.x, focus.y + 2.3, pos.z))
	return pos


## Keep a clear line from the skater to the camera: if a wall is in the way, sit just in front of it.
func _collide(from: Vector3, to: Vector3) -> Vector3:
	if not is_inside_tree():
		return to
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	var p: Vector3 = hit["position"]
	return p + (from - p).normalized() * 0.25


func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var sk: Skater = target
	var st: int = sk.state
	if _was_state == Skater.State.AIR and st != Skater.State.AIR and _vert_hold:
		_swing_boost = 1.0
	_was_state = st
	_swing_boost = maxf(0.0, _swing_boost - dt * 1.2)

	var rate: float = yaw_rate * (1.0 + _swing_boost * 1.5)
	if st == Skater.State.GROUND or st == Skater.State.GRIND:
		var d: Vector3 = _travel_dir()
		_yaw = lerp_angle(_yaw, atan2(-d.x, -d.z), 1.0 - exp(-rate * dt))
		_ground_y = lerpf(_ground_y, sk.global_position.y, 1.0 - exp(-10.0 * dt))
	elif st == Skater.State.AIR and not sk.vert_air:
		var v_h: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z)
		if v_h.length() > 3.0:
			_yaw = lerp_angle(_yaw, atan2(-v_h.x, -v_h.z), 1.0 - exp(-1.5 * dt))
	elif st == Skater.State.BAIL:
		_ground_y = lerpf(_ground_y, sk.global_position.y, 1.0 - exp(-4.0 * dt))

	if sk.vert_air and not _vert_hold:
		_vert_hold = true
		_vert_lip = sk.global_position
		# off to one side of the ramp, so the rider (side-on to the wall) is seen full length as it turns
		var along: Vector3 = sk.vert_out.cross(Vector3.UP).normalized()
		var side: float = 1.0 if sk.velocity.dot(along) >= 0.0 else -1.0
		_vert_anchor = _collide(_vert_lip + Vector3.UP * 0.5,
			_vert_lip + sk.vert_out * vert_back + along * side * vert_side + Vector3.UP * vert_rise)
	elif not sk.vert_air:
		_vert_hold = false

	var r: Dictionary = _desired()
	_pos = _pos.lerp(r["pos"], 1.0 - exp(-follow_rate * dt))
	_look = _look.lerp(r["look"], 1.0 - exp(-14.0 * dt))
	var spd: float = sk.velocity.length()
	_fov_kick = move_toward(_fov_kick, 0.0, dt * 12.0)
	var want_fov: float = fov_base + (fov_fast - fov_base) * clampf((spd - 6.0) / 12.0, 0.0, 1.0) + _fov_kick
	fov = lerpf(fov, want_fov, 1.0 - exp(-5.0 * dt))
	shake = maxf(0.0, shake - dt * 1.5)
	_apply()


func _apply() -> void:
	var dir: Vector3 = _look - _pos
	if dir.length() < 0.01:
		return
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(dir, up), _pos)
	if shake > 0.0:
		h_offset = randf_range(-1.0, 1.0) * shake
		v_offset = randf_range(-1.0, 1.0) * shake
	else:
		h_offset = 0.0
		v_offset = 0.0
