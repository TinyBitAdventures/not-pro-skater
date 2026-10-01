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
const KICK: float = 0.085                # board.py: the kicktails rise this much at the very ends
const FLAT_Z: float = 0.235              # board.py: the deck is flat this far either side of its middle
const DECK_HALF_L: float = 0.4
const AXLE: Vector2 = Vector2(0.027, 0.215)   # (height, along) of the back axle; the front one is at -along
const LEG_FRAC: float = 0.9              # hip_h fractions map onto this share of the real leg length
const FOOT_FRONT: float = -0.22          # foot centres along the deck (over the bolts)
const FOOT_BACK: float = 0.21
const FRONT_FOOT_ANGLE: float = 20.0     # the front foot turns toward the nose, the back foot a little the other way
const BACK_FOOT_ANGLE: float = -8.0
# where the feet stand on the deck for each move: [front, back] as (across: + toe edge, along: + tail, angle toward
# the nose in degrees). Real skating moves the feet all the time, and that reads as skating more than anything else
const FEET_CRUISE: Array[Vector3] = [Vector3(0.0, FOOT_FRONT, FRONT_FOOT_ANGLE), Vector3(0.0, FOOT_BACK, BACK_FOOT_ANGLE)]
const FEET_POP: Array[Vector3] = [Vector3(0.01, -0.07, 14.0), Vector3(0.0, 0.29, -10.0)]   # ollie: ball of the foot on the tail
const FEET_MANUAL: Array[Vector3] = [Vector3(0.0, -0.12, 24.0), Vector3(0.0, 0.25, -10.0)]  # back foot over the back truck
const FEET_NOSE: Array[Vector3] = [Vector3(0.0, -0.28, 10.0), Vector3(0.0, 0.07, -16.0)]    # front foot on the nose
const POP_PITCH: float = 26.0            # degrees nose up at the snap of an ollie
const TAIL_Z: float = 0.33               # the tail's tip on the ground: the snap tips the board about it
const OLLIE_TUCK: float = 0.15           # how high the knees bring the board at the top of an ollie
const MANUAL_PITCH: float = 9.0          # nose up in a manual (rocking with the balance)
# grinds: the line is the rail's (ledge's, coping's) top and the skater rides Skater.GRIND_ORIGIN_DY under it, which
# draws the deck 5 cm into the rail: the drawn rider sits up on it, the deck on it for a slide, the trucks for a 50-50
const ON_RAIL: float = 0.152             # the line above the rider's frame (-GRIND_ORIGIN_DY - CAPSULE_TO_CONTACT)
const DECK_BOTTOM: float = 0.098
const HANGER_BOTTOM: float = 0.027
const ABSORB_W: float = 14.0             # rad/s: the legs' spring taking a landing (damped 0.7: one small rebound)
const ABSORB_PER: float = 0.012          # hip drop (pose units, ~1.15 m each) per m/s into the floor: a flat ollie ~11 cm
const SKETCHY_TIME: float = 0.55
const HEAD_LOOK: float = 70.0            # head turned from the chest toward the nose, degrees
const CAPSULE_TO_CONTACT: float = 0.02
const SETTLE_SPEED: float = 0.45
const RELAXED_TONE: float = 0.35         # ragdoll muscle strength once the body is lying still
const WALK_TURN: float = 5.0             # rad/s: turning round toward the board before walking to it
const RUN_BACK_MAX: float = 5.2          # m/s: the fastest run back to the board (faster, the planted feet skate)
const WALK_GIVE_UP: float = 10.0         # s into the walk back: the rider is just put back on the board (a stuck walk;
                                         # SkateTuning.recover_max normally ends a long one first)
const FINGER_CURL: Dictionary = {        # degrees at each knuckle, base to tip: a relaxed hand
	"index": [14.0, 22.0, 12.0], "middle": [18.0, 26.0, 14.0], "ring": [22.0, 28.0, 16.0], "pinky": [26.0, 30.0, 16.0],
	"thumb": [6.0, 10.0, 12.0],
}
const CURL_SIGN: float = -1.0            # which way the palm faces (set by eye; see _setup_fingers)
const GAIT_START: float = 0.26           # set off with the left foot under the body (mid-stance), the right one lifting
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
var feet_lift: float = 0.0              # soles above the grip (on the deck they stand on it: 0)
var grab_amt: float = 0.0
var foot_f: Vector3 = FEET_CRUISE[0]     # where the feet stand on the deck now (see FEET_CRUISE)
var foot_b: Vector3 = FEET_CRUISE[1]
var board_piv: Vector2 = Vector2(DECK, 0.0)   # (height, along): what the board tilts about (the back axle in a manual)
var pelvis_z: float = 0.0                # hips along the board, + toward the tail (over the back wheels in a manual)
var free_feet: float = 0.0               # 0 the feet stand on the deck .. 1 they're off it (a flip goes round below)
var _flip_feet: Array = []               # in a flip: where each sole is (model space), off the deck
var _pop_y: float = 0.0                  # the board's height when it popped (the board leaves the ground after the body)
var _pop_seen: float = -1.0
var _absorb: float = 0.0                 # how far the hips are sunk by a landing now (pose units), and how fast
var _absorb_v: float = 0.0
var _lands: int = 0                      # Skater.lands last seen (a change = a touchdown)
var _since_land: float = 9.0
var _sketchy: float = 0.0                # seconds of arm-waving left after a sketchy landing
var _look_down: float = 0.0              # extra head nod: looking at the landing spot
var _lead: float = 0.0                   # degrees the head leads the shoulders into a spin
var pelvis_x: float = 0.0                # hips across the board, + toward the toe edge (into a frontside carve)
var body_yaw: float = 0.0                # the whole body turned with the board (a boardslide faces down the rail)
var board_shift: Vector2 = Vector2.ZERO  # (across, along) the board moved off the frame's middle (a nose on the rail)
var grind_lift: float = 0.0              # the drawn rider raised onto the rail (see ON_RAIL)
var _fit: Vector3 = Vector3.ZERO         # (pitch, roll degrees, lift): sets all four wheels on the ground (_ground_fit)
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
var _walk_pace: float = 1.5
var _gait: float = 0.0                   # leg cycle phase for walking / running, in cycles (two steps)
# the gait (walking back to the board, jogging, running out a mistake): see _gait_update
var _loco_speed: float = 0.0             # m/s along the ground right now
var _gait_now: Dictionary = {}           # this frame's feet, pelvis and arms (_gait_update)
var _hip_s: float = -1.0                 # the pelvis height, smoothed (-1: not started)
var _stand_hip: float = 0.9              # measured from the rest pose in setup()
var _hip_joint: Vector3 = Vector3.ZERO   # left thigh head relative to the pelvis origin
var _leg_chain: float = 0.84             # thigh + calf
var _arm_len: float = 0.55
var _foot_len: float = 0.25
var _body_k: float = 1.0                 # leg length against an adult's (kids take shorter steps)
var _plant: Array = [null, null]         # a planted foot's [world position, world heading], left and right
var _lift: Array = [null, null]          # where each foot last left the ground (the start of its swing)
var _gait_boost: float = 0.0             # hurries the cycle along while a planted foot is being left behind
var _down: Array = [true, false]         # each foot on the ground? (a foot finishes the swing it started)
var _prev_ph: Array = [0.0, 0.0]
var _lift_ph: Array = [-1.0, -1.0]       # the phase each foot lifted at (its swing runs from there to 1)
var _prev_v: float = 0.0
var _brake: float = 0.0                  # 0..1: slowing hard (a run-out): short quick steps
var _curl_axis: Dictionary = {}          # finger bone -> the axis it curls about toward the palm (rest, model space)
var _getup_keys: Array = []              # [time, pose] through the get-up (see _getup_poses)
var rest_facing: String = ""             # how the body came to rest: "prone", "supine" or "side" (films, tests)


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
	_stand_hip = _rest_model[_b["pelvis"]].origin.y
	_hip_joint = _rest_model[_b["thigh_l"]].origin - _rest_model[_b["pelvis"]].origin
	_leg_chain = _up_len["thigh_l"] + _up_len["calf_l"]
	_arm_len = _up_len["upperarm_l"] + _up_len["lowerarm_l"]
	_foot_len = maxf(0.12, (ball.x - ankle.x) * 1.9)
	_body_k = clampf(_leg_len / 0.92, 0.6, 1.2)
	_setup_fingers()
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
	_ground_fit(sk, dt)
	_pose(sk, dt)
	global_transform.origin += vis_n * grind_lift
	_apply_rig(sk)


