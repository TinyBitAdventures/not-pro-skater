extends Node
## Gameplay audit scenarios (headless):
##   AUDIT=<name> godot --headless --path . res://scenes/dev_audit_skate.tscn
## names: flip_window ollie_double spin_stick tank_word cam_snap manual_farm wall obstacles roundtrip minipump
##        rail score_math
## Run with --fixed-fps 120: faster than real time, every physics tick exactly 1/120 s (Engine.time_scale would change the tick delta).

const DT: float = 1.0 / 120.0
var level: Level
var sk: Skater
var score: ScoreKeeper
var cam: IsoCamera = null
var t: float = 0.0
var reasons: Array = []
var manual_sfx: int = 0


func _ready() -> void:
	Engine.time_scale = 1.0   # NB: Godot 4 time_scale multiplies the physics delta; use --fixed-fps 120 for fast exact runs
	_detach.call_deferred()


func _detach() -> void:
	var root: Node = get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	_run()


func _setup(x: float, y: float, z: float, face: Vector3, v0: float = 0.0, with_cam: bool = false) -> void:
	if level != null:
		level.queue_free()
	if sk != null:
		sk.queue_free()
	if cam != null:
		cam.queue_free()
		cam = null
	await get_tree().process_frame
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/community_park.glb")
	sk = Skater.new()
	sk.with_visual = false
	sk.scripted = true
	score = ScoreKeeper.new()
	sk.score = score
	sk.grind_lines = level.grind_lines
	reasons.clear()
	manual_sfx = 0
	if with_cam:
		cam = IsoCamera.new()
		add_child(cam)
		cam._apply()
		sk.cam = cam
	add_child(sk)
	sk.bailed.connect(_on_bailed)
	sk.sfx.connect(_on_sfx)
	sk.place_at(Transform3D(Basis.looking_at(face, Vector3.UP), Vector3(x, y, z)))
	await get_tree().physics_frame
	if v0 > 0.0:
		sk.velocity = sk.hdg * v0
	t = 0.0


func _on_bailed(r: String) -> void:
	reasons.append(r)
	if OS.get_environment("VERBOSE") != "":
		print("[audit]     bail(%s) t=%.2f at (%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f)" % [r, t, sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y, sk.velocity.z])


func _on_sfx(k: String) -> void:
	if k == "manual":
		manual_sfx += 1


func _tick() -> void:
	await get_tree().physics_frame
	t += DT


func _wait(sec: float) -> void:
	for i in range(int(sec / DT)):
		await _tick()


func _run() -> void:
	Game.steer_mode = "screen"   # the scenarios drive the stick in screen space; tank ones switch themselves
	var which: String = OS.get_environment("AUDIT")
	if which == "flip_window":
		await _a_flip_window()
	elif which == "ollie_double":
		await _a_ollie_double()
	elif which == "spin_stick":
		await _a_spin_stick()
	elif which == "tank_word":
		await _a_tank_word()
	elif which == "cam_snap":
		await _a_cam_snap()
	elif which == "manual_farm":
		await _a_manual_farm()
	elif which == "wall":
		await _a_wall()
	elif which == "obstacles":
		await _a_obstacles()
	elif which == "roundtrip":
		await _a_roundtrip()
	elif which == "minipump":
		await _a_minipump()
	elif which == "rail":
		await _a_rail()
	elif which == "score_math":
		_a_score_math()
	elif which == "tank_live":
		await _a_tank_live()
	elif which == "stall":
		await _a_stall()
	elif which == "dbg5":
		await _a_dbg5()
	elif which == "dbg4":
		await _a_dbg4()
	elif which == "dbg":
		await _a_dbg()
	elif which == "dbg2":
		await _a_dbg2()
	elif which == "map":
		await _a_map()
	elif which == "dbg3":
		await _a_dbg3()
	else:
		print("[audit] unknown AUDIT=", which)
	get_tree().quit()


# ------------------------------------------------------------------ feel: flip / ollie

