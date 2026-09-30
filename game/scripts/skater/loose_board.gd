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
var scrape_drag: float = 3.0         # per second, sliding on the deck or its side
var side_grip: float = 14.0          # how fast sideways slip dies while the wheels are down
var wheels_down: bool = false
var rider_key: String = "dev"           # whose deck graphic
var _put: Variant = null                # a transform to move to at the next physics step (put_at)


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


func _integrate_forces(st: PhysicsDirectBodyState3D) -> void:
	if _put != null:
		st.transform = _put
		st.linear_velocity = Vector3.ZERO
		st.angular_velocity = Vector3.ZERO
		_put = null
		return
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
			# the wheels also stop the board spinning flat on the ground like a top
			var w: Vector3 = st.angular_velocity
			st.angular_velocity = w - ground_n * w.dot(ground_n) * clampf(4.0 * dt, 0.0, 1.0)
		else:
			v *= exp(-scrape_drag * dt)
	st.linear_velocity = v


## Where to stand to step on: the board's position on the ground and its forward (nose) direction, flattened.
func stand_transform() -> Transform3D:
	var f: Vector3 = -global_transform.basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.1 else Vector3.FORWARD
	return Transform3D(Basis.looking_at(f, Vector3.UP), global_position)