## The body tilts to a smoothed board normal (Skater.board_n, then vis_n): on a curved transition that lags behind
## the curve, and the board's ends dug up to 8 cm into the ramp. The board itself sits on what's under its wheels:
## a pitch, a roll and a lift on top of the pose that put all four on the ground (the feet ride the board).
func _ground_fit(sk: Skater, dt: float) -> void:
	var want: Vector3 = Vector3.ZERO          # (pitch, roll, lift)
	if sk.state == Skater.State.GROUND and not sk.manual_on:
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var inv: Transform3D = global_transform.affine_inverse()
		var h: Array[float] = []
		for z in [-AXLE.y, AXLE.y]:
			for x in [-LooseBoard.WHEEL_X, LooseBoard.WHEEL_X]:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_transform * Vector3(x, 0.35, z),
					global_transform * Vector3(x, -0.3, z), 1)
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty():
					break
				h.append((inv * (hit["position"] as Vector3)).y)
		if h.size() == 4 and h.max() - h.min() < 0.25:
			var front: float = (h[0] + h[1]) * 0.5
			var back: float = (h[2] + h[3]) * 0.5
			var heel: float = (h[0] + h[2]) * 0.5     # x -: the heel edge
			var toe: float = (h[1] + h[3]) * 0.5
			want = Vector3(rad_to_deg(atan2(front - back, 2.0 * AXLE.y)), rad_to_deg(atan2(toe - heel, 2.0 * LooseBoard.WHEEL_X)),
				maxf(0.0, (front + back) * 0.5))
	_fit = want if sk.state == Skater.State.GROUND else _fit.lerp(want, 1.0 - exp(-30.0 * dt))   # (wheels drop at once)


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
	var piv_t: Vector2 = Vector2(DECK, 0.0)
	var ff_t: Vector3 = FEET_CRUISE[0]
	var fb_t: Vector3 = FEET_CRUISE[1]
	var pz_t: float = 0.0
	var px_t: float = 0.0
	var by_t: float = 0.0
	var shift_t: Vector2 = Vector2.ZERO
	var glift_t: float = 0.0
	var feet_rate: float = 14.0
	var free_t: float = 0.0
	var lift_rate: float = 18.0
	var exact: bool = false              # the board's angles follow their curves exactly (flips, the pop, rails)
	var look_t: float = 0.0
	var lead_t: float = 0.0
	var speed: float = sk.velocity.length()
	var fakie: bool = sk.stance == "fakie"
	_flip_feet = []
	if st != Skater.State.AIR:
		_pop_seen = -1.0
	_land_spring(sk, dt)
	match st:
		Skater.State.GROUND:
			# (a landing sets the skater's crouch to full: the legs' spring below takes a landing instead, as deep
			# as it came down hard)
			var cr: float = sk.crouch if _since_land > 0.4 else maxf(sk.charge_frac(), 0.25 if sk.floor_n.y < 0.9 else 0.0)
			hip_t = 0.72 - 0.17 * cr
			lean_t = 8.0 + 22.0 * cr + clampf(speed * 0.4, 0.0, 6.0)
			# carving: lean into the turn (the toe edge is the chest side, so a left turn regular, which is toward the
			# heels, leans back; fakie the other way round), hips over the inside edge, the deck rolling with it a
			# little, knees bending more on a heel-side turn
			var into: float = -sk.lean * (-1.0 if fakie else 1.0)            # + toward the toe edge
			sway_t = clampf(into * 30.0, -22.0, 22.0)
			px_t = clampf(into, -1.0, 1.0) * 0.05
			roll_t = clampf(into, -1.0, 1.0) * 5.0
			hip_t -= maxf(0.0, -into) * 0.05
			lean_t += minf(0.0, into) * 16.0                  # a heel-side turn sits back over the heels
			arms_t = 0.5 + absf(sk.lean) * 0.4
			# crouching for a jump (hold to jump): the back foot moves onto the tail, the front one back up the board
			var setup: float = smoothstep(0.0, 0.7, sk.charge_frac())
			if setup > 0.0:
				ff_t = ff_t.lerp(FEET_POP[0], setup)
				fb_t = fb_t.lerp(FEET_POP[1], setup)
				feet_rate = 22.0
			if sk.manual_on:
				# on the back wheels (or the front ones), hips over them, the other foot light
				hip_t = 0.66
				arms_t = 0.95
				if sk.manual_kind == "nose":
					pitch_t = -(MANUAL_PITCH + sk.manual_balance * 5.0)
					piv_t = Vector2(AXLE.x, -AXLE.y)
					ff_t = FEET_NOSE[0]
					fb_t = FEET_NOSE[1]
					pz_t = -0.07
					lean_t = 20.0
				else:
					pitch_t = MANUAL_PITCH + sk.manual_balance * 5.0
					piv_t = AXLE
					ff_t = FEET_MANUAL[0]
					fb_t = FEET_MANUAL[1]
					pz_t = 0.07
					lean_t = -8.0 - sk.manual_balance * 6.0
			if _sketchy > 0.0:
				# a sketchy landing: arms wheel, the body sways and the board wobbles under it, dying away
				var w: float = _sketchy / SKETCHY_TIME
				sway_t += sin(_t * 13.0) * 11.0 * w
				arms_t = maxf(arms_t, 0.9 + 0.3 * w)
				yaw_t = sin(_t * 10.0) * 6.0 * w
				lean_t += 6.0 * w
			if sk.pumping:
				# pumping a ramp: low through the flat, the legs driving the board into the curve as it rises, tall
				# near the top; sinking again on the way back down
				var steep: float = clampf((1.0 - sk.board_n.y) / 0.6, 0.0, 1.0)
				var ext: float = smoothstep(0.12, 0.5, steep) if sk.velocity.y > 0.0 else smoothstep(0.2, 0.65, steep)
				hip_t = lerpf(0.57, 0.77, ext)
				lean_t = lerpf(24.0, 6.0, ext)
				arms_t = lerpf(0.35, 0.6, ext)
			elif sk.pushing and not sk.braking and speed < 7.0:
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
			# an ollie: the tail snaps the nose up while the body is already rising (the board leaves the ground a
			# moment after it), the front foot drags up the grip and levels it, the knees bring it up; near the
			# ground the legs reach down to meet it. Rolled off something, it's just a small tuck
			var since: float = sk.air_time - sk.pop_at if sk.pop_at >= 0.0 else -1.0
			var reach: float = smoothstep(0.07, 0.22, _time_to_land(sk))     # 1 tucked .. 0 legs out for the landing
			hip_t = 0.70
			lean_t = 6.0
			arms_t = 0.85
			lift_rate = 30.0
			if since >= 0.0:
				if since < _pop_seen or _pop_seen < 0.0:
					_pop_y = sk.render_position().y - sk.velocity.y * since
				var snap: float = smoothstep(0.0, 0.045, since) * (1.0 - smoothstep(0.07, 0.24, since))
				pitch_t = POP_PITCH * snap
				var behind: float = minf(0.0, _pop_y - sk.render_position().y) * (1.0 - smoothstep(0.0, 0.1, since))
				lift_t = behind + TAIL_Z * sin(deg_to_rad(pitch_t)) + OLLIE_TUCK * smoothstep(0.04, 0.26, since) * reach
				hip_t = lerpf(0.76, 0.68, smoothstep(0.03, 0.22, since))      # stretched by the pop, then knees up
				ff_t = FEET_POP[0].lerp(FEET_CRUISE[0], smoothstep(0.05, 0.22, since))
				fb_t = FEET_POP[1].lerp(FEET_CRUISE[1], smoothstep(0.14, 0.34, since))
				feet_rate = 40.0
				exact = since < 0.3
			else:
				lift_t = 0.06 * smoothstep(0.05, 0.25, sk.air_time) * reach
			_pop_seen = since
			hip_t = lerpf(0.74, hip_t, reach)
			look_t = 22.0 * (1.0 - reach)                     # eyes on the landing
			# spinning: arms in (a fast spin tucks them), the shoulders and then the head lead the hips round
			var spin: float = clampf(sk.spin_vel / maxf(sk.tune.spin_max, 0.1), -1.0, 1.0)
			arms_t = lerpf(arms_t, 0.4, absf(spin) * 0.8)
			lead_t = spin * 28.0
			if sk.flip_kind != "":
				var f: float = sk.flip_t
				pitch_t *= 1.0 - smoothstep(0.0, 0.3, f)       # the pop's nose-up levels out as the flip starts
				_flip_pose(sk, pitch_t)
				var turn: float = smoothstep(0.06, 0.8, f)        # the board goes round between the flick and the catch
				free_t = smoothstep(0.0, 0.2, f) * (1.0 - smoothstep(0.76, 0.94, f))
				lift_t = maxf(lift_t, 0.14 * smoothstep(0.0, 0.3, f))
				hip_t = maxf(hip_t, 0.71)
				arms_t = 1.0
				exact = true
				match sk.flip_kind:
					"none":                            # kickflip
						roll_t = 360.0 * turn
					"left":                            # heelflip
						roll_t = -360.0 * turn
					"right":                           # pop shove-it
						yaw_t = 180.0 * turn
					"forward":                         # hardflip
						roll_t = 360.0 * turn
						yaw_t = 180.0 * turn
					"back":                            # impossible: end over end round the back foot (once the front
						turn = smoothstep(0.14, 0.82, f)   # foot is out of its way)
						pitch_t += 360.0 * turn
						piv_t = Vector2(DECK, AXLE.y)
						lift_t = maxf(lift_t, 0.3 * sin(PI * turn))
			if sk.grab_kind != "":
				# knees tucked hard and the board pulled up to the hand, back rounded over it, feet still on it
				grab_t = 1.0
				hip_t = 0.5
				lean_t = 38.0
				lift_t = 0.52
				pitch_t = -10.0
				arms_t = 0.7
				# each grab has its own shape
				match sk.grab_kind:
					"forward":                       # nosegrab: nose pulled up, leaning over it
						pitch_t = 22.0
						lean_t = 44.0
					"back":                          # method: board kicked back and up, chest arched
						pitch_t = -26.0
						roll_t = -34.0
						lean_t = 20.0
						twist_t = -20.0
					"left":                          # melon: reach down the heel side, board tilted up
						roll_t = 18.0
						twist_t = 30.0
					"right":                         # mute: reach across the body
						twist_t = 40.0
						roll_t = -10.0
		Skater.State.GRIND:
			hip_t = 0.58
			lean_t = 20.0
			arms_t = 0.95
			yaw_t = rad_to_deg(sk.grind_board_turn)
			roll_t = 6.0
			# leaning with the grind's balance (+ = right of travel: the chest side, the back side when fakie),
			# wobbling harder as it nears the edge
			var bal: float = sk.grind_balance * (-1.0 if fakie else 1.0)
			sway_t = bal * 16.0 + sin(_t * 9.0) * (2.0 + absf(bal) * 5.0)
			var face: float = -1.0 if fakie else 1.0     # turning the chest toward the way it's sliding
			glift_t = ON_RAIL - DECK_BOTTOM                # the deck on the rail
			match sk.grind_kind:
				"50-50":
					glift_t = ON_RAIL - HANGER_BOTTOM        # the trucks on it, the wheels either side
				"Boardslide", "Lip Slide":
					if sk.grind_board_turn != 0.0:
						# square across the rail, facing down it, head looking along the line
						by_t = face * 90.0
						roll_t = 0.0
						hip_t = 0.62
						lean_t = 14.0
				"Noseslide", "Tailslide":
					# the board turned across the rail with its nose (tail) on it: weight over that end, the shoulders
					# opened toward the way it's going
					var nose: bool = sk.grind_kind == "Noseslide"
					var turn: float = sk.grind_board_turn
					shift_t = Vector2((0.3 if nose else -0.3) * sin(turn), 0.0)
					by_t = face * rad_to_deg(turn) * 0.75
					px_t = (0.16 if nose else -0.16) * sin(turn)
					roll_t = 0.0
					ff_t = Vector3(0.0, -0.27, 12.0) if nose else Vector3(0.0, -0.1, 22.0)
					fb_t = Vector3(0.0, 0.1, -10.0) if nose else Vector3(0.0, 0.28, -10.0)
					lean_t = 24.0 if nose else 8.0
					hip_t = 0.6
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
						# the nose on the coping, the tail dropped down the ramp
						hip_t = 0.62
						lean_t = -4.0
						pitch_t = 28.0
						piv_t = Vector2(DECK, -0.3)
						shift_t = Vector2(0.0, 0.3)
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
						glift_t = ON_RAIL - HANGER_BOTTOM      # both trucks on the coping
	if sk.wallplant_t > 0.12:
		pitch_t = -70.0              # tail up, wheels on the wall
		hip_t = 0.62
		exact = false
	if fakie:
		twist_t = -twist_t           # turned toward the way it is going (over the other shoulder)
	twist_t += lead_t                # (a spin's lead is the same way round either stance)
	hip_h = _approach(hip_h, hip_t, 30.0 if st == Skater.State.AIR else 16.0, dt)
	lean = _approach(lean, lean_t, 12.0, dt)
	twist = _approach(twist, twist_t, 10.0, dt)
	sway = _approach(sway, sway_t, 10.0, dt)
	arms_out = _approach(arms_out, arms_t, 12.0, dt)
	board_lift = _approach(board_lift, lift_t, lift_rate, dt)
	feet_lift = _approach(feet_lift, feet_t, 18.0, dt)
	grab_amt = _approach(grab_amt, grab_t, 14.0, dt)
	foot_f = foot_f.lerp(ff_t, 1.0 - exp(-feet_rate * dt))
	foot_b = foot_b.lerp(fb_t, 1.0 - exp(-feet_rate * dt))
	board_piv = board_piv.lerp(piv_t, 1.0 - exp(-25.0 * dt))
	pelvis_z = _approach(pelvis_z, pz_t, 10.0, dt)
	pelvis_x = _approach(pelvis_x, px_t, 8.0 if st != Skater.State.GRIND else 14.0, dt)
	body_yaw = _approach(body_yaw, by_t, 14.0, dt)
	board_shift = board_shift.lerp(shift_t, 1.0 - exp(-20.0 * dt))
	grind_lift = _approach(grind_lift, glift_t, 30.0, dt)
	_look_down = _approach(_look_down, look_t, 10.0, dt)
	_lead = _approach(_lead, lead_t * 0.6, 8.0, dt)
	free_feet = free_t
	if exact:
		board_roll = roll_t
		board_yaw = yaw_t
		board_pitch = pitch_t
	elif st == Skater.State.GRIND:
		# locking onto a rail turns the board in about 0.08 s (in one frame it read as a glitch)
		board_roll = _approach(wrapf(board_roll, -180.0, 180.0), roll_t, 35.0, dt)
		board_yaw = _approach(wrapf(board_yaw, -180.0, 180.0), yaw_t, 35.0, dt)
		board_pitch = _approach(wrapf(board_pitch, -180.0, 180.0), pitch_t, 35.0, dt)
	else:
		# a flip that just finished stands at 360: that's 0, not a turn back the other way
		board_roll = _approach(wrapf(board_roll, -180.0, 180.0), roll_t, 20.0, dt)
		board_yaw = _approach(wrapf(board_yaw, -180.0, 180.0), yaw_t, 20.0, dt)
		board_pitch = _approach(wrapf(board_pitch, -180.0, 180.0), pitch_t, 14.0, dt)


