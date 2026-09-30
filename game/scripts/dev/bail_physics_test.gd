extends Node3D
## Physical bails with the skinned rider (ragdoll + loose board), headless:
##   BAIL=halfpipe|flat|wall|all godot --headless --path . --fixed-fps 60 res://scenes/dev_bailphys.tscn
## Prints where the body and the board went, and whether the rider got back on.

var level: Level
var sk: Skater


func _ready() -> void:
	_run.call_deferred()


func _spawn(start: String, offset: Vector3, vel: Vector3, yaw_off: float) -> void:
	if sk != null:
		sk.queue_free()
		for c in get_children():
			if c is LooseBoard:
				c.queue_free()
		await get_tree().physics_frame
	sk = Skater.new()
	sk.rider = "dev"
	sk.scripted = true
	sk.grind_lines = level.grind_lines
	add_child(sk)
	var xf: Transform3D = level.starts[start]
	xf.origin += offset
	sk.place_at(xf)
	await get_tree().physics_frame
	sk.velocity = vel
	if offset.y > 0.3:
		sk._enter_air()
		sk.yaw += deg_to_rad(yaw_off)
		sk.hdg = sk.heading_h()
		sk.air_time = 0.5


func _watch(label: String, secs: float) -> Dictionary:
	var t: float = 0.0
	var bailed: bool = false
	var done: bool = false
	var board_min_z: float = 99.0
	var board_max_z: float = -99.0
	var body_path: float = 0.0
	var last_focus: Vector3 = sk.global_position
	var kind: String = ""
	var t_bail: float = -1.0
	var t_done: float = -1.0
	var next_print: float = 0.0
	var knee: Dictionary = {"flex_min": 999.0, "flex_max": -999.0, "side_max": 0.0}
	var gait: Dictionary = {"slide": 0.0, "flex_sum": 0.0, "flex_max": 0.0, "n": 0, "hip_sum": 0.0, "planted": [null, null],
		"jog_sum": 0.0, "jog_n": 0}
	while t < secs:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second      # one physics tick (it used to count 1/60 at 120 Hz: times read double)
		if sk.state == Skater.State.BAIL:
			if not bailed:
				bailed = true
				t_bail = t
				kind = "%s/%s" % [sk.bail_kind, sk.bail_mode]
			var rig: RiderRig = sk.visual as RiderRig
			if rig.ragdoll != null and rig.ragdoll.simulating():
				if not knee.has("first"):
					knee["first"] = rig.ragdoll.knee_angles()
					print("[bail]   knees at the start of the fall (riding crouch): ", knee["first"])
				for k in rig.ragdoll.knee_angles():
					knee["flex_min"] = minf(knee["flex_min"], k[0])
					knee["flex_max"] = maxf(knee["flex_max"], k[0])
					knee["side_max"] = maxf(knee["side_max"], absf(k[1]))
			if (rig.phys_phase == "walk" or rig.phys_phase == "run") and not rig._gait_now.is_empty() and rig._step_on <= 0.0:
				_gait_sample(rig, gait)
			if rig.loose != null:
				board_min_z = minf(board_min_z, rig.loose.global_position.z)
				board_max_z = maxf(board_max_z, rig.loose.global_position.z)
			var f: Vector3 = sk.rider_position()
			body_path += f.distance_to(last_focus)
			last_focus = f
			if t >= next_print:
				next_print = t + 0.5
				var bp: Vector3 = rig.loose.global_position if rig.loose != null else Vector3.ZERO
				print("[bail]   %s t=%.1f phase=%s body=(%.1f,%.2f,%.1f) board=(%.1f,%.2f,%.1f) wheels_down=%s" % [label, t,
					rig.phys_phase, f.x, f.y, f.z, bp.x, bp.y, bp.z, rig.loose.wheels_down if rig.loose != null else false])
		elif bailed and not done:
			done = true
			t_done = t
			break
	# a knee bends one way only: no hyperextension, no bending sideways
	var knees_ok: bool = knee["flex_min"] > -8.0 and knee["side_max"] < 12.0
	if not knees_ok:
		print("[bail] FAIL %s: knees bent the wrong way (flex %.0f, sideways %.0f deg)" % [label, knee["flex_min"], knee["side_max"]])
	# walking back: planted feet stay put, and the standing leg is nearly straight (no crouched shuffle)
	var n: int = maxi(int(gait["n"]), 1)
	var flex_avg: float = float(gait["flex_sum"]) / n
	var gait_ok: bool = float(gait["slide"]) < 0.03 and (int(gait["n"]) == 0 or flex_avg < 23.0)   # a real walk averages ~15-25 over the stance
	if not gait_ok:
		print("[bail] FAIL %s: walking back, feet slid %.1f cm or the standing knee bent %.0f deg on average" % [label,
			float(gait["slide"]) * 100.0, flex_avg])
	var jog: String = ", jogging %d frames, standing knee %.0f deg avg" % [int(gait["jog_n"]),
		float(gait["jog_sum"]) / maxi(int(gait["jog_n"]), 1)] if int(gait["jog_n"]) > 0 else ""
	return {"gait": "walking %d frames: planted feet slid up to %.1f cm, standing knee %.0f deg avg (max %.0f), pelvis %.0f%% of standing%s%s" % [
		int(gait["n"]), float(gait["slide"]) * 100.0, flex_avg, float(gait["flex_max"]), 100.0 * float(gait["hip_sum"]) / n, jog,
		"" if gait_ok else "  FAIL"],
		"knees": "flex %.0f..%.0f deg, sideways up to %.0f deg%s" % [knee["flex_min"], knee["flex_max"], knee["side_max"],
		"" if knees_ok else "  FAIL"],
		"bailed": bailed, "done": done, "kind": kind, "t_bail": t_bail, "t_done": t_done, "board_z": [board_min_z, board_max_z],
		"end": sk.global_position, "body_path": body_path}


