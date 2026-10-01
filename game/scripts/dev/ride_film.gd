extends Node3D
## Films riding moves with real physics on the greybox (rig_tour freezes physics and pokes fields, so it shows a
## pose's target, never how it moves): pushes, pumps, ollies, flips, manuals, grinds, carves, landings.
##   CLIP=ollie,kickflip godot --path . res://scenes/dev_ridefilm.tscn --fixed-fps 60 --resolution 640x480 \
##       --audio-driver Dummy --position -3000,-3000
## Writes ../shots/ride_<clip>_NN.png from the clip's moment (the pop, the grind lock, ...), EVERY seconds apart
## (each clip has its own default), N frames. Every frame prints metrics too:
##   soles  how far each sole is above the grip under it (m, - = sunk into the deck), and whether it is over the deck
##   wheels the lowest and highest wheel above the ground under it (riding on the ground only: a manual lifts two)
##   cut    rider points (shins, feet) inside the deck: a flip passing through the legs
## Headless it prints the metrics without pictures, and exits with the number of frames over the limits
## (soles more than 1.5 cm off a deck the rider stands on, wheels in the ground, anything cut):
##   CLIP=all godot --headless --path . --fixed-fps 120 res://scenes/dev_ridefilm.tscn

const DT: float = 1.0 / 120.0
const HALF_L: float = 0.4
const HALF_W: float = 0.1025

var level: Level
var sk: Skater
var cam: Camera3D
var clip: Dictionary = {}
var d: Dictionary = {}                    # the clip's own state (lambdas capture primitives by value)
var ticks: int = 0
var film_tick: int = -1
var shots: int = 0
var busy: bool = false
var headless: bool = DisplayServer.get_name() == "headless"
var bad: int = 0
var report: Array[String] = []
var cam_side: Vector3 = Vector3.RIGHT
var cam_look: Vector3 = Vector3.ZERO


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.steer_mode = "screen"
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/greybox.glb", "grey")
	GreyEnv.build(self)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	await get_tree().physics_frame
	var want: String = OS.get_environment("CLIP") if OS.get_environment("CLIP") != "" else "ollie"
	var names: Array = _clips().keys() if want == "all" else Array(want.split(","))
	for nm in names:
		var spec: Dictionary = _clips().get(String(nm).strip_edges(), {})
		if spec.is_empty():
			print("[ride] unknown clip ", nm)
			continue
		await _play(String(nm).strip_edges(), spec)
	print("")
	for r in report:
		print(r)
	print("[ride] %d frame(s) over the limits" % bad)
	get_tree().quit(bad)


func _play(nm: String, spec: Dictionary) -> void:
	if sk != null:
		sk.queue_free()
		for c in get_children():
			if c is LooseBoard:
				c.queue_free()
		await get_tree().physics_frame
	sk = Skater.new()
	sk.rider = OS.get_environment("RIDER") if OS.get_environment("RIDER") != "" else "dev"
	sk.scripted = true
	sk.grind_lines = level.grind_lines
	add_child(sk)
	var xf: Transform3D = level.starts[spec.get("start", "flat")]
	xf.origin += spec.get("offset", Vector3.ZERO)
	if spec.has("turn"):
		xf.basis = xf.basis.rotated(Vector3.UP, deg_to_rad(float(spec["turn"])))
	sk.place_at(xf)
	await get_tree().physics_frame
	sk.velocity = sk.hdg * float(spec.get("v0", 0.0))
	if spec.has("air"):                       # thrown into the air: (height above the marker in offset)
		sk.velocity = sk.hdg * float(spec.get("v0", 0.0)) + Vector3.UP * float(spec["air"])
		sk._enter_air()
		sk.yaw += deg_to_rad(float(spec.get("yaw_off", 0.0)))
		sk.hdg = sk.heading_h()
		sk.air_time = 0.5
	d = {"name": nm, "phase": 0, "t": 0}
	clip = spec
	clip["name"] = nm
	ticks = 0
	film_tick = -1
	shots = 0
	var every: float = float(OS.get_environment("EVERY")) if OS.get_environment("EVERY") != "" else float(spec.get("every", 0.1))
	var n: int = int(OS.get_environment("N")) if OS.get_environment("N") != "" else int(spec.get("n", 12))
	clip["every_ticks"] = maxi(1, int(round(every / DT)))
	clip["n"] = n
	cam_side = sk.hdg.cross(Vector3.UP).normalized()
	cam_look = sk.render_position() + Vector3.UP * 0.75
	var worst: Dictionary = {"sole": 0.0, "wheel": 0.0, "cut": 0}
	clip["worst"] = worst
	while shots < n and ticks < 120 * 20:
		await get_tree().physics_frame
		if busy:
			continue
		if film_tick >= 0 and (ticks - film_tick) >= shots * int(clip["every_ticks"]):
			await _shot()
	report.append("[ride] %-11s soles off the grip up to %.3f m, wheels into the ground %.3f m, cut frames %d" % [
		nm, worst["sole"], worst["wheel"], worst["cut"]])
	clip = {}


