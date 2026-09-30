extends Node
## Drives every goal of an event directly (headless) and checks the runner ticks each one off:
##   EVENT=birthday godot --headless --path . --fixed-fps 120 res://scenes/dev_event.tscn     (or skateathon)
## Goals are driven by kind, so a new event is covered as soon as its goals use known kinds.

var world: Node3D


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _put(sk: Skater, p: Vector3) -> void:
	sk.global_position = p
	sk._render_prev = p
	sk._render_cur = p
	sk.velocity = Vector3.ZERO


func _run() -> void:
	var id: String = OS.get_environment("EVENT") if OS.get_environment("EVENT") != "" else "birthday"
	var packed: PackedScene = load("res://scenes/%s.tscn" % id)
	world = packed.instantiate()
	add_child(world)
	await _frames(10)
	var r: EventRunner = world.runner
	var sk: Skater = world.skater
	sk.scripted = true
	var lv: Level = world.level
	var ev: Dictionary = Events.get_event(id)
	var report: Array[String] = []
	for g in ev["goals"]:
		var gid: String = g["id"]
		match String(g["kind"]):
			"letters":
				for l in String(g["letters"]):
					_put(sk, (lv.markers["letter_" + l] as Transform3D).origin - Vector3.UP * 0.9)
					await _frames(3)
				report.append("%s (letters %s): %s" % [gid, g["letters"], r.done.has(gid)])
			"deliver":
				_put(sk, (lv.markers[String(g["from"])] as Transform3D).origin)
				await _frames(3)
				var carried: bool = r._cake_state == "carried"
				sk._start_bail("sideways")
				var dropped: bool = r._cake_state == "waiting"
				await _frames(2)
				sk.finish_physical_bail(Transform3D(Basis.IDENTITY, (lv.markers[String(g["from"])] as Transform3D).origin))
				await _frames(3)
				_put(sk, (lv.markers[String(g["to"])] as Transform3D).origin)
				await _frames(3)
				report.append("%s (deliver): carried=%s dropped_on_bail=%s delivered=%s" % [gid, carried, dropped, r.done.has(gid)])
			"show_kids":
				var n: int = (ev.get("kids", []) as Array).size()
				for i in n:
					_put(sk, (lv.markers["kid_%d" % (i + 1)] as Transform3D).origin + Vector3(2, 0, 0))
					await _frames(2)
					sk.score.add_trick("Kickflip", 300)
					await _frames(2)
				report.append("%s (show %d): %s" % [gid, n, r.done.has(gid)])
			"trick_on":
				var rails: Array = g.get("rails", [g.get("rail", "")])
				var found: bool = false
				for line in sk.grind_lines:
					if line.id == String(rails[0]):
						found = true
						sk.state = Skater.State.GRIND
						sk.grind_line = line
						sk.grind_kind = String(g.get("trick", "")) if String(g.get("trick", "")) != "" else "50-50"
				await _frames(2)
				sk.state = Skater.State.GROUND
				sk.grind_line = null
				report.append("%s (grind %s, rail in level %s): %s" % [gid, rails[0], found, r.done.has(gid)])
			"laps":
				var gates: int = r.gates.size()
				for lap in int(g["laps"]):
					for gi in gates + (1 if lap == 0 else 0):
						_put(sk, (lv.markers["gate_%d" % (gi % gates + 1)] as Transform3D).origin + Vector3.UP * 0.05)
						await _frames(3)
				# one more pass through the start closes the last lap
				_put(sk, (lv.markers["gate_1"] as Transform3D).origin)
				await _frames(3)
				report.append("%s (laps %d through %d gates): laps=%d done=%s" % [gid, g["laps"], gates, r.laps_done, r.done.has(gid)])
			"combo":
				sk.score.banked.emit(int(g["points"]) + 100, 4)
				await _frames(2)
				report.append("%s (combo): %s" % [gid, r.done.has(gid)])
			"score":
				sk.score.score = int(g["points"]) + 100
				await _frames(2)
				report.append("%s (score): %s" % [gid, r.done.has(gid)])
	for line in report:
		print("[event] ", line)
	var all_done: bool = r.done.size() == (ev["goals"] as Array).size()
	print("[event] %s all goals: %s" % [id, all_done])
	get_tree().quit(0 if all_done else 1)