## A touchdown kicks the legs' spring by how hard it came down (rolling back into a ramp barely sinks; a drop
## sinks deep), the hips sink and come back up with a small rebound. A sketchy one starts the arms wheeling.
func _land_spring(sk: Skater, dt: float) -> void:
	_since_land += dt
	_sketchy = maxf(0.0, _sketchy - dt)
	if sk.lands != _lands:
		_lands = sk.lands
		_since_land = 0.0
		if sk.land_kind != "":
			var peak: float = clampf(sk.land_impact * ABSORB_PER, 0.0, 0.17)
			_absorb_v += peak * ABSORB_W / 0.46          # (a spring damped 0.7 peaks at 0.46 v / w)
		if sk.land_kind == "sketchy":
			_sketchy = SKETCHY_TIME
	_absorb_v += (-ABSORB_W * ABSORB_W * _absorb - 2.0 * 0.7 * ABSORB_W * _absorb_v) * dt
	_absorb += _absorb_v * dt


## The grip's height at `z` along the deck (board space): flat between the trucks, curving up into the kicktails.
static func deck_y(z: float) -> float:
	var a: float = absf(z)
	if a <= FLAT_Z:
		return DECK
	return DECK + KICK * pow(clampf((a - FLAT_Z) / (DECK_HALF_L - FLAT_Z), 0.0, 1.0), 1.6)


## Seconds until the board meets the ground below (from the fall so far and a ray down), INF if nothing is below.
func _time_to_land(sk: Skater) -> float:
	var p: Vector3 = sk.render_position()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.2, p + Vector3.DOWN * 12.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return INF
	var h: float = maxf(0.0, p.y - (hit["position"] as Vector3).y)
	var g: float = sk.tune.air_gravity_down
	var vy: float = sk.velocity.y
	return (vy + sqrt(vy * vy + 2.0 * g * h)) / g


