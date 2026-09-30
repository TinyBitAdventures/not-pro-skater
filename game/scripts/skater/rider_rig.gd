class_name RiderRig
extends SkaterVisual
## A skinned character (blender/character.py, MPFB game-engine skeleton) riding the real-sized board
## (blender/board.py). SkaterVisual still decides the pose (crouch, lean, twist, flips, grabs, bails); this class
## turns it into bone rotations: hips and spine, both feet flat on the deck by two-bone leg IK, hands by arm IK
## (onto the board for grabs), and the head turned toward where the board is going.
##
## Everything is worked out in "model space" (SkaterVisual's: nose toward -Z, up +Y, chest toward +X for a
## regular stance). The character glb faces +Z, so it sits in a container turned +90 degrees about Y, which
## also puts its left foot toward the nose.

const BOARD_SCENE: PackedScene = preload("res://assets/models/board.glb")
const DECK: float = 0.11                 # deck top above the ground
const LEG_FRAC: float = 0.9              # hip_h fractions map onto this share of the real leg length
const FOOT_FRONT: float = -0.22          # foot centres along the deck (over the bolts)
const FOOT_BACK: float = 0.21
const FRONT_FOOT_ANGLE: float = 20.0     # the front foot turns toward the nose, the back foot a little the other way
const BACK_FOOT_ANGLE: float = -8.0
const HEAD_LOOK: float = 70.0            # head turned from the chest toward the nose, degrees

var char_key: String = "dev"
var skel: Skeleton3D
var container: Node3D
var _m: Transform3D                      # container: skeleton space -> model space
var _rest_local: Array[Transform3D] = []
var _rest_model: Array[Transform3D] = []
var _glob: Array[Transform3D] = []       # current global pose per bone, model space
var _parent: PackedInt32Array = PackedInt32Array()
var _b: Dictionary = {}                  # bone name -> index
var _leg_len: float = 0.93
var _up_len: Dictionary = {}             # chain lengths measured from the rest pose
var _ankle_off: Vector3 = Vector3.ZERO   # sole centre -> ankle, in the rest foot's model frame
# physical bails: ragdoll fall -> get up (blend from the fallen pose) -> walk to the loose board -> step on
var ragdoll: Ragdoll
var loose: LooseBoard
var phys_phase: String = ""
var _phase_t: float = 0.0
var _still_t: float = 0.0
var _blend_from: Array[Transform3D] = []
var _blend_w: float = 1.0
var _walk_mode: bool = false
var _walk_pos: Vector3 = Vector3.ZERO
var _walk_dir: Vector3 = Vector3.FORWARD
var _step_on: float = 0.0
var _apart_t: float = 0.0
var _walk_pace: float = 2.4
const GETUP_TIME: float = 0.75
const SETTLE_SPEED: float = 0.45


