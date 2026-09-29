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