## A flip: the front foot flicks the board off its corner, both knees come up and apart so it turns in the gap
## below them, then the feet come back down onto it (the catch). Fills _flip_feet with each sole off the deck
## (model space) and how it's turned: [front, front angle, back, back angle].
func _flip_pose(sk: Skater, pop_pitch: float) -> void:
	var f: float = sk.flip_t
	var up: float = smoothstep(0.0, 0.24, f)
	var flick: float = smoothstep(0.0, 0.12, f) * (1.0 - smoothstep(0.2, 0.55, f))
	var top: float = 0.14                     # soles above the board's middle at the top of the flip: its half width
	                                          # turned on edge (0.1) and a little
	var out: float = 0.0                      # the front foot's flick across the board (+ toe edge)
	var spread: float = 0.04                  # how far the feet part along the board
	var back_out: float = 0.0
	match sk.flip_kind:
		"none":
			out = -0.1                        # off the heel edge
		"left":
			out = 0.1                         # off the toe edge
		"right":
			top = 0.05                        # flat under the feet: only just clear of it
			back_out = 0.04                   # the back foot scoops
		"forward":
			out = 0.06
			spread = 0.08
		"back":
			out = -0.17                       # the front foot gets out of the way; the board wraps the back one
			back_out = 0.13
			top = 0.1
	var tilt: float = sin(deg_to_rad(pop_pitch))         # (still nose up from the pop: the feet start on its slope)
	var fy: float = deck_y(foot_f.y) + board_lift - foot_f.y * tilt + top * up
	var by: float = deck_y(foot_b.y) + board_lift - foot_b.y * tilt + (top - 0.03) * up
	var front: Vector3 = Vector3(out * flick + out * 0.3 * up, fy, foot_f.y - spread * up)
	var back: Vector3 = Vector3(back_out * up, by, foot_b.y + spread * up)
	_flip_feet = [front, foot_f.z + 12.0 * flick, back, foot_b.z]


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
	# board: flips, grabs and slides tilt and spin it about the deck centre, a manual about its back axle
	var bt: Transform3D
	var pivot: Vector3 = Vector3(0, board_piv.x, board_piv.y)
	var rot: Basis = Basis.from_euler(Vector3(deg_to_rad(board_pitch + _fit.x), deg_to_rad(board_yaw),
		deg_to_rad(board_roll + _fit.y)), EULER_ORDER_YXZ)
	bt = Transform3D(rot, pivot - rot * pivot + Vector3(board_shift.x, board_lift + _fit.z, board_shift.y))
	board.transform = bt                       # (hidden while the loose board is out in the world)

	# hips: hip_h is a pose number (0.72 riding tall .. 0.55 deep crouch) mapped onto a share of this leg
	var frac: float = clampf((hip_h - _absorb - 0.145) / 0.665, 0.42, 1.05)
	var hip_y: float = DECK + frac * LEG_FRAC * (_leg_len - _ankle_off.y) + _ankle_off.y * 0.2
	var walking: bool = _walk_mode and not _gait_now.is_empty()
	var off_k: float = 1.0 - _step_on if walking else 0.0      # 1 on foot .. 0 stepping onto the deck
	if walking:
		hip_y = lerpf(hip_y, float(_gait_now["hip"]), off_k)
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
	var walk_yaw: float = float(_gait_now["yaw"]) * off_k if walking else 0.0
	var q_body: Basis = Basis(Vector3.UP, deg_to_rad(body_yaw)) * Basis(Vector3(0, 0, 1), deg_to_rad(-sway)) \
		* Basis(Vector3.UP, deg_to_rad(twist * 0.3 + 30.0 * push_amt + walk_yaw))
	var pg: Transform3D = _rotated(pelvis, q_body)
	pg.origin = Vector3((-0.03 + pelvis_x) * (1.0 - off_k), hip_y, float(_gait_now["sway"]) * off_k if walking else pelvis_z)
	_pose_bone(pelvis, pg)

	# spine: lean toward the chest and twist toward the nose, spread over three bones
	var q_torso: Basis = Basis(Vector3.UP, deg_to_rad(twist * 0.7 + 25.0 * push_amt - walk_yaw * 1.4)) \
		* Basis(Vector3(0, 0, 1), deg_to_rad(-lean - _absorb * 110.0))
	var spine: Array[String] = ["spine_01", "spine_02", "spine_03"]
	for k in spine.size():
		var i: int = _b[spine[k]]
		var part: Basis = Basis(Quaternion.IDENTITY.slerp(q_torso.get_rotation_quaternion(), 1.0 / spine.size()))
		_pose_bone(i, _rotated(i, part))
	# head: look along the board toward the nose (and down at it in the air)
	var look: float = (HEAD_LOOK if sk.stance != "fakie" else -HEAD_LOOK) - twist + _lead - body_yaw * 0.8
	if _walk_mode:
		look = 0.0                             # walking: looking where it goes
	var nod: float = (10.0 if sk.state == Skater.State.AIR else 4.0) + _look_down
	var neck: int = _b["neck_01"]
	_pose_bone(neck, _rotated(neck, Basis(Vector3.UP, deg_to_rad(look * 0.4))))
	var hd: int = _b["head"]
	_pose_bone(hd, _rotated(hd, Basis(Vector3.UP, deg_to_rad(look * 0.6)) * Basis(Vector3(0, 0, 1), deg_to_rad(-nod))))
	for side in ["l", "r"]:
		_rest_follow(_b["clavicle_" + side])

	# legs: feet flat on their marks on the deck, riding its tilt (a manual's pitch, a grab, a slide), lifted off it
	# while a flip goes round below, walking or running on the ground after a bail
	var front: Vector3 = bt * Vector3(foot_f.x, deck_y(foot_f.y) + feet_lift, foot_f.y)
	var back: Vector3 = bt * Vector3(foot_b.x, deck_y(foot_b.y) + feet_lift, foot_b.y)
	var turn_f: Basis = bt.basis * Basis(Vector3.UP, deg_to_rad(foot_f.z))
	var turn_b: Basis = bt.basis * Basis(Vector3.UP, deg_to_rad(foot_b.z))
	if free_feet > 0.0 and not _flip_feet.is_empty():
		var on_f: Vector3 = front
		var on_b: Vector3 = back
		front = front.lerp(_flip_feet[0], free_feet)
		back = back.lerp(_flip_feet[2], free_feet)
		if sk.flip_t < (0.12 if sk.flip_kind == "back" else 0.25):
			# leaving the deck (still nose up from the pop, starting to turn): never down into it
			front.y = maxf(front.y, on_f.y)
			back.y = maxf(back.y, on_b.y)
		turn_f = _slerp_basis(turn_f, Basis(Vector3.UP, deg_to_rad(float(_flip_feet[1]))), free_feet)
		turn_b = _slerp_basis(turn_b, Basis(Vector3.UP, deg_to_rad(float(_flip_feet[3]))), free_feet)
	if not stride.is_empty():
		back = stride[0]
		turn_b = Basis(Vector3.UP, deg_to_rad(float(stride[1])))
		# the front foot swivels to point up the board, its heel a little back so the toes stay off the nose's kick
		turn_f = bt.basis * Basis(Vector3.UP, deg_to_rad(lerpf(foot_f.z, 65.0, push_amt)))
		front = bt * Vector3(foot_f.x, deck_y(foot_f.y + 0.05 * push_amt), foot_f.y + 0.05 * push_amt)
	var front_pitch: float = 0.0
	var back_pitch: float = 0.0
	var pole_l: Vector3 = Vector3(1.0, 0.1, -0.35)           # riding: knees over the toes, a little apart
	var pole_r: Vector3 = Vector3(1.0, 0.1, 0.25)
	if walking:
		# on foot (walking to the loose board, running out a mistake): the gait's feet, knees straight ahead;
		# the last step lands on the deck
		var fl: Array = _gait_now["feet"][0]
		var fr: Array = _gait_now["feet"][1]
		front = (fl[0] as Vector3).lerp(front, _step_on)
		back = (fr[0] as Vector3).lerp(back, _step_on)
		turn_f = _slerp_basis(Basis(Vector3.UP, deg_to_rad(float(fl[3]))), turn_f, _step_on)
		turn_b = _slerp_basis(Basis(Vector3.UP, deg_to_rad(float(fr[3]))), turn_b, _step_on)
		front_pitch = float(fl[1]) * off_k
		back_pitch = float(fr[1]) * off_k
		pole_l = pole_l.lerp(Vector3(1.0, 0.0, -0.1), off_k)
		pole_r = pole_r.lerp(Vector3(1.0, 0.0, 0.1), off_k)
	_rig_leg("l", front, turn_f, front_pitch, pole_l)
	_rig_leg("r", back, turn_b, back_pitch, pole_r)

	# arms: out for balance, onto the board for grabs
	var sh_l: Vector3 = (_glob[_b["clavicle_l"]] * _rest_local[_b["upperarm_l"]]).origin
	var sh_r: Vector3 = (_glob[_b["clavicle_r"]] * _rest_local[_b["upperarm_r"]]).origin
	var spread: float = arms_out
	# balance arms: out and a little forward, elbows soft, never a stiff T
	var free_l: Vector3 = sh_l + Vector3(0.12 + 0.1 * spread, -0.52 + 0.4 * spread, -0.18 - 0.24 * spread)
	var free_r: Vector3 = sh_r + Vector3(0.06 + 0.05 * spread, -0.5 + 0.36 * spread, 0.2 + 0.26 * spread)
	# pushing: the arms swing against the pushing leg (the front arm reaches toward the nose as the foot plants,
	# the back arm goes back as it pushes)
	if push_amt > 0.0 or (not stride.is_empty()):
		var sw: float = sin(TAU * (sk.push_anim - 0.1)) * 0.11
		free_l += Vector3(0.03, 0.0, -1.0) * sw
		free_r += Vector3(-0.03, 0.0, -1.0) * sw
	# a landing drops the arms a little with the hips; a sketchy one wheels them, out of step with each other
	free_l.y -= _absorb * 0.8
	free_r.y -= _absorb * 0.8
	if _sketchy > 0.0 and not walking:
		var wv: float = 0.22 * _sketchy / SKETCHY_TIME
		free_l += Vector3(0.0, sin(_t * 12.0), cos(_t * 12.0) * 0.6) * wv
		free_r += Vector3(0.0, sin(_t * 12.0 + PI), -cos(_t * 12.0 + PI) * 0.6) * wv
	var elbow_out: float = 0.3
	if walking:
		# arms swing from the shoulder against the legs (walking is chest first, +X), worked out from joint angles:
		# the upper arm swings, the elbow bends more as it comes forward (a jog holds it near 90 degrees). A hand
		# target on a circle round the shoulder kept walking arms all but still and folded jogging forearms up in
		# front like carrying a tray
		var run_k: float = float(_gait_now["run"])
		var up_l: float = float(_up_len["upperarm_l"])
		var lo_l: float = float(_up_len["lowerarm_l"])
		var hands: Array = []
		for side in [0, 1]:
			var th: float = deg_to_rad(float(_gait_now["arm_l" if side == 0 else "arm_r"]))
			var bend: float = deg_to_rad(lerpf(14.0, 78.0, run_k)) + maxf(0.0, th) * lerpf(0.9, 0.35, run_k)
			var sh: Vector3 = sh_l if side == 0 else sh_r
			var out: float = (-1.0 if side == 0 else 1.0) * lerpf(0.07, 0.04, run_k) * (1.0 - 0.5 * maxf(0.0, sin(th)))
			hands.append(sh + Vector3(sin(th) * up_l + sin(th + bend) * lo_l, -cos(th) * up_l - cos(th + bend) * lo_l, out))
		free_l = free_l.lerp(hands[0], off_k)
		free_r = free_r.lerp(hands[1], off_k)
		elbow_out = lerpf(0.3, 0.1, off_k)
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
	_limb("upperarm_l", "lowerarm_l", "hand_l", hand_l, elbow_back + Vector3(0, 0, -elbow_out), _rest_pole_arm("l"))
	_limb("upperarm_r", "lowerarm_r", "hand_r", hand_r, elbow_back + Vector3(0, 0, elbow_out), _rest_pole_arm("r"))
	for side in ["l", "r"]:
		_pose_bone(_b["hand_" + side], _rotated(_b["hand_" + side], Basis.IDENTITY))
	_pose_fingers()


## Fingers relaxed, curled a little toward the palm (the rest pose has them flat and spread, like a mannequin).
func _pose_fingers() -> void:
	for i in skel.get_bone_count():
		var nm: String = skel.get_bone_name(i)
		if nm.begins_with("index") or nm.begins_with("middle") or nm.begins_with("ring") or nm.begins_with("pinky") or nm.begins_with("thumb"):
			if _curl_axis.has(i):
				var p: int = _parent[i]
				var follow: Basis = _glob[p].basis * _rest_model[p].basis.inverse()
				var curl: float = float(FINGER_CURL[nm.get_slice("_", 0)][int(nm.get_slice("_", 1)) - 1])
				_pose_bone(i, _rotated(i, Basis((follow * (_curl_axis[i] as Vector3)).normalized(), deg_to_rad(curl))))
			else:
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


func _physics_process(dt: float) -> void:
	if phys_phase == "fall" and ragdoll != null:
		ragdoll.drive(dt)


func _physical(sk: Skater, dt: float) -> void:
	_phase_t += dt
	if loose != null and phys_phase != "":
		_keep_board_in(sk)
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
				_walk_pace = _pace_to(sk, to.length())
				phys_phase = "walk"
				_walk(sk, dt)
			else:
				_start_ragdoll(sk)          # tripped: into the ragdoll from the running pose
		"fall":
			sk.bail_focus = ragdoll.pelvis_position() - Vector3.UP * 0.6
			if _body_lost(sk):
				# thrown over the level's edge (or down a hole): like riding off the edge, the screen blinks and
				# the rider is back on the board on the last safe spot, instead of falling for ever and getting up
				# in mid-air
				_end_physical()
				sk.finish_physical_bail(Transform3D(Basis.IDENTITY, sk.bail_origin))
				sk._warp_back()
				return
			if _apart_t > 0.0:
				_apart_t -= dt
				if _apart_t <= 0.0 and loose != null:
					ragdoll.sim.physical_bones_remove_collision_exception(loose.get_rid())
			# muscles: arms out to catch the fall while the body is still going, then it lies there, relaxed a bit
			var moving: bool = ragdoll.core_speed() > 1.2 and _phase_t < 1.4
			ragdoll.reach = move_toward(ragdoll.reach, 1.0 if moving else 0.0, dt / 0.35)
			ragdoll.tone = move_toward(ragdoll.tone, 1.0 if _phase_t < 0.6 or moving else RELAXED_TONE, dt / 0.6)
			ragdoll.settle = move_toward(ragdoll.settle, 0.0 if moving else 1.0, dt / 0.8)
			# a small slam: up while still sliding to a stop; a big one stays down a moment longer
			var sev: float = sk.bail_severity
			_still_t = _still_t + dt if ragdoll.core_speed() < lerpf(0.9, SETTLE_SPEED, sev) else 0.0
			if (_phase_t > lerpf(0.45, 0.9, sev) and _still_t > lerpf(0.1, 0.45, sev)) or _phase_t > 4.5:
				_begin_getup(sk)
				_walk(sk, 0.0)          # pose it now: with the ragdoll off, the skeleton would show its stale riding pose for a frame
		"getup", "walk":
			_walk(sk, dt)


