extends Node
## Pass / fail feel tests on the greybox (headless, exact 120 Hz ticks):
##   FEEL=all godot --headless --path . --fixed-fps 120 res://scenes/dev_feel.tscn
##   FEEL=vert,transfer VERBOSE=1 ...        (a subset, with a per-tick trace)
## Exit code = number of failures. Each test spawns a fresh skater on a greybox Start_ marker.

const DT: float = 1.0 / 120.0
const ALL: Array[String] = ["momentum", "seam", "curb", "step", "qp_air", "vert", "transfer", "curve_rail", "kink",
	"land_0", "land_20", "land_34", "land_45", "land_65", "land_180", "rail_magnet", "early_tap", "early_hold",
	"vert_frame", "bail_small", "bail_big", "manual_combo", "nose_combo", "push_no_combo", "manual_hold",
	"manual_drop", "manual_air", "wallplant", "bail_no_snap", "camera_wall", "push_finish", "mini_angle", "mini_pop", "spin_rate", "lip_stall", "lip_arm",
	"grind_hold", "grind_drop", "grind_lean", "edge_warp", "wallride", "wallie", "wallride_headon", "grind_ground"]

var level: Level
var sk: Skater
var verbose: bool = false
var results: Array[Dictionary] = []
var bails: Array[String] = []
var tricks: Array[String] = []
var landings: Array[String] = []


func _ready() -> void:
	verbose = OS.get_environment("VERBOSE") != ""
	_run.call_deferred()


func _run() -> void:
	Game.steer_mode = "screen"
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/greybox.glb", "grey")
	await get_tree().physics_frame
	var want: String = OS.get_environment("FEEL")
	var names: Array[String] = ALL.duplicate()
	if want != "" and want != "all":
		names.clear()
		for n in want.split(","):
			names.append(n.strip_edges())
	for n in names:
		var m: String = "_t_" + n
		if n.begins_with("land_"):
			await _t_land(float(n.trim_prefix("land_")), n)
		elif has_method(m):
			await call(m)
		else:
			_result(n, false, "unknown test")
	var fails: int = 0
	print("")
	print("[feel] ---------------------------------------------------------------")
	for r in results:
		print("[feel] %s  %-12s %s" % ["PASS" if r["ok"] else "FAIL", r["name"], r["msg"]])
		if not r["ok"]:
			fails += 1
	print("[feel] %d / %d passed" % [results.size() - fails, results.size()])
	get_tree().quit(fails)


# ------------------------------------------------------------------ helpers

func _spawn(start: String, v0: float = 0.0, offset: Vector3 = Vector3.ZERO, turn_deg: float = 0.0) -> void:
	if sk != null:
		sk.queue_free()
		await get_tree().physics_frame
	sk = Skater.new()
	sk.with_visual = false
	sk.scripted = true
	sk.score = ScoreKeeper.new()
	sk.grind_lines = level.grind_lines
	add_child(sk)
	bails.clear()
	tricks.clear()
	landings.clear()
	sk.landing.connect(func(k: String) -> void: landings.append(k))
	sk.bailed.connect(func(r: String) -> void: bails.append(r))
	sk.score.trick_added.connect(func(t: String, _p: int) -> void: tricks.append(t))
	var xf: Transform3D = level.starts[start]
	xf.origin += offset
	if turn_deg != 0.0:
		xf.basis = xf.basis.rotated(Vector3.UP, deg_to_rad(turn_deg))
	sk.place_at(xf)
	await get_tree().physics_frame
	if offset.y < 0.5:
		for i in 30:                      # markers sit 2 cm up: settle onto the ground first
			if sk.state == Skater.State.GROUND and sk.is_on_floor():
				break
			await get_tree().physics_frame
	if v0 > 0.0:
		sk.velocity = sk.hdg * v0


func _tick(n: int = 1) -> void:
	for i in n:
		await get_tree().physics_frame
		if verbose:
			print("[trace] st=%d pos=(%.2f,%.2f,%.2f) v=(%.2f,%.2f,%.2f) n=(%.2f,%.2f,%.2f) yaw=%.0f" % [sk.state,
				sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y,
				sk.velocity.z, sk.floor_n.x, sk.floor_n.y, sk.floor_n.z, rad_to_deg(sk.yaw)])


func _result(name: String, ok: bool, msg: String) -> void:
	results.append({"name": name, "ok": ok, "msg": msg})
	print("[feel] %s %s: %s" % [name, "ok" if ok else "FAIL", msg])


## Holds the stick along the skater's heading (screen steering) = keep pushing straight.
func _push() -> void:
	sk.inp.world_dir = sk.hdg
	sk.inp.move = Vector2(0, -1)


func _coast() -> void:
	sk.inp.world_dir = Vector3.ZERO
	sk.inp.move = Vector2.ZERO


## Grinding: lean against the tip like a player watching the balance meter (stick across the rail).
func _steady() -> void:
	var u: float = clampf(-(sk.grind_balance * 3.0 + sk._grind_bal_vel * 0.8), -1.0, 1.0)
	sk.inp.world_dir = _right_of_travel() * u
	sk.inp.move = Vector2.ZERO


