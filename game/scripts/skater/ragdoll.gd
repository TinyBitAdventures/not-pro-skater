class_name Ragdoll
extends RefCounted
## A physics body for every major part of a rider (MPFB game-engine skeleton): pelvis, chest, head, upper and
## lower arms, thighs, calves and feet, as capsules sized from the bones and joined with cone joints. It sleeps
## until a crash, then takes over the skeleton: the rider falls, slides and tumbles against whatever is there.
##
## Collision layer 8 ("ragdoll"): hits the world and the loose board, not the skater capsule.

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

var sim: PhysicalBoneSimulator3D
var bones: Dictionary = {}          # bone name -> PhysicalBone3D
var skel: Skeleton3D


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
	sim.active = false


## Take over the skeleton from its current pose, moving with velocity `v` (and a spin `w` about the pelvis).
func start(v: Vector3, w: Vector3) -> void:
	sim.active = true
	sim.physical_bones_start_simulation()
	var centre: Vector3 = pelvis_position()
	for bone in bones:
		var pb: PhysicalBone3D = bones[bone]
		pb.linear_velocity = v + w.cross(pb.global_position - centre)
		pb.angular_velocity = w


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