## The board flies off on its own with the rider's speed (and some of its spin), from where it is now, the way the
## crash sends it: shot out ahead from under a rider going down backwards (nose flipping up), flipped onto its
## side or over by a sideways fall, and otherwise along its length a little faster than the body.
func _spawn_loose(sk: Skater) -> void:
	loose = LooseBoard.new()
	loose.rider_key = char_key
	loose.roll_resist = sk.tune.board_roll_resist
	var holder: Node = sk.get_parent()
	holder.add_child(loose)
	var right: Vector3 = sk.hdg.cross(Vector3.UP).normalized()
	var spin: Vector3 = Vector3.UP * sk.spin_vel * 0.6 + right * randf_range(-3.0, 3.0) * sk.bail_severity
	# for a moment the two ignore each other (the feet start inside the deck, and physics would fling them apart or
	# glue the rider to it)
	var from: Transform3D = board.global_transform
	if from.origin.distance_to(sk.global_position) > 2.0:
		# (a crash before the rider was ever drawn: the board is still where it was made)
		from = Transform3D(Basis.looking_at(Vector3(sk.hdg.x, 0.0, sk.hdg.z).normalized(), Vector3.UP), sk.global_position)
	var along: Vector3 = -from.basis.z
	var kick: Vector3 = along * signf(sk.bail_velocity.dot(along)) * 1.5
	var travel: Vector3 = Vector3(sk.bail_velocity.x, 0.0, sk.bail_velocity.z)
	var dir: Vector3 = sk.bail_dir
	if dir != Vector3.ZERO and travel.length() > 1.0:
		var with_travel: float = dir.dot(travel.normalized())
		if with_travel < -0.3:
			# a slip-out: the board shoots out ahead from under the feet, nose flipping up
			kick = travel.normalized() * 1.5
			spin += travel.normalized().cross(Vector3.UP) * -4.0
		elif absf(with_travel) < 0.85:
			# off to the side: it flips over sideways as it goes
			spin += along.normalized() * randf_range(4.0, 7.0) * signf(right.dot(dir) + 0.001)
	loose.setup(from, sk.bail_velocity * 1.05 + kick, spin)
	ragdoll.sim.physical_bones_add_collision_exception(loose.get_rid())
	_apart_t = 0.35
	board.visible = false


## The body keeps going the way it was going and tips the way the crash sends it (Skater.bail_dir: on with the
## travel, back off a manual over the tail, off a rail's side), harder the worse the crash. A tumble rolls as well.
func _start_ragdoll(sk: Skater) -> void:
	phys_phase = "fall"
	_phase_t = 0.0
	_still_t = 0.0
	_walk_mode = false
	_blend_w = 1.0
	var d: Vector3 = sk.bail_dir
	if d.length() < 0.5:
		d = Vector3(sk.hdg.x, 0.0, sk.hdg.z).normalized()
	var sev: float = sk.bail_severity
	var tip: Vector3 = Vector3.UP.cross(d).normalized()            # turning about this tips the head toward d
	var w: Vector3 = Vector3.UP * sk.spin_vel * 0.4 + tip * (1.0 + sev * 3.0)
	var v: Vector3 = sk.bail_velocity * 0.9
	var travel: Vector3 = Vector3(v.x, 0.0, v.z)
	if travel.length() > 1.0 and d.dot(travel.normalized()) < -0.3:
		# a slip-out: the board took the feet out ahead, the body goes down backwards, hips first
		v += Vector3.UP * 1.0
		w = Vector3.UP * sk.spin_vel * 0.4 + tip * (3.0 + 1.5 * sev)
	if sk.bail_kind == "tumble":
		w += d * (4.0 + 3.0 * sev) * (1.0 if randf() < 0.5 else -1.0)   # a roll, over the shoulder
	ragdoll.fall_dir = d
	ragdoll.start(v, w)


func _begin_getup(sk: Skater) -> void:
	var poses: Array[Transform3D] = ragdoll.world_poses()
	ragdoll.stop()
	var pelvis: Vector3 = poses[_b["pelvis"]].origin
	# get up the way the body lies: face down, push up onto hands and knees and stand facing where the head was;
	# on the back, sit up and stand facing where the feet were. Then turn to the board and walk.
	var chest: Basis = poses[_b["spine_03"]].basis * _rest_model[_b["spine_03"]].basis.inverse()
	var prone: bool = (chest * Vector3.RIGHT).y < 0.0
	var up_k: float = (chest * Vector3.RIGHT).y
	rest_facing = "side" if absf(up_k) < 0.4 else ("prone" if prone else "supine")
	var head_dir: Vector3 = poses[_b["head"]].origin - pelvis
	head_dir.y = 0.0
	if head_dir.length() < 0.1:
		head_dir = Vector3(sk.hdg.x, 0.0, sk.hdg.z)
	_walk_dir = head_dir.normalized() if prone else -head_dir.normalized()
	_getup_keys = _getup_poses(prone)
	# the sequence ends standing at the walker's origin: put it so the first pose lies where the body lies
	var lie: Vector3 = (_getup_keys[0][1] as Dictionary)["pelvis"]
	_walk_pos = _ground_under(pelvis - _walk_dir * lie.x)
	# room to stand: getting up leans forward past the feet (into a wall the rider slid down, feet first):
	# start a little further back instead
	var need: float = -lie.x + 0.62 * _body_k
	var from: Vector3 = _ground_under(pelvis) + Vector3.UP * 0.5
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + _walk_dir * need, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var short: float = need - from.distance_to(hit["position"]) + 0.05
		_walk_pos = _ground_under(_walk_pos - _walk_dir * short + Vector3.UP * 0.5)
	_place_walker()
	var inv: Transform3D = model.global_transform.affine_inverse()
	_blend_from.clear()
	for t in poses:
		_blend_from.append(inv * t)
	_blend_w = 0.0
	_walk_mode = true
	_step_on = 0.0
	_hip_s = -1.0
	_loco_speed = 0.0
	_plant = [null, null]
	_lift = [null, null]
	_gait_boost = 0.0
	_gait = GAIT_START
	_down = [true, false]
	_prev_ph = [GAIT_START, GAIT_START + 0.5]
	_lift_ph = [-1.0, -1.0]
	_brake = 0.0
	_prev_v = 0.0
	phys_phase = "getup"
	_phase_t = 0.0


## A board that flies over the level's edge (nothing under it: it would fall for ever, and the rider would chase
## it until the bail's safety cap) or drops far below where the rider went down turns up on the ground beside
## the rider instead.
func _keep_board_in(sk: Skater) -> void:
	var p: Vector3 = loose.global_position
	var out: bool = p.y < sk.bail_origin.y - 4.0
	var b: Rect2 = sk.bounds
	if b.has_area():
		out = out or minf(minf(p.x - b.position.x, b.end.x - p.x), minf(p.z - b.position.y, b.end.y - p.z)) < 0.5
	if not out:
		return
	var near: Vector3 = _walk_pos if phys_phase == "getup" or phys_phase == "walk" else sk.bail_focus
	if b.has_area():                       # and well inside the edge, toward the middle of the level
		near.x = clampf(near.x, b.position.x + 3.0, b.end.x - 3.0)
		near.z = clampf(near.z, b.position.y + 3.0, b.end.y - 3.0)
	var inward: Vector3 = Vector3(b.get_center().x - near.x, 0.0, b.get_center().y - near.z) if b.has_area() else Vector3.FORWARD
	inward = inward.normalized() if inward.length() > 0.1 else Vector3.FORWARD
	var at: Vector3 = _ground_under(near + inward * 1.2 + Vector3.UP * 0.5) + Vector3.UP * 0.12
	loose.put_at(Transform3D(Basis.looking_at(inward, Vector3.UP), at))


func _body_lost(sk: Skater) -> bool:
	var p: Vector3 = ragdoll.pelvis_position()
	if p.y < sk.bail_origin.y - 3.0:
		return true
	var b: Rect2 = sk.bounds
	return b.has_area() and minf(minf(p.x - b.position.x, b.end.x - p.x), minf(p.z - b.position.y, b.end.y - p.z)) < -0.5


func _walk(sk: Skater, dt: float) -> void:
	var target: Vector3 = loose.global_position
	var to: Vector3 = target - _walk_pos
	to.y = 0.0
	var dist: float = to.length()
	if phys_phase == "getup":
		var total: float = float(_getup_keys[-1][0])
		if _phase_t < total:
			# from the ragdoll's pose into the first lying pose, then through the get-up
			_blend_w = smoothstep(0.0, 1.0, _phase_t / float(_getup_keys[1][0]))
			_place_walker()
			sk.bail_focus = _walk_pos
			_apply_pose(_getup_pose(_phase_t))
			return
		# standing: hand over to the walk (a short blend covers the small difference)
		phys_phase = "walk"
		_walk_pace = _pace_to(sk, dist)
		_blend_from.clear()
		for g in _glob:
			_blend_from.append(g)
		_blend_w = 0.0
		_hip_s = -1.0
		_gait_update(0.0, 0.0)
	else:
		_blend_w = minf(1.0, _blend_w + dt / 0.2)
		var turn_rate: float = 0.0
		if dist > 0.02 and _blend_w >= 1.0:          # (standing still for a moment once up)
			# turn to face the board first (it is often behind: the run-out carried the rider past it), then
			# walk; slerping toward a direction right behind never turned, so the rider walked backwards
			var want: Vector3 = to / dist
			var ang: float = _walk_dir.signed_angle_to(want, Vector3.UP)
			if absf(ang) > PI - 0.05:
				ang = PI - 0.05                 # straight behind: pick a side and turn
			var turn: float = clampf(ang, -WALK_TURN * dt, WALK_TURN * dt)
			turn_rate = turn / maxf(dt, 0.0001)
			_walk_dir = _walk_dir.rotated(Vector3.UP, turn).normalized()
			var facing: float = clampf(_walk_dir.dot(want), 0.0, 1.0)
			_walk_pace = maxf(_walk_pace, _pace_to(sk, dist))    # (a board still rolling away)
			# speed up from standing, and slow down for the last steps onto the board
			var goal: float = minf(_walk_pace, sqrt(2.0 * 2.5 * maxf(dist - 0.2, 0.0)) + 0.45) * facing * facing
			_loco_speed = move_toward(_loco_speed, goal, 4.0 * dt)
			var heading_to: Vector3 = _walk_dir.lerp(want, clampf(1.0 - dist / 0.8, 0.0, 1.0)).normalized()
			_walk_pos += heading_to * minf(_loco_speed * dt, dist)
			_walk_pos = _ground_under(_walk_pos + Vector3.UP * 0.5)
		_gait_update(dt, _loco_speed, turn_rate if _loco_speed < 0.5 else 0.0)
		_step_on = 1.0 - clampf(dist / 0.6, 0.0, 1.0)
		# a board that came to rest up on something (a ledge, a car roof) or down in a hole is taken from where
		# the rider stands, not stepped up (or down) to; and a walk that goes on too long just ends
		var up_there: bool = dist < 1.0 and absf(_ground_under(target + Vector3.UP * 0.5).y - _walk_pos.y) > 0.6
		# past the recovery budget (a board that rolled away down a bank, say) the screen blinks and the rider is
		# on the board where they stand, facing the way they were walking
		var late: bool = sk.bail_time > sk.tune.recover_max and dist > 1.5
		if up_there or late or (phys_phase == "walk" and _phase_t > WALK_GIVE_UP):
			var at: Transform3D = loose.stand_transform()
			at.origin = _walk_pos
			if dist > 0.1:
				at.basis = Basis.looking_at(to / dist, Vector3.UP)
			_end_physical()
			sk.finish_physical_bail(at)
			if late:
				sk.warped.emit()
			return
		if dist < 0.06:
			var stand: Transform3D = loose.stand_transform()
			stand.origin = _ground_under(stand.origin + Vector3.UP * 0.5)
			_end_physical()
			sk.finish_physical_bail(stand)
			return
	_place_walker()
	sk.bail_focus = _walk_pos
	hip_h = 0.82
	lean = 3.0 + 6.0 * (float(_gait_now["run"]) if not _gait_now.is_empty() else 0.0)
	twist = 0.0
	sway = 0.0
	arms_out = 0.25
	_rest_board_pose()
	_apply_rig(sk)