func _right_of_travel() -> Vector3:
	return sk.velocity.cross(Vector3.UP).normalized()


func _ang(a: Vector3, b: Vector3) -> float:
	var ah: Vector3 = Vector3(a.x, 0, a.z)
	var bh: Vector3 = Vector3(b.x, 0, b.z)
	if ah.length() < 0.01 or bh.length() < 0.01:
		return 0.0
	return rad_to_deg(ah.angle_to(bh))


# ------------------------------------------------------------------ rolling

func _t_momentum() -> void:
	await _spawn("flat", 10.0)
	_coast()
	await _tick(600)
	var v: float = sk.velocity.length()
	_result("momentum", v >= 7.5 and bails.is_empty(), "coast 5 s from 10 m/s -> %.2f m/s (want >= 7.5)" % v)


func _t_seam() -> void:
	await _spawn("seam", 9.0)
	var max_dev: float = 0.0
	var airs: int = 0
	var min_v: float = 99.0
	var prev: int = sk.state
	for i in 700:
		_push()
		await _tick()
		max_dev = maxf(max_dev, rad_to_deg(sk.floor_n.angle_to(Vector3.UP)))
		if sk.state == Skater.State.AIR and prev != Skater.State.AIR:
			airs += 1
		prev = sk.state
		if i > 10:
			min_v = minf(min_v, sk.velocity.length())
	_result("seam", max_dev < 2.0 and airs == 0, "board tilt max %.2f deg, %d accidental airs, min speed %.1f" % [max_dev, airs, min_v])


func _t_curb() -> void:
	await _spawn("curb", 7.0)
	var top_y: float = 0.0
	for i in 400:
		_push()
		await _tick()
		if sk.global_position.z < -8.0:
			break
		if sk.global_position.z < -1.0 and sk.global_position.z > -5.0:
			top_y = maxf(top_y, sk.global_position.y)
	var ok: bool = bails.is_empty() and sk.global_position.z < -6.0 and top_y > 0.09 and top_y < 0.25
	_result("curb", ok, "0.12 m curb: rode over=%s, highest point on it %.2f (want 0.09 - 0.25, no launch), bails=%s" % [sk.global_position.z < -6.0, top_y, bails])


func _t_step() -> void:
	await _spawn("curb", 7.0)
	var max_y_on_step: float = 0.0
	for i in 480:
		_push()
		await _tick()
		if sk.global_position.z < -14.0 and sk.global_position.z > -18.0:
			max_y_on_step = maxf(max_y_on_step, sk.global_position.y)
	var ok: bool = max_y_on_step < 0.3
	_result("step", ok, "0.40 m step blocks: highest point on it %.2f (want < 0.3), bails=%s" % [max_y_on_step, bails])


# ------------------------------------------------------------------ ramps

## Rides up the 3 m quarter at speed with no input: how long is the air?
func _t_qp_air() -> void:
	await _spawn("qp", 14.0)
	_coast()
	var air: float = 0.0
	for i in 720:
		await _tick()
		if sk.state == Skater.State.AIR and sk.global_position.y > 1.0:
			air = maxf(air, sk.air_time)
		if air > 0.0 and sk.state != Skater.State.AIR:
			break
	_result("qp_air", air >= 0.9 and air <= 1.5 and bails.is_empty(), "3 m quarter at 14 m/s: %.2f s of air (want 0.9 - 1.5), bails=%s" % [air, bails])


## Straight up the vert wall with no input: must come back down the same face, lined up, no bail.
func _t_vert() -> void:
	await _spawn("vert", 15.0)
	_coast()
	var took_off: Vector3 = Vector3.INF
	var landed: Vector3 = Vector3.INF
	var air: float = 0.0
	for i in 900:
		var was: int = sk.state
		await _tick()
		if was == Skater.State.GROUND and sk.state == Skater.State.AIR and took_off == Vector3.INF:
			took_off = sk.global_position
		if sk.state == Skater.State.AIR:
			air = sk.air_time
		if was == Skater.State.AIR and sk.state != Skater.State.AIR and took_off != Vector3.INF:
			landed = sk.global_position
			await _tick(60)
			break
	var ok: bool = landed != Vector3.INF and bails.is_empty() and landed.y < 3.2 and landed.z > -11.5 \
		and absf(landed.x - took_off.x) < 0.5 and air > 0.4 and sk.velocity.z > 1.0
	_result("vert", ok, "air %.2f s, took off y %.2f, landed (%.2f, %.2f, %.2f), rolling back +z %.1f m/s, bails=%s" % [
		air, took_off.y, landed.x, landed.y, landed.z, sk.velocity.z, bails])


## Same launch, pushing up the wall, with the transfer button (manual) at the lip: clears the coping onto the deck.
func _t_transfer() -> void:
	await _spawn("vert", 15.0)
	var popped: bool = false
	var on_deck: bool = false
	for i in 900:
		sk.inp.world_dir = Vector3(0, 0, -1)
		sk.inp.move = Vector2(0, -1)
		var was: int = sk.state
		await _tick()
		if was == Skater.State.GROUND and sk.state == Skater.State.AIR and not popped:
			sk.inp.ollie_pressed = true
			sk.inp.manual = true
			popped = true
		if sk.state == Skater.State.GROUND and sk.global_position.y > 3.2 and sk.global_position.z < -11.4:
			on_deck = true
			break
	_result("transfer", on_deck and bails.is_empty(), "pop + transfer button at the lip reaches the deck: %s, bails=%s" % [on_deck, bails])