func _a_flip_window() -> void:
	print("[audit] flip_window: flat ollie at ~5 m/s; flip button pressed when air_time >= tf")
	for tf in [0.0, 0.03, 0.05, 0.07, 0.09, 0.10, 0.12, 0.16, 0.25, 0.40]:
		await _setup(-6.0, 0.06, -2.0, Vector3(1, 0, 0), 5.0)
		var ollied: bool = false
		var flipped: bool = false
		var peak: float = 0.0
		var ollie_frame: int = -1
		var frames: int = 0
		while frames < 400:
			await _tick()
			frames += 1
			sk.inp.world_dir = sk.hdg
			if not ollied and frames > 20:
				sk.inp.ollie_pressed = true
				ollied = true
				ollie_frame = frames
				if tf == 0.0:
					sk.inp.flip_pressed = true    # Space + J on the same physics frame
					flipped = true
			if ollied and not flipped and sk.state == Skater.State.AIR and sk.air_time >= tf:
				sk.inp.flip_pressed = true
				flipped = true
			if sk.state == Skater.State.AIR:
				peak = maxf(peak, sk.global_position.y - 0.06)
			if ollied and frames > ollie_frame + 10 and sk.state == Skater.State.GROUND:
				break
		print("[audit]   tf=%.2f  flip_credited=%s  names=%s  hop_air=%.3f s  peak=%.2f m  flip_kind_left=%s" % [
			tf, "YES" if score.trick_count > 0 else "no ", str(score.names), float(sk.stats["max_air"]), peak, sk.flip_kind])


func _a_ollie_double() -> void:
	print("[audit] ollie_double: second Space press dt after the first (still in air)")
	for gap in [-1.0, 0.05, 0.09, 0.105, 0.13, 0.2]:
		await _setup(-6.0, 0.06, -2.0, Vector3(1, 0, 0), 4.0)
		var ollie_t: float = -1.0
		var peak: float = 0.0
		var frames: int = 0
		var second: bool = false
		while frames < 400:
			await _tick()
			frames += 1
			sk.inp.world_dir = sk.hdg
			if frames == 30:
				sk.inp.ollie_pressed = true
				ollie_t = t
			if gap > 0.0 and not second and ollie_t > 0.0 and t - ollie_t >= gap:
				sk.inp.ollie_pressed = true
				second = true
			if sk.state == Skater.State.AIR:
				peak = maxf(peak, sk.global_position.y - 0.06)
			if frames > 40 and ollie_t > 0.0 and sk.state == Skater.State.GROUND:
				break
		print("[audit]   second_press_after=%s  peak=%.3f m  air=%.3f s" % ["none" if gap < 0.0 else "%.3f" % gap, peak, float(sk.stats["max_air"])])


func _a_spin_stick() -> void:
	print("[audit] spin_stick: skater rides toward screen direction m (real IsoCamera yaw 45), ollies, keeps holding m")
	var sticks: Array = [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0),
		Vector2(0.707, -0.707), Vector2(-0.707, -0.707), Vector2(0.707, 0.707), Vector2(-0.707, 0.707)]
	for m in sticks:
		await _setup(-1.0, 0.06, 0.0, Vector3(1, 0, 0), 0.0, true)
		var d: Vector3 = sk._stick_to_world(m)
		sk.place_at(Transform3D(Basis.looking_at(d, Vector3.UP), Vector3(-1.0, 0.06, 0.0)))
		await _wait(0.2)
		sk.velocity = sk.hdg * 5.0
		var ollied: bool = false
		var last_spin: float = 0.0
		var frames: int = 0
		var bails0: int = int(sk.stats["bails"])
		while frames < 400:
			await _tick()
			frames += 1
			sk.inp.world_dir = d
			sk.inp.move = m
			if OS.get_environment("PERP") != "" and sk.state == Skater.State.AIR:
				sk.inp.world_dir = d.cross(Vector3.UP)   # stick pushed to the rider's right while airborne
				sk.inp.move = Vector2(1, 0)
			if not ollied and frames > 5:
				sk.inp.ollie_pressed = true
				ollied = true
			if sk.state == Skater.State.AIR:
				last_spin = sk.spin_total
			if ollied and frames > 20 and sk.state != Skater.State.AIR and sk.state != Skater.State.GROUND:
				pass
			if ollied and frames > 30 and sk.state == Skater.State.GROUND:
				break
			if sk.state == Skater.State.BAIL:
				break
		print("[audit]   stick=(%.2f,%.2f) world_dir=(%.2f,%.2f)  spin=%.0f deg  bails=%d %s  names=%s" % [
			m.x, m.y, d.x, d.z, rad_to_deg(last_spin), int(sk.stats["bails"]) - bails0, str(reasons), str(score.names)])


