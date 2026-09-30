class_name RiderRig
extends Node3D
## The rider: a skinned character (blender/character.py, MPFB game-engine skeleton) on the real-sized board
## (blender/board.py). Each frame it works out a pose from what the skater is doing (crouch, lean, twist,
## pushing, flips, grabs, grinds, manuals) as a handful of smoothed numbers, then turns those into bones:
## hips and spine, both feet flat on the deck by two-bone leg IK, hands by arm IK (onto the board for grabs),
## the head turned toward where the board is going. Crashes are physical: a Ragdoll and a LooseBoard take
## over, then the rider gets up, walks to the board and steps on (see "physical bails").
##
## Everything is worked out in "model space": nose toward -Z, up +Y, chest toward +X for a regular stance.
## The character glb faces +Z, so it sits in a container turned +90 degrees about Y, which also puts its
## left foot toward the nose.

const BOARD_SCENE: PackedScene = preload("res://assets/models/board.glb")
const DECK: float = 0.11                 # deck top above the ground
const LEG_FRAC: float = 0.9              # hip_h fractions map onto this share of the real leg length
const FOOT_FRONT: float = -0.22          # foot centres along the deck (over the bolts)
const FOOT_BACK: float = 0.21
const FRONT_FOOT_ANGLE: float = 20.0     # the front foot turns toward the nose, the back foot a little the other way
const BACK_FOOT_ANGLE: float = -8.0
const HEAD_LOOK: float = 70.0            # head turned from the chest toward the nose, degrees
const CAPSULE_TO_CONTACT: float = 0.02
const GETUP_TIME: float = 0.75
const SETTLE_SPEED: float = 0.45
const WALK_TURN: float = 5.0             # rad/s: turning round toward the board before walking to it
const CARRY_OFFSET: Vector3 = Vector3(0.36, -0.4, 0.0)   # shoulders' midpoint -> the carried thing (chest is +X)
const CARRY_HALF_W: float = 0.17

var char_key: String = "dev"
var model: Node3D
var board: Node3D
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

# the pose, as smoothed numbers
var hip_h: float = 0.68
var lean: float = 0.0            # torso pitch, + leans forward (degrees)
var twist: float = 0.0           # torso twist toward travel (degrees)
var sway: float = 0.0            # sideways lean into turns (degrees)
var arms_out: float = 0.5
var board_lift: float = 0.0
var board_pitch: float = 0.0
var board_roll: float = 0.0
var board_yaw: float = 0.0
var feet_lift: float = 0.0
var grab_amt: float = 0.0
var vis_n: Vector3 = Vector3.UP
var _t: float = 0.0
var carry_item: Node3D = null            # something held in both hands in front of the belly (the cake)

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
var _gait: float = 0.0                   # leg cycle phase for walking / running
var _stride: float = 0.28


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
	style_board(board, char_key)
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
	prepare_character(ch, 1.5)
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


## Each rider's deck graphic (the bottom of the board): base, band, mark, pinstripe.
const DECKS: Dictionary = {
	"dev": [Color(0.13, 0.15, 0.19), Color(1.0, 0.56, 0.16), Color(0.25, 0.85, 0.8), Color(0.9, 0.9, 0.86)],
	"musician": [Color(0.08, 0.08, 0.08), Color(0.85, 0.68, 0.3), Color(0.85, 0.68, 0.3), Color(0.6, 0.15, 0.15)],
	"vlogger": [Color(0.95, 0.94, 0.9), Color(0.85, 0.2, 0.2), Color(0.12, 0.12, 0.14), Color(0.85, 0.2, 0.2)],
	"dad": [Color(0.24, 0.4, 0.28), Color(0.95, 0.9, 0.76), Color(0.95, 0.72, 0.2), Color(0.95, 0.9, 0.76)],
	"actor": [Color(0.3, 0.18, 0.45), Color(0.98, 0.8, 0.3), Color(0.95, 0.95, 0.95), Color(0.98, 0.8, 0.3)],
}
static var _deck_art: Dictionary = {}


