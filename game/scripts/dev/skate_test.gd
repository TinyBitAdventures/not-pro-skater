extends Node
## Headless skating checks:  godot --headless --path . res://scenes/dev_skate.tscn
## TEST=flat|ramp|grind|bail|tricks|all

var level: Level
var sk: Skater
var score: ScoreKeeper
var t: float = 0.0


func _ready() -> void:
	_detach.call_deferred()


func _detach() -> void:
	var root: Node = get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	_run()


func _setup(spawn: Transform3D) -> void:
	Game.steer_mode = "screen"
	if level != null:
		level.queue_free()
	if sk != null:
		sk.queue_free()
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
	add_child(sk)
	sk.place_at(spawn)
	await get_tree().physics_frame


func _at(x: float, y: float, z: float, face: Vector3) -> Transform3D:
	var b: Basis = Basis.looking_at(face, Vector3.UP)
	return Transform3D(b, Vector3(x, y, z))


func _run_for(seconds: float, every: float, tag: String, world_dir: Callable) -> void:
	var elapsed: float = 0.0
	var next: float = 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
		elapsed += dt
		world_dir.call(elapsed)
		if elapsed >= next:
			next += every
			print("[skate] %s t=%.2f state=%d pos=(%.1f,%.2f,%.1f) v=%.1f vy=%.1f surf=%s air=%.2f" % [
				tag, elapsed, sk.state, sk.global_position.x, sk.global_position.y, sk.global_position.z,
				sk.velocity.length(), sk.velocity.y, sk.surface, sk.air_time])


func _run() -> void:
	var which: String = OS.get_environment("TEST")
	if which == "":
		which = "all"
	if which in ["flat", "all"]:
		await _test_flat()
	if which in ["ramp", "all"]:
		await _test_ramp()
	if which in ["grind", "all"]:
		await _test_grind()
	if which in ["bail", "all"]:
		await _test_bail()
	if which == "lap":
		await _test_lap()
	if which == "latency":
		await _test_latency()
	if which == "bailclear":
		await _test_bail_clear()
	get_tree().quit()


func _test_flat() -> void:
	await _setup(Transform3D.IDENTITY)
	var spawn: Transform3D = level.spawn
	sk.place_at(spawn)
	await get_tree().physics_frame
	print("[skate] spawn ", spawn.origin, " facing ", -spawn.basis.z, " hdg ", sk.hdg)
	sk.inp.world_dir = sk.hdg
	await _run_for(4.0, 1.0, "flat", func(_e: float) -> void: sk.inp.world_dir = sk.hdg)
	print("[skate] flat done speed=%.1f y=%.2f state=%d" % [sk.velocity.length(), sk.global_position.y, sk.state])


func _test_ramp() -> void:
	# small quarter pipe at Blender (-3.5, -8.7) climbing toward -Y (Godot +Z). Approach from the north.
	await _setup(_at(-3.5, 0.1, 2.0, Vector3(0, 0, 1)))
	var got_air: float = 0.0
	var max_h: float = 0.0
	await _run_for(6.0, 0.5, "ramp", func(_e: float) -> void:
		sk.inp.world_dir = Vector3(0, 0, 1) if sk.global_position.z < 8.0 or sk.velocity.z > 0.0 else Vector3.ZERO
		got_air = maxf(got_air, sk.air_time)
		max_h = maxf(max_h, sk.global_position.y))
	print("[skate] ramp done max_air=%.2f max_h=%.2f airs=%d bails=%d" % [got_air, max_h, sk.stats["air"], sk.stats["bails"]])


func _test_grind() -> void:
	# flat rail (orange) at Blender (0.5, -10.5) along X. Approach along +X ... at height via ollie.
	await _setup(_at(-8.0, 0.1, 10.5, Vector3(1, 0, 0)))
	var pressed: bool = false
	await _run_for(4.0, 0.25, "grind", func(e: float) -> void:
		sk.inp.world_dir = Vector3(1, 0, 0)
		if not pressed and sk.global_position.x > -3.2:
			sk.inp.ollie_pressed = true
			pressed = true
		if pressed and sk.state == Skater.State.AIR and sk.air_time > 0.12:
			sk.inp.grind_pressed = true)
	print("[skate] grind done grinds=%d score=%d/%d %s" % [sk.stats["grinds"], score.score, score.pending, score.names])


func _test_bail() -> void:
	await _setup(_at(-8.0, 0.1, 10.5, Vector3(1, 0, 0)))
	var popped: bool = false
	await _run_for(3.0, 0.3, "bail", func(e: float) -> void:
		sk.inp.world_dir = Vector3(1, 0, 0)
		if not popped and e > 1.5:
			sk.inp.ollie_pressed = true
			popped = true
		if popped and sk.state == Skater.State.AIR:
			sk.inp.move = Vector2(-1, 0))
	print("[skate] bail done bails=%d state=%d" % [sk.stats["bails"], sk.state])