## How fast to go back to a board `dist` away: a walk to one close by, a jog or a run to one further off (up to
## RUN_BACK_MAX), quicker when a slower pace wouldn't get there within the recovery budget
## (SkateTuning.recover_max; about a second goes on turning round, speeding up and the last slow steps).
func _pace_to(sk: Skater, dist: float) -> float:
	var pace: float = clampf(dist * 0.8, sk.tune.walk_speed, RUN_BACK_MAX)
	var left: float = sk.tune.recover_max - sk.bail_time - 1.0
	return maxf(pace, minf(dist / maxf(left, 0.3), RUN_BACK_MAX))


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
	_hip_s = -1.0
	_loco_speed = h.length()
	_plant = [null, null]
	_lift = [null, null]
	_gait_boost = 0.0
	_gait = GAIT_START
	_down = [true, false]
	_prev_ph = [GAIT_START, GAIT_START + 0.5]
	_lift_ph = [-1.0, -1.0]
	_brake = 0.0
	_prev_v = 0.0
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
	_loco_speed = spd
	_gait_update(dt, spd)
	sk.bail_focus = _walk_pos
	hip_h = 0.8
	lean = 10.0 - spd * 1.5                    # leaning back against the speed
	twist = 0.0
	sway = 0.0
	arms_out = 0.55
	_rest_board_pose()
	_apply_rig(sk)


## The get-up as a few poses in the walker's frame (chest +X, left -Z, the ground at y 0), ending standing at the
## origin: [[time, pose], ...]. A pose is where the pelvis is and how far it pitches forward (+) or back (-), the
## spine and head pitch, where each ankle, knee and hand goes (IK), and whether each foot is flat on the ground (1)
## or hangs off its shin (0: toes dug in when kneeling or lying). The legs and arms stay whole because every pose
## goes through the IK: blending bone rotations from lying to standing coiled the legs like a snake.
func _getup_poses(prone: bool) -> Array:
	var s: float = _body_k
	var th: float = _up_len["thigh_l"]
	var ca: float = _up_len["calf_l"]
	var hz: float = absf(_hip_joint.z)
	var kneel_y: float = 0.07 * s + th - _hip_joint.y           # pelvis height with a knee on the ground under the hip
	var sh: Vector3 = _rest_model[_b["upperarm_l"]].origin
	var hang: float = _arm_len * 0.93
	var stand: Dictionary = _pose_dict(Vector3(0, _stand_hip, 0), 0.0, 3.0, 0.0,
		_flat_ankle(Vector3(0, 0, -0.075 * s), 8.0), Vector3(1, 0, -0.1), 1.0,
		_flat_ankle(Vector3(0, 0, 0.075 * s), -8.0), Vector3(1, 0, 0.1), 1.0,
		Vector3(sh.x + 0.02, sh.y - hang, sh.z - 0.03), Vector3(-0.6, -0.3, -0.1))
	var keys: Array = []
	if prone:
		# face down -> hands and knees -> the left knee comes up -> kneeling on the right knee, hands on the left
		# knee -> rise onto the left foot, the right leg stepping through -> standing where the left foot was
		var fx: float = 0.4 * s                                   # the left foot's spot: the sequence ends over it
		var lie_x: float = -0.12 * s - fx
		var four_x: float = -0.22 * s - fx
		keys = [
			[0.0, _pose_dict(Vector3(lie_x, 0.13 * s, 0), 86.0, 0.0, -35.0,
				Vector3(lie_x - 0.97 * (th + ca), 0.1 * s, -hz * 1.4), Vector3(0, -1, 0), 0.0,
				Vector3(lie_x - 0.97 * (th + ca), 0.1 * s, hz * 1.4), Vector3(0, -1, 0), 0.0,
				Vector3(lie_x + 0.42 * s, 0.03, -0.28 * s), Vector3(-0.4, 1.0, -0.5))],
			[0.22, {}],                                             # (the ragdoll blends into the pose above)
			[0.56, _pose_dict(Vector3(four_x, kneel_y, 0), 78.0, -8.0, -25.0,
				Vector3(four_x - 0.96 * ca, 0.1 * s, -hz * 1.2), Vector3(0.6, -1, 0), 0.0,
				Vector3(four_x - 0.96 * ca, 0.1 * s, hz * 1.2), Vector3(0.6, -1, 0), 0.0,
				Vector3(four_x + 0.5 * s, 0.0, -0.2 * s), Vector3(-1, 0, -0.4))],
			[0.76, _pose_dict(Vector3(four_x + 0.05 * s, kneel_y + 0.02 * s, 0), 62.0, 0.0, -20.0,
				Vector3(-fx + 0.02 * s, 0.24 * s, -hz), Vector3(1, 0.6, -0.2), 0.3,
				Vector3(four_x - 0.96 * ca, 0.1 * s, hz * 1.2), Vector3(0.6, -1, 0), 0.0,
				Vector3(four_x + 0.52 * s, 0.0, -0.2 * s), Vector3(-1, 0, -0.4))],
			[0.96, _pose_dict(Vector3(-fx, kneel_y + 0.02 * s, 0), 20.0, 8.0, 0.0,
				_flat_ankle(Vector3(0, 0, -hz), 8.0), Vector3(1, 0.4, -0.2), 1.0,
				Vector3(-fx - 0.05 * s - 0.96 * ca, 0.1 * s, hz * 1.1), Vector3(0.6, -1, 0), 0.0,
				Vector3(-0.04 * s, 0.55 * s, -0.16 * s), Vector3(-1, 0.2, -0.6))],
			[1.2, _pose_dict(Vector3(-0.12 * s, lerpf(kneel_y, _stand_hip, 0.6), 0), 14.0, 6.0, 0.0,
				_flat_ankle(Vector3(0, 0, -hz), 8.0), Vector3(1, 0.2, -0.15), 1.0,
				Vector3(-0.12 * s, 0.24 * s, hz), Vector3(1, 0.4, 0.2), 0.4,
				Vector3(0.02 * s, 0.5 * s, -0.2 * s), Vector3(-1, 0, -0.5))],
			[1.44, stand],
		]
	else:
		# on the back -> sit up, knees bent, hands propping behind -> rock forward into a crouch over the feet,
		# hands on the knees -> stand
		var sit_x: float = -0.42 * s
		var feet_l: Vector3 = _flat_ankle(Vector3(0, 0, -0.1 * s), 8.0)
		var feet_r: Vector3 = _flat_ankle(Vector3(0, 0, 0.1 * s), -8.0)
		keys = [
			[0.0, _pose_dict(Vector3(sit_x - 0.08 * s, 0.12 * s, 0), -86.0, 0.0, 20.0,
				Vector3(sit_x - 0.08 * s + 0.97 * (th + ca), 0.09 * s, -hz * 1.4), Vector3(0, 1, 0), 0.0,
				Vector3(sit_x - 0.08 * s + 0.97 * (th + ca), 0.09 * s, hz * 1.4), Vector3(0, 1, 0), 0.0,
				Vector3(sit_x, 0.03, -0.32 * s), Vector3(0, 1, -0.3))],
			[0.22, {}],
			[0.6, _pose_dict(Vector3(sit_x, 0.11 * s, 0), -15.0, 12.0, 5.0,
				feet_l, Vector3(0.4, 1, -0.25), 1.0, feet_r, Vector3(0.4, 1, 0.25), 1.0,
				Vector3(sit_x - 0.22 * s, 0.0, -0.24 * s), Vector3(-1, 0, -0.3))],
			[0.96, _pose_dict(Vector3(-0.14 * s, 0.36 * s, 0), 40.0, 12.0, -15.0,
				feet_l, Vector3(1, 0.3, -0.25), 1.0, feet_r, Vector3(1, 0.3, 0.25), 1.0,
				Vector3(0.2 * s, 0.44 * s, -0.16 * s), Vector3(-1, 0, -0.6))],
			[1.3, stand],
		]
	# the blend-in key holds the lying pose
	keys[1][1] = keys[0][1]
	return keys


## One get-up pose (see _getup_poses). Hands are given for the left side and mirrored.
func _pose_dict(pelvis: Vector3, pitch: float, spine: float, head: float, ankle_l: Vector3, knee_l: Vector3,
		flat_l: float, ankle_r: Vector3, knee_r: Vector3, flat_r: float, hand_l: Vector3, elbow_l: Vector3) -> Dictionary:
	return {"pelvis": pelvis, "pitch": pitch, "spine": spine, "head": head,
		"ankle_l": ankle_l, "knee_l": knee_l, "flat_l": flat_l, "ankle_r": ankle_r, "knee_r": knee_r, "flat_r": flat_r,
		"hand_l": hand_l, "hand_r": Vector3(hand_l.x, hand_l.y, -hand_l.z),
		"elbow_l": elbow_l, "elbow_r": Vector3(elbow_l.x, elbow_l.y, -elbow_l.z)}


## The ankle over a foot flat on the ground at `sole`, toes turned out `yaw` degrees.
func _flat_ankle(sole: Vector3, yaw: float) -> Vector3:
	return sole + Basis(Vector3.UP, deg_to_rad(yaw)) * _ankle_off