func _run() -> void:
	Game.steer_mode = "screen"
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/greybox.glb", "grey")
	await get_tree().physics_frame
	var which: String = OS.get_environment("BAIL") if OS.get_environment("BAIL") != "" else "all"
	if which in ["halfpipe", "all"]:
		# coming down onto the far transition of the mini ramp, 80 degrees crooked
		await _spawn("mini", Vector3(0, 2.4, -6.1), Vector3(0, -2.0, 3.0), 80.0)
		var r: Dictionary = await _watch("halfpipe", 7.0)
		print("[bail] halfpipe: %s" % r)
	if which in ["flat", "all"]:
		await _spawn("flat", Vector3(0, 1.2, 0), Vector3(0, 1.0, -12.0), 85.0)
		var r2: Dictionary = await _watch("flat", 7.0)
		print("[bail] flat: %s" % r2)
	if which in ["wall", "all"]:
		await _spawn("wall", Vector3(0, 0, -2.0), Vector3(0, 0, -11.0), 0.0)
		for i in 240:
			sk.inp.world_dir = Vector3(0, 0, -1)
			sk.inp.move = Vector2(0, -1)
			await get_tree().physics_frame
			if sk.state == Skater.State.BAIL:
				break
		sk.inp.world_dir = Vector3.ZERO
		sk.inp.move = Vector2.ZERO
		var r3: Dictionary = await _watch("wall", 7.0)
		print("[bail] wall: %s" % r3)
	if which in ["runout", "all"]:
		# a small crooked landing on the flat: runs it out, stops, walks to the board
		await _spawn("flat", Vector3(0, 0.9, 0), Vector3(0, 1.0, -5.0), 64.0)
		var r4: Dictionary = await _watch_run("runout", 12.0)
		print("[bail] runout: %s" % r4)
	if which in ["runout_trip", "all"]:
		# the same small mistake a couple of metres from the wall: runs into it and trips
		await _spawn("wall", Vector3(0, 0.9, -5.2), Vector3(0, 1.0, -5.5), 64.0)
		var r5: Dictionary = await _watch_run("runout_trip", 12.0)
		print("[bail] runout_trip: %s" % r5)
	if which in ["edge", "all"]:
		# a 12 m/s crash 4 m inside the level's edge, heading out: the board flies past the ground and used to fall
		# for ever, the rider chasing it until the bail's 12 s safety cap. It must turn up beside the rider.
		await _spawn("flat", Vector3.ZERO, Vector3.ZERO, 0.0)
		sk.bounds = level.bounds
		var b: Rect2 = level.bounds
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(b.end.x - 4.0, 30.0, b.get_center().y),
			Vector3(b.end.x - 4.0, -30.0, b.get_center().y), 1)
		var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(q)
		sk.place_at(Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), (hit["position"] as Vector3) + Vector3.UP * 0.02))
		for i in 6:
			await get_tree().physics_frame
		sk.velocity = Vector3.RIGHT * 12.0
		sk._impact_v = sk.velocity
		sk._start_bail("crash")
		var t: float = 0.0
		var board_out: float = 0.0
		while sk.state == Skater.State.BAIL and t < 13.0:
			await get_tree().physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			var rig: RiderRig = sk.visual as RiderRig
			if rig != null and rig.loose != null:
				board_out = maxf(board_out, rig.loose.global_position.x - b.end.x)
			if OS.get_environment("EDGE_DEBUG") != "" and rig != null and int(t * 120.0) % 60 == 0:
				print("[edge] t %.1f phase %s board %s walk %s pelvis %s bounds end %s" % [t, rig.phys_phase,
					rig.loose.global_position.snappedf(0.1) if rig.loose != null else "-", rig._walk_pos.snappedf(0.1),
					rig.ragdoll.pelvis_position().snappedf(0.1) if rig.ragdoll != null else "-", b.end])
		var ok: bool = t < 9.0 and b.grow(0.5).has_point(Vector2(sk.global_position.x, sk.global_position.z))
		print("[bail] edge: %s  back on after %.2f s (the cap is 12), board at most %.1f m past the edge, rider ended %s" % [
			"PASS" if ok else "FAIL", t, board_out, sk.global_position.snappedf(0.1)])
	if which in ["edge_board", "all"]:
		# a slow crash near the edge whose board goes over it (put there by hand: the body stays on the ground)
		await _spawn("flat", Vector3.ZERO, Vector3.ZERO, 0.0)
		sk.bounds = level.bounds
		var b2: Rect2 = level.bounds
		var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(b2.end.x - 6.0, 30.0, b2.get_center().y),
			Vector3(b2.end.x - 6.0, -30.0, b2.get_center().y), 1)
		var hit2: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(q2)
		sk.place_at(Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), (hit2["position"] as Vector3) + Vector3.UP * 0.02))
		for i in 6:
			await get_tree().physics_frame
		sk.velocity = Vector3.RIGHT * 4.0
		sk._impact_v = sk.velocity
		sk._start_bail("crash")
		for i in 12:
			await get_tree().physics_frame
		var rig2: RiderRig = sk.visual as RiderRig
		rig2.loose.put_at(Transform3D(Basis.IDENTITY, Vector3(b2.end.x + 3.0, 0.5, b2.get_center().y)))
		var t2: float = 0.0
		var lowest: float = 0.0
		while sk.state == Skater.State.BAIL and t2 < 13.0:
			await get_tree().physics_frame
			t2 += 1.0 / Engine.physics_ticks_per_second
			if rig2.loose != null:
				lowest = minf(lowest, rig2.loose.global_position.y)
		var ok2: bool = t2 < 9.0 and b2.has_point(Vector2(sk.global_position.x, sk.global_position.z)) and lowest > -6.0
		print("[bail] edge_board: %s  back on after %.2f s, the board fell to y %.1f, rider ended %s" % [
			"PASS" if ok2 else "FAIL", t2, lowest, sk.global_position.snappedf(0.1)])
	get_tree().quit()


