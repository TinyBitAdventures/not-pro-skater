class_name ChaseCamera
extends Camera3D
## Third-person perspective camera behind the skater.
##
## - Swings behind the direction of TRAVEL (not the board), so air spins never spin the view.
## - In the air it holds its heading and only half follows the jump height, so the arc reads as height.
## - Vert air: it moves out in front of the wall at about coping height and frames the lip low in the shot with
##   the skater rising above it; after the landing it swings round behind again.
## - Looks a little ahead along the velocity; the field of view opens up with speed and kicks on a pop.
## - Landings press it down on a spring (bigger air, deeper dip) and it settles back with a small rebound.
## - A ray from the skater pulls it in front of any wall behind.
## - A crash presses it down and shakes it as hard as the crash was, then it swings round behind the rider toward the
##   loose board so both stay in the shot, and behind the board's nose for the last steps (riding goes on with the
##   camera already behind).

const WORLD_MASK: int = 1

var target: Skater = null
var distance: float = 4.4
var height: float = 1.65
var look_height: float = 1.05
var fov_base: float = 68.0
var fov_fast: float = 80.0
var yaw_rate: float = 4.5          # how quickly it swings behind the travel direction (1/s)
var follow_rate: float = 10.0      # how tightly the position follows (1/s)
var _dip: float = 0.0              # landing spring: vertical offset (m) and its velocity
var _dip_v: float = 0.0

var _yaw: float = 0.0
var _pos: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0
var _fov_kick: float = 0.0
var _vert_hold: bool = false
var _vert_anchor: Vector3 = Vector3.ZERO
var _vert_lip: Vector3 = Vector3.ZERO
var vert_back: float = 4.8         # how far out from the wall the vert shot sits (2.9 was too tight: a flip or a
var vert_rise: float = 1.2         # grab's full shape left the frame), how far above the lip
var vert_side: float = 3.0         # and how far to the side along the coping
const VERT_FOLLOW_Y: float = 0.7   # share of the rider's height above the lip the vert shot rises with
const VERT_LOOK_RIDER: float = 0.95  # how far from the lip toward the rider the vert shot looks
const AIR_ZOOM: float = 12.0       # degrees of field of view taken off at the top of a big air
var min_distance: float = 1.7      # closer than this to the rider (a wall behind), rise over instead
var _swing_boost: float = 0.0      # extra swing speed just after a vert landing
var _shake: float = 0.0            # a crash's shake: metres now (dying away) and the clock it wobbles to
var _shake_t: float = 0.0
var _bail_k: float = 0.0           # 0..1: in a crash (the shot pulls out a little)
var _was_state: int = -1


const EYE_R: float = 0.22                  # the camera keeps this far from walls
var _eye_ball: SphereShape3D = null

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
		if air > 0.35:
			_dip_v -= clampf(air * 0.9, 0.25, 1.6))
	sk.bailed.connect(func(_r: String) -> void:
		_dip_v -= lerpf(0.4, 1.6, sk.bail_severity)
		_shake = lerpf(0.03, 0.09, sk.bail_severity) if sk.bail_kind != "runout" and Game.camera_shake else 0.0)
	snap_behind()


## Jump straight to the resting spot behind the skater (after a warp or respawn).
func snap_behind() -> void:
	if target == null:
		return
	var d: Vector3 = _travel_dir()
	_yaw = atan2(-d.x, -d.z)
	_ground_y = target.render_position().y
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
	var look: Vector3 = _collide(focus + Vector3.UP * look_height, focus + Vector3.UP * look_height + ahead)
	var pos: Vector3 = focus + back * distance * (1.0 + 0.15 * _bail_k) + Vector3.UP * height
	if _vert_hold:
		# the air is the show: the shot rises with the rider, slides along the coping with any drift, and
		# keeps the rider (not the lip) at the centre of the frame
		var rp: Vector3 = sk.render_position()
		var along: Vector3 = sk.vert_out.cross(Vector3.UP).normalized() if sk.vert_out.length() > 0.1 else Vector3.ZERO
		var drift: float = (rp - _vert_lip).dot(along)
		var above: float = maxf(0.0, rp.y - _vert_lip.y)
		pos = _vert_anchor + along * drift + Vector3.UP * above * VERT_FOLLOW_Y
		look = _vert_lip.lerp(rp + Vector3.UP * 0.8, VERT_LOOK_RIDER)
		return {"pos": _collide(look, pos), "look": look}
	# rise tests look for the rider's chest, so a lift over a ramp's deck never hides the rider behind the lip
	var chest: Vector3 = focus + Vector3.UP * 1.0
	return {"pos": _clear_of_rider(focus, look, _collide_rise(chest, pos)), "look": look}