# ------------------------------------------------------------------ rails

## Ollie onto the curved rail and ride it round: the grind must stay on the curve.
func _t_curve_rail() -> void:
	await _spawn("curve", 8.0)
	var max_dev: float = 0.0
	var ground_s: float = 0.0
	var got: bool = false
	var end_dir: Vector3 = Vector3.ZERO
	for i in 480:
		if sk.state == Skater.State.GROUND:
			_push()
		if not got and sk.state == Skater.State.GROUND and sk.global_position.z < -2.2:
			sk.inp.ollie_pressed = true
		if sk.state == Skater.State.AIR and sk.velocity.y < 1.0:
			sk.inp.grind_pressed = true
		if sk.state == Skater.State.GRIND:
			_steady()
		await _tick()
		if sk.state == Skater.State.GRIND:
			got = true
			var p: Vector3 = sk.global_position - Vector3.UP * Skater.GRIND_ORIGIN_DY
			var r: float = Vector2(p.x - 70.0, p.z + 4.0).length()
			max_dev = maxf(max_dev, absf(r - 8.0))
			ground_s += DT
			end_dir = sk.velocity.normalized()
		elif got:
			break
	var ok: bool = got and max_dev < 0.03 and end_dir.x > 0.8 and bails.is_empty()
	_result("curve_rail", ok, "grind=%s for %.2f s, off the arc by %.3f m max (want < 0.03), exit dir (%.2f, %.2f, %.2f), bails=%s" % [
		got, ground_s, max_dev, end_dir.x, end_dir.y, end_dir.z, bails])


func _t_kink() -> void:
	await _spawn("kink", 8.0)
	var got: bool = false
	var last_z: float = 0.0
	for i in 480:
		if sk.state == Skater.State.GROUND:
			_push()
		if not got and sk.state == Skater.State.GROUND and sk.global_position.z < 0.2:
			sk.inp.ollie_pressed = true
		if sk.state == Skater.State.AIR and sk.velocity.y < 2.0:
			sk.inp.grind_pressed = true
		if sk.state == Skater.State.GRIND:
			_steady()
		await _tick()
		if sk.state == Skater.State.GRIND:
			got = true
			last_z = sk.global_position.z
		elif got:
			break
	_result("kink", got and last_z < -13.0 and bails.is_empty(), "grind=%s, rode to z %.1f (rail ends at -14), bails=%s" % [got, last_z, bails])


## Rail 1.1 m to the side of the air path, grind pressed ~0.25 s before the rail: magnetism should lock on.
## Grind pressed on the ground, rolling up beside a rail too high to step onto (0.67 m): an automatic pop onto it.
func _t_grind_ground() -> void:
	await _spawn("rail_side", 7.0)
	var pressed: bool = false
	var aired: bool = false
	var grind_t: float = 0.0
	for i in 360:
		if sk.state == Skater.State.GROUND and not pressed:
			_push()
		if not pressed and sk.state == Skater.State.GROUND and sk.global_position.z < -3.6:
			_coast()
			sk.inp.grind_pressed = true
			pressed = true
		await _tick()
		aired = aired or sk.state == Skater.State.AIR
		if sk.state == Skater.State.GRIND:
			grind_t += DT
	_result("grind_ground", pressed and aired and grind_t > 0.4, "grind pressed on the ground 1.1 m beside a 0.67 m rail: popped %s, grind %.2f s (want > 0.4), bails=%s" % [
		aired, grind_t, bails])


func _t_rail_magnet() -> void:
	await _spawn("rail_side", 7.0)
	var ollied: bool = false
	var press_at: int = -1
	var grind_t: float = 0.0
	var press_gap: float = 0.0
	for i in 360:
		if sk.state == Skater.State.GROUND and not ollied:
			_push()
		if not ollied and sk.global_position.z < -1.2:
			sk.inp.ollie_pressed = true
			ollied = true
		var to_rail: float = (sk.global_position.z - (-4.05)) / maxf(-sk.velocity.z, 0.1)
		if ollied and press_at < 0 and sk.state == Skater.State.AIR and to_rail <= 0.25:
			sk.inp.grind_pressed = true
			press_at = i
			press_gap = to_rail
		await _tick()
		if sk.state == Skater.State.GRIND:
			grind_t += DT
	_result("rail_magnet", grind_t > 0.4, "pressed %.2f s before the rail starts, 1.1 m to the side: grind %.2f s (want > 0.4)" % [press_gap, grind_t])


# ------------------------------------------------------------------ jumping

## Chaining ollies: a tap while still falling (0.3 s before touchdown) must pop again on landing.
func _t_early_tap() -> void:
	await _early(false, "early_tap")


func _t_early_hold() -> void:
	await _early(true, "early_hold")