## The deck's bottom as a small texture: u runs across the board, v along it (tail at 0, nose at 1).
static func deck_art(key: String) -> Texture2D:
	if _deck_art.has(key):
		return _deck_art[key]
	var c: Array = DECKS.get(key, DECKS["dev"])
	var w: int = 64
	var h: int = 256
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var v: float = (y + 0.5) / h
		for x in w:
			var u: float = (x + 0.5) / w
			var col: Color = c[0]
			if absf(u - 0.5) > 0.4 and absf(u - 0.5) < 0.43:
				col = c[3]                                           # pinstripes down both edges
			var band: float = v - 0.24 - (u - 0.5) * 0.25                # a slanted band toward the tail
			if absf(band) < 0.055:
				col = c[1]
			var dx: float = (u - 0.5) * 8.0
			var dy: float = (v - 0.7) * 31.5                             # a round mark toward the nose (real inches)
			var r: float = sqrt(dx * dx + dy * dy)
			if r < 2.4:
				col = c[2] if r > 1.5 or r < 0.7 else c[0]
			img.set_pixel(x, h - 1 - y, col)
	img.generate_mipmaps()
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_deck_art[key] = tex
	return tex


static func style_board(root: Node, rider_key: String = "dev") -> void:
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
					m.albedo_color = Color.WHITE
					m.albedo_texture = deck_art(rider_key)
			inst.set_surface_override_material(s, m)


## Tidy a freshly instanced character glb. Skinned meshes are culled by their rest bounds, so poses need a
## margin; eyes, brows and lashes are too small to show in a shadow but would cost a draw call in every
## shadow pass.
static func prepare_character(ch: Node, cull_margin: float) -> void:
	for mi in ch.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.extra_cull_margin = cull_margin
		var nm: String = String(m.name)
		if nm.contains("eyebrow") or nm.contains("eyelash") or nm.contains("low-poly"):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not (nm.contains("eyebrow") or nm.contains("eyelash")):     # brows and lashes stay soft
			for s in m.mesh.get_surface_count():
				_cutout(m.mesh.surface_get_material(s) as BaseMaterial3D)
		if nm == "Body":
			for s in m.mesh.get_surface_count():
				_skin(m.mesh.surface_get_material(s) as BaseMaterial3D)


## Skin without subsurface scattering (not in the Compatibility renderer) looks like plastic: a soft warm rim at
## grazing angles and a little warm backlight (ears and fingers against the sun) stand in for light passing
## through skin. Changes the imported material once for everyone.
static func _skin(mat: BaseMaterial3D) -> void:
	if mat == null or mat.rim_enabled:
		return
	mat.roughness = 0.62
	mat.metallic_specular = 0.35
	mat.rim_enabled = true
	mat.rim = 0.35
	mat.rim_tint = 0.65
	mat.backlight_enabled = true
	mat.backlight = Color(0.32, 0.12, 0.08)


## Hair arrives alpha-blended (Blender 5 dropped the material setting that exported it as a cutout), which
## sorts badly and leaves dark patches on the scalp. A hard cutout smoothed by alpha to coverage
## (MSAA) looks right, sorts right and casts proper shadows. Changes the imported material once for everyone.
static func _cutout(mat: BaseMaterial3D) -> void:
	if mat == null or mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			or mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		return
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.4
	mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED


