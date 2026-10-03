class_name Ragdoll
extends RefCounted
## A physics body for every major part of a rider (MPFB game-engine skeleton): pelvis, chest, head, upper and
## lower arms, thighs, calves and feet, as capsules sized from the bones and joined with cone joints. It sleeps
## until a crash, then takes over the skeleton: the rider falls, slides and tumbles against whatever is there.
##
## Collision layer 8 ("ragdoll"): hits the world and the loose board, not the skater capsule.
##
## A person is not a doll: every part has a muscle (drive()) that holds the pose the body had when it went down,
## the head stays on the shoulders, and the arms react to the way the body is going down: elbows bent to catch it
## (the arm on that side), the other arm coming over. Once the body has come to rest the rig relaxes the muscles
## and it lies like a person (hips and knees bent, one leg drawn up, arms limp), not a plank.

const LAYER: int = 8

# bone -> [child bone that marks its end (or "" for a fixed length), radius, mass, swing span, twist span]
const PARTS: Dictionary = {
	"pelvis": ["spine_02", 0.13, 11.0, 0.0, 0.0],
	"spine_02": ["neck_01", 0.14, 14.0, 30.0, 25.0],
	"head": ["", 0.105, 5.0, 45.0, 40.0],
	"upperarm_l": ["lowerarm_l", 0.05, 2.4, 85.0, 45.0],
	"upperarm_r": ["lowerarm_r", 0.05, 2.4, 85.0, 45.0],
	"lowerarm_l": ["hand_l", 0.043, 1.8, 70.0, 20.0],
	"lowerarm_r": ["hand_r", 0.043, 1.8, 70.0, 20.0],
	"thigh_l": ["calf_l", 0.075, 8.5, 70.0, 20.0],
	"thigh_r": ["calf_r", 0.075, 8.5, 70.0, 20.0],
	"calf_l": ["foot_l", 0.055, 3.8, 70.0, 10.0],
	"calf_r": ["foot_r", 0.055, 3.8, 70.0, 10.0],
	"foot_l": ["ball_l", 0.045, 1.0, 30.0, 10.0],
	"foot_r": ["ball_r", 0.045, 1.0, 30.0, 10.0],
}
const FIXED_LEN: Dictionary = {"head": 0.22}
# bone -> [muscle frequency (1/s), damping ratio]: how firmly each part holds its pose. Stiffest at the neck
# and back, softer in the limbs so they still give a little when they hit the ground.
const MUSCLE: Dictionary = {
	"spine_02": [12.0, 1.0], "head": [14.0, 1.0],
	"upperarm_l": [9.0, 0.8], "upperarm_r": [9.0, 0.8], "lowerarm_l": [8.0, 0.8], "lowerarm_r": [8.0, 0.8],
	"thigh_l": [8.0, 0.9], "thigh_r": [8.0, 0.9], "calf_l": [8.0, 0.9], "calf_r": [8.0, 0.9],
	"foot_l": [7.0, 1.0], "foot_r": [7.0, 1.0],
}
const KNEE_RANGE: Vector2 = Vector2(-3.0, 140.0)   # hinge limits, degrees (straight .. fully bent)
const KNEE_SIGN: float = 1.0          # flips knee_angles() so that the knee's natural bend reads positive
const LEG_EASE: float = 0.5           # how far the legs go from the riding crouch toward the lying pose once the fall begins
# the lying pose (_lying): degrees of hip and knee bend, for the straighter leg and the one drawn up
const LIE_HIP: Vector2 = Vector2(20.0, 50.0)
const LIE_KNEE: Vector2 = Vector2(30.0, 75.0)
# a slip-out (the board shot out from under a manual): both legs up in front, knees bent, sitting down (the riding
# stance held through the fall put the hips down between the feet, in the splits)
const SIT_HIP: float = 80.0
const SIT_KNEE: float = 70.0
const MAX_KICK: float = 3.0           # rad/s a muscle may add in one tick (keeps a bad frame from exploding)
static var limp: bool = OS.get_environment("LIMP") != ""     # LIMP=1: no muscles (the old doll, for comparison)

