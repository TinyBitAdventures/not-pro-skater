extends Node
## Pass / fail feel tests on the greybox (headless, exact 120 Hz ticks):
##   FEEL=all godot --headless --path . --fixed-fps 120 res://scenes/dev_feel.tscn
##   FEEL=vert,transfer VERBOSE=1 ...        (a subset, with a per-tick trace)
## Exit code = number of failures. Each test spawns a fresh skater on a greybox Start_ marker.

const DT: float = 1.0 / 120.0
const ALL: Array[String] = ["momentum", "seam", "curb", "step", "qp_air", "vert", "transfer", "curve_rail", "kink",
	"land_0", "land_20", "land_34", "land_45", "land_65", "land_180", "rail_magnet", "early_tap", "early_hold",
	"vert_frame", "bail_small", "bail_big"]

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

func _spawn(start: String, v0: float = 0.0, offset: Vector3 = Vector3.ZERO) -> void:
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
	var ok: bool = got and max_dev < 0.03 and end_dir.x > 0.8
	_result("curve_rail", ok, "grind=%s for %.2f s, off the arc by %.3f m max (want < 0.03), exit dir (%.2f, %.2f, %.2f)" % [
		got, ground_s, max_dev, end_dir.x, end_dir.y, end_dir.z])


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
		await _tick()
		if sk.state == Skater.State.GRIND:
			got = true
			last_z = sk.global_position.z
		elif got:
			break
	_result("kink", got and last_z < -13.0, "grind=%s, rode to z %.1f (rail ends at -14)" % [got, last_z])


## Rail 1.1 m to the side of the air path, grind pressed ~0.25 s before the rail: magnetism should lock on.
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