## A yaw near `want` with a clear view of the rider from where the camera would sit (behind a rider down against a
## wall is inside the wall: the shot rose and looked straight down): `want`, then either side of it.
func _clear_yaw(focus: Vector3, want: float) -> float:
	if not is_inside_tree():
		return want
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var chest: Vector3 = focus + Vector3.UP * 1.0
	for off in [0.0, 0.8, -0.8, 1.5, -1.5]:
		var y: float = want + off
		var p: Vector3 = focus + Vector3(sin(y), 0.0, cos(y)) * distance + Vector3.UP * height
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, p, WORLD_MASK)).is_empty():
			return y
	return want


## After a vert air the shot stays out in front while the rider comes back down the wall, and lets go (to
## swing behind) once the rider is off the steep part, or doing something else.
func _vert_done(sk: Skater) -> bool:
	if sk.state != Skater.State.GROUND:
		return true
	return sk.floor_n.y > 0.8


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


## Behind the rider can be inside a ramp (rolling back down a transition, "behind" is up the slope): rather
## than pulling in to the ramp's face, right against the coping, rise until the view is clear, like a skate
## game camera floating over the deck. Only if no height up to 3 m clears it does it pull in.
func _collide_rise(from: Vector3, to: Vector3) -> Vector3:
	if not is_inside_tree():
		return to
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for lift in [0.0, 0.8, 1.6, 2.4, 3.2]:
		var p: Vector3 = to + Vector3.UP * lift
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(from, p, WORLD_MASK)).is_empty():
			return p
	return _collide(from, to)


## Keep a clear line from the skater to the camera: if a wall is in the way, sit just in front of it. A sphere
## is swept rather than a ray: a ray running along a wall let the eye graze it, and the near plane cut the wall.
func _collide(from: Vector3, to: Vector3) -> Vector3:
	if not is_inside_tree():
		return to
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if _eye_ball == null:
		_eye_ball = SphereShape3D.new()
		_eye_ball.radius = EYE_R
	var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	sq.shape = _eye_ball
	sq.transform = Transform3D(Basis.IDENTITY, from)
	sq.motion = to - from
	sq.collision_mask = WORLD_MASK
	var frac: PackedFloat32Array = space.cast_motion(sq)
	if frac.size() == 2 and frac[0] > 0.05:
		return from + (to - from) * frac[0]
	# wedged from the start (a wall right at the rider): a ray, its hit pushed off the surface it met
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return to
	var p: Vector3 = hit["position"]
	return p + (hit["normal"] as Vector3) * EYE_R + (from - p).normalized() * 0.1