func setup(_look: Dictionary = {}) -> void:
	model = Node3D.new()
	model.name = "Rider"
	add_child(model)
	container = Node3D.new()
	container.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	model.add_child(container)
	var ch: Node3D = (load("res://assets/characters/%s.glb" % char_key) as PackedScene).instantiate()
	container.add_child(ch)
	skel = ch.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_m = container.transform * ch.transform * _node_to(ch, skel)
	board = BOARD_SCENE.instantiate()
	model.add_child(board)
	style_board(board)
	var n: int = skel.get_bone_count()
	_rest_local.resize(n)
	_rest_model.resize(n)
	_glob.resize(n)
	_parent.resize(n)
	for i in n:
		_parent[i] = skel.get_bone_parent(i)
		_rest_local[i] = skel.get_bone_rest(i)
		_rest_model[i] = _m * skel.get_bone_global_rest(i)
		_b[skel.get_bone_name(i)] = i
	for side in ["l", "r"]:
		var th: Vector3 = _rest_model[_b["thigh_" + side]].origin
		var ca: Vector3 = _rest_model[_b["calf_" + side]].origin
		var fo: Vector3 = _rest_model[_b["foot_" + side]].origin
		_up_len["thigh_" + side] = th.distance_to(ca)
		_up_len["calf_" + side] = ca.distance_to(fo)
		var ua: Vector3 = _rest_model[_b["upperarm_" + side]].origin
		var la: Vector3 = _rest_model[_b["lowerarm_" + side]].origin
		var ha: Vector3 = _rest_model[_b["hand_" + side]].origin
		_up_len["upperarm_" + side] = ua.distance_to(la)
		_up_len["lowerarm_" + side] = la.distance_to(ha)
	var ankle: Vector3 = _rest_model[_b["foot_l"]].origin
	var ball: Vector3 = _rest_model[_b["ball_l"]].origin
	_leg_len = _up_len["thigh_l"] + _up_len["calf_l"] + ankle.y
	# sole centre: under the ankle, a little toward the ball of the foot
	var sole: Vector3 = Vector3(ankle.x + (ball.x - ankle.x) * 0.45, 0.0, ankle.z + (ball.z - ankle.z) * 0.45)
	_ankle_off = ankle - sole
	for mi in ch.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).extra_cull_margin = 1.5     # skinned: poses reach well outside the rest bounds
	ragdoll = Ragdoll.new()
	ragdoll.build(skel)