## Returns [mid, end] for a two-bone chain from `origin` reaching `target`, bending toward `pole`.
static func ik(origin: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var to_t: Vector3 = target - origin
	var dist: float = clampf(to_t.length(), absf(l1 - l2) + 0.02, l1 + l2 - 0.004)
	var dir: Vector3 = to_t.normalized() if to_t.length() > 0.0001 else Vector3.DOWN
	var a: float = (dist * dist + l1 * l1 - l2 * l2) / (2.0 * dist)
	var h: float = sqrt(maxf(l1 * l1 - a * a, 0.0))
	var perp: Vector3 = pole - dir * pole.dot(dir)
	perp = perp.normalized() if perp.length() > 0.001 else Vector3.RIGHT
	return [origin + dir * a + perp * h, origin + dir * dist]


# ------------------------------------------------------------------ riding

## Riding (not crashed): place the rider on the board and pose it.
func _sync_riding(sk: Skater, dt: float) -> void:
	_t += dt
	var n: Vector3 = Vector3.UP
	var fwd: Vector3 = sk.facing()
	match sk.state:
		Skater.State.GROUND:
			n = sk.board_n
		Skater.State.AIR:
			n = sk.air_up                  # vert airs: side-on to the wall, turning in the wall's plane
			fwd = sk.air_fwd
	var blended: Vector3 = vis_n.lerp(n.normalized(), 1.0 - exp(-16.0 * dt))
	vis_n = blended.normalized() if blended.length() > 0.2 else Vector3.UP
	fwd = (fwd - vis_n * fwd.dot(vis_n)).normalized()
	if fwd.length() < 0.5:
		fwd = Vector3(0, 0, -1)
	var pos: Vector3 = sk.render_position() + Vector3.UP * (Skater.CAPSULE_R + CAPSULE_TO_CONTACT) - n * Skater.CAPSULE_R
	global_transform = Transform3D(Basis(fwd.cross(vis_n), vis_n, -fwd), pos)
	_pose(sk, dt)
	_apply_rig(sk)


static func _approach(cur: float, tgt: float, rate: float, dt: float) -> float:
	return lerpf(cur, tgt, 1.0 - exp(-rate * dt))


func _pose(sk: Skater, dt: float) -> void:
	var st: int = sk.state
	var hip_t: float = 0.70
	var lean_t: float = 8.0
	var twist_t: float = 25.0
	var arms_t: float = 0.45
	var lift_t: float = 0.0
	var pitch_t: float = 0.0
	var roll_t: float = 0.0
	var yaw_t: float = 0.0
	var feet_t: float = 0.0
	var sway_t: float = 0.0
	var grab_t: float = 0.0
	var speed: float = sk.velocity.length()
	var fakie: bool = sk.stance == "fakie"
	match st:
		Skater.State.GROUND:
			hip_t = 0.72 - 0.17 * sk.crouch
			lean_t = 8.0 + 22.0 * sk.crouch + clampf(speed * 0.4, 0.0, 6.0)
			sway_t = sk.lean * 14.0
			arms_t = 0.5 + absf(sk.lean) * 0.4
			if sk.manual_on:
				hip_t = 0.66
				arms_t = 0.95
				if sk.manual_kind == "nose":
					pitch_t = -20.0 - sk.manual_balance * 6.0
					lean_t = 20.0
				else:
					pitch_t = 24.0 + sk.manual_balance * 6.0
					lean_t = -8.0 - sk.manual_balance * 6.0
			if sk.pushing and not sk.braking and speed < 7.0:
				lean_t += 8.0
			# standing still: breathe, shift weight, glance about (a frozen statue read as a mannequin)
			var still: float = 1.0 - clampf(speed / 0.8, 0.0, 1.0)
			if still > 0.0 and not sk.manual_on and not sk.pushing:
				hip_t += sin(_t * 1.6) * 0.006 * still
				lean_t += (sin(_t * 1.6 + 0.8) * 1.2 + sin(_t * 0.37) * 2.0) * still
				sway_t += sin(_t * 0.23 + 1.3) * 3.0 * still
				twist_t += sin(_t * 0.31) * 7.0 * still
				arms_t -= 0.12 * still
		Skater.State.AIR:
			var rising: bool = sk.velocity.y > 0.8
			hip_t = 0.80 if rising else 0.66     # stretch on the pop, tuck on the way down
			lean_t = 4.0
			arms_t = 0.85
			feet_t = 0.03 if rising else 0.08
			lift_t = 0.0
			if sk.flip_kind != "":
				lift_t = 0.05
				feet_t = 0.06
				arms_t = 1.0
				var f: float = sk.flip_t
				var ease_f: float = f * f * (3.0 - 2.0 * f)
				match sk.flip_kind:
					"none":
						roll_t = 360.0 * ease_f
					"left":
						roll_t = -360.0 * ease_f
					"right":
						yaw_t = 180.0 * ease_f
					"forward":
						roll_t = 360.0 * ease_f
						yaw_t = 180.0 * ease_f
					"back":
						pitch_t = 360.0 * ease_f
			if sk.grab_kind != "":
				grab_t = 1.0
				hip_t = 0.66
				lean_t = 26.0
				feet_t = 0.16
				lift_t = 0.24
				pitch_t = -8.0
				arms_t = 0.7
		Skater.State.GRIND:
			hip_t = 0.58
			lean_t = 20.0
			arms_t = 0.95
			yaw_t = rad_to_deg(sk.grind_board_turn)
			roll_t = 6.0
			sway_t = sin(_t * 9.0) * 3.0
			if sk.lip_kind != "":
				# stalled on the coping: weight back over the ramp, arms out, swaying with the balance
				sway_t = sk.lip_balance * 18.0
				arms_t = 0.9
				roll_t = 0.0
				match sk.lip_kind:
					"Rock to Fakie":
						hip_t = 0.64
						lean_t = 6.0
						pitch_t = 10.0
					"Nose Stall":
						hip_t = 0.62
						lean_t = -4.0
						pitch_t = 28.0
					"Blunt to Fakie":
						hip_t = 0.56
						lean_t = 18.0
						pitch_t = 58.0
					"Disaster":
						hip_t = 0.6
						lean_t = 10.0
						pitch_t = -14.0
						roll_t = 12.0
					"Axle Stall":
						hip_t = 0.66
						lean_t = 4.0
						pitch_t = 0.0
	if sk.wallplant_t > 0.12:
		pitch_t = -70.0              # tail up, wheels on the wall
		hip_t = 0.62
	if fakie:
		twist_t = -twist_t           # turned toward the way it is going (over the other shoulder)
	hip_h = _approach(hip_h, hip_t, 30.0 if st == Skater.State.AIR else 16.0, dt)
	lean = _approach(lean, lean_t, 12.0, dt)
	twist = _approach(twist, twist_t, 10.0, dt)
	sway = _approach(sway, sway_t, 10.0, dt)
	arms_out = _approach(arms_out, arms_t, 12.0, dt)
	board_lift = _approach(board_lift, lift_t, 18.0, dt)
	feet_lift = _approach(feet_lift, feet_t, 18.0, dt)
	grab_amt = _approach(grab_amt, grab_t, 14.0, dt)
	if sk.flip_kind != "" or (st == Skater.State.GRIND and sk.lip_kind == ""):
		board_roll = roll_t
		board_yaw = yaw_t
		board_pitch = pitch_t
	else:
		board_roll = _approach(board_roll, roll_t, 20.0, dt)
		board_yaw = _approach(board_yaw, yaw_t, 20.0, dt)
		board_pitch = _approach(board_pitch, pitch_t, 14.0, dt)


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
	var chain: Array = ik(head, target, _up_len[root], _up_len[mid], pole)
	_aim(r, m, chain[0], pole, rest_pole)
	_aim(m, e, chain[1], pole, rest_pole)


# ------------------------------------------------------------------ per frame

func _apply_rig(sk: Skater) -> void:
	# board: flips, grabs, manuals and slides tilt and spin it about the deck centre
	var bt: Transform3D
	var pivot: Vector3 = Vector3(0, DECK, 0)
	var rot: Basis = Basis.from_euler(Vector3(deg_to_rad(board_pitch), deg_to_rad(board_yaw), deg_to_rad(board_roll)), EULER_ORDER_YXZ)
	bt = Transform3D(rot, pivot - rot * pivot + Vector3(0, board_lift, 0))
	board.transform = bt                       # (hidden while the loose board is out in the world)

	# hips: hip_h is a pose number (0.72 riding tall .. 0.55 deep crouch) mapped onto a share of this leg
	var frac: float = clampf((hip_h - 0.145) / 0.665, 0.45, 1.05)
	var hip_y: float = DECK + frac * LEG_FRAC * (_leg_len - _ankle_off.y) + _ankle_off.y * 0.2
	if _walk_mode:
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

	# legs: feet flat on the deck (or walking / running on the ground after a bail)
	var lift: float = feet_lift + board_lift * 0.6
	var front: Vector3 = Vector3(0.0, DECK + lift, FOOT_FRONT)
	var back: Vector3 = Vector3(0.0, DECK + lift, FOOT_BACK)
	var front_ang: float = FRONT_FOOT_ANGLE
	var back_ang: float = BACK_FOOT_ANGLE
	if not stride.is_empty():
		back = stride[0]
		back_ang = stride[1]
		front_ang = lerpf(FRONT_FOOT_ANGLE, 65.0, push_amt)   # front foot swivels to point up the board
	if _walk_mode:
		# walking forward (chest first) to the loose board; the last step lands on the deck
		var phk: float = _gait
		var on_k: float = _step_on
		var lift_k: float = 0.14 + (_stride - 0.28) * 0.5
		# a foot lifts while it swings forward (x rising) and is planted while it pushes back: the lift used to
		# come in the backward half, which read as walking backwards
		front = Vector3(cos(phk) * _stride, maxf(0.0, -sin(phk)) * lift_k, -0.1).lerp(front, on_k)
		back = Vector3(-cos(phk) * _stride, maxf(0.0, sin(phk)) * lift_k, 0.1).lerp(back, on_k)
		front_ang = lerpf(0.0, front_ang, on_k)
		back_ang = lerpf(0.0, back_ang, on_k)
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
	if _walk_mode:
		var sw: float = 0.12 + (_stride - 0.28) * 0.8
		# arms swing forward and back (walking is chest first, +X), each against its own leg
		free_l = sh_l + Vector3(0.04 - cos(_gait) * sw, -0.44, -0.06)
		free_r = sh_r + Vector3(0.04 + cos(_gait) * sw, -0.44, 0.06)
	var hand_l: Vector3 = free_l
	var hand_r: Vector3 = free_r
	if carry_item != null and is_instance_valid(carry_item) and not _walk_mode:
		# both hands under the sides of whatever is carried, held out in front of the belly
		var c: Vector3 = (sh_l + sh_r) * 0.5 + CARRY_OFFSET
		hand_l = c + Vector3(-0.03, -0.02, -CARRY_HALF_W)
		hand_r = c + Vector3(-0.03, -0.02, CARRY_HALF_W)
		carry_item.global_transform = global_transform * Transform3D(Basis.IDENTITY, c + Vector3(0.0, -0.06, 0.0))
	elif grab_amt > 0.01 and sk.grab_kind != "":
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
	_sync_riding(sk, dt)


func _physical(sk: Skater, dt: float) -> void:
	_phase_t += dt
	match phys_phase:
		"":
			_spawn_loose(sk)
			if sk.run_state == "run":
				_begin_run(sk)
			else:
				_start_ragdoll(sk)
		"run":
			if sk.run_state == "run":
				_run(sk, dt)
			elif sk.run_state == "stopped":
				_walk_pos = _ground_under(sk.global_position + Vector3.UP * 0.5)
				var to: Vector3 = loose.global_position - _walk_pos
				to.y = 0.0
				_walk_pace = maxf(sk.tune.walk_speed, to.length() / 1.4)
				phys_phase = "walk"
				_walk(sk, dt)
			else:
				_start_ragdoll(sk)          # tripped: into the ragdoll from the running pose
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


## The board flies off on its own with the rider's speed (and some of its spin), from where it is now.
func _spawn_loose(sk: Skater) -> void:
	loose = LooseBoard.new()
	loose.rider_key = char_key
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


## The body keeps going the way it was going, pitching forward the harder the crash.
func _start_ragdoll(sk: Skater) -> void:
	phys_phase = "fall"
	_phase_t = 0.0
	_still_t = 0.0
	_walk_mode = false
	_blend_w = 1.0
	var right: Vector3 = sk.hdg.cross(Vector3.UP).normalized()
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
		_gait += dt * 7.0
		_stride = 0.28
		if dist > 0.02:
			# turn to face the board first (it is often behind: the run-out carried the rider past it), then
			# walk; slerping toward a direction right behind never turned, so the rider walked backwards
			var want: Vector3 = to / dist
			var ang: float = _walk_dir.signed_angle_to(want, Vector3.UP)
			if absf(ang) > PI - 0.05:
				ang = PI - 0.05                 # straight behind: pick a side and turn
			_walk_dir = _walk_dir.rotated(Vector3.UP, clampf(ang, -WALK_TURN * dt, WALK_TURN * dt)).normalized()
			var facing: float = clampf(_walk_dir.dot(want), 0.0, 1.0)
			_walk_pos += want * minf(pace * dt * facing * facing, dist)
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


## A small mistake: off the board and running it out on foot. The capsule is the body (Skater._run_out);
## this blends from the riding pose into a run whose stride follows the real speed.
func _begin_run(sk: Skater) -> void:
	var inv_from: Transform3D = model.global_transform
	var world: Array[Transform3D] = []
	for g in _glob:
		world.append(inv_from * g)
	var h: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z)
	_walk_dir = h.normalized() if h.length() > 0.2 else Vector3(sk.hdg.x, 0.0, sk.hdg.z).normalized()
	_walk_pos = sk.global_position
	_place_walker()
	var inv: Transform3D = model.global_transform.affine_inverse()
	_blend_from.clear()
	for t in world:
		_blend_from.append(inv * t)
	_blend_w = 0.0
	_walk_mode = true
	_step_on = 0.0
	phys_phase = "run"
	_phase_t = 0.0


func _run(sk: Skater, dt: float) -> void:
	var h: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z)
	var spd: float = h.length()
	if spd > 0.2:
		_walk_dir = _walk_dir.slerp(h / spd, 1.0 - exp(-10.0 * dt)).normalized()
	_walk_pos = sk.global_position
	_place_walker()
	_blend_w = minf(1.0, _blend_w + dt / 0.25)
	_gait += dt * (4.0 + spd * 1.4)
	_stride = 0.28 + spd * 0.06
	sk.bail_focus = _walk_pos
	hip_h = 0.8
	lean = 10.0 - spd * 1.5                    # leaning back against the speed
	twist = 0.0
	sway = 0.0
	arms_out = 0.55
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