## One frame of the walk back: how far each planted foot's ball has moved since it touched down, the standing
## knee's bend and the pelvis height.
func _gait_sample(rig: RiderRig, g: Dictionary) -> void:
	var sk3: Skeleton3D = rig.skel
	var feet: Array = rig._gait_now["feet"]
	var planted: Array = g["planted"]
	for i in 2:
		var side: String = "l" if i == 0 else "r"
		var ball: Vector3 = sk3.global_transform * sk3.get_bone_global_pose(sk3.find_bone("ball_" + side)).origin
		if bool(feet[i][2]) and OS.get_environment("GAIT_DEBUG") != "":
			var f: Array = feet[i]
			var want: Vector3 = rig.global_transform * (rig._foot_pose(f[0], Basis(Vector3.UP, deg_to_rad(float(f[3]))), float(f[1]))[0] as Vector3)
			var got: Vector3 = sk3.global_transform * sk3.get_bone_global_pose(sk3.find_bone("foot_" + side)).origin
			if want.distance_to(got) > 0.03:
				print("[gait] foot %d misses its ankle target by %.2f (target model %s, hip %.3f of %.3f, walk %s)" % [i,
					want.distance_to(got), (f[0] as Vector3).snappedf(0.01), float(rig._gait_now["hip"]), rig._stand_hip, rig.phys_phase])
		if bool(feet[i][2]):
			if planted[i] == null:
				planted[i] = ball
			else:
				var d: Vector3 = ball - (planted[i] as Vector3)
				d.y = 0.0
				if OS.get_environment("GAIT_DEBUG") != "" and d.length() > 0.05:
					print("[gait] foot %d slid %.2f: ball %s planted %s walk_pos %s dir %s speed %.2f step_on %.2f blend %.2f anchor %s" % [
						i, d.length(), ball.snappedf(0.01), (planted[i] as Vector3).snappedf(0.01), rig._walk_pos.snappedf(0.01),
						rig._walk_dir.snappedf(0.01), rig._loco_speed, rig._step_on, rig._blend_w, rig._plant[i]])
				g["slide"] = maxf(float(g["slide"]), d.length())
			var th: Vector3 = sk3.get_bone_global_pose(sk3.find_bone("thigh_" + side)).origin
			var ca: Vector3 = sk3.get_bone_global_pose(sk3.find_bone("calf_" + side)).origin
			var fo: Vector3 = sk3.get_bone_global_pose(sk3.find_bone("foot_" + side)).origin
			var flex: float = rad_to_deg((ca - th).angle_to(fo - ca))
			if float(rig._gait_now["run"]) > 0.5:             # jogging: a softer standing knee is right
				g["jog_sum"] = float(g["jog_sum"]) + flex
				g["jog_n"] = int(g["jog_n"]) + 1
			else:
				g["flex_sum"] = float(g["flex_sum"]) + flex
				g["flex_max"] = maxf(float(g["flex_max"]), flex)
				g["n"] = int(g["n"]) + 1
				g["hip_sum"] = float(g["hip_sum"]) + float(rig._gait_now["hip"]) / rig._stand_hip
		else:
			planted[i] = null