func _test_lap() -> void:
	await _setup(Transform3D.IDENTITY)
	sk.place_at(level.spawn)
	await get_tree().physics_frame
	var lane: float = float(OS.get_environment("LANE")) if OS.get_environment("LANE") != "" else 36.0
	var st: Dictionary = {"last_a": atan2(-sk.global_position.z, sk.global_position.x), "total": 0.0, "minr": 999.0, "maxr": 0.0, "t_done": -1.0}
	await _run_for(40.0, 10.0, "lap", func(e: float) -> void:
		var p: Vector3 = sk.global_position
		var a: float = atan2(-p.z, p.x)
		st["total"] += wrapf(a - st["last_a"], -PI, PI)
		st["last_a"] = a
		var r: float = Vector2(p.x, p.z).length()
		st["minr"] = minf(st["minr"], r)
		st["maxr"] = maxf(st["maxr"], r)
		var ta: float = a + 0.16
		var tgt: Vector3 = Vector3(lane * cos(ta), 0.0, -lane * sin(ta))
		sk.inp.world_dir = (tgt - p).normalized()
		if st["total"] >= TAU and st["t_done"] < 0.0:
			st["t_done"] = e)
	print("[skate] lap done lap_time=%.1f r=[%.1f, %.1f] bails=%d max_speed=%.1f" % [st["t_done"], st["minr"], st["maxr"], sk.stats["bails"], sk.stats["max_speed"]])


## Bail with the visual on: the lowest point of the rider must never dip below the ground.
func _test_bail_clear() -> void:
	await _setup(_at(-8.0, 0.1, -3.0, Vector3(1, 0, 0)))
	sk.queue_free()
	await get_tree().process_frame
	sk = Skater.new()
	sk.scripted = true
	sk.score = score
	sk.grind_lines = level.grind_lines
	add_child(sk)
	sk.place_at(_at(-8.0, 0.1, -3.0, Vector3(1, 0, 0)))
	var st: Dictionary = {"popped": false, "lowest": 999.0, "frames": 0}
	await _run_for(4.5, 10.0, "bailclear", func(e: float) -> void:
		sk.inp.world_dir = Vector3(1, 0, 0)
		if not st["popped"] and e > 1.0:
			sk.inp.ollie_pressed = true
			st["popped"] = true
		if st["popped"] and sk.state == Skater.State.AIR:
			sk.inp.move = Vector2(-1, 0)
		else:
			sk.inp.move = Vector2.ZERO
		if sk.state == Skater.State.BAIL and sk.visual != null:
			for mi in sk.visual.model.find_children("*", "MeshInstance3D", true, false):
				var m: MeshInstance3D = mi as MeshInstance3D
				if m.get_parent().name == "Board":
					continue
				var bb: AABB = m.get_aabb()
				for cx in [0.0, 1.0]:
					for cy in [0.0, 1.0]:
						for cz in [0.0, 1.0]:
							var corner: Vector3 = m.global_transform * (bb.position + bb.size * Vector3(cx, cy, cz))
							st["lowest"] = minf(st["lowest"], corner.y - (sk.global_position.y + 0.02))
			st["frames"] += 1)
	print("[skate] bailclear bail_frames=%d lowest_rel_y=%.3f bails=%d" % [st["frames"], st["lowest"], sk.stats["bails"]])


## Input-to-takeoff latency: physics ticks from the ollie press until the rider is measurably off the ground.
func _test_latency() -> void:
	await _setup(_at(-8.0, 0.1, -3.0, Vector3(1, 0, 0)))
	var st: Dictionary = {"pressed_tick": -1, "y0": 0.0, "t5": -1, "t20": -1, "ticks": 0, "vy_tick": -1}
	await _run_for(2.5, 10.0, "latency", func(e: float) -> void:
		st["ticks"] += 1
		sk.inp.world_dir = Vector3(1, 0, 0)
		if st["pressed_tick"] < 0 and e > 1.5:
			st["pressed_tick"] = st["ticks"]
			st["y0"] = sk.global_position.y
			sk.inp.ollie_pressed = true
			sk.inp.ollie_held = true
		if st["pressed_tick"] >= 0:
			var dy: float = sk.global_position.y - st["y0"]
			if st["vy_tick"] < 0 and sk.velocity.y > 3.0:
				st["vy_tick"] = st["ticks"] - st["pressed_tick"]
			if st["t5"] < 0 and dy > 0.05:
				st["t5"] = st["ticks"] - st["pressed_tick"]
			if st["t20"] < 0 and dy > 0.2:
				st["t20"] = st["ticks"] - st["pressed_tick"])
	var ms: float = 1000.0 / float(Engine.physics_ticks_per_second)
	print("[skate] latency ticks: vy>3 after %d, +5cm after %d, +20cm after %d (%.1f ms/tick)" % [st["vy_tick"], st["t5"], st["t20"], ms])