static func _node_to(from: Node3D, to: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var chain: Array[Node3D] = []
	var n: Node = to
	while n != null and n != from:
		chain.push_front(n as Node3D)
		n = n.get_parent()
	for c in chain:
		xf = xf * c.transform
	return xf


static func style_board(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi
		for s in inst.mesh.get_surface_count():
			var m: StandardMaterial3D = (inst.mesh.surface_get_material(s) as StandardMaterial3D)
			if m == null:
				continue
			m = m.duplicate() as StandardMaterial3D
			match m.resource_name:
				"TruckMetal":
					m.metallic = 1.0
					m.roughness = 0.35
				"Wheel":
					m.roughness = 0.55
				"Grip":
					m.roughness = 1.0
				"DeckArt":
					m.roughness = 0.45
			inst.set_surface_override_material(s, m)


# ------------------------------------------------------------------ bones

func _pose_bone(i: int, g: Transform3D) -> void:
	if _blend_w < 1.0 and i < _blend_from.size():
		var a: Transform3D = _blend_from[i]
		var q: Quaternion = a.basis.orthonormalized().get_rotation_quaternion().slerp(g.basis.orthonormalized().get_rotation_quaternion(), _blend_w)
		g = Transform3D(Basis(q), a.origin.lerp(g.origin, _blend_w))
	var p: int = _parent[i]
	var local: Transform3D = (_glob[p].affine_inverse() * g) if p >= 0 else (_m.affine_inverse() * g)
	skel.set_bone_pose_position(i, local.origin)
	skel.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
	_glob[i] = Transform3D(g.basis.orthonormalized(), g.origin)


## Follow the parent at rest (for bones this rig does not drive: fingers, toes, clavicles).
func _rest_follow(i: int) -> void:
	var p: int = _parent[i]
	_glob[i] = (_glob[p] * _rest_local[i]) if p >= 0 else (_m * _rest_local[i])
	skel.set_bone_pose_position(i, _rest_local[i].origin)
	skel.set_bone_pose_rotation(i, _rest_local[i].basis.get_rotation_quaternion())


## Rotate bone i (as it is now, following its parent) by `q` about its own head, in model space.
func _rotated(i: int, q: Basis) -> Transform3D:
	var p: int = _parent[i]
	var here: Transform3D = (_glob[p] * _rest_local[i]) if p >= 0 else (_m * _rest_local[i])
	var rest_rel: Basis = _rest_model[p].basis.inverse() * _rest_model[i].basis if p >= 0 else _rest_model[i].basis
	var b: Basis = q * (_glob[p].basis * rest_rel if p >= 0 else _rest_model[i].basis)
	return Transform3D(b, here.origin)


## Point bone i from its head toward `target`, bending around `pole`: its rest direction (toward its child)
## maps onto the new direction and its rest "knee side" onto the pole.
func _aim(i: int, child: int, target: Vector3, pole: Vector3, rest_pole: Vector3) -> void:
	var p: int = _parent[i]
	var head: Vector3 = ((_glob[p] * _rest_local[i]) if p >= 0 else (_m * _rest_local[i])).origin
	var rest_dir: Vector3 = (_rest_model[child].origin - _rest_model[i].origin).normalized()
	var want: Vector3 = (target - head).normalized()
	var f_rest: Basis = _frame(rest_dir, rest_pole)
	var f_want: Basis = _frame(want, pole)
	var b: Basis = f_want * f_rest.inverse() * _rest_model[i].basis
	_pose_bone(i, Transform3D(b, head))


static func _frame(dir: Vector3, pole: Vector3) -> Basis:
	var x: Vector3 = dir.normalized()
	var y: Vector3 = pole - x * pole.dot(x)
	if y.length() < 0.001:
		y = Vector3.UP - x * Vector3.UP.dot(x)
		if y.length() < 0.001:
			y = Vector3.RIGHT - x * Vector3.RIGHT.dot(x)
	y = y.normalized()
	return Basis(x, y, x.cross(y))


func _limb(root: String, mid: String, end: String, target: Vector3, pole: Vector3, rest_pole: Vector3) -> void:
	var r: int = _b[root]
	var m: int = _b[mid]
	var e: int = _b[end]
	var p: int = _parent[r]
	var head: Vector3 = (_glob[p] * _rest_local[r]).origin
	var chain: Array = SkaterVisual.ik(head, target, _up_len[root], _up_len[mid], pole)
	_aim(r, m, chain[0], pole, rest_pole)
	_aim(m, e, chain[1], pole, rest_pole)


# ------------------------------------------------------------------ per frame

func _apply_rig(sk: Skater) -> void:
	# board (same moves as the cartoon rider: flips, grabs, bails)
	var bt: Transform3D
	var pivot: Vector3 = Vector3(0, DECK, 0)
	var rot: Basis = Basis.from_euler(Vector3(deg_to_rad(board_pitch), deg_to_rad(board_yaw), deg_to_rad(board_roll)), EULER_ORDER_YXZ)
	bt = Transform3D(rot, pivot - rot * pivot + Vector3(0, board_lift, 0))
	var bail_u: float = clampf(sk.bail_time / maxf(sk.bail_duration, 0.1), 0.0, 1.0)
	var bailing: bool = sk.state == Skater.State.BAIL
	if _walk_mode:
		board.transform = bt                   # hidden: the loose board is out in the world
	elif bailing:
		# the loose board IS the physics body: it sits where the skater's position is (rolling on and
		# stopping), skids round a little and, after a big crash, flips over in the air first; its spin
		# always settles back to straight so the rider steps onto it with nothing snapping
		var t: float = sk.bail_time
		var settle: float = clampf(t / maxf(sk.bail_duration * 0.8, 0.1), 0.0, 1.0)
		var skid: float = sin(settle * PI) * (0.25 if sk.bail_kind == "runout" else 1.1)
		var b_rot: Basis = Basis(Vector3.UP, skid)
		var hop: float = 0.0
		if sk.bail_kind == "tumble":
			var f: float = clampf(t / 0.7, 0.0, 1.0)
			b_rot = b_rot * Basis(Vector3(0, 0, 1), f * TAU)
			hop = sin(f * PI) * 0.6
		bt = Transform3D(b_rot, pivot - b_rot * pivot + Vector3(0, hop, 0))
		board.transform = model.global_transform.affine_inverse() * upright_xf * bt
	else:
		board.transform = bt

	# hips: SkaterVisual's hip_h (cartoon units, deck 0.145, legs 0.665) -> a share of this leg
	var walking: bool = _walk_mode or (bailing and sk.bail_kind != "runout" and sk.bail_time > _getup_at(sk))
	var frac: float = clampf((hip_h - 0.145) / 0.665, 0.45, 1.05)
	var hip_y: float = DECK + frac * LEG_FRAC * (_leg_len - _ankle_off.y) + _ankle_off.y * 0.2
	if (bailing and sk.bail_kind == "runout") or walking:
		hip_y = frac * LEG_FRAC * _leg_len + 0.02
	var stride: Array = []
	var push_amt: float = 0.0              # 0..1 through a stride: the body turns to face the nose to push
	if sk.push_anim >= 0.0 and sk.state == Skater.State.GROUND and not sk.manual_on:
		stride = _push_stride(sk.push_anim)
		hip_y -= float(stride[2])            # the standing leg bends as the other reaches the ground
		push_amt = clampf(1.0 - absf(sk.push_anim - 0.42) / 0.42, 0.0, 1.0)
		push_amt = push_amt * push_amt * (3.0 - 2.0 * push_amt)
	for i in [_b["Root"]]:
		_rest_follow(i)
	var pelvis: int = _b["pelvis"]
	var q_body: Basis = Basis(Vector3(0, 0, 1), deg_to_rad(-sway)) * Basis(Vector3.UP, deg_to_rad(twist * 0.3 + 30.0 * push_amt))
	var pg: Transform3D = _rotated(pelvis, q_body)
	pg.origin = Vector3(-0.03, hip_y, 0.0)
	_pose_bone(pelvis, pg)

	# spine: lean toward the chest and twist toward the nose, spread over three bones
	var q_torso: Basis = Basis(Vector3.UP, deg_to_rad(twist * 0.7 + 25.0 * push_amt)) * Basis(Vector3(0, 0, 1), deg_to_rad(-lean))
	var spine: Array[String] = ["spine_01", "spine_02", "spine_03"]
	for k in spine.size():
		var i: int = _b[spine[k]]
		var part: Basis = Basis(Quaternion.IDENTITY.slerp(q_torso.get_rotation_quaternion(), 1.0 / spine.size()))
		_pose_bone(i, _rotated(i, part))
	# head: look along the board toward the nose (and down at it in the air)
	var look: float = (HEAD_LOOK if sk.stance != "fakie" else -HEAD_LOOK) - twist
	if _walk_mode:
		look = 0.0                             # walking: looking where it goes
	var nod: float = 10.0 if sk.state == Skater.State.AIR else 4.0
	var neck: int = _b["neck_01"]
	_pose_bone(neck, _rotated(neck, Basis(Vector3.UP, deg_to_rad(look * 0.4))))
	var hd: int = _b["head"]
	_pose_bone(hd, _rotated(hd, Basis(Vector3.UP, deg_to_rad(look * 0.6)) * Basis(Vector3(0, 0, 1), deg_to_rad(-nod))))
	for side in ["l", "r"]:
		_rest_follow(_b["clavicle_" + side])

	# legs: feet flat on the deck (or running on the ground in a run-out)
	var lift: float = feet_lift + board_lift * 0.6
	var front: Vector3 = Vector3(0.0, DECK + lift, FOOT_FRONT)
	var back: Vector3 = Vector3(0.0, DECK + lift, FOOT_BACK)
	var front_ang: float = FRONT_FOOT_ANGLE
	var back_ang: float = BACK_FOOT_ANGLE
	if not stride.is_empty():
		back = stride[0]
		back_ang = stride[1]
		front_ang = lerpf(FRONT_FOOT_ANGLE, 65.0, push_amt)   # front foot swivels to point up the board
	if bailing and sk.bail_kind == "runout":
		var phr: float = sk.bail_time * 10.0
		var on: float = clampf((bail_u - 0.75) / 0.25, 0.0, 1.0)
		front = Vector3(0.12, maxf(0.0, sin(phr)) * 0.25, -0.05 - cos(phr) * 0.42).lerp(front, on)
		back = Vector3(-0.12, maxf(0.0, -sin(phr)) * 0.25, -0.05 + cos(phr) * 0.42).lerp(back, on)
		front_ang = lerpf(80.0, front_ang, on)
		back_ang = lerpf(80.0, back_ang, on)
	elif _walk_mode:
		# walking forward (chest first) to the loose board; the last step lands on the deck
		var phk: float = _phase_t * 7.0
		var on_k: float = _step_on
		front = Vector3(cos(phk) * 0.28, maxf(0.0, sin(phk)) * 0.14, -0.1).lerp(front, on_k)
		back = Vector3(-cos(phk) * 0.28, maxf(0.0, -sin(phk)) * 0.14, 0.1).lerp(back, on_k)
		front_ang = lerpf(0.0, front_ang, on_k)
		back_ang = lerpf(0.0, back_ang, on_k)
	elif walking:
		# up and walking to the board; the last steps land on the deck
		var span: float = maxf(sk.bail_duration - _getup_at(sk), 0.05)
		var wu: float = clampf((sk.bail_time - _getup_at(sk)) / span, 0.0, 1.0)
		var phw: float = sk.bail_time * 7.0
		var on2: float = clampf((wu - 0.7) / 0.3, 0.0, 1.0)
		front = Vector3(0.1, maxf(0.0, sin(phw)) * 0.15, -0.05 - cos(phw) * 0.3).lerp(front, on2)
		back = Vector3(-0.1, maxf(0.0, -sin(phw)) * 0.15, -0.05 + cos(phw) * 0.3).lerp(back, on2)
		front_ang = lerpf(85.0, front_ang, on2)
		back_ang = lerpf(85.0, back_ang, on2)
	elif bailing:
		var amp: float = 0.15 if sk.bail_kind == "slam" else 0.3
		var w: float = sin(sk.bail_time * 11.0)
		front = Vector3(0.35, 0.25 + w * amp, -0.55)
		back = Vector3(-0.35, 0.35 - w * amp, 0.5)
	# feet ride the board's tilt on the ground and on rails (manuals, boardslides), not its flips in the air
	var on_board: bool = sk.state == Skater.State.GROUND or sk.state == Skater.State.GRIND
	var feet_xf: Transform3D = bt if on_board else Transform3D.IDENTITY
	_rig_leg("l", front, front_ang, feet_xf)
	_rig_leg("r", back, back_ang, feet_xf)

	# arms: out for balance, onto the board for grabs
	var sh_l: Vector3 = (_glob[_b["clavicle_l"]] * _rest_local[_b["upperarm_l"]]).origin
	var sh_r: Vector3 = (_glob[_b["clavicle_r"]] * _rest_local[_b["upperarm_r"]]).origin
	var spread: float = arms_out
	# balance arms: out and a little forward, elbows soft, never a stiff T
	var free_l: Vector3 = sh_l + Vector3(0.12 + 0.1 * spread, -0.52 + 0.4 * spread, -0.18 - 0.24 * spread)
	var free_r: Vector3 = sh_r + Vector3(0.06 + 0.05 * spread, -0.5 + 0.36 * spread, 0.2 + 0.26 * spread)
	if (bailing and sk.bail_kind == "runout") or walking:
		var ph2: float = sk.bail_time * (10.0 if not walking else 7.0)
		var sw: float = 0.35 if not walking else 0.2
		free_l = sh_l + Vector3(0.1, -0.42, -0.05 + cos(ph2) * sw)
		free_r = sh_r + Vector3(-0.08, -0.42, 0.05 - cos(ph2) * sw)
	elif bailing:
		var w2: float = sin(sk.bail_time * 9.0)
		free_l = sh_l + Vector3(0.15, 0.35 + w2 * 0.2, -0.55)
		free_r = sh_r + Vector3(-0.1, 0.35 - w2 * 0.2, 0.55)
	var hand_l: Vector3 = free_l
	var hand_r: Vector3 = free_r
	if grab_amt > 0.01 and sk.grab_kind != "":
		var gp: Array = _grab_targets(sk.grab_kind, bt)
		hand_l = free_l.lerp(gp[0], grab_amt * float(gp[2]))
		hand_r = free_r.lerp(gp[1], grab_amt * float(gp[3]))
	var elbow_back: Vector3 = Vector3(-0.6, -0.3, 0.0)
	_limb("upperarm_l", "lowerarm_l", "hand_l", hand_l, elbow_back + Vector3(0, 0, -0.3), _rest_pole_arm("l"))
	_limb("upperarm_r", "lowerarm_r", "hand_r", hand_r, elbow_back + Vector3(0, 0, 0.3), _rest_pole_arm("r"))
	for side in ["l", "r"]:
		_pose_bone(_b["hand_" + side], _rotated(_b["hand_" + side], Basis.IDENTITY))
	# everything else follows at rest
	for i in skel.get_bone_count():
		var nm: String = skel.get_bone_name(i)
		if nm.begins_with("index") or nm.begins_with("middle") or nm.begins_with("ring") or nm.begins_with("pinky") or nm.begins_with("thumb"):
			_rest_follow(i)


# ------------------------------------------------------------------ physical bails

## Skater checks for this: a rider with a ragdoll takes over its own bails.
func physical_bail() -> bool:
	return true


func sync_from(sk: Skater, dt: float) -> void:
	if sk.state == Skater.State.BAIL and sk.bail_mode == "physical":
		_physical(sk, dt)
		return
	if phys_phase != "":
		_end_physical()                        # respawned or reset mid-bail
	super.sync_from(sk, dt)


func _physical(sk: Skater, dt: float) -> void:
	_phase_t += dt
	match phys_phase:
		"":
			_begin_fall(sk)
		"fall":
			sk.bail_focus = ragdoll.pelvis_position() - Vector3.UP * 0.6
			if _apart_t > 0.0:
				_apart_t -= dt
				if _apart_t <= 0.0 and loose != null:
					ragdoll.sim.physical_bones_remove_collision_exception(loose.get_rid())
			_still_t = _still_t + dt if ragdoll.core_speed() < SETTLE_SPEED else 0.0
			if (_phase_t > 0.8 and _still_t > 0.3) or _phase_t > 4.5:
				_begin_getup(sk)
		"getup", "walk":
			_walk(sk, dt)


func _begin_fall(sk: Skater) -> void:
	phys_phase = "fall"
	_phase_t = 0.0
	_still_t = 0.0
	# the board flies off on its own with the rider's speed (and some of its spin), from where it is now
	loose = LooseBoard.new()
	var holder: Node = sk.get_parent()
	holder.add_child(loose)
	var right: Vector3 = sk.hdg.cross(Vector3.UP).normalized()
	var spin: Vector3 = Vector3.UP * sk.spin_vel * 0.6 + right * randf_range(-3.0, 3.0) * sk.bail_severity
	# the board shoots out along its length, a little faster than the body; for a moment the two ignore each
	# other (the feet start inside the deck, and physics would fling them apart or glue the rider to it)
	var along: Vector3 = -board.global_transform.basis.z
	var kick: Vector3 = along * signf(sk.bail_velocity.dot(along)) * 1.5
	loose.setup(board.global_transform, sk.bail_velocity * 1.05 + kick, spin)
	ragdoll.sim.physical_bones_add_collision_exception(loose.get_rid())
	_apart_t = 0.35
	board.visible = false
	# the body keeps going the way it was going, pitching forward the harder the crash
	var w: Vector3 = Vector3.UP * sk.spin_vel * 0.4 - right * (1.0 + sk.bail_severity * 4.0)
	ragdoll.start(sk.bail_velocity * 0.9, w)


func _begin_getup(sk: Skater) -> void:
	var poses: Array[Transform3D] = ragdoll.world_poses()
	ragdoll.stop()
	var pelvis: Vector3 = poses[_b["pelvis"]].origin
	_walk_pos = _ground_under(pelvis)
	var to_board: Vector3 = loose.global_position - _walk_pos
	to_board.y = 0.0
	_walk_dir = to_board.normalized() if to_board.length() > 0.2 else Vector3(sk.hdg.x, 0.0, sk.hdg.z).normalized()
	_place_walker()
	var inv: Transform3D = model.global_transform.affine_inverse()
	_blend_from.clear()
	for t in poses:
		_blend_from.append(inv * t)
	_blend_w = 0.0
	_walk_mode = true
	_step_on = 0.0
	phys_phase = "getup"
	_phase_t = 0.0


func _walk(sk: Skater, dt: float) -> void:
	var target: Vector3 = loose.global_position
	var to: Vector3 = target - _walk_pos
	to.y = 0.0
	var dist: float = to.length()
	if phys_phase == "getup":
		_blend_w = clampf(_phase_t / GETUP_TIME, 0.0, 1.0)
		_blend_w = _blend_w * _blend_w * (3.0 - 2.0 * _blend_w)
		if _phase_t >= GETUP_TIME:
			_blend_w = 1.0
			phys_phase = "walk"
			_walk_pace = maxf(sk.tune.walk_speed, dist / 1.4)   # a far board: jog to it
	else:
		var pace: float = _walk_pace
		if dist > 0.02:
			_walk_dir = _walk_dir.slerp(to / dist, 1.0 - exp(-8.0 * dt)).normalized()
			_walk_pos += (to / dist) * minf(pace * dt, dist)
			_walk_pos = _ground_under(_walk_pos + Vector3.UP * 0.5)
		_step_on = 1.0 - clampf(dist / 0.6, 0.0, 1.0)
		if dist < 0.06:
			var stand: Transform3D = loose.stand_transform()
			stand.origin = _ground_under(stand.origin + Vector3.UP * 0.5)
			_end_physical()
			sk.finish_physical_bail(stand)
			return
	_place_walker()
	sk.bail_focus = _walk_pos
	hip_h = 0.82
	lean = 6.0
	twist = 0.0
	sway = 0.0
	arms_out = 0.25
	feet_lift = 0.0
	board_lift = 0.0
	board_pitch = 0.0
	board_roll = 0.0
	board_yaw = 0.0
	grab_amt = 0.0
	_apply_rig(sk)


## Stand the visual up at the walker's spot, chest (+X) toward where it is walking.
func _place_walker() -> void:
	var x: Vector3 = _walk_dir
	var z: Vector3 = x.cross(Vector3.UP).normalized()
	global_transform = Transform3D(Basis(x, Vector3.UP, z), _walk_pos)
	vis_n = Vector3.UP


func _ground_under(p: Vector3) -> Vector3:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 6.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else Vector3(p.x, 0.0, p.z)


func _end_physical() -> void:
	if ragdoll.simulating():
		ragdoll.stop()
	if loose != null and is_instance_valid(loose):
		loose.queue_free()
	loose = null
	board.visible = true
	phys_phase = ""
	_walk_mode = false
	_blend_w = 1.0
	_blend_from.clear()


## The back foot through one push: lift off the deck, plant on the ground beside the board ahead of the back
## truck, push back along the ground, then swing up and back onto the tail. Returns [foot, angle, hip drop].
func _push_stride(ph: float) -> Array:
	var deck: Vector3 = Vector3(0.0, DECK, FOOT_BACK)
	var plant: Vector3 = Vector3(0.2, 0.0, -0.02)
	var reach: Vector3 = Vector3(0.2, 0.0, 0.55)
	var foot: Vector3
	var ang: float
	if ph < 0.18:                                   # lift and step down beside the board
		var k: float = ph / 0.18
		var e: float = k * k * (3.0 - 2.0 * k)
		foot = deck.lerp(plant, e) + Vector3(0, sin(k * PI) * 0.08, 0)
		ang = lerpf(BACK_FOOT_ANGLE, -75.0, e)
	elif ph < 0.62:                                 # push back along the ground
		var k2: float = (ph - 0.18) / 0.44
		foot = plant.lerp(reach, k2 * k2 * (3.0 - 2.0 * k2))
		ang = -75.0
	elif ph < 0.88:                                 # swing back up onto the tail
		var k3: float = (ph - 0.62) / 0.26
		var e3: float = k3 * k3 * (3.0 - 2.0 * k3)
		foot = reach.lerp(deck, e3) + Vector3(0, sin(k3 * PI) * 0.16, 0)
		ang = lerpf(-75.0, BACK_FOOT_ANGLE, e3)
	else:
		foot = deck
		ang = BACK_FOOT_ANGLE
	var on_ground: float = clampf(1.0 - absf(ph - 0.4) / 0.3, 0.0, 1.0)
	return [foot, ang, on_ground * 0.06]


func _bail_body_offset(sk: Skater) -> Vector3:
	return sk.rider_position() - sk.global_position


## The rest pose's knee (or elbow) side, in model space: knees bend toward the chest (+X), elbows behind.
func _rest_pole_leg() -> Vector3:
	return Vector3(1, 0, 0)


func _rest_pole_arm(_side: String) -> Vector3:
	return Vector3(-1, 0, 0)


func _rig_leg(side: String, sole: Vector3, foot_angle: float, board_xf: Transform3D) -> void:
	# the foot turns about the up axis (toes across the board, front foot angled to the nose) and rides the
	# board's tilt; the ankle sits above and behind the sole centre
	var turn: Basis = board_xf.basis * Basis(Vector3.UP, deg_to_rad(foot_angle))
	var sole_w: Vector3 = board_xf * (sole - Vector3(0, board_lift, 0)) if board_xf != Transform3D.IDENTITY else sole
	var ankle: Vector3 = sole_w + turn * _ankle_off
	var knee_pole: Vector3 = Vector3(1.0, 0.1, -0.35 if side == "l" else 0.25)
	_limb("thigh_" + side, "calf_" + side, "foot_" + side, ankle, knee_pole, _rest_pole_leg())
	var f: int = _b["foot_" + side]
	var fg: Transform3D = _glob[_parent[f]] * _rest_local[f]
	_pose_bone(f, Transform3D(turn * _rest_model[f].basis, fg.origin))
	_rest_follow(_b["ball_" + side])


## [left hand target, right hand target, use left, use right] for a grab, on the board as it is posed now.
func _grab_targets(kind: String, bt: Transform3D) -> Array:
	var toe: Vector3 = bt * Vector3(0.1, DECK, -0.02)
	var heel: Vector3 = bt * Vector3(-0.1, DECK, -0.02)
	var nose: Vector3 = bt * Vector3(0.0, DECK + 0.03, -0.36)
	match kind:
		"none":
			return [toe, toe, 0.0, 1.0]       # indy: back hand, toe edge
		"left":
			return [heel, heel, 1.0, 0.0]     # melon
		"right":
			return [toe, toe, 1.0, 0.0]       # mute
		"forward":
			return [nose, nose, 1.0, 0.0]     # nosegrab
		"back":
			return [heel, heel, 1.0, 0.0]     # method
	return [toe, toe, 0.0, 0.0]


## Skinned meshes keep their rest bounds, so measure the posed bones instead and lift the rider clear.
func _keep_above(contact: Vector3) -> void:
	var lowest: float = 0.0
	var gx: Transform3D = model.global_transform
	for nm in ["head", "hand_l", "hand_r", "foot_l", "foot_r", "ball_l", "ball_r", "pelvis", "calf_l", "calf_r", "lowerarm_l", "lowerarm_r"]:
		var p: Vector3 = gx * _glob[_b[nm]].origin
		lowest = minf(lowest, (p - contact).dot(vis_n) - 0.1)
	if lowest < 0.0:
		global_position += vis_n * (-lowest)
