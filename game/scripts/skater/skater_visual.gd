class_name SkaterVisual
extends Node3D
## Draws the rider. Every limb is placed by two-bone IK toward targets that depend on what the skater
## is doing (riding, pushing, crouching, flipping, grabbing, grinding, bailing), so poses are just numbers.
##
## Model space: forward = -Z, up = +Y, the chest faces +X (regular stance, left foot forward).

const MODEL: PackedScene = preload("res://assets/models/skater.glb")
const THIGH: float = 0.30
const SHIN: float = 0.27
const ANKLE_TO_SOLE: float = 0.095
const UPPER_ARM: float = 0.22
const FORE_ARM: float = 0.25
const DECK_TOP: float = 0.145
const CAPSULE_TO_CONTACT: float = 0.02

var model: Node3D
var board: Node3D
var body: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var rest: Dictionary = {}

# smoothed pose values
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
var grab_l: Vector3 = Vector3.ZERO
var grab_r: Vector3 = Vector3.ZERO
var grab_use_l: float = 0.0
var grab_use_r: float = 0.0
var vis_n: Vector3 = Vector3.UP
var tumble: float = 0.0
var tumble_axis: Vector3 = Vector3.RIGHT
var _t: float = 0.0
var shoes: Dictionary = {}       # node -> rest transform, per side
var upright_xf: Transform3D = Transform3D.IDENTITY   # the rider's frame before any bail roll (the ground under it)


func setup(look: Dictionary = {}) -> void:
	model = MODEL.instantiate()
	add_child(model)
	Toon.skin(model, look, false)
	board = model.find_child("Board", true, false)
	body = model.find_child("Body", true, false)
	torso = model.find_child("Torso", true, false)
	head = model.find_child("Head", true, false)
	arm_l = model.find_child("ArmL", true, false)
	arm_r = model.find_child("ArmR", true, false)
	fore_l = model.find_child("ForeL", true, false)
	fore_r = model.find_child("ForeR", true, false)
	leg_l = model.find_child("LegL", true, false)
	leg_r = model.find_child("LegR", true, false)
	shin_l = model.find_child("ShinL", true, false)
	shin_r = model.find_child("ShinR", true, false)
	for n in [board, body, torso, head, arm_l, arm_r, fore_l, fore_r, leg_l, leg_r, shin_l, shin_r]:
		rest[n] = (n as Node3D).transform
	for side in ["L", "R"]:
		var sh: Node3D = model.find_child("Shin" + side, true, false)
		var parts: Array = []
		for nm in ["Shoe", "Sole", "KneePad"]:
			var m: Node3D = sh.find_child(nm + side, false, false)
			if m != null:
				parts.append([m, m.transform])
		shoes[side] = parts
	if look.get("no_ponytail", false):
		var pt: Node3D = model.find_child("Ponytail", true, false)
		if pt != null:
			pt.visible = false


# ------------------------------------------------------------------ helpers

const SKINS: Array[String] = ["f2b48c", "e0a173", "c98358", "a4643f", "7a4a2f", "f7cfae"]
const SHIRTS: Array[String] = ["ff7a3d", "3d9bff", "3fc66d", "ff5a5a", "8a5cf0", "ffd23f", "1fc2b0", "ff7eb6"]
const HELMETS: Array[String] = ["3d9bff", "ffd23f", "ff5a5a", "3fc66d", "8a5cf0", "f4f7fb", "ff8a3d"]
const PANTS: Array[String] = ["3b4a78", "2a3050", "5a4a3a", "4a6fa5", "6b6f7d"]
const HAIRS: Array[String] = ["5a3a24", "20263a", "c98a3a", "8a3a24", "e8d8b0"]