## The get-up pose at time t: a Catmull-Rom curve through the poses, so the body keeps moving through each one
## instead of stopping at it.
func _getup_pose(t: float) -> Dictionary:
	var keys: Array = _getup_keys
	var n: int = keys.size()
	var i: int = 0
	while i < n - 2 and t >= float(keys[i + 1][0]):
		i += 1
	var t0: float = float(keys[i][0])
	var t1: float = float(keys[i + 1][0])
	var u: float = clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
	var a: Dictionary = keys[maxi(i - 1, 0)][1]
	var b: Dictionary = keys[i][1]
	var c: Dictionary = keys[i + 1][1]
	var d: Dictionary = keys[mini(i + 2, n - 1)][1]
	var out: Dictionary = {}
	for k in b:
		var pa: Variant = a[k]
		var pb: Variant = b[k]
		var pc: Variant = c[k]
		var pd: Variant = d[k]
		if pb is Vector3:
			out[k] = (pb as Vector3) * 2.0 + (-(pa as Vector3) + (pc as Vector3)) * u \
				+ ((pa as Vector3) * 2.0 - (pb as Vector3) * 5.0 + (pc as Vector3) * 4.0 - (pd as Vector3)) * u * u \
				+ (-(pa as Vector3) + (pb as Vector3) * 3.0 - (pc as Vector3) * 3.0 + (pd as Vector3)) * u * u * u
			out[k] = (out[k] as Vector3) * 0.5
		else:
			var fa: float = pa
			var fb: float = pb
			var fc: float = pc
			var fd: float = pd
			out[k] = 0.5 * (2.0 * fb + (-fa + fc) * u + (2.0 * fa - 5.0 * fb + 4.0 * fc - fd) * u * u
				+ (-fa + 3.0 * fb - 3.0 * fc + fd) * u * u * u)
	return out


## Pose the whole body from a get-up pose (walker frame).
func _apply_pose(k: Dictionary) -> void:
	_rest_follow(_b["Root"])
	var pelvis: int = _b["pelvis"]
	var pg: Transform3D = _rotated(pelvis, Basis(Vector3(0, 0, 1), deg_to_rad(-float(k["pitch"]))))
	pg.origin = k["pelvis"]
	_pose_bone(pelvis, pg)
	for nm in ["spine_01", "spine_02", "spine_03"]:
		var i: int = _b[nm]
		_pose_bone(i, _rotated(i, Basis(Vector3(0, 0, 1), deg_to_rad(-float(k["spine"]) / 3.0))))
	var neck: int = _b["neck_01"]
	_pose_bone(neck, _rotated(neck, Basis(Vector3(0, 0, 1), deg_to_rad(-float(k["head"]) * 0.4))))
	var hd: int = _b["head"]
	_pose_bone(hd, _rotated(hd, Basis(Vector3(0, 0, 1), deg_to_rad(-float(k["head"]) * 0.6))))
	for side in ["l", "r"]:
		_rest_follow(_b["clavicle_" + side])
	for side in ["l", "r"]:
		_limb("thigh_" + side, "calf_" + side, "foot_" + side, k["ankle_" + side],
			(k["knee_" + side] as Vector3).normalized(), _rest_pole_leg())
		var f: int = _b["foot_" + side]
		var hang: Basis = _rotated(f, Basis.IDENTITY).basis            # the foot as it hangs off the shin
		var flat: Basis = Basis(Vector3.UP, deg_to_rad(8.0 if side == "l" else -8.0)) * _rest_model[f].basis
		var w: float = clampf(float(k["flat_" + side]), 0.0, 1.0)
		var q: Quaternion = hang.orthonormalized().get_rotation_quaternion().slerp(flat.orthonormalized().get_rotation_quaternion(), w)
		var fg: Transform3D = _glob[_parent[f]] * _rest_local[f]
		_pose_bone(f, Transform3D(Basis(q), fg.origin))
		_rest_follow(_b["ball_" + side])
	for side in ["l", "r"]:
		_limb("upperarm_" + side, "lowerarm_" + side, "hand_" + side, k["hand_" + side],
			(k["elbow_" + side] as Vector3).normalized(), _rest_pole_arm(side))
		var h: int = _b["hand_" + side]
		_pose_bone(h, _rotated(h, Basis.IDENTITY))
	_pose_fingers()


## Each finger bone's curl axis: across the finger, so a positive turn brings the tip toward the palm.
func _setup_fingers() -> void:
	for side in ["l", "r"]:
		if not _b.has("index_01_" + side) or not _b.has("pinky_01_" + side):
			continue
		var hand: Vector3 = _rest_model[_b["hand_" + side]].origin
		var across: Vector3 = _rest_model[_b["index_01_" + side]].origin - _rest_model[_b["pinky_01_" + side]].origin
		var along: Vector3 = _rest_model[_b["middle_01_" + side]].origin - hand
		var palm: Vector3 = across.cross(along).normalized() * (CURL_SIGN if side == "l" else -CURL_SIGN)
		for f in ["index", "middle", "ring", "pinky", "thumb"]:
			for k in [1, 2, 3]:
				var nm: String = "%s_%02d_%s" % [f, k, side]
				if not _b.has(nm):
					continue
				var i: int = _b[nm]
				var tip: String = "%s_%02d_%s" % [f, k + 1, side]
				var d: Vector3 = (_rest_model[_b[tip]].origin - _rest_model[i].origin) if _b.has(tip) else \
					(_rest_model[i].origin - _rest_model[_parent[i]].origin)
				_curl_axis[i] = d.normalized().cross(palm).normalized()


## One frame of walking or running on foot, into `_gait_now`. `v` is the speed over the ground, `turn_rate` how
## fast the body is turning on the spot (rad/s: it steps round instead of pivoting on planted feet).
## The phase follows the distance covered, so a planted foot moves back under the body at exactly the walking
## speed (no sliding). Walking keeps a foot on the ground: the heel lands with the toes up, the foot rolls flat and
## pushes off from the ball, and the stance leg stays nearly straight, so the pelvis rides up over it and dips as
## the feet swap. Faster, it blends into a jog: shorter contact, a flight phase, the heel folding up behind, a
## forward lean and bent arms. The pelvis turns with the stride; the arms swing against the legs.
func _gait_update(dt: float, v: float, turn_rate: float = 0.0) -> void:
	var run_k: float = smoothstep(1.9, 3.0, v)
	if dt > 0.0:
		_brake = lerpf(_brake, clampf((_prev_v - v) / dt / 5.0, 0.0, 1.0), 1.0 - exp(-10.0 * dt))
	_prev_v = v
	var step: float = clampf(0.42 + 0.2 * v, 0.45, 1.5) * _body_k * lerpf(1.0, 0.68, _brake)
	var stride: float = 2.0 * step
	var rate: float = v / stride + absf(turn_rate) * 0.3          # cycles a second
	_gait = fposmod(_gait + rate * (1.0 + _gait_boost) * dt, 1.0)
	_gait_boost = 0.0
	var move: float = clampf(rate / 0.8, 0.0, 1.0)                # standing still: feet flat and together
	var duty: float = lerpf(0.62, 0.36, run_k)
	var reach: float = duty * v / maxf(rate, 0.001)               # a planted foot's travel under the body
	var lift: float = lerpf(0.09, 0.3, run_k) * _body_k * move
	var roll: float = lerpf(34.0, 28.0, run_k) * move              # heel up at push off
	var strike: float = 12.0 * (1.0 - run_k) * move                # toes up at heel strike (walking)
	var width: float = 0.075 * _body_k
	var floor_hip: float = _stand_hip * lerpf(0.9, 0.84, run_k)    # never sink lower than this over a planted foot
	# planted feet stay where they landed in the world, whatever the body does meanwhile (speeds up from
	# standing, slows for the board, turns): the gait only says when a foot lifts and where it lands next
	var frame: Transform3D = Transform3D(Basis(_walk_dir, Vector3.UP, _walk_dir.cross(Vector3.UP).normalized()), _walk_pos)
	var inv: Transform3D = frame.affine_inverse()
	var heading: float = atan2(-_walk_dir.z, _walk_dir.x)
	var feet: Array = []
	var cap: float = INF
	for i in 2:
		var ph: float = fposmod(_gait + 0.5 * i, 1.0)
		var toe: float = 8.0 if i == 0 else -8.0                     # toes out a touch
		var p: Vector3 = Vector3(0.0, 0.0, -width if i == 0 else width)   # the left foot on -Z
		var yaw: float = toe
		var pitch: float
		# a foot goes down when its cycle comes round (phase wraps) and lifts when its stance is done; the speed
		# (and with it the share of the cycle on the ground) can change meanwhile without planting a foot mid-air
		if bool(_down[i]) and ph >= duty and ph >= float(_prev_ph[i]):
			_down[i] = false
			_lift_ph[i] = ph
		elif not bool(_down[i]) and (ph < float(_prev_ph[i]) or dt <= 0.0 and ph < duty):
			_down[i] = true
		_prev_ph[i] = ph
		var ground: bool = _down[i]
		if ground:
			var sg: float = clampf(ph / duty, 0.0, 1.0)              # 0 touch down .. 1 push off
			if _plant[i] == null or dt <= 0.0:
				_plant[i] = [frame * Vector3(reach * (0.42 - sg), 0.0, p.z), heading + deg_to_rad(toe)]
			var q: Vector3 = inv * (_plant[i][0] as Vector3)
			var q_yaw: float = rad_to_deg(wrapf(float(_plant[i][1]) - heading, -PI, PI))
			var q_pitch: float = strike * (1.0 - smoothstep(0.0, 0.2, sg)) - roll * smoothstep(0.6, 1.0, sg)
			# how high the pelvis can be over this foot with the knee all but straight (a little softer mid-stance)
			# walking: a dip just after heel strike (the knee takes the weight), nearly straight mid-stance; a jog is
			# softest mid-stance
			var k_walk: float = 0.996 - 0.022 * sin(PI * clampf(sg / 0.4, 0.0, 1.0)) - 0.004 * sin(PI * sg)
			var k: float = lerpf(k_walk, lerpf(0.988, 0.9, sin(PI * sg)), run_k)
			var ankle: Vector3 = _foot_pose(q, Basis(Vector3.UP, deg_to_rad(q_yaw)), q_pitch)[0]
			var hj: Vector3 = Vector3(_hip_joint.x, _hip_joint.y, absf(_hip_joint.z) * (1.0 if i == 1 else -1.0))
			var dx: float = hj.x - ankle.x
			var dz: float = hj.z - ankle.z
			var room: float = ankle.y - hj.y + sqrt(maxf(0.0, pow(k * _leg_chain, 2.0) - dx * dx - dz * dz))
			var other_down: bool = bool(_down[1 - i])
			if room < floor_hip and q.x < 0.0:
				# being left behind (the body turned or sped up over it): hurry the other foot down
				_gait_boost = maxf(_gait_boost, clampf((floor_hip - room) / 0.04, 0.0, 3.0))
			if room < floor_hip - 0.03 and q.x < 0.0 and other_down and dt > 0.0:
				# still behind once the other foot is down: lift it now rather than sink into a crouch or let it slide
				_down[i] = false
				_lift_ph[i] = ph
				_lift[i] = _plant[i]
				_plant[i] = null
				ground = false
				p = q
				yaw = q_yaw
				pitch = -roll
			else:
				p = q
				yaw = q_yaw
				pitch = q_pitch
				cap = minf(cap, room)
		if not ground:
			if _plant[i] != null:
				_lift[i] = _plant[i]
				_plant[i] = null
			var from_ph: float = float(_lift_ph[i]) if float(_lift_ph[i]) >= 0.0 else duty
			var sw: float = clampf((ph - from_ph) / maxf(1.0 - from_ph, 0.05), 0.0, 1.0)   # 0 lift off .. 1 touch down
			var e: float = sw * sw * sw * (10.0 + sw * (-15.0 + 6.0 * sw))    # minimum jerk
			var from: Vector3 = Vector3(reach * -0.58, 0.0, p.z)
			var from_yaw: float = toe
			if _lift[i] != null:
				from = inv * (_lift[i][0] as Vector3)
				from_yaw = rad_to_deg(wrapf(float(_lift[i][1]) - heading, -PI, PI))
			p = from.lerp(Vector3(reach * 0.42, 0.0, p.z), e)
			p.y += lift * sin(PI * pow(sw, lerpf(0.9, 0.6, run_k)))  # a runner's heel comes up early
			yaw = lerpf(from_yaw, toe, e)
			pitch = -roll * (1.0 - smoothstep(0.0, 0.4, sw)) + strike * smoothstep(0.6, 1.0, sw)
		feet.append([p, pitch, ground, yaw])
	var top: float = _stand_hip * lerpf(1.0, 0.97, run_k)          # airborne (running), or standing
	var want: float = clampf(cap, floor_hip, top)
	_hip_s = want if _hip_s < 0.0 or dt <= 0.0 else lerpf(_hip_s, want, 1.0 - exp(-30.0 * dt))
	var half: float = maxf(stride * 0.5, 0.01)
	var ahead: float = clampf(((feet[0][0] as Vector3).x - (feet[1][0] as Vector3).x) / half, -1.2, 1.2)   # + the left foot is forward
	_gait_now = {
		"feet": feet,
		"hip": _hip_s,
		"run": run_k,
		# the pelvis turns the forward leg's hip forward; the shoulders turn back against it
		"yaw": -ahead * lerpf(9.0, 12.0, run_k),
		# weight over the standing foot
		"sway": -width * 0.45 * cos(TAU * (_gait - duty * 0.5)) * (1.0 - 0.6 * run_k) * move,
		"arm_l": -ahead * lerpf(24.0, 38.0, run_k) - lerpf(4.0, 10.0, run_k),     # (a little behind the body at rest:
		"arm_r": ahead * lerpf(24.0, 38.0, run_k) - lerpf(4.0, 10.0, run_k),      # the swing is more back than forward)
	}