func _a_tank_word() -> void:
	print("[audit] tank_word: tank steering, player holds stick UP (= forward for the board); word used for flips/grabs")
	await _setup(-1.0, 0.06, 0.0, Vector3(1, 0, 0), 0.0, true)
	Game.steer_mode = "tank"
	var up: Vector2 = Vector2(0, -1)
	var wd: Vector3 = sk._stick_to_world(up)
	print("[audit]   camera-relative world_dir for stick up = (%.2f, %.2f, %.2f)" % [wd.x, wd.y, wd.z])
	for hd in [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
		var w: String = Tricks.direction_word(wd, hd)
		print("[audit]   board heading (%.0f,%.0f): word=%s -> flip=%s grab=%s (board-relative 'forward' would be Hardflip/Nosegrab)" % [
			hd.x, hd.z, w, Tricks.FLIPS[w][0], Tricks.GRABS[w][0]])
	# live: ollie in tank mode heading east, hold stick up in the air, watch where the air drift goes
	sk.velocity = sk.hdg * 4.0
	var v_at: Vector3 = Vector3.ZERO
	var frames: int = 0
	while frames < 200:
		await _tick()
		frames += 1
		sk.inp.move = up
		sk.inp.world_dir = wd
		if frames == 10:
			sk.inp.ollie_pressed = true
			v_at = sk.velocity
		if frames > 30 and sk.state == Skater.State.GROUND:
			break
	var dv: Vector3 = sk.velocity - v_at
	print("[audit]   tank-mode live hop, stick up held: hdg=(%.2f,%.2f) velocity change during hop dv=(%.2f, %.2f, %.2f)  (board points +X, drift went to camera-forward)" % [
		sk.hdg.x, sk.hdg.z, dv.x, dv.y, dv.z])
	Game.steer_mode = "screen"


func _a_cam_snap() -> void:
	print("[audit] cam_snap: stick held UP while the camera snaps 90 deg (E)")
	await _setup(-1.0, 0.06, 0.0, Vector3(1, 0, 0), 0.0, true)
	var up: Vector2 = Vector2(0, -1)
	var a0: float = rad_to_deg(atan2(sk._stick_to_world(up).x, -sk._stick_to_world(up).z))
	cam.snap_yaw(1)
	var last: float = a0
	var swept: float = 0.0
	for i in range(0, 90):
		cam._process(1.0 / 60.0)
		var w: Vector3 = sk._stick_to_world(up)
		var a: float = rad_to_deg(atan2(w.x, -w.z))
		if i % 6 == 0:
			print("[audit]   frame %2d (%.2fs) world_dir bearing=%.1f deg" % [i, i / 60.0, a])
		last = a
	print("[audit]   bearing went %.1f -> %.1f deg (turn %.1f deg); skater TURN_FAST=%.1f rad/s = %.0f deg/s" % [a0, last, wrapf(last - a0, -180.0, 180.0), Skater.TURN_FAST, rad_to_deg(Skater.TURN_FAST)])
	# three quick presses: lerp_angle takes the short way round
	cam.yaw = deg_to_rad(45.0)
	cam.yaw_target = deg_to_rad(45.0)
	cam.snap_yaw(1)
	cam.snap_yaw(1)
	cam.snap_yaw(1)
	var first: float = cam.yaw
	for i in range(0, 10):
		cam._process(1.0 / 60.0)
	print("[audit]   3x E quickly: target=%.0f deg, yaw after 10 frames moved %.1f deg (negative = spun the OTHER way)" % [
		rad_to_deg(cam.yaw_target), rad_to_deg(cam.yaw - first)])


# ------------------------------------------------------------------ scoring exploits

func _ring_dir(p: Vector3, lane: float) -> Vector3:
	var a: float = atan2(-p.z, p.x)
	var ta: float = a + 0.16
	var tgt: Vector3 = Vector3(lane * cos(ta), 0.0, -lane * sin(ta))
	return (tgt - p).normalized()


func _a_manual_farm() -> void:
	print("[audit] manual_farm: hold M + stick along the ring for 60 s of game time")
	await _setup(0.0, 0.06, 36.0, Vector3(1, 0, 0))
	var next: float = 0.0
	while t < 60.0:
		await _tick()
		sk.inp.world_dir = _ring_dir(sk.global_position, 36.3)
		sk.inp.manual = true
		if t >= next:
			next += 10.0
			print("[audit]   t=%4.1f v=%.2f manual_on=%s tricks=%d names.size=%d pending=%d mult=%d manual_sfx=%d" % [
				t, sk.velocity.length(), str(sk.manual_on), score.trick_count, score.names.size(), score.pending, score.mult, manual_sfx])
	var before: int = score.score
	score.bank()
	print("[audit]   banked %d pts from 60 s of holding one button (mult %d), bails=%d" % [score.score - before, score.mult, int(sk.stats["bails"])])


func _a_score_math() -> void:
	print("[audit] score_math (pure ScoreKeeper)")
	var s: ScoreKeeper = ScoreKeeper.new()
	var seq: String = ""
	var prev: int = 0
	for i in range(12):
		s.add_trick("Kickflip", 300)
		seq += "%d " % (s.pending - prev)
		prev = s.pending
	print("[audit]   12 x Kickflip(300) increments: %s  pending=%d mult=%d" % [seq, s.pending, s.mult])
	# repeat penalty vs many manual flickers
	var s2: ScoreKeeper = ScoreKeeper.new()
	var pts: PackedInt32Array = PackedInt32Array()
	for i in range(100):
		var b: int = s2.pending
		s2.add_trick("Manual", 150)
		pts.append(s2.pending - b)
	print("[audit]   Manual x100 increments (first 5 / at 20 / at 76+): %s / %d / %d" % [str(pts.slice(0, 5)), pts[19], pts[80]])
	# mult applies to hold points
	var s3: ScoreKeeper = ScoreKeeper.new()
	for nm in ["Kickflip", "Heelflip", "Indy", "Melon", "Method", "360"]:
		s3.add_trick(nm, 300)
	s3.add_trick("Manual", 150)
	for i in range(60 * 120):
		s3.hold("manual", 1.0 / 120.0, Tricks.MANUAL_HOLD_RATE)
	s3.bank()
	print("[audit]   7 distinct tricks + 60 s manual hold banked=%d (mult 7)" % s3.score)
	# hold points leaking into next combo
	var s4: ScoreKeeper = ScoreKeeper.new()
	s4.hold("manual", 2.0, 110.0)
	print("[audit]   hold() while not live: pending=%d live=%s (never banked, leaks into next combo)" % [s4.pending, str(s4.live)])
	s4.add_trick("Kickflip", 300)
	s4.bank()
	print("[audit]   next combo Kickflip(300) banked=%d" % s4.score)


# ------------------------------------------------------------------ wall / wedge

func _a_wall() -> void:
	print("[audit] wall: push straight into the east plaza fence (x=20.25) below the crash speed")
	for v0 in [3.0, 6.0]:
		await _setup(18.5, 0.06, 8.0, Vector3(1, 0, 0), v0)
		var maxy: float = 0.0
		for i in range(480):
			await _tick()
			sk.inp.world_dir = Vector3(1, 0, 0)
			maxy = maxf(maxy, sk.global_position.y)
			if i % 20 == 0 and i < 300:
				print("[audit]   v0=%.0f t=%.2f pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) real_speed=%.2f state=%d" % [v0, t, sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y, sk.velocity.z, sk.get_real_velocity().length(), sk.state])
		print("[audit]   v0=%.0f max_y=%.2f bails=%d %s" % [v0, maxy, int(sk.stats["bails"]), str(reasons)])
	print("[audit] wall: push into the small quarter-pipe SIDE panel (x=-6) at ~7.4 m/s then keep pushing")
	await _setup(-8.0, 0.06, 10.5, Vector3(1, 0, 0))
	var maxy2: float = 0.0
	for i in range(720):
		await _tick()
		sk.inp.world_dir = Vector3(1, 0, 0)
		maxy2 = maxf(maxy2, sk.global_position.y)
		if i % 30 == 0 or (sk.state == Skater.State.AIR and i % 6 == 0 and i > 300):
			print("[audit]   t=%.2f pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) state=%d bails=%d" % [t, sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y, sk.velocity.z, sk.state, int(sk.stats["bails"])])
	print("[audit]   max_y=%.2f bails=%d %s" % [maxy2, int(sk.stats["bails"]), str(reasons)])


# ------------------------------------------------------------------ obstacles: air numbers

func _line(label: String, x: float, z: float, face: Vector3, v0: float, secs: float, lip: float = -1.0) -> void:
	await _setup(x, 0.06, z, face, v0)
	var peak: float = 0.0
	var air_max: float = 0.0
	var took: bool = false
	var v_take: Vector3 = Vector3.ZERO
	var p_take: Vector3 = Vector3.ZERO
	var p_land: Vector3 = Vector3.ZERO
	var ollied: bool = false
	var v_pre: Vector3 = Vector3.ZERO
	var v_post: Vector3 = Vector3.ZERO
	var pending_post: bool = false
	for i in range(int(secs / DT)):
		await _tick()
		sk.inp.world_dir = face
		if pending_post:
			v_post = sk.velocity
			pending_post = false
		if lip > 0.0 and not ollied and sk.state == Skater.State.GROUND and sk.floor_n.y < 0.9 and sk.global_position.y > lip * 0.85 and sk.velocity.y > 0.5:
			sk.inp.ollie_pressed = true
			ollied = true
			v_pre = sk.velocity
			pending_post = true
		peak = maxf(peak, sk.global_position.y - 0.06)
		if sk.state == Skater.State.AIR:
			if not took and sk.global_position.y > 0.3:
				took = true
				v_take = sk.velocity
				p_take = sk.global_position
			air_max = maxf(air_max, sk.air_time)
			p_land = sk.global_position
	print("[audit]   %-28s air_max=%.2f s peak=%.2f m takeoff v=(%.1f h, %.1f up) hdist=%.1f m bails=%d%s%s" % [
		label, air_max, peak, Vector2(v_take.x, v_take.z).length(), v_take.y, Vector2(p_land.x - p_take.x, p_land.z - p_take.z).length(),
		int(sk.stats["bails"]), str(reasons) if not reasons.is_empty() else "",
		("  ollie@lip v %.1f,%.1f,%.1f -> %.1f,%.1f,%.1f" % [v_pre.x, v_pre.y, v_pre.z, v_post.x, v_post.y, v_post.z]) if ollied else ""])


func _a_obstacles() -> void:
	print("[audit] obstacles: air time / height, pushing along the line (start speeds in the label)")
	await _line("plaza kicker (H .7) v8", -16.5, 2.4, Vector3(0, 0, -1), 8.0, 3.0)
	await _line("funbox (H .9 deck) v6", 11.5, -3.0, Vector3(0, 0, 1), 6.0, 3.0)
	await _line("pyramid (H .75) v6", 12.0, -15.0, Vector3(0, 0, 1), 6.0, 3.0)
	await _line("stairs (6 x .19) v6", 5.5, 9.0, Vector3(0, 0, -1), 6.0, 4.0)
	await _line("small QP (H1.4) no ollie", -3.5, 1.0, Vector3(0, 0, 1), 6.0, 5.0)
	await _line("small QP (H1.4) ollie@lip", -3.5, 1.0, Vector3(0, 0, 1), 6.0, 5.0, 1.4)
	await _line("big QP (H2.6) no ollie", -6.0, 6.5, Vector3(-1, 0, 0), 6.0, 6.0)
	await _line("big QP (H2.6) ollie@lip", -6.0, 6.5, Vector3(-1, 0, 0), 6.0, 6.0, 2.6)


func _a_roundtrip() -> void:
	print("[audit] roundtrip: small quarter pipe (base z=8.7, climbs +Z). speed at z=6.0 going in vs coming back")
	for mode in ["coast", "hold_toward_ramp", "hold_along_travel"]:
		await _setup(-3.5, 0.06, 3.0, Vector3(0, 0, 1), 5.5)
		var v_in: float = -1.0
		var t_in: float = 0.0
		var v_out: float = -1.0
		var t_out: float = 0.0
		var maxy: float = 0.0
		for i in range(int(6.0 / DT)):
			await _tick()
			var wd: Vector3 = Vector3.ZERO
			if mode == "hold_toward_ramp":
				wd = Vector3(0, 0, 1)
			elif mode == "hold_along_travel":
				wd = Vector3(0, 0, signf(sk.velocity.z)) if absf(sk.velocity.z) > 0.3 else Vector3(0, 0, 1)
			sk.inp.world_dir = wd
			maxy = maxf(maxy, sk.global_position.y)
			var z: float = sk.global_position.z
			if v_in < 0.0 and z >= 6.0 and sk.velocity.z > 0.0:
				v_in = sk.velocity.length()
				t_in = t
			elif v_in > 0.0 and v_out < 0.0 and z <= 6.0 and sk.velocity.z < 0.0:
				v_out = sk.velocity.length()
				t_out = t
		var dt_trip: float = t_out - t_in
		print("[audit]   %-18s v_in=%.2f v_out=%.2f ratio=%.2f  trip=%.2fs  drag-only expectation ratio=%.2f  max_y=%.2f bails=%d" % [
			mode, v_in, v_out, v_out / maxf(v_in, 0.01), dt_trip, exp(-Skater.COAST_DRAG * dt_trip), maxy - 0.06, int(sk.stats["bails"])])


func _a_minipump() -> void:
	print("[audit] minipump: mini ramp (flat between x=-12.5..-7.5 at z=-8), from rest, stick always along travel")
	await _setup(-10.0, 0.06, -8.0, Vector3(1, 0, 0), 3.0)
	var maxv: float = 0.0
	var maxy: float = 0.0
	var next: float = 0.0
	while t < 30.0:
		await _tick()
		var dx: float = signf(sk.velocity.x) if absf(sk.velocity.x) > 0.3 else 0.0
		sk.inp.world_dir = Vector3(dx, 0, 0)
		maxv = maxf(maxv, sk.velocity.length())
		maxy = maxf(maxy, sk.global_position.y - 0.06)
		if t >= next:
			next += 3.0
			print("[audit]   t=%4.1f pos=(%.1f,%.2f,%.1f) v=%.1f state=%d max_v=%.1f max_y=%.2f bails=%d air=%.2f" % [
				t, sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.length(), sk.state, maxv, maxy, int(sk.stats["bails"]), float(sk.stats["max_air"])])


func _a_rail() -> void:
	print("[audit] rail: blue rail x=4, z -0.75..4.75; run -Z from z=10.6 at 8 m/s (orange rail crosses x=4 at z=12.2), ollie at z<7.4, press grind in air")
	for dx in [0.0, 0.6, 0.9, 1.1]:
		await _setup(4.0 + dx, 0.06, 10.6, Vector3(0, 0, -1), 8.0)
		var ollied: bool = false
		var grind_frames: int = 0
		var pend: int = 0
		var exit_v: float = 0.0
		var was_grind: bool = false
		for i in range(int(4.0 / DT)):
			await _tick()
			sk.inp.world_dir = Vector3(0, 0, -1)
			if not ollied and sk.global_position.z < 7.4:
				sk.inp.ollie_pressed = true
				ollied = true
			if ollied and sk.state == Skater.State.AIR and sk.air_time > 0.12:
				sk.inp.grind_pressed = true
			if sk.state == Skater.State.GRIND:
				grind_frames += 1
				pend = score.pending
				was_grind = true
			elif was_grind and exit_v == 0.0:
				exit_v = sk.velocity.length()
		print("[audit]   rail offset dx=%.1f: grinds=%d grind_time=%.2fs names=%s pending_at_end_of_grind=%d exit_speed=%.1f bails=%d %s" % [
			dx, int(sk.stats["grinds"]), float(sk.stats["grind_time"]), str(score.names), pend, exit_v, int(sk.stats["bails"]), str(reasons)])


func _a_stall() -> void:
	print("[audit] stall: from rest, hold the stick toward the ramp (dx=+1 when nearly stopped), release at t=5")
	await _setup(-10.0, 0.06, -8.0, Vector3(1, 0, 0), 0.0)
	var t_release: float = -1.0
	var t_down: float = -1.0
	for i in range(int(12.0 / DT)):
		await _tick()
		var dx: float = signf(sk.velocity.x) if absf(sk.velocity.x) > 0.5 else 1.0
		sk.inp.world_dir = Vector3(dx, 0, 0) if t < 5.0 else Vector3.ZERO
		if t >= 5.0 and t_release < 0.0:
			t_release = t
			print("[audit]   at release: pos=(%.2f,%.2f,%.2f) floor n.y=%.2f speed=%.2f state=%d" % [sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.floor_n.y, sk.velocity.length(), sk.state])
		if t_release > 0.0 and t_down < 0.0 and sk.global_position.y < 0.3:
			t_down = t
		if i % 60 == 0 and t < 8.0:
			print("[audit]   t=%.2f y=%.2f x=%.2f z=%.2f v=%.2f n.y=%.2f" % [t, sk.global_position.y, sk.global_position.x, sk.global_position.z, sk.velocity.length(), sk.floor_n.y])
	print("[audit]   time from release to y<0.3: %s  (a free slide down from y~1.5 at ~20 m/s^2 takes ~0.5 s)" % ("%.2f s" % (t_down - t_release) if t_down > 0 else "never within 7 s"))


func _a_dbg() -> void:
	await _setup(-6.0, 0.06, -2.0, Vector3(1, 0, 0), 5.0)
	for i in range(140):
		await _tick()
		sk.inp.world_dir = sk.hdg
		if i == 20:
			sk.inp.ollie_pressed = true
		if i % 6 == 0:
			print("[dbg] i=%d st=%d pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) air=%.3f buf=%.3f coy=%.3f" % [i, sk.state, sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y, sk.velocity.z, sk.air_time, sk._ollie_buf, sk._coyote])


func _a_dbg2() -> void:
	await _setup(0.0, 0.06, 36.0, Vector3(1, 0, 0))
	for i in range(720):
		await _tick()
		sk.inp.world_dir = _ring_dir(sk.global_position, 36.0)
		sk.inp.manual = true
		if i % 30 == 0 or (i > 100 and i < 140):
			print("[dbg] i=%d st=%d man=%s pos=(%.2f,%.3f,%.2f) vel=(%.3f,%.3f,%.3f) real=%.3f hdg=(%.2f,%.2f,%.2f) push=%s wd=(%.2f,%.2f)" % [i, sk.state, str(sk.manual_on), sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y, sk.velocity.z, sk.get_real_velocity().length(), sk.hdg.x, sk.hdg.y, sk.hdg.z, str(sk.pushing), sk.inp.world_dir.x, sk.inp.world_dir.z])


func _a_map() -> void:
	await _setup(0.0, 0.06, 36.0, Vector3(1, 0, 0))
	var space: PhysicsDirectSpaceState3D = sk.get_world_3d().direct_space_state
	print("[map] Godot x (columns -24..24), z rows (-18..18); '.'=flat, digit=height/0.25, '#'>=2.5, '|'=tall thin/wall at 0.9m")
	for zi in range(-18, 19):
		var row: String = ""
		for xi in range(-24, 25):
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(xi, 8.0, zi), Vector3(xi, -1.0, zi), 1)
			var h: Dictionary = space.intersect_ray(q)
			var ch: String = "?"
			if not h.is_empty():
				var y: float = h["position"].y
				if y < 0.1:
					ch = "."
				elif y >= 2.5:
					ch = "#"
				else:
					ch = str(int(y / 0.25))
			row += ch
		print("[map] z=%3d %s" % [zi, row])