## A deterministic random look for an AI skater (material name -> Color).
static func random_look(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return {
		"Skin": Color.html(SKINS[rng.randi() % SKINS.size()]),
		"Shirt": Color.html(SHIRTS[rng.randi() % SHIRTS.size()]),
		"Helmet": Color.html(HELMETS[rng.randi() % HELMETS.size()]),
		"Pants": Color.html(PANTS[rng.randi() % PANTS.size()]),
		"Hair": Color.html(HAIRS[rng.randi() % HAIRS.size()]),
		"Deck": Color.html(SHIRTS[rng.randi() % SHIRTS.size()]),
		"DeckB": Color.html(HELMETS[rng.randi() % HELMETS.size()]),
		"ShirtB": Color.html(["fff1d6", "ffd23f", "f4f7fb"][rng.randi() % 3]),
		"no_ponytail": rng.randf() < 0.5,
	}


static func aim_down(dir: Vector3, hint: Vector3) -> Basis:
	var y: Vector3 = -dir.normalized()
	var x: Vector3 = hint - y * hint.dot(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT - y * Vector3.RIGHT.dot(y)
	x = x.normalized()
	var z: Vector3 = x.cross(y)
	return Basis(x, y, z)


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


func _approach(cur: float, tgt: float, rate: float, dt: float) -> float:
	return lerpf(cur, tgt, 1.0 - exp(-rate * dt))


# ------------------------------------------------------------------ per-frame

func sync_from(sk: Skater, dt: float) -> void:
	_t += dt
	var n: Vector3 = Vector3.UP
	var fwd: Vector3 = sk.facing()
	match sk.state:
		Skater.State.GROUND:
			n = sk.board_n
		Skater.State.BAIL:
			n = sk.floor_n
			fwd = sk.hdg
		Skater.State.AIR:
			n = sk.air_up                  # vert airs: side-on to the wall, turning in the wall's plane
			fwd = sk.air_fwd
	var blended: Vector3 = vis_n.lerp(n.normalized(), 1.0 - exp(-16.0 * dt))
	vis_n = blended.normalized() if blended.length() > 0.2 else Vector3.UP
	fwd = (fwd - vis_n * fwd.dot(vis_n)).normalized()
	if fwd.length() < 0.5:
		fwd = Vector3(0, 0, -1)
	var pos: Vector3 = sk.global_position + Vector3.UP * (Skater.CAPSULE_R + CAPSULE_TO_CONTACT) - n * Skater.CAPSULE_R
	var basis_v: Basis = Basis(fwd.cross(vis_n), vis_n, -fwd)
	_pose(sk, dt)
	var xf: Transform3D = Transform3D(basis_v, pos)
	upright_xf = xf
	if sk.state == Skater.State.BAIL and sk.bail_kind != "runout":
		xf = _slam_transform(sk, basis_v, pos) if sk.bail_kind == "slam" else _tumble_transform(sk, basis_v, pos)
	if sk.state == Skater.State.BAIL:
		xf.origin += _bail_body_offset(sk)
	global_transform = xf
	_apply_rig(sk)
	if sk.state == Skater.State.BAIL:
		_keep_above(pos)


## Where the body is relative to the board during a bail (the cartoon rider stays with its board).
func _bail_body_offset(_sk: Skater) -> Vector3:
	return Vector3.ZERO


## Measure the posed rig and push it out along the surface normal until nothing is below the ground.
func _keep_above(contact: Vector3) -> void:
	var lowest: float = 0.0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		var bb: AABB = m.get_aabb()
		var gx: Transform3D = m.global_transform
		for k in 8:
			var corner: Vector3 = bb.position + bb.size * Vector3(k & 1, (k >> 1) & 1, (k >> 2) & 1)
			lowest = minf(lowest, ((gx * corner) - contact).dot(vis_n))
	if lowest < 0.0:
		global_position += vis_n * (-lowest)


## Tumble around the body's centre and keep the lowest point resting on the surface, so the rider flops
## on top of the ground instead of swinging through it. Ends by continuing the roll back onto the feet.
func _tumble_transform(sk: Skater, basis_v: Basis, pos: Vector3) -> Transform3D:
	const CENTER: Vector3 = Vector3(0, 0.55, 0)          # roughly the hips, in model space
	const ABOVE: float = 1.15                            # head height above CENTER
	const BELOW: float = 0.55                            # feet below CENTER
	const THICK: float = 0.3                             # half thickness when lying down
	var t: float = sk.bail_time
	var get_up: float = 0.5
	var roll_end: float = _getup_at(sk) - get_up
	var phi: float
	if t < roll_end:
		var p: float = clampf(t / 0.85, 0.0, 1.0)
		phi = (1.0 - pow(1.0 - p, 3.0)) * TAU * 0.75      # 270 degrees: ends lying on the front
	else:
		var q: float = clampf((t - roll_end) / get_up, 0.0, 1.0)
		phi = TAU * 0.75 + q * q * (3.0 - 2.0 * q) * TAU * 0.25
	var c: float = cos(phi)
	var extent: float = (BELOW if c > 0.0 else ABOVE) * absf(c) + THICK * absf(sin(phi))
	var hop: float = sin(clampf(t / 0.7, 0.0, 1.0) * PI) * 0.25
	var rot: Basis = Basis(Vector3.RIGHT, -phi)
	var center_world: Vector3 = pos + vis_n * (extent + 0.03 + hop)
	var m: Basis = basis_v * rot
	return Transform3D(m, center_world - m * CENTER)


func _getup_at(sk: Skater) -> float:
	return sk.bail_getup if sk.bail_getup > 0.0 else sk.bail_duration


## A slam: the rider goes down onto a hip (rolling ~80 degrees about the direction of travel), slides, and
## gets back up. Lowest point kept on the surface like the tumble.
func _slam_transform(sk: Skater, basis_v: Basis, pos: Vector3) -> Transform3D:
	const CENTER: Vector3 = Vector3(0, 0.55, 0)
	const BELOW: float = 0.55
	const THICK: float = 0.28
	var t: float = sk.bail_time
	var get_up: float = 0.45
	var down: float = clampf(t / 0.28, 0.0, 1.0)
	var up: float = clampf((t - (_getup_at(sk) - get_up)) / get_up, 0.0, 1.0)
	var amt: float = (1.0 - pow(1.0 - down, 2.0)) * (1.0 - up * up * (3.0 - 2.0 * up))
	var side: float = 1.0 if int(sk.stats["bails"]) % 2 == 0 else -1.0   # alternate hips
	var phi: float = deg_to_rad(80.0) * amt * side
	var extent: float = BELOW * absf(cos(phi)) + THICK * absf(sin(phi))
	var rot: Basis = Basis(Vector3(0, 0, 1), phi)
	var m: Basis = basis_v * rot
	return Transform3D(m, pos + vis_n * (extent + 0.03) - m * CENTER)


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
		Skater.State.BAIL:
			hip_t = 0.5
			if sk.bail_time > _getup_at(sk) and sk.bail_kind != "runout":
				hip_t = 0.82               # up and walking back to the board
			arms_t = 1.2
			if sk.bail_kind == "runout":
				hip_t = 0.86
				lean_t = 16.0
				arms_t = 0.7
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
	if sk.flip_kind != "" or st == Skater.State.GRIND:
		board_roll = roll_t
		board_yaw = yaw_t
		board_pitch = pitch_t
	else:
		board_roll = _approach(board_roll, roll_t, 20.0, dt)
		board_yaw = _approach(board_yaw, yaw_t, 20.0, dt)
		board_pitch = _approach(board_pitch, pitch_t, 14.0, dt)


func _apply_rig(sk: Skater) -> void:
	# board
	var bt: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, board_lift, 0))
	var pivot: Vector3 = Vector3(0, DECK_TOP, 0)
	var rot: Basis = Basis.from_euler(Vector3(deg_to_rad(board_pitch), deg_to_rad(board_yaw), deg_to_rad(board_roll)), EULER_ORDER_YXZ)
	# spin about the deck centre, not the wheels
	bt = Transform3D(rot, pivot - rot * pivot + Vector3(0, board_lift, 0))
	var bail_u: float = clampf(sk.bail_time / maxf(sk.bail_duration, 0.1), 0.0, 1.0)
	if sk.state == Skater.State.BAIL:
		match sk.bail_kind:
			"runout":    # the board rolls on ahead, then the rider catches up and hops back on
				var ahead: float = sin(bail_u * PI) * 1.3
				bt = Transform3D(Basis(Vector3.UP, sin(sk.bail_time * 5.0) * 0.15 * (1.0 - bail_u)), Vector3(0, 0, -ahead))
			"slam":      # the board shoots out sideways along the ground
				var p2: float = 1.0 - pow(1.0 - minf(sk.bail_time / 0.6, 1.0), 2.0)
				var back_on: float = clampf((bail_u - 0.7) / 0.3, 0.0, 1.0)
				bt = Transform3D(Basis(Vector3.UP, p2 * 1.4 * (1.0 - back_on)), Vector3(0.7 * p2, 0.0, -0.9 * p2) * (1.0 - back_on))
			_:
				var p: float = clampf(sk.bail_time / 1.0, 0.0, 1.0)
				bt = Transform3D(Basis.from_euler(Vector3(p * 5.0, p * 3.0, p * 2.0)), Vector3(0.5 * p, sin(p * PI) * 0.9, -0.9 * p))
	board.transform = bt

	# body + torso
	var hips: Vector3 = Vector3(0, hip_h, 0)
	body.transform = Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(-sway))), hips)
	var tb: Basis = Basis.from_euler(Vector3(0, deg_to_rad(twist), deg_to_rad(-lean)), EULER_ORDER_YXZ)
	torso.transform = Transform3D(tb, Vector3.ZERO)
	var head_off: Vector3 = (rest[head] as Transform3D).origin
	head.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-lean * 0.3), deg_to_rad(-twist * 0.6), 0)), tb * head_off)

	var body_xf: Transform3D = body.transform
	var body_inv: Transform3D = body_xf.affine_inverse()

	# legs: feet on the deck (front foot L at -Z), knees forward (+X)
	var front: Vector3 = Vector3(0.02, DECK_TOP + feet_lift + board_lift * 0.6, -0.25)
	var back: Vector3 = Vector3(0.02, DECK_TOP + feet_lift + board_lift * 0.6, 0.22)
	if sk.pushing and not sk.braking and sk.state == Skater.State.GROUND and sk.velocity.length() < 6.5 and not sk.manual_on:
		var ph: float = fposmod(sk.push_phase, 1.0)
		if ph < 0.55:
			var k: float = ph / 0.55
			back = Vector3(0.05, maxf(0.0, sin(k * PI) * 0.16), 0.22 + 0.45 * sin(k * PI * 0.5))
	if sk.state == Skater.State.BAIL and sk.bail_kind == "runout":
		# running steps on the ground, easing back onto the deck for the last quarter
		var ph: float = sk.bail_time * 11.0
		var on: float = clampf((bail_u - 0.75) / 0.25, 0.0, 1.0)
		var run_f: Vector3 = Vector3(0.1, maxf(0.0, sin(ph)) * 0.22 - 0.02, -0.05 - cos(ph) * 0.34)
		var run_b: Vector3 = Vector3(-0.1, maxf(0.0, -sin(ph)) * 0.22 - 0.02, -0.05 + cos(ph) * 0.34)
		front = run_f.lerp(front, on)
		back = run_b.lerp(back, on)
	elif sk.state == Skater.State.BAIL:
		var amp: float = 0.12 if sk.bail_kind == "slam" else 0.25
		var w: float = sin(sk.bail_time * 11.0)
		front = Vector3(0.3, 0.2 + w * amp, -0.5)
		back = Vector3(-0.3, 0.3 - w * amp, 0.4)
	_leg(leg_l, shin_l, "L", front, body_inv)
	_leg(leg_r, shin_r, "R", back, body_inv)

	# arms
	var sh_l: Vector3 = tb * (rest[arm_l] as Transform3D).origin
	var sh_r: Vector3 = tb * (rest[arm_r] as Transform3D).origin
	var spread: float = arms_out
	var free_l: Vector3 = sh_l + Vector3(0.10 + 0.1 * spread, -0.42 + 0.55 * spread, -0.18 - 0.30 * spread)
	var free_r: Vector3 = sh_r + Vector3(0.05, -0.40 + 0.5 * spread, 0.20 + 0.34 * spread)
	if sk.state == Skater.State.BAIL and sk.bail_kind == "runout":
		var ph2: float = sk.bail_time * 11.0
		free_l = sh_l + Vector3(0.12, -0.3, -0.05 + cos(ph2) * 0.3)
		free_r = sh_r + Vector3(-0.12, -0.3, 0.05 - cos(ph2) * 0.3)
	elif sk.state == Skater.State.BAIL:
		var w2: float = sin(sk.bail_time * 9.0)
		free_l = sh_l + Vector3(0.1, 0.4 + w2 * 0.2, -0.5)
		free_r = sh_r + Vector3(-0.1, 0.4 - w2 * 0.2, 0.5)
	var hand_l: Vector3 = free_l
	var hand_r: Vector3 = free_r
	if grab_amt > 0.01 and sk.grab_kind != "":
		var gp: Array = _grab_points(sk.grab_kind, body_inv)
		var target_l: Vector3 = gp[0]
		var target_r: Vector3 = gp[1]
		hand_l = free_l.lerp(target_l, grab_amt * grab_use_l)
		hand_r = free_r.lerp(target_r, grab_amt * grab_use_r)
	else:
		grab_use_l = 0.0
		grab_use_r = 0.0
	_arm(arm_l, fore_l, sh_l, hand_l, Vector3(-0.3, -0.2, -0.6))
	_arm(arm_r, fore_r, sh_r, hand_r, Vector3(-0.3, -0.2, 0.6))