func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var sk: Skater = target
	var st: int = sk.state
	_was_state = st
	_swing_boost = maxf(0.0, _swing_boost - dt * 1.2)

	var rate: float = yaw_rate * (1.0 + _swing_boost * 1.5)
	if st == Skater.State.GROUND or st == Skater.State.GRIND:
		var d: Vector3 = _travel_dir()
		_yaw = lerp_angle(_yaw, atan2(-d.x, -d.z), 1.0 - exp(-rate * dt))
		_ground_y = lerpf(_ground_y, sk.render_position().y, 1.0 - exp(-10.0 * dt))
	elif st == Skater.State.AIR and not sk.vert_air:
		var v_h: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z)
		if v_h.length() > 3.0:
			_yaw = lerp_angle(_yaw, atan2(-v_h.x, -v_h.z), 1.0 - exp(-1.5 * dt))
	elif st == Skater.State.BAIL:
		_ground_y = lerpf(_ground_y, sk.render_position().y, 1.0 - exp(-4.0 * dt))
		# behind the rider looking toward the loose board (both in the shot, not the rider walking at the lens with
		# the board behind it); for the last steps, behind the board's nose
		var rg: RiderRig = sk.visual
		if rg != null and rg.loose != null and is_instance_valid(rg.loose):
			var to_board: Vector3 = rg.loose.global_position - sk.rider_position()
			to_board.y = 0.0
			var on_foot: bool = rg.phys_phase == "walk" or rg.phys_phase == "getup"
			var want: float = _yaw
			if on_foot and to_board.length() < 1.6:
				var f: Vector3 = -rg.loose.stand_transform().basis.z
				want = atan2(-f.x, -f.z)
			elif to_board.length() > 1.0:
				want = atan2(-to_board.x, -to_board.z)
			want = _clear_yaw(sk.rider_position(), want)
			_yaw = lerp_angle(_yaw, want, 1.0 - exp(-(1.8 if on_foot else 0.8) * dt))
	_bail_k = move_toward(_bail_k, 1.0 if st == Skater.State.BAIL else 0.0, dt * 1.5)

	if sk.vert_air and not _vert_hold:
		_vert_hold = true
		_vert_lip = sk.render_position()
		# off to one side of the ramp, so the rider (side-on to the wall) is seen full length as it turns
		var along: Vector3 = sk.vert_out.cross(Vector3.UP).normalized()
		var side: float = 1.0 if sk.velocity.dot(along) >= 0.0 else -1.0
		_vert_anchor = _collide(_vert_lip + Vector3.UP * 0.5,
			_vert_lip + sk.vert_out * vert_back + along * side * vert_side + Vector3.UP * vert_rise)
	elif _vert_hold and not sk.vert_air and _vert_done(sk):
		_vert_hold = false
		_swing_boost = 1.0                     # now swing round behind, quickly

	var r: Dictionary = _desired()
	_pos = _pos.lerp(r["pos"], 1.0 - exp(-follow_rate * dt))
	# a big swing (after a vert landing) would slide straight through the rider: keep it out on a radius
	var f: Vector3 = sk.rider_position() + Vector3.UP * look_height
	var off: Vector3 = _pos - f
	var min_r: float = maxf(min_distance, distance * 0.7)
	if off.length() < min_r and off.length() > 0.01:
		_pos = f + off.normalized() * min_r
	# the smoothed position must not pass through walls either: tested from the rider's chest, not the look-ahead
	# point (with speed, that point is round a corner, and from there the eye dropped into the floor behind it)
	_pos = _collide(sk.rider_position() + Vector3.UP * 1.0, _pos)
	_look = _look.lerp(r["look"], 1.0 - exp(-14.0 * dt))
	var spd: float = sk.velocity.length()
	_fov_kick = move_toward(_fov_kick, 0.0, dt * 12.0)
	var want_fov: float = fov_base + (fov_fast - fov_base) * clampf((spd - 6.0) / 12.0, 0.0, 1.0) + _fov_kick
	# push in on the rider through a big air (vert above the lip, or high off a kicker): the trick fills the frame
	if st == Skater.State.AIR:
		var into: float = clampf(sk.air_time / 0.3, 0.0, 1.0)
		if not _vert_hold:                                      # (the vert shot is framed wide: no push-in there)
			var high: float = sk.render_position().y - _ground_y
			want_fov -= AIR_ZOOM * clampf(high / 2.0, 0.0, 1.0) * into
	fov = lerpf(fov, want_fov, 1.0 - exp(-5.0 * dt))
	# slightly underdamped spring back to rest
	var k: float = 90.0
	_dip_v += (-k * _dip - 2.0 * sqrt(k) * 0.75 * _dip_v) * dt
	_dip += _dip_v * dt
	_shake_t += dt
	_shake = maxf(0.0, _shake - dt * 0.4)          # (about 0.2 s)
	_apply()


func _apply() -> void:
	var dir: Vector3 = _look - _pos
	if dir.length() < 0.01:
		return
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.FORWARD
	var dip: Vector3 = Vector3.UP * _dip
	var shake: Vector3 = Vector3.ZERO
	if _shake > 0.001:
		shake = Vector3(sin(_shake_t * 61.0), sin(_shake_t * 53.0 + 1.3), sin(_shake_t * 47.0 + 2.1)) * _shake
	global_transform = Transform3D(Basis.looking_at(dir - dip * 0.4, up), _pos + dip + shake)