func _a_dbg3() -> void:
	await _setup(-10.0, 0.06, -8.0, Vector3(1, 0, 0), 0.0)
	for i in range(480):
		await _tick()
		var dx: float = signf(sk.velocity.x) if absf(sk.velocity.x) > 0.5 else 1.0
		sk.inp.world_dir = Vector3(dx, 0, 0)
		if i % 12 == 0:
			print("[dbg] t=%.2f st=%d pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) real=(%.2f,%.2f,%.2f) n=(%.2f,%.2f,%.2f) hdg=(%.2f,%.2f,%.2f) surf=%s" % [t, sk.state, sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y, sk.velocity.z, sk.get_real_velocity().x, sk.get_real_velocity().y, sk.get_real_velocity().z, sk.floor_n.x, sk.floor_n.y, sk.floor_n.z, sk.hdg.x, sk.hdg.y, sk.hdg.z, sk.surface])


func _a_dbg4() -> void:
	await _setup(4.0, 0.06, 13.0, Vector3(0, 0, -1), 8.0)
	print("[dbg] grind lines near rail:")
	for gl in level.grind_lines:
		var c: Dictionary = gl.closest(Vector3(4.0, 0.9, 3.0))
		if float(c["gap"]) < 3.0:
			print("[dbg]   ", gl.id, " len=%.2f start=(%.2f,%.2f,%.2f) end=(%.2f,%.2f,%.2f)" % [gl.length, gl.points[0].x, gl.points[0].y, gl.points[0].z, gl.points[-1].x, gl.points[-1].y, gl.points[-1].z])
	var ollied: bool = false
	for i in range(int(2.5 / DT)):
		await _tick()
		sk.inp.world_dir = Vector3(0, 0, -1)
		if not ollied and sk.global_position.z < 7.4:
			sk.inp.ollie_pressed = true
			ollied = true
		if ollied and sk.state == Skater.State.AIR and sk.air_time > 0.12:
			sk.inp.grind_pressed = true
		if i % 8 == 0:
			print("[dbg] t=%.2f st=%d pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) air=%.2f gcd=%.2f" % [t, sk.state, sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y, sk.velocity.z, sk.air_time, sk._grind_cd])


