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
	while t < secs:
		await get_tree().physics_frame
		t += 1.0 / 60.0
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
	return {"knees": "flex %.0f..%.0f deg, sideways up to %.0f deg%s" % [knee["flex_min"], knee["flex_max"], knee["side_max"],
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
		var r: Dictionary = await _watch("halfpipe", 14.0)
		print("[bail] halfpipe: %s" % r)
	if which in ["flat", "all"]:
		await _spawn("flat", Vector3(0, 1.2, 0), Vector3(0, 1.0, -12.0), 85.0)
		var r2: Dictionary = await _watch("flat", 14.0)
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
		var r3: Dictionary = await _watch("wall", 14.0)
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
	get_tree().quit()


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
		t += 1.0 / 120.0
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