## Where the ankle goes for a sole centre (model space) with the foot turned `turn` and pitched `pitch` degrees
## about its own left-right axis: + toes up, rocking on the heel; - heel up, rolling on the ball. [ankle, basis]
func _foot_pose(sole: Vector3, turn: Basis, pitch: float) -> Array:
	var ankle: Vector3 = sole + turn * _ankle_off
	if absf(pitch) < 0.01:
		return [ankle, turn]
	var fwd: Vector3 = turn * Vector3.RIGHT                         # the toes (+X at rest)
	var r: Basis = Basis((turn * Vector3.BACK).normalized(), deg_to_rad(pitch))
	var pivot: Vector3 = sole - fwd * (_foot_len * 0.42) if pitch > 0.0 else sole + fwd * (_foot_len * 0.29)
	return [pivot + r * (ankle - pivot), r * turn]


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


## On foot: the board pose numbers back to riding flat (the step onto the deck lands on the cruising marks).
func _rest_board_pose() -> void:
	feet_lift = 0.0
	board_lift = 0.0
	board_pitch = 0.0
	board_roll = 0.0
	board_yaw = 0.0
	grab_amt = 0.0
	foot_f = FEET_CRUISE[0]
	foot_b = FEET_CRUISE[1]
	board_piv = Vector2(DECK, 0.0)
	pelvis_z = 0.0
	free_feet = 0.0
	_flip_feet = []
	_absorb = 0.0
	_absorb_v = 0.0
	_sketchy = 0.0
	pelvis_x = 0.0
	_look_down = 0.0
	_lead = 0.0
	body_yaw = 0.0
	board_shift = Vector2.ZERO
	grind_lift = 0.0


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


## The back foot through one push: up off its mark, out past the deck's edge and down beside the board ahead of the
## back truck, push back along the ground, then up, back in over the deck and onto it. Returns [foot, angle, hip
## drop]. (Straight lines from the deck to the ground cut the foot through the deck's edge.)
func _push_stride(ph: float) -> Array:
	var deck: Vector3 = Vector3(foot_b.x, deck_y(foot_b.y), foot_b.y)
	var plant: Vector3 = Vector3(0.22, 0.0, -0.02)
	var reach: Vector3 = Vector3(0.22, 0.0, 0.55)
	var foot: Vector3
	var ang: float
	if ph < 0.18:                                   # lift, out and step down beside the board
		var k: float = ph / 0.18
		var out: float = smoothstep(0.0, 0.6, k)
		var down: float = smoothstep(0.3, 1.0, k)
		foot = Vector3(lerpf(deck.x, plant.x, out), lerpf(deck.y, plant.y, down) + sin(k * PI) * 0.05,
			lerpf(deck.z, plant.z, smoothstep(0.0, 1.0, k)))
		ang = lerpf(foot_b.z, -75.0, smoothstep(0.0, 1.0, k))
	elif ph < 0.62:                                 # push back along the ground
		var k2: float = (ph - 0.18) / 0.44
		foot = plant.lerp(reach, k2 * k2 * (3.0 - 2.0 * k2))
		ang = -75.0
	elif ph < 0.88:                                 # swing up, back in over the deck and onto it
		var k3: float = (ph - 0.62) / 0.26
		var up: float = smoothstep(0.0, 0.5, k3)
		var inward: float = smoothstep(0.4, 1.0, k3)
		foot = Vector3(lerpf(reach.x, deck.x, inward), lerpf(reach.y, deck.y, up) + sin(k3 * PI) * 0.1,
			lerpf(reach.z, deck.z, smoothstep(0.0, 1.0, k3)))
		ang = lerpf(-75.0, foot_b.z, smoothstep(0.0, 1.0, k3))
	else:
		foot = deck
		ang = foot_b.z
	var on_ground: float = clampf(1.0 - absf(ph - 0.4) / 0.3, 0.0, 1.0)
	return [foot, ang, on_ground * 0.06]


## The rest pose's knee (or elbow) side, in model space: knees bend toward the chest (+X), elbows behind.
func _rest_pole_leg() -> Vector3:
	return Vector3(1, 0, 0)


func _rest_pole_arm(_side: String) -> Vector3:
	return Vector3(-1, 0, 0)


## One leg: the sole centre at `sole` (model space), the foot turned `turn` (toes across the board, the front foot
## angled to the nose, tilted with the deck); the ankle sits above and behind the sole centre. On foot it also
## rolls heel to toe (pitch).
func _rig_leg(side: String, sole: Vector3, turn: Basis, pitch: float = 0.0, knee_pole: Vector3 = Vector3.ZERO) -> void:
	var fp: Array = _foot_pose(sole, turn, pitch)
	if knee_pole == Vector3.ZERO:
		knee_pole = Vector3(1.0, 0.1, -0.35 if side == "l" else 0.25)
	_limb("thigh_" + side, "calf_" + side, "foot_" + side, fp[0], knee_pole, _rest_pole_leg())
	var f: int = _b["foot_" + side]
	var fg: Transform3D = _glob[_parent[f]] * _rest_local[f]
	_pose_bone(f, Transform3D((fp[1] as Basis) * _rest_model[f].basis, fg.origin))
	var ball: int = _b["ball_" + side]
	if pitch < -0.5:
		# heel up: the toes bend back and stay on the ground
		_pose_bone(ball, _rotated(ball, Basis((turn * Vector3.BACK).normalized(), deg_to_rad(-pitch))))
	else:
		_rest_follow(ball)


static func _slerp_basis(a: Basis, b: Basis, w: float) -> Basis:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	return Basis(a.orthonormalized().get_rotation_quaternion().slerp(b.orthonormalized().get_rotation_quaternion(), w))


## [left hand target, right hand target, use left, use right] for a grab, on the board as it is posed now.
func _grab_targets(kind: String, bt: Transform3D) -> Array:
	# points on the posed deck (bt), in model space: the toe edge faces the chest (+X), the nose is -Z
	var toe_mid: Vector3 = bt * Vector3(0.11, DECK + 0.01, 0.02)
	var heel_mid: Vector3 = bt * Vector3(-0.11, DECK + 0.01, 0.02)
	var heel_front: Vector3 = bt * Vector3(-0.11, DECK + 0.01, -0.12)
	var nose: Vector3 = bt * Vector3(0.0, DECK + 0.03, -0.38)
	var tail: Vector3 = bt * Vector3(0.0, DECK + 0.03, 0.38)
	match kind:
		"none":
			return [toe_mid, toe_mid, 0.0, 1.0]        # indy: back hand, toe edge between the feet
		"left":
			return [heel_front, heel_front, 1.0, 0.0]  # melon: front hand, heel edge
		"right":
			return [toe_mid, toe_mid, 1.0, 0.0]        # mute: front hand, toe edge
		"forward":
			return [nose, nose, 1.0, 0.0]              # nosegrab
		"back":
			return [heel_mid, tail, 1.0, 0.0]          # method: front hand, heel edge; board kicked out behind
	return [toe_mid, toe_mid, 0.0, 0.0]