func _physics_process(_dt: float) -> void:
	if clip.is_empty() or sk == null:
		return
	ticks += 1
	(clip["drive"] as Callable).call()
	if film_tick < 0 and (clip["begin"] as Callable).call():
		film_tick = ticks


func _process(_dt: float) -> void:
	if sk == null or not is_instance_valid(sk) or clip.is_empty():
		return
	_aim()


## Where the camera looks from: side-on to the clip's start heading ("side"), three-quarter from the chest side
## and ahead ("near", default) or behind ("behind", for carves).
func _aim() -> void:
	var p: Vector3 = sk.rider_position()
	cam_look = cam_look.lerp(p + Vector3.UP * 0.65, 0.25)
	var mode: String = clip.get("cam", "near")
	var fwd: Vector3 = Vector3.UP.cross(cam_side).normalized()      # the start heading
	var dist: float = float(clip.get("dist", 2.3))
	var from: Vector3
	match mode:
		"side":
			from = cam_side * dist + Vector3.UP * 0.25
		"behind":
			from = -fwd * dist + Vector3.UP * 0.6
		"chase":                                  # behind the way it's going now (carves)
			var h: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z)
			var back: Vector3 = -h.normalized() if h.length() > 0.5 else -fwd
			from = back * dist + Vector3.UP * 0.5
		_:
			from = (cam_side * 0.85 + fwd * 0.4 + Vector3.UP * 0.05).normalized() * dist
	cam.global_transform = Transform3D(Basis.looking_at(-from, Vector3.UP), cam_look + from)


func _shot() -> void:
	busy = true
	var t: float = (ticks - film_tick) * DT
	var m: Dictionary = metrics(sk)
	var st: String = ["GROUND", "AIR", "GRIND", "BAIL"][sk.state]
	var line: String = "[ride] %s %02d t=%.2f %-6s" % [clip["name"], shots, t, st]
	if OS.get_environment("LEAN_DBG") != "":
		var rgd: RiderRig = sk.visual as RiderRig
		var spine: Vector3 = rgd.global_transform * rgd._glob[rgd._b["head"]].origin - rgd.global_transform * rgd._glob[rgd._b["pelvis"]].origin
		var v_h: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z).normalized()
		line += " lean %+.2f spine->left %+.3f" % [sk.lean, spine.normalized().dot(Vector3.UP.cross(v_h))]
	if m.has("soles"):
		var s: Array = m["soles"]
		line += " soles %+.3f%s %+.3f%s" % [s[0][0], "" if s[0][1] else "(off)", s[1][0], "" if s[1][1] else "(off)"]
	if m.has("wheels"):
		line += " wheels %+.3f..%+.3f" % [m["wheels"][0], m["wheels"][1]]
	line += " cut %d pitch %.0f" % [m.get("cut", 0), m.get("pitch", 0.0)]
	if m.has("rail"):
		line += " rail %s" % [(m["rail"] as Vector3).snapped(Vector3(0.001, 0.001, 0.001))]
	var w: Dictionary = clip["worst"]
	var over: bool = false
	if m.has("soles") and bool(m.get("on_deck", false)):
		for s2 in m["soles"]:
			if bool(s2[1]):
				w["sole"] = maxf(w["sole"], absf(float(s2[0])))
				over = over or absf(float(s2[0])) > 0.015
	if m.has("wheels"):
		w["wheel"] = maxf(w["wheel"], -float(m["wheels"][0]))
		over = over or float(m["wheels"][0]) < -0.01
	if int(m.get("cut", 0)) > 0:
		w["cut"] += 1
		over = true
	if over:
		bad += 1
		line += "  <-"
	print(line)
	if not headless:
		await RenderingServer.frame_post_draw
		var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
		DirAccess.make_dir_recursive_absolute(dir)
		get_viewport().get_texture().get_image().save_png(dir.path_join("ride_%s_%02d.png" % [clip["name"], shots]))
	shots += 1
	busy = false


# ------------------------------------------------------------------ metrics

