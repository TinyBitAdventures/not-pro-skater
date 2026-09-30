class_name Ragdoll
extends RefCounted
## A physics body for every major part of a rider (MPFB game-engine skeleton): pelvis, chest, head, upper and
## lower arms, thighs, calves and feet, as capsules sized from the bones and joined with cone joints. It sleeps
## until a crash, then takes over the skeleton: the rider falls, slides and tumbles against whatever is there.
##
## Collision layer 8 ("ragdoll"): hits the world and the loose board, not the skater capsule.
##
## A person is not a doll: every part has a muscle (drive()) that holds the pose the body had when it went down,
## the head stays on the shoulders, and the arms reach toward where the body is falling to catch it. The rig
## relaxes the muscles once the body has come to rest.

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
const LEG_EASE: float = 0.45          # how far the legs straighten out of the riding crouch once the fall begins
const MAX_KICK: float = 3.0           # rad/s a muscle may add in one tick (keeps a bad frame from exploding)
static var limp: bool = OS.get_environment("LIMP") != ""     # LIMP=1: no muscles (the old doll, for comparison)

var sim: PhysicalBoneSimulator3D
var bones: Dictionary = {}          # bone name -> PhysicalBone3D
var skel: Skeleton3D
var tone: float = 1.0               # 0..1: muscle strength (1 falling, lower once the body is lying still)
var reach: float = 0.0              # 0..1: arms reach out toward the fall instead of holding their pose
var settle: float = 0.0             # 0..1: lying still, the back and legs ease out of the riding crouch toward straight
var _parent: Dictionary = {}        # bone -> the physical bone it hangs from
var _hold: Dictionary = {}          # bone -> its rotation relative to that parent when the fall began
var _rest: Dictionary = {}          # bone -> the same at rest (standing straight)
var _inertia: Dictionary = {}       # bone -> rough moment of inertia about its joint


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
	for bone in bones:
		var p: int = skel.get_bone_parent(skel.find_bone(bone))
		while p >= 0 and not bones.has(skel.get_bone_name(p)):
			p = skel.get_bone_parent(p)
		if p >= 0:
			_parent[bone] = skel.get_bone_name(p)
			var ra: Basis = skel.get_bone_global_rest(p).basis.orthonormalized()
			var rb: Basis = skel.get_bone_global_rest(skel.find_bone(bone)).basis.orthonormalized()
			_rest[bone] = Quaternion((ra.inverse() * rb).orthonormalized())
	sim.active = false


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
	var fall: Vector3 = pelvis.linear_velocity
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
		# legs let go of the crouch as soon as the board is gone (a slam does not keep its knees bent)
		var ease: float = maxf(settle, LEG_EASE) if (bone.begins_with("thigh") or bone.begins_with("calf") or bone.begins_with("foot")) else settle
		if ease > 0.0 and not arm:
			rel = rel.slerp(_rest[bone], ease)
		var err: Vector3 = _turn(cur, pa.global_transform.basis.orthonormalized() * Basis(rel))
		if reach > 0.0 and arm:
			var side: float = 1.0 if bone.ends_with("_r") else -1.0
			var want: Vector3 = (fall * 0.8 + Vector3.DOWN * 0.8 + right * side * 0.35).normalized()
			var dir: Vector3 = cur.y.normalized()             # the bone runs along its +Y
			var ax: Vector3 = dir.cross(want)
			var aim: Vector3 = ax.normalized() * dir.angle_to(want) if ax.length() > 0.0001 else Vector3.ZERO
			err = err.lerp(aim, reach)
		var spec: Array = MUSCLE.get(bone, [8.0, 1.0])
		var wn: float = spec[0]
		var w_rel: Vector3 = pb.angular_velocity - pa.angular_velocity
		var dw: Vector3 = (err * wn * wn - w_rel * 2.0 * float(spec[1]) * wn) * dt * tone
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
