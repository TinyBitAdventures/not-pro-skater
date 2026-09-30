extends Node
## Rides an event's route for real: the skater steers at each gate in turn (screen-mode stick toward it,
## pushing), with full physics. Every gate must be reached without getting stuck, and the runner must count
## the laps (or, for a one-take run, the take within its time limit):
##   EVENT=skateathon godot --headless --path . --fixed-fps 120 res://scenes/dev_lapride.tscn   (exit code = failures)
##   EVENT=rushhour ...                                                                          (checkpoints check_n)
##   EVENT=betweentakes ...                                    (rides to each chalk mark and brakes to a stop on it)

const STUCK_TIME: float = 3.0
const GATE_TIMEOUT: float = 25.0
## The way a player rides between gates where the straight line is blocked (x, z in Godot coordinates):
## gate number -> points to pass on the way to it
const VIA: Dictionary = {
	"skateathon": {3: [Vector2(-49.0, 23.0), Vector2(-49.0, 30.0)], 4: [Vector2(22.0, 31.0)]},
	# up the plaza ramp (its foot on Market Street's sidewalk) and across; round the plaza's corner to the end
	"rushhour": {4: [Vector2(10.5, -34.0), Vector2(10.5, -48.0), Vector2(16.0, -48.0)], 6: [Vector2(6.0, -26.0), Vector2(1.0, -30.0)]},
	# out of the gate past the trailers into the western street; across the lot below the director's chair (the
	# dolly tracks lie across the New York street's south end) and up it; out its north end to the green screen
	"betweentakes": {1: [Vector2(-5.0, 25.0), Vector2(-20.0, 24.0), Vector2(-30.0, 20.0), Vector2(-31.0, 11.0)],
		2: [Vector2(-30.0, 11.0), Vector2(-30.0, 22.0), Vector2(-10.0, 25.0), Vector2(10.0, 21.5), Vector2(24.0, 21.5),
			Vector2(30.0, 12.0), Vector2(32.5, 0.0)],
		3: [Vector2(30.0, 0.0), Vector2(30.0, -22.0)], 4: [Vector2(18.0, -22.0)]},
}

var world: Node3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.steer_mode = "screen"
	var id: String = OS.get_environment("EVENT") if OS.get_environment("EVENT") != "" else "skateathon"
	world = (load("res://scenes/%s.tscn" % id) as PackedScene).instantiate()
	add_child(world)
	for i in 10:
		await get_tree().physics_frame
	var r: EventRunner = world.runner
	var sk: Skater = world.skater
	sk.scripted = true
	var ev: Dictionary = Events.get_event(id)
	var laps: int = 0
	var run: Dictionary = {}
	var marks: Dictionary = {}
	for g in ev["goals"]:
		if g["kind"] == "laps":
			laps = int(g["laps"])
		elif g["kind"] == "timed_run":
			run = g
		elif g["kind"] == "marks":
			marks = g
	var prefix: String = "check" if not run.is_empty() else ("mark" if not marks.is_empty() else "gate")
	var n: int = r.marks.size() if not marks.is_empty() else r.gates.size()
	var fails: int = 0
	var order: Array[int] = []
	if run.is_empty() and marks.is_empty():
		for lap in laps:
			for gi in n:
				order.append(gi)
		order.append(0)                          # back through the start closes the last lap
	else:
		for gi in n:
			order.append(gi)
	var clock: float = 0.0
	var via: Dictionary = VIA.get(id, {})
	for k in order.size():
		var gate: Vector3 = (world.level.markers["%s_%d" % [prefix, order[k] + 1]] as Transform3D).origin
		var points: Array = []
		for v in via.get(order[k] + 1, []):
			points.append(Vector3(v.x, 0.0, v.y))
		points.append(gate)
		var t: float = 0.0
		var still: float = 0.0
		var reached: bool = false
		while t < GATE_TIMEOUT:
			var target: Vector3 = points[0]
			var to: Vector3 = target - sk.global_position
			to.y = 0.0
			var near: float = EventRunner.MARK_RADIUS * 0.6 if marks and points.size() == 1 else EventRunner.GATE_RADIUS * 0.8
			if to.length() < near:
				if points.size() > 1:
					points.pop_front()
					continue
				reached = true
				break
			sk.inp.world_dir = to.normalized()
			sk.inp.move = Vector2(0, -1)
			# coming in to a mark: slow down like a player would, so the stop lands on it
			sk.inp.brake = marks and points.size() == 1 and to.length() < 7.0 and sk.velocity.length() > 1.0 + to.length() * 0.5
			await get_tree().physics_frame
			var dt: float = 1.0 / Engine.physics_ticks_per_second
			t += dt
			still = still + dt if sk.velocity.length() < 0.6 else 0.0
			if still > STUCK_TIME or sk.state == Skater.State.BAIL:
				var hit: Array[String] = []
				for i in sk.get_slide_collision_count():
					var c: KinematicCollision3D = sk.get_slide_collision(i)
					hit.append("%s n=%s" % [(c.get_collider() as Node).name, c.get_normal().snappedf(0.01)])
				print("[lapride]   at %s heading to %s, hit %s" % [sk.global_position.snappedf(0.1), target.snappedf(0.1), hit])
				break
		if reached and marks:                    # brake to a stop on the mark
			sk.inp.move = Vector2.ZERO
			sk.inp.world_dir = Vector3.ZERO
			sk.inp.brake = true
			for i in 240:
				await get_tree().physics_frame
				if r.marks_hit.has(order[k]):
					break
			sk.inp.brake = false
			if not r.marks_hit.has(order[k]):
				reached = false
				print("[lapride]   stopped at %s, %.2f m from the mark" % [sk.global_position.snappedf(0.01),
					Vector2(sk.global_position.x - gate.x, sk.global_position.z - gate.z).length()])
		clock += t
		var ok: bool = reached
		if not ok:
			fails += 1
		print("[lapride] %s  gate %d  %5.1f s  (%s)" % ["PASS" if ok else "FAIL", order[k] + 1, t,
			"reached" if reached else ("bailed" if sk.state == Skater.State.BAIL else "stuck at %s" % sk.global_position.snappedf(0.1))])
		if not ok:                               # carry on from the gate, to find every blocked leg in one run
			if sk.state == Skater.State.BAIL:
				sk.finish_physical_bail(Transform3D(Basis.IDENTITY, gate))
			sk.place_at(Transform3D(Basis.IDENTITY, gate + Vector3.UP * 0.05))
			for i in 30:
				await get_tree().physics_frame
	for i in 10:
		await get_tree().physics_frame
	if marks:
		var all_hit: bool = r.done.has(marks["id"])
		if not all_hit:
			fails += 1
		print("[lapride] %d marks ridden to and stopped on in %.1f s, runner counted them all: %s" % [n, clock, all_hit])
	elif run.is_empty():
		if r.laps_done < laps:
			fails += 1
		print("[lapride] %d laps ridden in %.1f s, runner counted %d, session %d s" % [laps, clock, r.laps_done,
			int(ev.get("session", 120))])
	else:
		var took: bool = r.done.has(run["id"])
		if not took:
			fails += 1
		print("[lapride] one take ridden in %.1f s (limit %d s), runner counted it: %s" % [clock, int(run["limit"]), took])
	print("[lapride] %d failed" % fails)
	get_tree().quit(fails)
