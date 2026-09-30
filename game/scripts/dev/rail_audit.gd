extends Node
## Every grindable line in a level, tried for real: the skater is dropped just above the start of the line,
## moving along it, grind pressed; it must lock on and slide a good part of the line.
##   LEVEL=school godot --headless --path . --fixed-fps 120 res://scenes/dev_railaudit.tscn   (exit code = failures)

var level: Level
var sk: Skater


func _ready() -> void:
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var lv_name: String = OS.get_environment("LEVEL") if OS.get_environment("LEVEL") != "" else "school"
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/%s.gltf" % lv_name, "grey")
	await _ticks(2)
	var fails: int = 0
	for line in level.grind_lines:
		if sk != null:
			sk.queue_free()
			await _ticks(1)
		sk = Skater.new()
		sk.with_visual = false
		sk.scripted = true
		sk.grind_lines = level.grind_lines
		add_child(sk)
		var d: Vector3 = line.dir_at(0.3)
		var p: Vector3 = line.point_at(0.3)
		var flat: Vector3 = Vector3(d.x, 0.0, d.z).normalized()
		sk.place_at(Transform3D(Basis.looking_at(flat, Vector3.UP), p - flat * 0.6 + Vector3.UP * 0.25))
		sk.velocity = d * 6.0
		sk._enter_air()
		var grind_t: float = 0.0
		var max_dist: float = 0.0
		for i in 240:
			sk.inp.grind_pressed = i < 30 and sk.state == Skater.State.AIR
			await _ticks(1)
			if sk.state == Skater.State.GRIND and sk.grind_line == line:
				grind_t += 1.0 / 120.0
				max_dist = maxf(max_dist, absf(sk.grind_dist - 0.3))
			elif grind_t > 0.0:
				break
		var need: float = minf(line.length * 0.6, 3.0)
		var ok: bool = max_dist >= need - 0.05
		if not ok:
			fails += 1
		print("[rails] %s  %-18s %-6s %5.1f m long: slid %.1f m in %.2f s" % ["PASS" if ok else "FAIL", line.id, line.kind,
			line.length, max_dist, grind_t])
	print("[rails] %d of %d failed" % [fails, level.grind_lines.size()])
	get_tree().quit(fails)