var sim: PhysicalBoneSimulator3D
var bones: Dictionary = {}          # bone name -> PhysicalBone3D
var skel: Skeleton3D
var tone: float = 1.0               # 0..1: muscle strength (1 falling, lower once the body is lying still)
var reach: float = 0.0              # 0..1: arms reach out toward the fall instead of holding their pose
var settle: float = 0.0             # 0..1: lying still, the back and legs ease toward the lying pose, the arms go limp
var fall_dir: Vector3 = Vector3.ZERO   # horizontal: the way the body is going down (the arms react to it); 0 = its velocity
var drawn_up: int = 0               # which leg the lying pose draws up (0 left, 1 right)
var sit: bool = false               # a slip-out: the legs go for _sit instead of the lying pose (set before start())
var _sit: Dictionary = {}           # bone -> relative rotation sitting down, both legs bent up in front
var _parent: Dictionary = {}        # bone -> the physical bone it hangs from
var _hold: Dictionary = {}          # bone -> its rotation relative to that parent when the fall began
var _rest: Dictionary = {}          # bone -> the same at rest (standing straight)
var _lying: Array = [{}, {}]        # bone -> relative rotation lying down, with the left / right leg drawn up
var _inertia: Dictionary = {}       # bone -> rough moment of inertia about its joint
var _lateral: Dictionary = {}       # thigh bone -> the body's left-right axis in that bone's own frame (knee hinge axis)


func build(skeleton: Skeleton3D) -> void:
	skel = skeleton
	sim = PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skel.add_child(sim)
	for bone in PARTS:
		var spec: Array = PARTS[bone]
		var i: int = skel.find_bone(bone)
		if i < 0:
			continue
		var length: float = float(FIXED_LEN.get(bone, 0.2))
		if String(spec[0]) != "":
			var c: int = skel.find_bone(String(spec[0]))
			length = skel.get_bone_global_rest(i).origin.distance_to(skel.get_bone_global_rest(c).origin)
		var r: float = spec[1]
		var pb: PhysicalBone3D = PhysicalBone3D.new()
		pb.name = "PB_" + bone
		pb.bone_name = bone
		pb.mass = spec[2]
		pb.friction = 0.9
		pb.bounce = 0.05
		pb.linear_damp = 0.05
		pb.angular_damp = 0.5              # enough to settle, not so much that the body falls in slow motion
		pb.collision_layer = LAYER
		pb.collision_mask = 1 | 4
		# the capsule runs along the bone (+Y in bone space) from its head to its end
		pb.body_offset = Transform3D(Basis.IDENTITY, Vector3(0, length * 0.5, 0))
		if bone == "pelvis":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		elif bone.begins_with("calf"):
			# a knee is a hinge: it bends one way only, about the body's left-right axis, and never sideways
			var lat: Vector3 = skel.get_bone_global_rest(i).basis.orthonormalized().inverse() * Vector3(1, 0, 0)
			lat = (lat - Vector3.UP * lat.dot(Vector3.UP)).normalized()
			var jb: Basis = Basis(Vector3.UP.cross(lat).normalized(), Vector3.UP, lat)
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			pb.joint_offset = Transform3D(jb, Vector3(0, -length * 0.5, 0))
			pb.set("joint_constraints/angular_limit_enabled", true)
			# the hinge measures the other way round from knee_angles(): natural bend is negative
			pb.set("joint_constraints/angular_limit_lower", -KNEE_RANGE.y)
			pb.set("joint_constraints/angular_limit_upper", -KNEE_RANGE.x)
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.joint_offset = Transform3D(Basis.IDENTITY, Vector3(0, -length * 0.5, 0))
			pb.joint_rotation = Vector3(0, 0, PI * 0.5)     # the cone's twist axis (X) along the bone
			pb.set("joint_constraints/swing_span", float(spec[3]))
			pb.set("joint_constraints/twist_span", float(spec[4]))
		var cs: CollisionShape3D = CollisionShape3D.new()
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = r
		cap.height = maxf(length + r, r * 2.0 + 0.01)
		cs.shape = cap
		pb.add_child(cs)
		sim.add_child(pb)
		bones[bone] = pb
		var m: float = spec[2]
		_inertia[bone] = m * (length * length / 3.0 + r * r * 0.25)
	for side in ["l", "r"]:
		var th: int = skel.find_bone("thigh_" + side)
		if th >= 0:
			var lat: Vector3 = skel.get_bone_global_rest(th).basis.orthonormalized().inverse() * Vector3(1, 0, 0)
			lat = (lat - Vector3.UP * lat.dot(Vector3.UP)).normalized()     # square to the bone (+Y)
			_lateral["thigh_" + side] = lat
	for bone in bones:
		var p: int = skel.get_bone_parent(skel.find_bone(bone))
		while p >= 0 and not bones.has(skel.get_bone_name(p)):
			p = skel.get_bone_parent(p)
		if p >= 0:
			_parent[bone] = skel.get_bone_name(p)
			var ra: Basis = skel.get_bone_global_rest(p).basis.orthonormalized()
			var rb: Basis = skel.get_bone_global_rest(skel.find_bone(bone)).basis.orthonormalized()
			_rest[bone] = Quaternion((ra.inverse() * rb).orthonormalized())
	_build_lying()
	sim.active = false