## Like _watch, but records the run-out phases the rig went through.
func _watch_run(label: String, secs: float) -> Dictionary:
	var phases: Array[String] = []
	var t: float = 0.0
	var bailed: bool = false
	var run_dist: float = 0.0
	var start: Vector3 = Vector3.ZERO
	var kind0: String = ""
	var back_steps: int = 0          # frames walking against the way the rider faces (moonwalking)
	var walk_steps: int = 0
	var last_walk: Vector3 = Vector3.INF
	while t < secs:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if sk.state == Skater.State.BAIL:
			var rig: RiderRig = sk.visual as RiderRig
			if not bailed:
				bailed = true
				start = sk.global_position
				kind0 = sk.bail_kind
			if rig.phys_phase != "" and (phases.is_empty() or phases[-1] != rig.phys_phase):
				phases.append(rig.phys_phase)
			if sk.run_state == "run":
				run_dist = start.distance_to(sk.global_position)
			if rig.phys_phase == "walk":
				if last_walk != Vector3.INF:
					var mv: Vector3 = rig._walk_pos - last_walk
					mv.y = 0.0
					if mv.length() > 0.004:
						walk_steps += 1
						if mv.normalized().dot(rig._walk_dir) < 0.0:
							back_steps += 1
				last_walk = rig._walk_pos
		elif bailed:
			return {"started_as": kind0, "phases": phases, "ran_m": snappedf(run_dist, 0.01), "back_on_after_s": snappedf(t, 0.01),
				"done": true, "walking_backwards": "%d / %d frames" % [back_steps, walk_steps]}
	return {"started_as": kind0, "phases": phases, "ran_m": snappedf(run_dist, 0.01), "done": false}