## Soles against the grip, wheels against the ground, legs against the deck, from the rig as it is drawn now.
static func metrics(s: Skater) -> Dictionary:
	var rg: RiderRig = s.visual
	var out: Dictionary = {}
	if rg == null or rg._walk_mode or rg.phys_phase != "":
		return out
	var bt: Transform3D = rg.board.transform
	var inv: Transform3D = bt.affine_inverse()
	var soles: Array = []
	var cut: int = 0
	for side in ["l", "r"]:
		var fi: int = rg._b["foot_" + side]
		var f: Transform3D = rg._glob[fi]
		var turn: Basis = f.basis * rg._rest_model[fi].basis.inverse()
		var sole: Vector3 = inv * (f.origin - turn * rg._ankle_off)
		var over: bool = absf(sole.x) < HALF_W + 0.03 and absf(sole.z) < HALF_L
		if side == ("l" if s.stance == "fakie" else "r") and s.push_anim >= 0.0 and s.state == Skater.State.GROUND:
			over = false                      # the pushing foot leaves the deck on purpose
		soles.append([sole.y - RiderRig.deck_y(sole.z), over])
		# the shin and foot (knee -> ankle -> ball) must stay out of the deck
		var knee: Vector3 = inv * rg._glob[rg._b["calf_" + side]].origin
		var ankle: Vector3 = inv * f.origin
		var ball: Vector3 = inv * rg._glob[rg._b["ball_" + side]].origin
		for k in 9:
			var u: float = k / 8.0
			var p: Vector3 = knee.lerp(ankle, u * 1.6) if u < 0.625 else ankle.lerp(ball, (u - 0.625) / 0.375)
			# inside the deck's slab, or a shin's thickness under it (a joint at the grip is a shoe standing on it)
			if absf(p.x) < HALF_W + 0.01 and absf(p.z) < HALF_L - 0.02 and p.y < RiderRig.deck_y(p.z) - 0.004 \
					and p.y > RiderRig.deck_y(p.z) - 0.012 - 0.025:
				cut += 1
				if OS.get_environment("CUT_DBG") != "":
					print("    cut: %s point %d at (%.3f, %.3f, %.3f), grip %.3f" % [side, k, p.x, p.y, p.z, RiderRig.deck_y(p.z)])
	out["soles"] = soles
	if s.state == Skater.State.GRIND and s.grind_line != null:
		# where the rail (its top: the grind line) passes under the board, in board space: across, above the
		# deck's underside (- = into it), along
		var lp: Vector3 = rg.global_transform.affine_inverse() * s.grind_line.point_at(s.grind_dist)
		var rb: Vector3 = inv * lp
		out["rail"] = Vector3(rb.x, rb.y - RiderRig.DECK_BOTTOM, rb.z)
	out["cut"] = cut
	out["pitch"] = rg.board_pitch
	out["on_deck"] = s.state == Skater.State.GROUND or s.state == Skater.State.GRIND or (s.state == Skater.State.AIR \
		and rg.free_feet < 0.01)
	if s.state == Skater.State.GROUND:
		var lo: float = INF
		var hi: float = -INF
		var space: PhysicsDirectSpaceState3D = rg.get_world_3d().direct_space_state
		for wx in [-LooseBoard.WHEEL_X, LooseBoard.WHEEL_X]:
			for wz in [-LooseBoard.TRUCK_Z, LooseBoard.TRUCK_Z]:
				var p2: Vector3 = rg.global_transform * (bt * Vector3(wx, 0.0, wz))
				var up: Vector3 = rg.global_transform.basis.y.normalized()     # the drawn frame's up
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p2 + up * 0.3, p2 - up * 0.5, 1)
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty():
					continue
				var g: float = (p2 - (hit["position"] as Vector3)).dot(up)
				lo = minf(lo, g)
				hi = maxf(hi, g)
		if lo < INF:
			out["wheels"] = [lo, hi]
	return out


# ------------------------------------------------------------------ clips

func _push() -> void:
	sk.inp.world_dir = sk.hdg
	sk.inp.move = Vector2(0, -1)


func _coast() -> void:
	sk.inp.world_dir = Vector3.ZERO
	sk.inp.move = Vector2.ZERO


func _right() -> Vector3:
	return sk.hdg.cross(Vector3.UP).normalized()


## Grinding: lean against the tip (stick across the rail), like a player watching the meter.
func _steady() -> void:
	var u: float = clampf(-(sk.grind_balance * 3.0 + sk._grind_bal_vel * 0.8), -1.0, 1.0)
	sk.inp.world_dir = sk.velocity.cross(Vector3.UP).normalized() * u
	sk.inp.move = Vector2.ZERO


