class_name LooseBoard
extends RigidBody3D
## The board after a bail: a real rigid body that rolls on its wheels, runs down ramps and back up the other
## side, tips over, bounces off things and stops by itself. Upright on its wheels it grips sideways and rolls
## freely along its length; on its side or upside down it scrapes to a stop.
##
## Collision layers: world 1, skater 2, loose board 4, ragdoll 8. The board hits the world and the ragdoll.

const LAYER: int = 4
const DECK_Y: float = 0.104
const WHEEL_R: float = 0.027
const AXLE_Y: float = 0.027
const TRUCK_Z: float = 0.215
const WHEEL_X: float = 0.09

var roll_drag: float = 0.22          # per second, rolling on its wheels
var roll_resist: float = 1.8         # m/s per second, rolling on its wheels (SkateTuning.board_roll_resist): a
                                     # crashed board runs over grit and cracks, and with drag alone one rolled on for
                                     # 15 m across the flat and far further down a bank
var scrape_drag: float = 3.0         # per second, sliding on the deck or its side
var side_grip: float = 14.0          # how fast sideways slip dies while the wheels are down
var wheels_down: bool = false
var rider_key: String = "dev"           # whose deck graphic
var _put: Variant = null                # a transform to move to at the next physics step (put_at)
var _prev_v: Vector3 = Vector3.ZERO
var _flip: Array = []                   # being flipped over by the rider's foot: [from, to, seconds, seconds done]
var _knock_cd: float = 0.0

signal knocked(strength: float)         # hit something hard enough to clack (m/s of speed changed in one step)


func setup(xf: Transform3D, vel: Vector3, spin: Vector3) -> void:
	mass = 2.2
	collision_layer = LAYER
	collision_mask = 1 | 8
	continuous_cd = true
	can_sleep = true
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = 0.05                # the wheels roll: sliding friction is handled in _integrate_forces
	pm.bounce = 0.2
	physics_material_override = pm
	angular_damp = 0.6
	var deck: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.2, 0.03, 0.78)
	deck.shape = box
	deck.position = Vector3(0, DECK_Y, 0)
	add_child(deck)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w: CollisionShape3D = CollisionShape3D.new()
			var sph: SphereShape3D = SphereShape3D.new()
			sph.radius = WHEEL_R
			w.shape = sph
			w.position = Vector3(sx * WHEEL_X, AXLE_Y, sz * TRUCK_Z)
			add_child(w)
	var vis: Node3D = RiderRig.BOARD_SCENE.instantiate()
	add_child(vis)
	RiderRig.style_board(vis, rider_key)
	for mi in vis.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.07, 0)
	contact_monitor = true
	max_contacts_reported = 8
	global_transform = xf
	linear_velocity = vel
	angular_velocity = spin


## Move the board (stopped) at the next physics step: setting a rigid body's transform from outside is undone by
## the physics server.
func put_at(xf: Transform3D) -> void:
	_put = xf


## Lying upside down or on its side: is it?
func wheels_up() -> bool:
	return global_transform.basis.y.y < 0.6


## Hooked over by the rider's foot: a little hop and a roll onto its wheels, `to` (on the ground, nose the way it
## pointed) over `seconds`.
func flip_to(to: Transform3D, seconds: float) -> void:
	_flip = [global_transform, to, seconds, 0.0]


func flipping() -> bool:
	return not _flip.is_empty()


func _integrate_forces(st: PhysicsDirectBodyState3D) -> void:
	if not _flip.is_empty():
		_flip[3] = float(_flip[3]) + st.step
		var u: float = clampf(float(_flip[3]) / float(_flip[2]), 0.0, 1.0)
		var e: float = u * u * (3.0 - 2.0 * u)
		var a: Transform3D = _flip[0]
		var b: Transform3D = _flip[1]
		var q: Quaternion = a.basis.orthonormalized().get_rotation_quaternion().slerp(b.basis.orthonormalized().get_rotation_quaternion(), e)
		st.transform = Transform3D(Basis(q), a.origin.lerp(b.origin, e) + Vector3.UP * 0.16 * sin(PI * u))
		st.linear_velocity = Vector3.ZERO
		st.angular_velocity = Vector3.ZERO
		_prev_v = Vector3.ZERO
		if u >= 1.0:
			_flip = []
		return
	if _put != null:
		st.transform = _put
		st.linear_velocity = Vector3.ZERO
		st.angular_velocity = Vector3.ZERO
		_put = null
		return
	# a hit: the speed jumps in one step (gravity and rolling drag change it far less)
	_knock_cd = maxf(0.0, _knock_cd - st.step)
	var jolt: float = (st.linear_velocity - _prev_v).length()
	if jolt > 1.1 and _knock_cd <= 0.0 and st.get_contact_count() > 0:
		_knock_cd = 0.08
		knocked.emit(jolt)
	var b: Basis = st.transform.basis
	var up: Vector3 = b.y
	var ground_n: Vector3 = Vector3.ZERO
	for i in st.get_contact_count():
		ground_n += st.get_contact_local_normal(i)
	wheels_down = false
	var dt: float = st.step
	var v: Vector3 = st.linear_velocity
	if ground_n.length() > 0.1:
		ground_n = ground_n.normalized()
		if up.dot(ground_n) > 0.75:
			wheels_down = true
			var side: Vector3 = b.x
			v -= side * v.dot(side) * clampf(side_grip * dt, 0.0, 1.0)
			var along: Vector3 = b.z
			v -= along * v.dot(along) * (1.0 - exp(-roll_drag * dt))
			var s: float = v.dot(along)
			v -= along * signf(s) * minf(absf(s), roll_resist * dt)     # (never past a stop)
			# the wheels also stop the board spinning flat on the ground like a top
			var w: Vector3 = st.angular_velocity
			st.angular_velocity = w - ground_n * w.dot(ground_n) * clampf(4.0 * dt, 0.0, 1.0)
		else:
			v *= exp(-scrape_drag * dt)
	st.linear_velocity = v
	_prev_v = v


## Where to stand to step on: the board's position on the ground and its forward (nose) direction, flattened.
func stand_transform() -> Transform3D:
	var f: Vector3 = -global_transform.basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.1 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(f, Vector3.UP), global_position)