func _early(hold_mode: bool, name: String) -> void:
	await _spawn("flat", 7.0)
	sk.force_charge = hold_mode
	var pops: Dictionary = {"n": 0}        # lambdas capture primitives by value: count in a Dictionary
	sk.sfx.connect(func(k: String) -> void:
		if k == "ollie":
			pops["n"] += 1)
	var pressed: bool = false
	var phase: int = 0            # 0 first jump, 1 waiting to tap early, 2 done
	for i in 360:
		_push()
		if phase == 0:
			if hold_mode:
				sk.inp.ollie_held = i < 3
				sk.inp.ollie_released = i == 3
			else:
				sk.inp.ollie_pressed = i == 0
			if sk.state == Skater.State.AIR and sk.velocity.y < 0.0:
				phase = 1
		elif phase == 1:
			var h: float = sk.global_position.y
			var vy: float = -sk.velocity.y
			var g: float = sk.tune.air_gravity_down
			var t_land: float = (-vy + sqrt(vy * vy + 2.0 * g * maxf(h, 0.0))) / g
			if t_land <= 0.3:
				if hold_mode:
					sk.inp.ollie_held = true
					await _tick(3)
					sk.inp.ollie_held = false
					sk.inp.ollie_released = true
				else:
					sk.inp.ollie_pressed = true
				phase = 2
		await _tick()
		sk.inp.ollie_released = false
	_result(name, int(pops["n"]) >= 2, "%s tapped 0.3 s before landing: %d pops (want 2)" % ["hold/release" if hold_mode else "tap", int(pops["n"])])


# ------------------------------------------------------------------ vert frame and bails

## In a vert air the rider stays side-on to the wall (feet toward it) and turns in the wall's plane.
func _t_vert_frame() -> void:
	await _spawn("vert", 15.0)
	_coast()
	var max_up_y: float = 0.0
	var seen: bool = false
	var f0: Vector3 = Vector3.ZERO
	var turn: float = 0.0
	for i in 600:
		await _tick()
		if sk.state == Skater.State.AIR and sk.vert_air:
			if not seen:
				f0 = sk.air_fwd
				seen = true
			max_up_y = maxf(max_up_y, absf(sk.air_up.y))
			turn = maxf(turn, rad_to_deg(f0.angle_to(sk.air_fwd)))
		elif seen:
			break
	_result("vert_frame", seen and max_up_y < 0.5 and turn > 150.0, "vert air: rider's up stays within %.0f deg of horizontal (want < 30), turns %.0f deg in the wall's plane (want > 150)" % [
		rad_to_deg(asin(clampf(max_up_y, 0.0, 1.0))), turn])


func _t_bail_small() -> void:
	await _t_land(65.0, "land_65_kind")
	var kind: String = sk.bail_kind
	results.pop_back()
	_result("bail_small", kind == "runout", "a 65 degree landing at 8 m/s is a %s (want runout)" % kind)


func _t_bail_big() -> void:
	await _spawn("flat", 0.0, Vector3(0, 4.0, 0))
	sk.velocity = sk.hdg * 16.0 + Vector3.UP * 3.0
	sk._enter_air()
	sk.yaw += deg_to_rad(85.0)
	sk.hdg = sk.heading_h()
	for i in 240:
		await _tick()
		if sk.state == Skater.State.BAIL:
			break
	_result("bail_big", sk.bail_kind != "runout", "a sideways landing from 4 m at 16 m/s is a %s (want slam or tumble)" % sk.bail_kind)


# ------------------------------------------------------------------ manuals

## Taps the stick: `seq` = list of [move.y, ticks]. Keeps rolling straight meanwhile.
func _stick(seq: Array) -> void:
	for step in seq:
		for i in int(step[1]):
			sk.inp.world_dir = sk.hdg if sk.state == Skater.State.GROUND and false else Vector3.ZERO
			sk.inp.move = Vector2(0, float(step[0]))
			await _tick()
	sk.inp.move = Vector2.ZERO


func _t_manual_combo() -> void:
	await _spawn("flat", 6.0)
	await _stick([[-1.0, 6], [1.0, 6], [0.0, 2]])
	_result("manual_combo", sk.manual_on and sk.manual_kind == "manual", "up then down: manual_on=%s kind=%s" % [sk.manual_on, sk.manual_kind])


func _t_nose_combo() -> void:
	await _spawn("flat", 6.0)
	await _stick([[1.0, 6], [-1.0, 6], [0.0, 2]])
	_result("nose_combo", sk.manual_on and sk.manual_kind == "nose", "down then up: manual_on=%s kind=%s" % [sk.manual_on, sk.manual_kind])


## Holding W to push and then braking with S must not start a manual.
func _t_push_no_combo() -> void:
	await _spawn("flat", 4.0)
	await _stick([[-1.0, 90], [1.0, 20], [0.0, 2]])
	_result("push_no_combo", not sk.manual_on, "push 0.75 s then brake: manual_on=%s (want false)" % sk.manual_on)