## A pop on the flat after `at` ticks, then the trick: a flip (stick `dir`), a grab, a spin, or nothing.
func _ollie_drive(trick: String, dir: String) -> Callable:
	return func() -> void:
		_coast()
		if d["phase"] == 0 and ticks >= 24:
			sk.inp.ollie_pressed = true
			d["phase"] = 1
		elif d["phase"] == 1 and sk.state == Skater.State.AIR:
			d["phase"] = 2
			d["t"] = ticks
		elif d["phase"] == 2 and ticks - int(d["t"]) >= 5:
			var stick: Vector3 = Vector3.ZERO
			match dir:
				"left": stick = -_right()
				"right": stick = _right()
				"forward": stick = sk.hdg
				"back": stick = -sk.hdg
			if trick == "flip":
				sk.inp.world_dir = stick
				sk.inp.flip_pressed = true
				d["phase"] = 3
			elif trick == "grab":
				sk.inp.world_dir = stick
				sk.inp.grab_held = true
			elif trick == "spin":
				sk.inp.world_dir = _right()
		if sk.state != Skater.State.AIR and d["phase"] >= 2:
			sk.inp.grab_held = false


func _clips() -> Dictionary:
	var in_air: Callable = func() -> bool: return sk.state == Skater.State.AIR
	var c: Dictionary = {
		"cruise": {"v0": 5.0, "every": 0.25, "n": 4, "drive": _coast, "begin": func() -> bool: return ticks > 30},
		"push": {"v0": 0.0, "every": 0.1, "n": 16, "drive": _push, "begin": func() -> bool: return ticks > 1},
		"wallplant": {"start": "wall", "v0": 7.0, "every": 0.04, "n": 16, "cam": "side", "dist": 3.0,
			"drive": func() -> void:
				if sk.state == Skater.State.GROUND and d["phase"] == 0:
					_push()
				else:
					_coast()
				if d["phase"] == 0 and sk.global_position.z < -34.6:
					sk.inp.ollie_pressed = true
					d["phase"] = 1
				if d["phase"] == 1 and sk.state == Skater.State.AIR and sk._wall_t > 0.0:
					sk.inp.ollie_pressed = true,
			"begin": func() -> bool: return sk.wallplant_t > 0.0},
		"push_fakie": {"v0": 1.5, "every": 0.1, "n": 16, "cam": "side", "dist": 2.6,
			"drive": func() -> void:
				if ticks == 1:
					sk.stance = "fakie"             # rolling tail first
				_push(),
			"begin": func() -> bool: return ticks > 2},
		"push_side": {"v0": 1.5, "every": 0.1, "n": 16, "cam": "side", "dist": 2.6, "drive": _push,
			"begin": func() -> bool: return ticks > 2},
		"wallride": {"start": "wall", "v0": 8.0, "offset": Vector3(-6.0, 0.0, -5.5), "turn": -60.0, "every": 0.06, "n": 18,
			"cam": "near", "dist": 3.2,
			"drive": func() -> void:
				if sk.state == Skater.State.GROUND and d["phase"] == 0:
					_push()
					if sk.global_position.z < -36.4:
						sk.inp.ollie_pressed = true
						d["phase"] = 1
				elif sk.state == Skater.State.AIR and d["phase"] == 1:
					_coast()
					sk.inp.grind_pressed = true
					d["phase"] = 2,
			"begin": func() -> bool: return sk.state == Skater.State.AIR},
		"idle": {"v0": 0.0, "every": 0.4, "n": 32, "drive": _coast, "begin": func() -> bool: return ticks > 1},
		"cheer": {"v0": 5.0, "every": 0.1, "n": 10,
			"drive": func() -> void:
				_coast()
				if ticks == 30:
					(sk.visual as RiderRig)._on_banked(4000, 5),
			"begin": func() -> bool: return ticks >= 30},
		"carve": {"v0": 7.0, "every": 0.1, "n": 20, "cam": "chase", "dist": 2.8,
			"drive": func() -> void:
				var s: float = 1.0 if int(floor(ticks / 72.0)) % 2 == 0 else -1.0
				sk.inp.world_dir = sk.hdg.rotated(Vector3.UP, s * 1.0)
				sk.inp.move = Vector2(-s, -0.5),
			"begin": func() -> bool: return ticks > 60},
		"ollie": {"v0": 6.0, "every": 0.05, "n": 16, "drive": _ollie_drive("", ""), "begin": in_air},
		"kickflip": {"v0": 6.0, "every": 0.04, "n": 18, "drive": _ollie_drive("flip", "none"), "begin": in_air},
		"heelflip": {"v0": 6.0, "every": 0.04, "n": 18, "drive": _ollie_drive("flip", "left"), "begin": in_air},
		"shove": {"v0": 6.0, "every": 0.04, "n": 18, "drive": _ollie_drive("flip", "right"), "begin": in_air},
		"hardflip": {"v0": 6.0, "every": 0.04, "n": 18, "drive": _ollie_drive("flip", "forward"), "begin": in_air},
		"impossible": {"v0": 6.0, "every": 0.04, "n": 18, "drive": _ollie_drive("flip", "back"), "begin": in_air},
		"indy": {"v0": 6.0, "every": 0.05, "n": 14, "drive": _ollie_drive("grab", "none"), "begin": in_air},
		"spin": {"v0": 6.0, "every": 0.05, "n": 16, "drive": _ollie_drive("spin", ""), "begin": in_air},
		"land_big": {"v0": 6.0, "offset": Vector3(0, 2.2, 0), "air": 1.0, "every": 0.05, "n": 20, "drive": _coast,
			"begin": func() -> bool: return sk.global_position.y < 1.6},
		"sketchy": {"v0": 7.0, "offset": Vector3(0, 1.2, 0), "air": 1.0, "yaw_off": 46.0, "every": 0.05, "n": 20,
			"drive": _coast, "begin": func() -> bool: return sk.global_position.y < 0.5},
		"pump": {"start": "mini", "v0": 3.0, "every": 0.08, "n": 24, "dist": 3.0,
			"drive": func() -> void:
				if sk.velocity.length() < 5.0:
					_push()
				else:
					_coast(),
			"begin": func() -> bool: return ticks > 60},
	}
	for kind in ["manual", "nose"]:
		var k: String = kind
		c["manual" if k == "manual" else "nosemanual"] = {"v0": 7.0, "every": 0.15, "n": 12,
			"drive": func() -> void:
				if ticks == 20:
					sk._start_manual(k)
				if sk.manual_on:
					var u: float = clampf(sk.manual_balance * 3.0 + sk._balance_vel * 0.6, -1.0, 1.0)
					sk.inp.move = Vector2(0, u if k == "manual" else -u)
				else:
					_coast(),
			"begin": func() -> bool: return sk.manual_on}
	for lp in [["rock", "none"], ["nosestall", "forward"], ["blunt", "back"], ["axle", "left"], ["disaster", "right"]]:
		var lstick: String = lp[1]
		c["lip_" + String(lp[0])] = {"start": "mini", "v0": 10.5, "offset": Vector3(0.6, 0, 0), "every": 0.08, "n": 12,
			"cam": "side", "dist": 3.4,
			"drive": func() -> void:
				_coast()
				if d["phase"] == 0 and sk.vert_air and sk.global_position.y > 1.4:
					var up_wall: Vector3 = -sk.vert_out
					var r: Vector3 = up_wall.cross(Vector3.UP)
					var st: Vector3 = Vector3.ZERO
					match lstick:
						"forward": st = up_wall
						"back": st = -up_wall
						"left": st = -r
						"right": st = r
					sk.inp.world_dir = st
					sk.inp.grind_pressed = true
					d["phase"] = 1
				elif d["phase"] == 1 and sk.lip_kind != "":
					sk.inp.world_dir = Vector3.ZERO
					sk.lip_balance = 0.0                     # (hold the stall still for the film)
					sk._lip_vel = 0.0,
			"begin": func() -> bool: return sk.lip_kind != ""}
	for g in [["5050", "none"], ["noseslide", "forward"], ["tailslide", "back"], ["boardslide", "board"]]:
		var gname: String = g[0]
		var stick: String = g[1]
		c[gname] = {"start": "rail", "v0": 7.5, "every": 0.1, "n": 10,
			"drive": func() -> void:
				if sk.state == Skater.State.GROUND:
					_push()
					if sk.global_position.z < 0.6 and d["phase"] == 0:
						sk.inp.ollie_pressed = true
						d["phase"] = 1
				elif sk.state == Skater.State.AIR:
					sk.inp.grind_pressed = true
					sk.inp.world_dir = sk.hdg if stick == "forward" else (-sk.hdg if stick == "back" else Vector3.ZERO)
				elif sk.state == Skater.State.GRIND:
					if stick == "board" and sk.grind_kind != "Boardslide":
						sk.grind_kind = "Boardslide"           # (coming in square across the rail is hard to script)
						sk.grind_board_turn = PI * 0.5
					sk.grind_speed = maxf(sk.grind_speed, 3.0)
					_steady(),
			"begin": func() -> bool: return sk.state == Skater.State.GRIND}
	return c
