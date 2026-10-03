class_name Npc
extends Node3D
## A bystander (MPFB character, not a rider): stands relaxed (breathing, arms swaying a little), turns its head to
## follow someone, and reacts when asked: claps for a trick, cheers (arms up, waving, bouncing; higher and faster
## for a big combo), winces at a crash (hands to the head, looking down). Poses are set straight on the skeleton:
## arms by two-bone IK, head and neck turned about the vertical axis. The character glb faces +Z.

var char_key: String = "kid_leo"
var watch: Node3D = null                  # who to follow with the eyes (the skater)
var cheer_time: float = 0.0
var cheer_level: int = 1                  # 0 a clap, 1 a cheer, 2 a big one (a big combo)
var wince_time: float = 0.0
var _delay: float = 0.0                   # a reaction starts this much later (people take a moment)
var _pending: Array = []                  # [kind, seconds, level] waiting out the delay
var skel: Skeleton3D
var _b: Dictionary = {}
var _rest_g: Array[Transform3D] = []      # rest global poses (skeleton space)
var _t: float = 0.0
var _seed: float = 0.0
var _root_y: float = 0.0
const HAT_UP: float = 0.2         # head bone origin -> the crown, metres (bone space)


func _ready() -> void:
	var ch: Node3D = (load("res://assets/characters/%s.glb" % char_key) as PackedScene).instantiate()
	add_child(ch)
	skel = ch.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in skel.get_bone_count():
		_b[skel.get_bone_name(i)] = i
		_rest_g.append(skel.get_bone_global_rest(i))
	RiderRig.prepare_character(ch, 1.0)
	_seed = randf() * 10.0
	_root_y = ch.position.y


## A paper party hat (a striped cone with a pom-pom) on the head bone.
func wear_party_hat(color: Color) -> void:
	var att: BoneAttachment3D = BoneAttachment3D.new()
	att.bone_name = "head"
	skel.add_child(att)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.075
	cone.height = 0.2
	cone.radial_segments = 14
	cone.material = m
	var hat: MeshInstance3D = MeshInstance3D.new()
	hat.mesh = cone
	# the head bone runs up the neck into the skull: sit the hat on the crown, tipped back a touch
	hat.position = Vector3(0.0, HAT_UP, -0.01)
	hat.rotation = Vector3(-0.2, 0.0, 0.0)
	att.add_child(hat)
	var pom: SphereMesh = SphereMesh.new()
	pom.radius = 0.028
	pom.height = 0.056
	var pm: StandardMaterial3D = StandardMaterial3D.new()
	pm.albedo_color = Color(0.98, 0.97, 0.94)
	pom.material = pm
	var p: MeshInstance3D = MeshInstance3D.new()
	p.mesh = pom
	p.position = Vector3(0.0, 0.1, 0.0)
	hat.add_child(p)


## Cheer for `seconds`: level 0 claps, 1 cheers, 2 cheers big. A wince in progress isn't cut short by it.
func cheer(seconds: float = 2.5, level: int = 1, delay: float = 0.0) -> void:
	if delay > 0.0:
		_pending.append(["cheer", seconds, level])
		_delay = delay
		return
	if wince_time > 0.0:
		return
	if cheer_time <= 0.0 or level >= cheer_level:
		cheer_level = level
	cheer_time = maxf(cheer_time, seconds)


## A crash: hands to the head, eyes down, for `seconds` (it stops any cheer).
func wince(seconds: float = 1.5, delay: float = 0.0) -> void:
	if delay > 0.0:
		_pending.append(["wince", seconds, 0])
		_delay = delay
		return
	cheer_time = 0.0
	wince_time = maxf(wince_time, seconds)


func _process(dt: float) -> void:
	_t += dt
	if not _pending.is_empty():
		_delay -= dt
		if _delay <= 0.0:
			for r in _pending:
				if r[0] == "wince":
					wince(float(r[1]))
				else:
					cheer(float(r[1]), int(r[2]))
			_pending.clear()
	cheer_time = maxf(0.0, cheer_time - dt)
	wince_time = maxf(0.0, wince_time - dt)
	var mood: String = "wince" if wince_time > 0.0 else ("cheer" if cheer_time > 0.0 else "")
	# a hop while cheering (higher for a big one), breathing while idle
	var ch: Node3D = get_child(0) as Node3D
	var hop: float = 0.0
	if mood == "cheer" and cheer_level >= 1:
		hop = absf(sin(_t * (9.0 if cheer_level == 1 else 11.0))) * (0.06 if cheer_level == 1 else 0.13)
	ch.position.y = _root_y + hop
	_breathe()
	_arms(mood)
	_look(mood == "wince")