## A player who corrects the balance keeps the manual going; letting go of the stick loses it.
func _t_manual_hold() -> void:
	await _spawn("flat", 8.0)
	await _stick([[-1.0, 6], [1.0, 6], [0.0, 1]])
	var held: float = 0.0
	for i in 480:
		sk.inp.move = Vector2(0, clampf(sk.manual_balance * 3.0 + sk._balance_vel * 0.6, -1.0, 1.0))
		await _tick()
		if not sk.manual_on:
			break
		held += DT
	_result("manual_hold", held >= 3.0 and bails.is_empty(), "balancing keeps the manual %.1f s (want >= 3), bails=%s" % [held, bails])


func _t_manual_drop() -> void:
	await _spawn("flat", 8.0)
	await _stick([[-1.0, 6], [1.0, 6], [0.0, 1]])
	var t: float = 0.0
	for i in 600:
		await _tick()
		t += DT
		if not sk.manual_on:
			break
	var kind: String = sk.bail_kind if not bails.is_empty() else "-"
	_result("manual_drop", not bails.is_empty() and kind == "runout" and t < 4.0, "no balancing: fell off after %.1f s as a %s (want a run-out)" % [t, kind])


## The combo pressed while still in the air lands straight into a manual.
func _t_manual_air() -> void:
	await _spawn("flat", 7.0)
	sk.inp.ollie_pressed = true
	await _tick()
	for i in 200:
		await _tick()
		if sk.state == Skater.State.AIR and sk.velocity.y < -2.0:
			break
	await _stick([[-1.0, 5], [1.0, 5], [0.0, 1]])
	for i in 120:
		await _tick()
		if sk.state == Skater.State.GROUND:
			break
	await _tick(3)
	_result("manual_air", sk.manual_on, "combo in the air, landed in a manual: %s" % sk.manual_on)


# ------------------------------------------------------------------ wall plant

func _t_wallplant() -> void:
	await _spawn("wall", 7.0)
	var planted: bool = false
	var popped: bool = false
	var away: float = 0.0
	for i in 300:
		if sk.state == Skater.State.GROUND and not popped:
			_push()
		if not popped and sk.global_position.z < -34.6:
			sk.inp.ollie_pressed = true
			popped = true
		if popped and sk.state == Skater.State.AIR and sk._wall_t > 0.0:
			sk.inp.ollie_pressed = true
		await _tick()
		if tricks.has("Wallplant"):
			planted = true
		if planted:
			away = maxf(away, sk.velocity.z)
		if planted and sk.state == Skater.State.GROUND:
			break
	_result("wallplant", planted and away > 2.0 and bails.is_empty(), "jump at the wall, pop on contact: wallplant=%s, off the wall at %.1f m/s, bails=%s" % [planted, away, bails])


# ------------------------------------------------------------------ wallrides

## Riding at the greybox wall 30 degrees off it, pop and press grind: rides along the wall, drops off at its end
## (or with `jump_at`, jumps off: a wallie), lands without a bail. Returns [rode seconds, landed, the trick names].
func _wallride_run(test_name: String, jump_at: float, turn: float = -60.0, offset: Vector3 = Vector3(-6.0, 0.0, -5.5)) -> Array:
	await _spawn("wall", 8.0, offset, turn)
	var rode: float = 0.0
	var popped: bool = false
	var pressed: bool = false
	var landed: bool = false
	var was_wall: bool = false
	var off_wall_v: Vector3 = Vector3.ZERO
	for i in 600:
		if sk.state == Skater.State.GROUND and not popped:
			_push()
			# the wall's face is at z -38: pop about 1.6 m before it
			if sk.global_position.z < -36.4:
				sk.inp.ollie_pressed = true
				popped = true
		elif sk.state == Skater.State.AIR and popped and not pressed:
			_coast()
			sk.inp.grind_pressed = true
			pressed = true
		if sk.wallriding and jump_at >= 0.0 and rode >= jump_at:
			sk.inp.ollie_pressed = true
		var was: int = sk.state
		await _tick()
		if sk.wallriding:
			rode += DT
			was_wall = true
		elif was_wall and off_wall_v == Vector3.ZERO:
			off_wall_v = sk.velocity
		if rode > 0.0 and was != Skater.State.GROUND and sk.state == Skater.State.GROUND:     # (off the wall or down it)
			landed = true
			break
		if not bails.is_empty():
			break
	return [rode, landed, off_wall_v]


func _t_wallride() -> void:
	var r: Array = await _wallride_run("wallride", -1.0)
	var ok: bool = float(r[0]) > 0.3 and bool(r[1]) and bails.is_empty() and tricks.has("Wallride")
	_result("wallride", ok, "pop + grind at a wall 30 degrees off: rode it %.2f s (want > 0.3), landed %s, tricks %s, bails %s" % [
		r[0], r[1], tricks, bails])


func _t_wallie() -> void:
	var r: Array = await _wallride_run("wallie", 0.2)
	var away: float = (r[2] as Vector3).z                     # the wall faces +z
	var ok: bool = float(r[0]) > 0.15 and bool(r[1]) and bails.is_empty() and tricks.has("Wallie") and away > 1.5 \
		and (r[2] as Vector3).y > 3.0
	_result("wallie", ok, "jump on the wall: tricks %s, off it at (%.1f, %.1f, %.1f) (want up and away), landed %s, bails %s" % [
		tricks, (r[2] as Vector3).x, (r[2] as Vector3).y, (r[2] as Vector3).z, r[1], bails])


