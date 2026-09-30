extends Node
## Drives every goal of an event directly (headless) and checks the runner ticks each one off:
##   EVENT=birthday godot --headless --path . res://scenes/dev_event.tscn

var world: Node3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _put(sk: Skater, p: Vector3) -> void:
	sk.global_position = p
	sk.velocity = Vector3.ZERO


func _run() -> void:
	var id: String = OS.get_environment("EVENT") if OS.get_environment("EVENT") != "" else "birthday"
	var packed: PackedScene = load("res://scenes/birthday.tscn")
	world = packed.instantiate()
	add_child(world)
	await _frames(10)
	var r: EventRunner = world.runner
	var sk: Skater = world.skater
	sk.scripted = true
	var lv: Level = world.level
	var report: Array[String] = []
	# balloons: ride (fly) through each letter
	for l in "PARTY":
		_put(sk, (lv.markers["letter_" + l] as Transform3D).origin - Vector3.UP * 0.9)
		await _frames(3)
	report.append("letters: %s" % r.done.has("party"))
	# cake: pick up, drop it by bailing, pick up again, deliver
	_put(sk, (lv.markers["cake_pickup"] as Transform3D).origin)
	await _frames(3)
	var carried: bool = r._cake_state == "carried"
	sk._start_bail("sideways")
	var dropped: bool = r._cake_state == "waiting"     # (a zero-speed bail recovers at once, next to the table)
	await _frames(2)
	sk.finish_physical_bail(Transform3D(Basis.IDENTITY, (lv.markers["cake_pickup"] as Transform3D).origin))
	await _frames(3)
	_put(sk, (lv.markers["cake_drop"] as Transform3D).origin)
	await _frames(3)
	report.append("cake: carried=%s dropped_on_bail=%s delivered=%s" % [carried, dropped, r.done.has("cake")])
	# kids: a trick near each
	for i in 3:
		_put(sk, (lv.markers["kid_%d" % (i + 1)] as Transform3D).origin + Vector3(2, 0, 0))
		await _frames(2)
		sk.score.add_trick("Kickflip", 300)
		await _frames(2)
	report.append("kids: %s" % r.done.has("kids"))
	# boardslide on the party bench
	for line in sk.grind_lines:
		if line.id == "party_bench":
			sk.state = Skater.State.GRIND
			sk.grind_line = line
			sk.grind_kind = "Boardslide"
	await _frames(2)
	sk.state = Skater.State.GROUND
	report.append("bench: %s" % r.done.has("bench"))
	sk.score.banked.emit(12000, 4)
	sk.score.score = 30000
	await _frames(2)
	report.append("combo: %s  score: %s" % [r.done.has("combo"), r.done.has("score")])
	for line in report:
		print("[event] ", line)
	var all_done: bool = r.done.size() == (Events.get_event(id)["goals"] as Array).size()
	print("[event] all goals: %s" % all_done)
	get_tree().quit(0 if all_done else 1)