## The lying poses: the hips bend the thighs forward and the knees bend the shins back (the skeleton's own front,
## from the toes), more on the drawn-up leg. Everything else as at rest.
func _build_lying() -> void:
	for up in 2:
		var p: Variant = _leg_pose([LIE_HIP.y if up == 0 else LIE_HIP.x, LIE_HIP.y if up == 1 else LIE_HIP.x],
			[LIE_KNEE.y if up == 0 else LIE_KNEE.x, LIE_KNEE.y if up == 1 else LIE_KNEE.x])
		if p == null:
			return
		_lying[up] = p
	_sit = _leg_pose([SIT_HIP, SIT_HIP], [SIT_KNEE, SIT_KNEE])


## The rest pose with each leg bent: `hip` and `knee` degrees for the left and right leg (the hip forward, the
## knee back). Null without the foot bones.
func _leg_pose(hip: Array, knee: Array) -> Variant:
	var foot: int = skel.find_bone("foot_l")
	var ball: int = skel.find_bone("ball_l")
	if foot < 0 or ball < 0:
		return null
	var front: Vector3 = skel.get_bone_global_rest(ball).origin - skel.get_bone_global_rest(foot).origin
	front.y = 0.0
	front = front.normalized()
	var pose: Dictionary = {}
	for bone in _rest:
		pose[bone] = _rest[bone]
	for i in 2:
		var side: String = "l" if i == 0 else "r"
		for pair in [["thigh_" + side, "calf_" + side, front, float(hip[i])], ["calf_" + side, "foot_" + side, -front, float(knee[i])]]:
			var bone: String = pair[0]
			if not pose.has(bone) or not _parent.has(bone):
				continue
			var b: int = skel.find_bone(bone)
			var c: int = skel.find_bone(String(pair[1]))
			var dir: Vector3 = (skel.get_bone_global_rest(c).origin - skel.get_bone_global_rest(b).origin).normalized()
			var axis: Vector3 = dir.cross(pair[2] as Vector3).normalized()
			var pb: Basis = skel.get_bone_global_rest(skel.find_bone(_parent[bone])).basis.orthonormalized()
			pose[bone] = Quaternion((pb.inverse() * axis).normalized(), deg_to_rad(float(pair[3]))) * (_rest[bone] as Quaternion)
	return pose


