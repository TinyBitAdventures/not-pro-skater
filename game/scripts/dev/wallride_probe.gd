extends Node3D
## Wallrides on a real level's walls: finds up to a dozen tall walls (at random, seeded) and throws the skater at each,
## in the air about 30 degrees off it with grind pressed. Prints how long each was ridden; exit code = walls not ridden.
##   LEVEL=downtown godot --headless --path . --fixed-fps 120 res://scenes/dev_wallprobe.tscn

var level: Level
var sk: Skater


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.steer_mode = "screen"
	level = Level.new()
	add_child(level)
	var lv: String = OS.get_environment("LEVEL") if OS.get_environment("LEVEL") != "" else "neighborhood"
	level.load_glb("res://assets/levels/%s.gltf" % lv, "real")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var b: Rect2 = level.bounds
	seed(7)
	var tried: int = 0
	var rode: int = 0
	var times: Array[float] = []
	for k in 400:
		if tried >= 12:
			break
		var p: Vector3 = Vector3(randf_range(b.position.x + 4, b.end.x - 4), 30.0, randf_range(b.position.y + 4, b.end.y - 4))
		var g: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 60.0, 1))
		if g.is_empty() or (g["normal"] as Vector3).y < 0.95:
			continue
		var ground: Vector3 = g["position"]
		var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		var w1: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 0.6, ground + Vector3.UP * 0.6 + dir * 3.0, 1))
		var w2: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 1.6, ground + Vector3.UP * 1.6 + dir * 3.0, 1))
		if w1.is_empty() or w2.is_empty() or absf((w1["normal"] as Vector3).y) > 0.2:
			continue
		var n: Vector3 = w1["normal"]
		n.y = 0.0
		n = n.normalized()
		var along: Vector3 = n.cross(Vector3.UP).normalized()
		# the wall must go on a few metres along there
		var far: Vector3 = (w1["position"] as Vector3) + along * 3.0 + n * 0.3
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(far, far - n * 0.6, 1)).is_empty():
			continue
		tried += 1
		if sk != null:
			sk.queue_free()
			await get_tree().physics_frame
		sk = Skater.new()
		sk.with_visual = false
		sk.scripted = true
		sk.grind_lines = level.grind_lines
		add_child(sk)
		var start: Vector3 = (w1["position"] as Vector3) + n * 0.9 - along * 1.5
		start.y = ground.y + 1.4
		sk.place_at(Transform3D(Basis.looking_at(along, Vector3.UP), start))
		await get_tree().physics_frame
		sk.velocity = along * 7.0 - n * 3.5 + Vector3.UP * 1.0
		sk._enter_air()
		sk.air_time = 0.3
		sk.inp.grind_pressed = true
		var t: float = 0.0
		for i in 240:
			await get_tree().physics_frame
			if sk.wallriding:
				t += 1.0 / 120.0
		times.append(t)
		if t > 0.1:
			rode += 1
		print("[probe] wall at %s facing %s: rode %.2f s" % [(w1["position"] as Vector3).snappedf(0.1), n.snappedf(0.01), t])
	print("[probe] %s: %d of %d walls ridden" % [lv, rode, tried])
	get_tree().quit(tried - rode)
