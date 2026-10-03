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
	# every start (and the spawn): nothing to collect hangs between the chase camera and the rider (a letter balloon
	# filled the whole screen at Between Takes' New York street start)
	var spots: Dictionary = lv.starts.duplicate()
	spots["spawn"] = lv.spawn
	var blocked: Array[String] = []
	for nm in spots:
		var xf: Transform3D = spots[nm]
		var f: Vector3 = -xf.basis.z
		f.y = 0.0
		f = f.normalized() if f.length() > 0.1 else Vector3.FORWARD
		var rider: Vector3 = xf.origin + Vector3.UP * 1.0
		var cam: Vector3 = xf.origin - f * 4.4 + Vector3.UP * 1.65
		for mk in lv.markers:
			if not (String(mk).begins_with("letter_") or String(mk).ends_with("pickup")):
				continue
			var m: Vector3 = (lv.markers[mk] as Transform3D).origin
			var t: float = clampf((m - cam).dot(rider - cam) / maxf((rider - cam).length_squared(), 0.001), 0.0, 1.0)
			if m.distance_to(cam.lerp(rider, t)) < 1.3:
				blocked.append("%s: %s" % [nm, mk])
	report.append("starts (camera view clear): %s" % ("true" if blocked.is_empty() else "false " + str(blocked)))
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
				# back on the board somewhere clear (Skater.clear_spot: the pickup spot is in the van, 1 m up), so go
				# back for the dropped item, then bring it
				_put(sk, (lv.markers[String(g["from"])] as Transform3D).origin)
				await _frames(3)
				_put(sk, (lv.markers[String(g["to"])] as Transform3D).origin)
				await _frames(3)
				report.append("%s (deliver): carried=%s dropped_on_bail=%s delivered=%s" % [gid, carried, dropped, r.done.has(gid)])
			"show_kids":
				# a trick that ends in a bail shows nobody; a landed one shows the kids near it
				var n: int = (ev.get("kids", []) as Array).size()
				_put(sk, (lv.markers["kid_1"] as Transform3D).origin + Vector3(2, 0, 0))
				await _frames(2)
				sk.score.add_trick("Kickflip", 300)
				sk.score.bail()
				await _frames(2)
				var bailed_counted: bool = r._kids_shown.size() > 0
				for i in n:
					_put(sk, (lv.markers["kid_%d" % (i + 1)] as Transform3D).origin + Vector3(2, 0, 0))
					await _frames(2)
					sk.score.add_trick("Kickflip", 300)
					sk.score.bank()
					await _frames(2)
				report.append("%s (show %d): bailed trick counted %s, landed %s" % [gid, n, bailed_counted, r.done.has(gid)])

			"trick_on":
				var rails: Array = g.get("rails", [g.get("rail", "")])
				var found: bool = false
				var want: String = String(g.get("trick", ""))
				if want != "":
					# the right rail with the wrong grind: a hint, and the goal stays open
					var hints: Array = []
					r.hint.connect(func(t: String, _s: String) -> void: hints.append(t))
					for line in sk.grind_lines:
						if line.id == String(rails[0]):
							sk.state = Skater.State.GRIND
							sk.grind_line = line
							sk.grind_kind = "50-50"
					await _frames(2)
					sk.state = Skater.State.GROUND
					sk.grind_line = null
					await _frames(2)
					report.append("%s (wrong grind first): hinted %s, counted %s" % [gid, hints, r.done.has(gid)])
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
			"marks":
				# rolling through a mark doesn't count; stopping on it does
				var n: int = r.marks.size()
				_put(sk, (lv.markers["mark_1"] as Transform3D).origin)
				sk.velocity = Vector3(6.0, 0.0, 0.0)
				await _frames(1)
				var rolled: bool = r.marks_hit.has(0)
				var missed: Array[String] = []
				for mi in n:
					_put(sk, (lv.markers["mark_%d" % (mi + 1)] as Transform3D).origin)
					await _frames(15)                    # settle onto the ground (a mark only counts standing on it)
					if not r.marks_hit.has(mi):
						missed.append("mark_%d at %s (%s)" % [mi + 1, sk.global_position.snappedf(0.01), Skater.State.keys()[sk.state]])
				report.append("%s (marks, %d): counted while rolling %s, all hit %s %s" % [gid, n, rolled, r.done.has(gid),
					"" if missed.is_empty() else "missed " + ", ".join(missed)])
			"timed_run":
				# a bail mid-take ruins it; then a clean take through every checkpoint in order counts
				var n: int = r.gates.size()
				_put(sk, (lv.markers["check_1"] as Transform3D).origin)
				await _frames(3)
				_put(sk, (lv.markers["check_2"] as Transform3D).origin)
				await _frames(3)
				sk._start_bail("sideways")
				await _frames(2)
				var ruined: bool = r._run_t < 0.0 and r._next_gate == 0
				sk.finish_physical_bail(Transform3D(Basis.IDENTITY, (lv.markers["check_1"] as Transform3D).origin))
				await _frames(3)
				for ci in n:
					_put(sk, (lv.markers["check_%d" % (ci + 1)] as Transform3D).origin)
					await _frames(3)
				report.append("%s (timed run, %d checkpoints): bail ruined the take %s, clean take %s" % [gid, n, ruined,
					r.done.has(gid)])
			"combo":
				sk.score.banked.emit(int(g["points"]) + 100, 4)
				await _frames(2)
				report.append("%s (combo): %s" % [gid, r.done.has(gid)])
			"zone_combo":
				# it's where the tricks are done that counts, not where the combo banks: done outside and rolled in
				# doesn't count, done inside and rolled out does
				var zc: Vector3 = (lv.markers["zone_" + String(g["zone"])] as Transform3D).origin
				var away: Vector3 = zc + Vector3(float(g.get("radius", 8.0)) + 6.0, 0, 0)
				_put(sk, away)
				await _frames(2)
				sk.score.add_trick("Kickflip", int(g["points"]) + 100)
				_put(sk, zc + Vector3(1.0, 0, 0))
				await _frames(2)
				sk.score.bank()
				await _frames(2)
				var outside: bool = r.done.has(gid)
				sk.score.add_trick("Heelflip", int(g["points"]) + 100)
				_put(sk, away)
				await _frames(2)
				sk.score.bank()
				await _frames(2)
				report.append("%s (zone combo): done outside counted %s, done inside counted %s" % [gid, outside, r.done.has(gid)])

			"score":
				sk.score.score = int(g["points"]) + 100
				await _frames(2)
				report.append("%s (score): %s" % [gid, r.done.has(gid)])
			"wallride":
				# a real wallride on the wall inside the goal's area: find its face with rays from points along the
				# area, throw the skater at it about 30 degrees off in the air with grind pressed; try the next spot
				# if something stands in front of the wall there (a stoop)
				var a: Rect2 = g["area"]
				var space: PhysicsDirectSpaceState3D = sk.get_world_3d().direct_space_state
				var long_x: bool = a.size.x > a.size.y
				var found: bool = false
				var rode: bool = false
				for off in [0.0, 0.15, -0.15, 0.3, -0.3]:
					if rode:
						break
					var c2: Vector2 = a.get_center() + (Vector2(a.size.x * off, 0.0) if long_x else Vector2(0.0, a.size.y * off))
					var mid: Vector3 = Vector3(c2.x, 40.0, c2.y)
					var gh: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(mid, mid + Vector3.DOWN * 80.0, 1))
					var floor_y: float = (gh["position"] as Vector3).y if not gh.is_empty() else 0.0
					var wall: Dictionary = {}
					for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
						var from: Vector3 = Vector3(mid.x, floor_y + 2.4, mid.z)
						var wh: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 12.0, 1))
						if not wh.is_empty() and absf((wh["normal"] as Vector3).y) < 0.2 \
								and a.grow(0.2).has_point(Vector2((wh["position"] as Vector3).x, (wh["position"] as Vector3).z)):
							wall = wh
							break
					if wall.is_empty():
						continue
					found = true
					var n: Vector3 = wall["normal"]
					n = Vector3(n.x, 0.0, n.z).normalized()
					var along: Vector3 = n.cross(Vector3.UP).normalized()
					var at: Vector3 = (wall["position"] as Vector3) + n * 0.9 - along * 1.5
					var gu: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 8.0, 1))
					at.y = ((gu["position"] as Vector3).y if not gu.is_empty() else floor_y) + 1.5
					sk.place_at(Transform3D(Basis.looking_at(along, Vector3.UP), at))
					await _frames(1)
					sk.velocity = along * 7.0 - n * 3.5 + Vector3.UP * 1.0
					sk._enter_air()
					sk.air_time = 0.3
					sk.inp.grind_pressed = true
					for i in 120:
						await get_tree().physics_frame
						rode = rode or sk.wallriding
				report.append("%s (wallride): wall found %s, rode it %s, counted %s" % [gid, found, rode, r.done.has(gid)])
	for line in report:
		print("[event] ", line)
	var all_done: bool = r.done.size() == (ev["goals"] as Array).size() and not report.any(func(l: String) -> bool:
		return (l.contains("wrong grind first") and (l.contains("counted true") or l.contains("hinted []"))) \
			or l.contains("done outside counted true") or l.contains("counted while rolling true") \
			or l.contains("bailed trick counted true") or l.contains("camera view clear): false"))
	print("[event] %s all goals: %s" % [id, all_done])
	get_tree().quit(0 if all_done else 1)