func _a_tank_live() -> void:
	print("[audit] tank_live: UNSCRIPTED skater (real _read_input via injected actions), tank mode, stick up held during a hop")
	await _setup(-1.0, 0.06, 0.0, Vector3(1, 0, 0), 4.0, true)
	Game.steer_mode = "tank"
	sk.scripted = false
	Input.action_press("move_up")
	var v_at: Vector3 = Vector3.ZERO
	var frames: int = 0
	var wd: Vector3 = Vector3.ZERO
	while frames < 240:
		await _tick()
		frames += 1
		if frames == 10:
			Input.action_press("ollie")
			v_at = sk.velocity
		if frames == 13:
			Input.action_release("ollie")
		if sk.state == Skater.State.AIR:
			wd = sk.inp.world_dir
		if frames > 30 and sk.state == Skater.State.GROUND:
			break
	Input.action_release("move_up")
	var dv: Vector3 = sk.velocity - v_at
	print("[audit]   in-air world_dir=(%.2f,%.2f,%.2f) hdg=(%.2f,%.2f,%.2f) dv over hop=(%.2f, %.2f, %.2f) state=%d" % [wd.x, wd.y, wd.z, sk.hdg.x, sk.hdg.y, sk.hdg.z, dv.x, dv.y, dv.z, sk.state])
	Game.steer_mode = "screen"


func _a_dbg5() -> void:
	await _setup(-16.5, 0.06, 2.4, Vector3(0, 0, -1), 8.0)
	for i in range(int(1.4 / DT)):
		await _tick()
		sk.inp.world_dir = Vector3(0, 0, -1)
		if sk.global_position.y > 0.12 or sk.state != Skater.State.GROUND:
			print("[dbg] t=%.3f st=%d pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) n.y=%.2f air=%.2f" % [t, sk.state, sk.global_position.x, sk.global_position.y, sk.global_position.z, sk.velocity.x, sk.velocity.y, sk.velocity.z, sk.floor_n.y, sk.air_time])