## The chest rising and falling a little (spine_03 pitching a degree or so, at about 15 breaths a minute).
func _breathe() -> void:
	if not _b.has("spine_03"):
		return
	var i: int = _b["spine_03"]
	var rest: Quaternion = skel.get_bone_rest(i).basis.get_rotation_quaternion()
	skel.set_bone_pose_rotation(i, rest * Quaternion(Vector3.RIGHT, sin(_t * 1.6 + _seed) * 0.018))


func _arms(mood: String) -> void:
	var head: Vector3 = _rest_g[_b["head"]].origin
	for side in ["l", "r"]:
		var s: float = 1.0 if side == "l" else -1.0          # left arm on +X (the character faces +Z)
		var sh: Vector3 = _rest_g[_b["upperarm_" + side]].origin
		var hand: Vector3
		var pole: Vector3
		if mood == "wince":                                   # hands to the sides of the head, elbows forward
			hand = head + Vector3(s * 0.11, 0.1, 0.04)
			pole = Vector3(s * 0.6, 0.0, 1.0)
		elif mood == "cheer" and cheer_level == 0:           # a clap in front of the chest
			var k: float = absf(sin(_t * 11.0 + _seed))
			hand = Vector3(s * (0.035 + 0.075 * k), sh.y - 0.14, sh.z + 0.3)
			pole = Vector3(s, -0.4, -0.2)
		elif mood == "cheer":
			var rate: float = 10.0 if cheer_level == 1 else 14.0
			var wave: float = sin(_t * rate + (0.0 if side == "l" else 1.7)) * (0.12 if cheer_level == 1 else 0.18)
			hand = sh + Vector3(s * (0.22 + wave), 0.48 if cheer_level == 1 else 0.56, 0.06)
			pole = Vector3(s, 0.0, -0.3)
		else:
			var sway: float = sin(_t * 1.3 + _seed) * 0.02
			hand = sh + Vector3(s * 0.1, -0.54, 0.06 + sway)
			pole = Vector3(s * 0.2, 0.0, -1.0)
		_arm(side, hand, pole)


func _arm(side: String, target: Vector3, pole: Vector3) -> void:
	var ua: int = _b["upperarm_" + side]
	var la: int = _b["lowerarm_" + side]
	var ha: int = _b["hand_" + side]
	var sh: Vector3 = _rest_g[ua].origin
	var l1: float = sh.distance_to(_rest_g[la].origin)
	var l2: float = _rest_g[la].origin.distance_to(_rest_g[ha].origin)
	var chain: Array = RiderRig.ik(sh, target, l1, l2, pole)
	var rest_pole: Vector3 = Vector3(0, 0, -1)
	var g_ua: Basis = _aimed(ua, la, sh, chain[0], pole, rest_pole)
	var parent_g: Basis = _rest_g[skel.get_bone_parent(ua)].basis
	skel.set_bone_pose_rotation(ua, (parent_g.inverse() * g_ua).get_rotation_quaternion())
	var g_la: Basis = _aimed(la, ha, chain[0], chain[1], pole, rest_pole)
	skel.set_bone_pose_rotation(la, (g_ua.inverse() * g_la).get_rotation_quaternion())


func _aimed(i: int, child: int, head: Vector3, target: Vector3, pole: Vector3, rest_pole: Vector3) -> Basis:
	var rest_dir: Vector3 = (_rest_g[child].origin - _rest_g[i].origin).normalized()
	var want: Vector3 = (target - head).normalized()
	return RiderRig._frame(want, pole) * RiderRig._frame(rest_dir, rest_pole).inverse() * _rest_g[i].basis


## Turn the head (and a little of the neck) toward whoever it is watching; wincing, it drops a little too.
func _look(down: bool = false) -> void:
	if watch == null or not is_instance_valid(watch):
		return
	# the rider, not the skater's capsule: in a crash the capsule waits where the fall began
	var at: Vector3 = (watch as Skater).rider_position() if watch is Skater else watch.global_position
	var to: Vector3 = global_transform.affine_inverse() * at
	var yaw: float = clampf(atan2(to.x, to.z), -1.2, 1.2)
	var pitch: float = 0.35 if down else 0.0                  # (about +X: the face, toward +Z, tips down)
	for pair in [["neck_01", 0.35], ["head", 0.65]]:
		var i: int = _b[pair[0]]
		var p: int = skel.get_bone_parent(i)
		var want: Basis = Basis(Vector3.UP, yaw * float(pair[1])) * Basis(Vector3.RIGHT, pitch * float(pair[1])) * _rest_g[i].basis
		var parent_b: Basis = _rest_g[p].basis if pair[0] == "neck_01" else Basis(Vector3.UP, yaw * 0.35) * _rest_g[p].basis
		skel.set_bone_pose_rotation(i, (parent_b.inverse() * want).get_rotation_quaternion())
