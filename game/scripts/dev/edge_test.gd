extends Node3D
## The edges of every level: rides out at each side (a probe every 8 m) at 8 m/s and says what happens:
##   godot --headless --path . --fixed-fps 120 res://scenes/dev_edges.tscn          (LEVEL=warehouse for one)
## "wall"  a wall or a fence stopped it (the level's designed edge: it used to warp 2 m short of it)
## "warp"  open ground ran out and it was put back inside (the edge of the world, as intended)
## "out"   it got past the level's bounds without either: a gap in the edge.
## Then spawns: a spot asked for inside every solid block (a dock, a stage, a planter: where a crash can leave the
## board) must come back as ground with nothing over it and room for the body (Skater.clear_spot).
## Exit code = "out" probes + bad spawns.

const LEVELS: Array[String] = ["neighborhood", "school", "campus", "warehouse", "downtown", "backlot"]
const STEP: float = 8.0
const DT: float = 1.0 / 120.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.steer_mode = "screen"
	var want: String = OS.get_environment("LEVEL") if OS.get_environment("LEVEL") != "" else "all"
	var names: Array = LEVELS if want == "all" else Array(want.split(","))
	var outs: int = 0
	for nm in names:
		outs += await _level(String(nm))
	print("[edges] %d probe(s) got out" % outs)
	get_tree().quit(outs)


func _level(nm: String) -> int:
	var level: Level = Level.new()
	add_child(level)
	var path: String = "res://assets/levels/%s.gltf" % nm
	level.load_glb(path, "grey")
	await get_tree().physics_frame
	var b: Rect2 = level.bounds
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var counts: Dictionary = {"wall": 0, "warp": 0, "out": 0, "skip": 0}
	var outs: Array[String] = []
	# each side: points along it, a start 8 m inside, heading straight out
	var sides: Array = [[Vector3.LEFT, b.position.x], [Vector3.RIGHT, b.end.x], [Vector3.FORWARD, b.position.y], [Vector3.BACK, b.end.y]]
	for sd in sides:
		var out: Vector3 = sd[0]
		var along: Vector3 = Vector3(absf(out.z), 0.0, absf(out.x))
		var lo: float = b.position.y if out.x != 0.0 else b.position.x
		var hi: float = b.end.y if out.x != 0.0 else b.end.x
		var t: float = lo + STEP * 0.5
		while t < hi:
			var edge: float = float(sd[1])
			var p: Vector3 = (Vector3(edge, 0.0, t) if out.x != 0.0 else Vector3(t, 0.0, edge)) - out * 8.0
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 10.0, 1))
			t += STEP
			if hit.is_empty() or (hit["normal"] as Vector3).y < 0.95 or (hit["position"] as Vector3).y > 0.6:
				counts["skip"] += 1                   # no flat ground to start on (a building, a roof, a slope)
				continue
			var r: String = await _probe(level, (hit["position"] as Vector3), out)
			counts[r] += 1
			if r == "out":
				outs.append("(%.0f, %.0f) heading (%d, %d)" % [p.x, p.z, out.x, out.z])
	print("[edges] %-12s wall %d, warp %d, out %d (%d probes skipped: no flat start) %s" % [nm, counts["wall"],
		counts["warp"], counts["out"], counts["skip"], " ".join(outs)])
	var bad: int = await _spawns(level, nm)
	level.queue_free()
	await get_tree().physics_frame
	return int(counts["out"]) + bad


## Ask for a stand spot at the bottom middle of every solid block 0.3 - 3 m high and at least 1 m across.
func _spawns(level: Level, nm: String) -> int:
	var sk: Skater = Skater.new()
	sk.with_visual = false
	sk.scripted = true
	add_child(sk)
	await get_tree().physics_frame
	var tried: int = 0
	var bad: Array[String] = []
	for b in level.collision_root.get_children():
		for c in b.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			var box: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
			if box.size.y < 0.3 or box.size.y > 3.0 or box.size.x < 1.0 or box.size.z < 1.0 or box.size.x > 40.0 or box.size.z > 40.0:
				continue
			var inside: Vector3 = Vector3(box.get_center().x, box.position.y + 0.05, box.get_center().z)
			tried += 1
			var got: Vector3 = sk.clear_spot(inside)
			if not sk._spot_ok(got):
				bad.append("%s at (%.1f, %.1f, %.1f) -> (%.1f, %.1f, %.1f)" % [b.name, inside.x, inside.y, inside.z, got.x, got.y, got.z])
	sk.queue_free()
	print("[edges] %-12s spawns: %d inside blocks moved clear, %d not %s" % [nm, tried - bad.size(), bad.size(), "; ".join(bad.slice(0, 6))])
	return bad.size()


func _probe(level: Level, at: Vector3, out: Vector3) -> String:
	var sk: Skater = Skater.new()
	sk.with_visual = false
	sk.scripted = true
	sk.grind_lines = level.grind_lines
	add_child(sk)
	sk.place_at(Transform3D(Basis.looking_at(out, Vector3.UP), at + Vector3.UP * 0.05))
	sk.bounds = level.bounds
	var warps: Array[int] = [0]
	sk.warped.connect(func() -> void: warps[0] += 1)
	await get_tree().physics_frame
	sk.velocity = out * 8.0
	sk.hdg = out
	var result: String = "wall"
	for i in 360:
		sk.inp.world_dir = out
		sk.inp.move = Vector2(0, -1)
		await get_tree().physics_frame
		if warps[0] > 0:
			result = "warp"
			break
		if sk._edge_distance() < -0.5 or sk.global_position.y < at.y - 3.0:
			result = "out"
			print("[edges]   out: %s at (%.1f, %.1f, %.1f), %.1f past the edge, %s" % [["ground", "air", "grind", "bail"][sk.state],
				sk.global_position.x, sk.global_position.y, sk.global_position.z, -sk._edge_distance(), sk.bail_kind])
			break
	sk.queue_free()
	await get_tree().physics_frame
	return result