## Straight at the wall with grind pressed: not a wallride (that's for a wall met at an angle).
func _t_wallride_headon() -> void:
	var r: Array = await _wallride_run("wallride_headon", -1.0, 0.0, Vector3.ZERO)
	_result("wallride_headon", float(r[0]) == 0.0, "pop + grind straight at the wall: rode it %.2f s (want 0), tricks %s" % [r[0], tricks])


# ------------------------------------------------------------------ bails and camera

## The loose board rolls on; the rider gets up and walks to it: no jump when the bail ends.
func _t_bail_no_snap() -> void:
	await _spawn("flat", 0.0, Vector3(0, 2.0, 0))
	sk.velocity = sk.hdg * 9.0 + Vector3.UP * 2.0
	sk._enter_air()
	sk.yaw += deg_to_rad(80.0)
	sk.hdg = sk.heading_h()
	var last: Vector3 = sk.rider_position()
	var max_jump: float = 0.0
	var gap_end: float = -1.0
	var was_bail: bool = false
	for i in 600:
		await _tick()
		var p: Vector3 = sk.rider_position()
		if verbose and p.distance_to(last) > 0.12:
			print("[feel]   tick %d state %d phase %s run %s jump %.3f" % [i, sk.state, sk.visual.phys_phase if sk.visual else "-", sk.run_state, p.distance_to(last)])
		max_jump = maxf(max_jump, p.distance_to(last))
		last = p
		if sk.state == Skater.State.BAIL:
			was_bail = true
			gap_end = sk.rider_position().distance_to(sk.global_position)
		elif was_bail:
			break
	_result("bail_no_snap", was_bail and max_jump < 0.2 and gap_end < 0.05, "%s: rider moved at most %.2f m in a tick (want < 0.2), %.2f m from the board as the bail ends" % [
		sk.bail_kind, max_jump, gap_end])


## Back to a wall: the chase camera must stay out of the rider's body.
func _t_camera_wall() -> void:
	await _spawn("wall", 0.0, Vector3(0, 0, -7.4))
	sk.hdg = Vector3(0, 0, 1)                     # facing away from the wall (it is right behind)
	sk.yaw = PI
	var cam: ChaseCamera = ChaseCamera.new()
	add_child(cam)
	cam.attach(sk)
	var worst: float = 99.0
	for i in 60:
		await get_tree().process_frame
		var c: Vector3 = cam.global_position
		var f: Vector3 = sk.global_position
		var inside: bool = Vector2(c.x - f.x, c.z - f.z).length() < 0.5 and c.y < f.y + 2.0
		worst = minf(worst, 0.0 if inside else Vector2(c.x - f.x, c.z - f.z).length())
	cam.queue_free()
	_result("camera_wall", worst > 0.0, "camera with a wall right behind the rider: inside the body=%s" % [worst == 0.0])


## Let go of W mid-push: the stride finishes (foot back on the deck) instead of snapping.
func _t_push_finish() -> void:
	await _spawn("flat", 0.0)
	for i in 30:
		_push()
		await _tick()
	var mid: float = sk.push_anim
	_coast()
	var frames: int = 0
	while sk.push_anim >= 0.0 and frames < 240:
		await _tick()
		frames += 1
	_result("push_finish", mid > 0.0 and mid < 0.9 and frames > 5 and sk.push_anim < 0.0, "released at stride %.2f: the stride ran on %d ticks, then ended" % [mid, frames])


# ------------------------------------------------------------------ landing

## Drops the skater from 1.5 m with its board turned `deg` away from the direction of travel.
func _t_land(deg: float, name: String) -> void:
	await _spawn("flat", 0.0, Vector3(0, 1.5, 0))
	var travel: Vector3 = sk.hdg
	sk.velocity = travel * 8.0 + Vector3.UP * 2.0
	sk._enter_air()
	sk.yaw += deg_to_rad(deg)
	sk.hdg = sk.heading_h()
	_coast()
	var landed: bool = false
	for i in 240:
		sk.yaw = sk.yaw   # no spin input: the board keeps its angle
		await _tick()
		if sk.state != Skater.State.AIR:
			landed = true
			break
	await _tick(30)
	var bailed: bool = not bails.is_empty()
	var off: float = _ang(sk.hdg, sk.velocity) if sk.velocity.length() > 0.5 else 0.0
	var fakie: bool = sk.get("stance") == "fakie"
	var ok: bool = false
	var want: String = ""
	if deg < 35.0:
		ok = landed and not bailed and (off < 5.0 or off > 175.0)
		want = "clean, board lined up with travel"
	elif deg < 58.0:
		ok = landed and not bailed and landings.has("sketchy")
		want = "sketchy landing, no bail"
	elif deg < 150.0:
		ok = bailed
		want = "bail"
	else:
		ok = landed and not bailed and fakie
		want = "rolls away fakie"
	_result(name, ok, "board %.0f deg off travel -> bailed=%s, board vs travel after %.1f deg, fakie=%s (want: %s)" % [
		deg, bailed, off, fakie, want])