## Take over the skeleton from its current pose, moving with velocity `v` (and a spin `w` about the pelvis).
func start(v: Vector3, w: Vector3) -> void:
	# the pose to hold: each part's rotation relative to its parent, as the rider was posed a moment ago
	_hold.clear()
	for bone in _parent:
		var a: Basis = skel.get_bone_global_pose(skel.find_bone(_parent[bone])).basis.orthonormalized()
		var b: Basis = skel.get_bone_global_pose(skel.find_bone(bone)).basis.orthonormalized()
		_hold[bone] = Quaternion((a.inverse() * b).orthonormalized())
	tone = 1.0
	reach = 1.0
	settle = 0.0
	drawn_up = randi() % 2
	sim.active = true
	sim.physical_bones_start_simulation()
	var centre: Vector3 = pelvis_position()
	for bone in bones:
		var pb: PhysicalBone3D = bones[bone]
		pb.linear_velocity = v + w.cross(pb.global_position - centre)
		pb.angular_velocity = w


## One physics tick of muscle: each part is pulled toward its held pose relative to its parent (and the parent
## pushed back the other way, so the body cannot spin itself up), with damping on their relative spin. The arms
## instead aim down and toward where the body is falling, a little out to the sides, as `reach` says.
func drive(dt: float) -> void:
	if limp or tone <= 0.0 or _hold.is_empty() or not simulating():
		return
	var pelvis: PhysicalBone3D = bones["pelvis"]
	var fall: Vector3 = fall_dir
	if fall == Vector3.ZERO:
		fall = pelvis.linear_velocity
		fall.y = 0.0
		fall = fall.normalized() if fall.length() > 0.5 else Vector3.ZERO
	var right: Vector3 = Vector3.ZERO
	if bones.has("upperarm_l") and bones.has("upperarm_r"):
		right = ((bones["upperarm_r"] as PhysicalBone3D).global_position - (bones["upperarm_l"] as PhysicalBone3D).global_position).normalized()
	for bone in _hold:
		var pb: PhysicalBone3D = bones[bone]
		var pa: PhysicalBone3D = bones[_parent[bone]]
		var cur: Basis = pb.global_transform.basis.orthonormalized()
		var arm: bool = bone.begins_with("upperarm") or bone.begins_with("lowerarm")
		var rel: Quaternion = _hold[bone]
		# legs let go of the riding crouch as soon as the board is gone, toward lying with the knees bent (a straight
		# target made every slam a plank)
		var leg: bool = bone.begins_with("thigh") or bone.begins_with("calf") or bone.begins_with("foot")
		var ease: float = maxf(settle, LEG_EASE) if leg else settle
		var target: Dictionary = _lying[drawn_up]
		if sit and leg and not _sit.is_empty():
			target = _sit                                  # a slip-out: up in front and sitting, not lying flat
			ease = maxf(ease, 0.9)
		if ease > 0.0 and not arm:
			rel = rel.slerp(target.get(bone, _rest[bone]), ease)
		var err: Vector3 = _turn(cur, pa.global_transform.basis.orthonormalized() * Basis(rel))
		if reach > 0.0 and arm:
			var side: float = 1.0 if bone.ends_with("_r") else -1.0
			var toward: float = right.dot(fall) * side          # > 0: this arm is on the side it's falling to
			var upper: bool = bone.begins_with("upperarm")
			var want: Vector3
			if toward > -0.35:
				# catching: the upper arm out toward the fall and down, the forearm more down (the elbow bends)
				want = (fall * 0.8 + Vector3.DOWN * 0.8 + right * side * 0.35) if upper else (fall * 0.35 + Vector3.DOWN + right * side * 0.15)
			else:
				# the far arm on a fall to the side comes over the body instead of mirroring the near one
				want = (fall * 0.7 + Vector3.UP * 0.25 - right * side * 0.1) if upper else (fall * 0.6 + Vector3.DOWN * 0.4)
			want = want.normalized()
			var dir: Vector3 = cur.y.normalized()             # the bone runs along its +Y
			var ax: Vector3 = dir.cross(want)
			var aim: Vector3 = ax.normalized() * dir.angle_to(want) if ax.length() > 0.0001 else Vector3.ZERO
			err = err.lerp(aim, reach)
		var spec: Array = MUSCLE.get(bone, [8.0, 1.0])
		var wn: float = spec[0]
		var w_rel: Vector3 = pb.angular_velocity - pa.angular_velocity
		var strength: float = tone * (1.0 - 0.75 * settle) if arm else tone      # lying still, the arms go limp
		var dw: Vector3 = (err * wn * wn - w_rel * 2.0 * float(spec[1]) * wn) * dt * strength
		var imp: Vector3 = dw.limit_length(MAX_KICK) * float(_inertia[bone])
		PhysicsServer3D.body_apply_torque_impulse(pb.get_rid(), imp)
		PhysicsServer3D.body_apply_torque_impulse(pa.get_rid(), -imp)


