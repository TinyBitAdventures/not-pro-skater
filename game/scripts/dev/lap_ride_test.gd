extends Node
## Rides an event's lap route for real: the skater steers at each gate in turn (screen-mode stick toward it,
## pushing), with full physics. Every gate must be reached without getting stuck, and the runner must count
## the laps:
##   EVENT=skateathon godot --headless --path . --fixed-fps 120 res://scenes/dev_lapride.tscn   (exit code = failures)

const STUCK_TIME: float = 3.0
const GATE_TIMEOUT: float = 25.0
## The way a player rides between gates where the straight line is blocked (x, z in Godot coordinates):
## gate number -> points to pass on the way to it
const VIA: Dictionary = {
	"skateathon": {3: [Vector2(-49.0, 23.0), Vector2(-49.0, 30.0)], 4: [Vector2(22.0, 31.0)]},
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
	for g in ev["goals"]:
		if g["kind"] == "laps":
			laps = int(g["laps"])
	var n: int = r.gates.size()
	var fails: int = 0
	var order: Array[int] = []
	for lap in laps:
		for gi in n:
			order.append(gi)
	order.append(0)                              # back through the start closes the last lap
	var clock: float = 0.0
	var via: Dictionary = VIA.get(id, {})
	for k in order.size():
		var gate: Vector3 = (world.level.markers["gate_%d" % (order[k] + 1)] as Transform3D).origin
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
			if to.length() < EventRunner.GATE_RADIUS * 0.8:
				if points.size() > 1:
					points.pop_front()
					continue
				reached = true
				break
			sk.inp.world_dir = to.normalized()
			sk.inp.move = Vector2(0, -1)
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
	var counted: bool = r.laps_done >= laps
	if not counted:
		fails += 1
	print("[lapride] %d laps ridden in %.1f s, runner counted %d, session %d s" % [laps, clock, r.laps_done,
		int(ev.get("session", 120))])
	print("[lapride] %d failed" % fails)
	get_tree().quit(fails)