## Up a half pipe wall at an angle: the air must stay in the ramp (come back down the same transition, rolling
## back toward the flat), not fly off over the deck. Riders rarely hit a wall dead straight.
func _t_mini_angle() -> void:
	await _mini_run("mini_angle", 20.0, false, Vector3(3.0, 0, 0))


## A pop partway up the face (jump released early): straight up and back down the transition, like a skate game.
func _t_mini_pop() -> void:
	await _mini_run("mini_pop", 10.0, true, Vector3(0.6, 0, 0))


func _mini_run(test_name: String, turn: float, pop_on_face: bool, offset: Vector3) -> void:
	await _spawn("mini", 10.5, offset, turn)
	_coast()
	var start_z: float = sk.global_position.z
	var into: float = -signf(sk.hdg.z)          # heading toward the wall along z
	var took_off: bool = false
	var popped: bool = false
	var landed_y: float = INF
	var landed_n: float = 1.0
	var back: bool = false
	var max_y: float = 0.0
	for i in 600:
		if pop_on_face and not popped and sk.state == Skater.State.GROUND and sk.floor_n.y < 0.8 and sk.velocity.y > 0.5:
			sk.inp.ollie_pressed = true
			popped = true
		var was: int = sk.state
		await _tick()
		if sk.state == Skater.State.AIR and sk.global_position.y > 0.8:
			took_off = true
		if sk.state == Skater.State.AIR:
			max_y = maxf(max_y, sk.global_position.y)
		if took_off and was == Skater.State.AIR and sk.state != Skater.State.AIR:
			landed_y = sk.global_position.y
			landed_n = sk.floor_n.y
			await _tick(30)
			back = (sk.global_position.z - start_z) * into < 1.6 and sk.state == Skater.State.GROUND   # back down toward the flat
			break
	# landed back on the curved transition (not the deck, not out on the flat), then rolled back down it
	var on_curve: bool = landed_n < 0.97 and landed_y > 0.1 and landed_y < 1.72
	var ok: bool = took_off and on_curve and back and bails.is_empty() and (not pop_on_face or popped)
	_result(test_name, ok, "%s: air up to %.2f m, landed at y %.2f on a %.0f deg slope (want the transition, not the deck or the flat), rolled back %s, bails=%s" % [
		"pop on the face" if pop_on_face else "%d deg approach" % int(turn), max_y, landed_y,
		rad_to_deg(acos(clampf(landed_n, -1.0, 1.0))), back, bails])


## Full stick in the air: a 360 should take most of a second, not a flick (it was 630 deg/s in 0.18 s).
func _t_spin_rate() -> void:
	await _spawn("flat", 0.0, Vector3(0, 3.0, 0))
	sk._enter_air()
	sk.inp.move = Vector2(1, 0)
	sk.inp.world_dir = sk.hdg.cross(Vector3.UP)     # screen steering: the stick points right
	var t: float = 0.0
	var start_yaw: float = sk.yaw
	var t360: float = -1.0
	var t_half: float = -1.0
	for i in 240:
		await _tick()
		t += 1.0 / 120.0
		var turned: float = absf(sk.yaw - start_yaw)
		if t_half < 0.0 and absf(sk.spin_vel) >= sk.tune.spin_max * 0.5:
			t_half = t
		if turned >= TAU:
			t360 = t
			break
		sk.velocity.y = 0.0                     # hold it in the air
	_result("spin_rate", t360 > 0.75 and t360 < 1.2 and t_half > 0.08, "360 in %.2f s (want 0.75 - 1.2), half speed after %.2f s" % [t360, t_half])


## Lip trick from a half pipe air: grind near the coping stalls on it (Rock to Fakie with no stick), jump
## drops back in, and it rolls away fakie on the transition without a bail.
func _t_lip_stall() -> void:
	await _spawn("mini", 10.5, Vector3(0.6, 0, 0))
	_coast()
	var stalled: bool = false
	var stall_t: float = 0.0
	var landed: String = ""
	var pressed: bool = false
	var last: Vector3 = sk.render_position()
	var max_jump: float = 0.0
	for i in 900:
		var rp: Vector3 = sk.render_position()
		max_jump = maxf(max_jump, rp.distance_to(last))
		last = rp
		if not pressed and sk.vert_air and sk.global_position.y > 1.4:
			sk.inp.grind_pressed = true
			pressed = true
		if sk.lip_kind != "":
			stalled = true
			stall_t += 1.0 / 120.0
			if stall_t > 0.8:
				sk.inp.ollie_pressed = true
		var was: int = sk.state
		await _tick()
		if stalled and sk.lip_kind == "" and was == Skater.State.AIR and sk.state == Skater.State.GROUND:
			landed = "fakie" if sk.stance == "fakie" else "regular"
			await _tick(30)
			break
	var ok: bool = stalled and tricks.has("Rock to Fakie") and stall_t >= 0.8 and landed == "fakie" and bails.is_empty() \
		and max_jump < 0.16
	_result("lip_stall", ok, "stalled %s for %.2f s, tricks %s, dropped in and rolled away %s, drawn rider moved at most %.3f m in a tick (want < 0.16), bails=%s" % [
		stalled, stall_t, tricks, landed, max_jump, bails])