## The rotation (axis * angle, world space) that turns `cur` into `want`.
static func _turn(cur: Basis, want: Basis) -> Vector3:
	var q: Quaternion = (want * cur.inverse()).get_rotation_quaternion()
	if q.w < 0.0:
		q = -q
	var ang: float = q.get_angle()
	return q.get_axis() * ang if ang > 0.0001 else Vector3.ZERO


func stop() -> void:
	sim.physical_bones_stop_simulation()
	sim.active = false


## Each knee now, in degrees: [flex, side] per leg (l, r). flex > 0 bends the knee the natural way, < 0 is
## hyperextension; side is the calf bent out of the leg's plane (a knee does not do that).
func knee_angles() -> Array:
	var out: Array = []
	for side in ["l", "r"]:
		var tb: PhysicalBone3D = bones.get("thigh_" + side)
		var cb: PhysicalBone3D = bones.get("calf_" + side)
		if tb == null or cb == null:
			out.append([0.0, 0.0])
			continue
		var t: Basis = (tb.global_transform * tb.body_offset.affine_inverse()).basis.orthonormalized()
		var c: Basis = (cb.global_transform * cb.body_offset.affine_inverse()).basis.orthonormalized()
		var lat: Vector3 = (t * _lateral["thigh_" + side]).normalized()
		var td: Vector3 = t.y
		var cd: Vector3 = c.y
		var side_deg: float = rad_to_deg(asin(clampf(cd.dot(lat), -1.0, 1.0)))
		var cp: Vector3 = (cd - lat * cd.dot(lat)).normalized()
		var flex: float = rad_to_deg(atan2(td.cross(cp).dot(lat), td.dot(cp))) * KNEE_SIGN
		out.append([flex, side_deg])
	return out


func simulating() -> bool:
	return sim.is_simulating_physics()


func pelvis_position() -> Vector3:
	var pb: PhysicalBone3D = bones.get("pelvis")
	if pb != null and simulating():
		return pb.global_position
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone("pelvis")).origin


## How fast the core (pelvis and chest) is moving: the body has come to rest when this stays low for a moment.
## (Hands and feet keep twitching a little and would never settle.)
func core_speed() -> float:
	var m: float = 0.0
	for bone in ["pelvis", "spine_02"]:
		if bones.has(bone):
			m = maxf(m, (bones[bone] as PhysicalBone3D).linear_velocity.length())
	return m


## Every bone's pose in world space right now, read from the physics bodies themselves (the skeleton's own
## pose query does not include the simulation): physical bones from their bodies, the rest following their
## parents with their current local poses.
func world_poses() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.resize(skel.get_bone_count())
	var by_id: Dictionary = {}
	for bone in bones:
		var pb: PhysicalBone3D = bones[bone]
		by_id[skel.find_bone(bone)] = pb.global_transform * pb.body_offset.affine_inverse()
	for i in skel.get_bone_count():
		if by_id.has(i):
			out[i] = by_id[i]
		else:
			var p: int = skel.get_bone_parent(i)
			out[i] = (out[p] if p >= 0 else skel.global_transform) * skel.get_bone_pose(i)
	return out