func _grab_points(kind: String, body_inv: Transform3D) -> Array:
	var bxf: Transform3D = board.transform
	var toe: Vector3 = body_inv * (bxf * Vector3(0.125, DECK_TOP, -0.02))
	var heel: Vector3 = body_inv * (bxf * Vector3(-0.125, DECK_TOP, -0.02))
	var nose: Vector3 = body_inv * (bxf * Vector3(0.0, DECK_TOP + 0.03, -0.42))
	var free_l: Vector3 = body_inv * (bxf * Vector3(0.1, DECK_TOP, 0.0))
	grab_use_l = 0.0
	grab_use_r = 0.0
	var tl: Vector3 = free_l
	var tr: Vector3 = free_l
	match kind:
		"none":    # indy: back hand, toe edge
			tr = toe
			grab_use_r = 1.0
		"left":    # melon: front hand, heel edge
			tl = heel
			grab_use_l = 1.0
		"right":   # mute: front hand, toe edge
			tl = toe
			grab_use_l = 1.0
		"forward": # nosegrab
			tl = nose
			grab_use_l = 1.0
		"back":    # method: front hand, heel edge, board pulled high
			tl = heel
			grab_use_l = 1.0
	return [tl, tr]


func _leg(leg: Node3D, shin: Node3D, side: String, foot_root: Vector3, body_inv: Transform3D) -> void:
	var hip: Vector3 = (rest[leg] as Transform3D).origin
	var ankle_target: Vector3 = body_inv * (foot_root + Vector3(0, ANKLE_TO_SOLE, 0))
	var chain: Array = ik(hip, ankle_target, THIGH, SHIN, Vector3(1.0, 0.0, 0.0))
	var knee: Vector3 = chain[0]
	var ankle: Vector3 = chain[1]
	var thigh_b: Basis = aim_down(knee - hip, Vector3.RIGHT)
	leg.transform = Transform3D(thigh_b, hip)
	var shin_global: Basis = aim_down(ankle - knee, Vector3.RIGHT)
	shin.transform = Transform3D(thigh_b.inverse() * shin_global, (rest[shin] as Transform3D).origin)
	# keep the shoe flat on the board whatever the shin is doing
	var foot_basis: Basis = Basis.IDENTITY
	var r: Basis = shin_global.inverse() * body_inv.basis * foot_basis
	var ankle_local: Vector3 = Vector3(0, -SHIN, 0)
	for pair in shoes[side]:
		var m: Node3D = pair[0]
		var t0: Transform3D = pair[1]
		if String(m.name).begins_with("KneePad"):
			continue
		m.transform = Transform3D(r, ankle_local) * Transform3D(Basis.IDENTITY, t0.origin - ankle_local)


func _arm(arm: Node3D, fore: Node3D, shoulder: Vector3, hand: Vector3, pole: Vector3) -> void:
	var chain: Array = ik(shoulder, hand, UPPER_ARM, FORE_ARM, pole)
	var elbow: Vector3 = chain[0]
	var wrist: Vector3 = chain[1]
	var up_b: Basis = aim_down(elbow - shoulder, Vector3.RIGHT)
	arm.transform = Transform3D(up_b, shoulder)
	var fore_g: Basis = aim_down(wrist - elbow, Vector3.RIGHT)
	fore.transform = Transform3D(up_b.inverse() * fore_g, (rest[fore] as Transform3D).origin)