## Grind pressed while still riding up the face waits for the coping: stall on arrival (Nose Stall with up).
func _t_lip_arm() -> void:
	await _spawn("mini", 9.6, Vector3(0.6, 0, 0))
	_coast()
	var armed: bool = false
	var kind: String = ""
	for i in 600:
		if not armed and sk.state == Skater.State.GROUND and sk.floor_n.y < 0.75 and sk.velocity.y > 0.5:
			sk.inp.grind_pressed = true
			sk.inp.world_dir = sk.hdg          # stick toward the deck: nose stall
			armed = true
		await _tick()
		if sk.lip_kind != "":
			kind = sk.lip_kind
			break
	_result("lip_arm", kind == "Nose Stall", "grind pressed halfway up the face: stall %s (want Nose Stall), bails=%s" % [kind if kind != "" else "none", bails])



# ------------------------------------------------------------------ grind balance

## Ollie onto the curved rail and slow the grind to 3 m/s (about four seconds of rail left). `stick` runs every
## grinding tick; returns {t: seconds grinding, lean: balance on the last grinding tick, at: body there,
## right: right of travel there, meter: the HUD showed the balance}.
func _slow_grind(stick: Callable) -> Dictionary:
	await _spawn("curve", 8.0)
	var r: Dictionary = {"t": 0.0, "lean": 0.0, "at": Vector3.ZERO, "right": Vector3.ZERO, "meter": false, "got": false}
	for i in 900:
		if sk.state == Skater.State.GROUND:
			_push()
		if not r["got"] and sk.state == Skater.State.GROUND and sk.global_position.z < -2.2:
			sk.inp.ollie_pressed = true
		if sk.state == Skater.State.AIR and sk.velocity.y < 1.0:
			sk.inp.grind_pressed = true
		if sk.state == Skater.State.GRIND:
			if not r["got"]:
				sk.grind_speed = 3.0
			r["got"] = true
			stick.call()
			r["meter"] = r["meter"] or sk.balancing()
			r["lean"] = sk.grind_balance
			r["at"] = sk.global_position
			r["right"] = _right_of_travel()
		await _tick()
		if sk.state == Skater.State.GRIND:
			r["t"] += DT
		elif r["got"]:
			break
	return r


## Leaning against the tip keeps a long, slow grind going to the end of the rail, with the meter up.
func _t_grind_hold() -> void:
	var r: Dictionary = await _slow_grind(_steady)
	_result("grind_hold", r["got"] and r["t"] > 3.0 and bails.is_empty() and r["meter"],
		"balancing: grind %.2f s at 3 m/s (want > 3, to the rail's end), meter shown=%s, bails=%s" % [r["t"], r["meter"], bails])


## Hands off the stick: the lean tips over and the rider falls off the rail, to the side it leaned.
func _t_grind_drop() -> void:
	var r: Dictionary = await _slow_grind(_coast)
	await _tick(60)
	var off: float = (sk.global_position - r["at"]).dot(r["right"]) * signf(r["lean"])
	var ok: bool = bails == ["grind"] and r["t"] > 0.9 and r["t"] < 2.4 and off > 0.2
	_result("grind_drop", ok, "no balancing: fell off after %.2f s (want 0.9 - 2.4), bails=%s, landed %.2f m to the side it leaned (want > 0.2)" % [
		r["t"], bails, off])


## The stick is the rider's weight: holding it right leans right (and over, soon).
func _t_grind_lean() -> void:
	var r: Dictionary = await _slow_grind(func() -> void:
		sk.inp.world_dir = _right_of_travel()
		sk.inp.move = Vector2.ZERO)
	_result("grind_lean", bails == ["grind"] and r["lean"] > 0.9 and r["t"] < 1.2,
		"stick held right: fell off after %.2f s (want < 1.2), leaning %.2f (want > 0.9, right), bails=%s" % [r["t"], r["lean"], bails])


# ------------------------------------------------------------------ level edge

## Rolling at the edge of the level: warped back to the last safe spot before reaching it (never falls off),
## stopped and facing back in.
func _t_edge_warp() -> void:
	await _spawn("flat", 0.0, Vector3.ZERO, 90.0)          # facing -x: the west edge is 20 m away
	sk.bounds = level.bounds
	var start: Vector3 = sk.global_position
	var warps: Array[int] = [0]
	sk.warped.connect(func() -> void: warps[0] += 1)
	sk.velocity = sk.hdg * 10.0
	_coast()
	var low: float = INF
	var closest: float = INF
	for i in 360:
		await _tick()
		low = minf(low, sk.global_position.y)
		closest = minf(closest, sk._edge_distance())
	var back: float = sk.global_position.distance_to(start)
	var ok: bool = warps[0] == 1 and low > -0.2 and closest > 1.5 and back < 1.0 and sk.hdg.x > 0.9
	_result("edge_warp", ok, "bounds %s: warped %d time(s) (want 1), closest to the edge %.2f m (want > 1.5), lowest y %.2f, back %.2f m from the safe spot, facing (%.2f, %.2f) (want +x)" % [
		level.bounds, warps[0], closest, low, back, sk.hdg.x, sk.hdg.z])
