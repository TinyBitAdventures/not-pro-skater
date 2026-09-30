extends Node3D
## Films physical bails up close on the greybox, side-on, to judge how the body falls:
##   FILM=flat,tumble,halfpipe,wall,grind godot --path . res://scenes/dev_bailfilm.tscn --resolution 480x360
## Writes ../shots/film_<name>_NN.png every FILM_EVERY seconds (0.1) from the moment of the crash, FILM_N frames (20).

var level: Level
var film_dist: float = float(OS.get_environment("FILM_DIST")) if OS.get_environment("FILM_DIST") != "" else 3.2
var sk: Skater
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _spawn(start: String, offset: Vector3, vel: Vector3, yaw_off: float) -> void:
	if sk != null:
		sk.queue_free()
		for c in get_children():
			if c is LooseBoard:
				c.queue_free()
		await get_tree().physics_frame
	sk = Skater.new()
	sk.rider = OS.get_environment("RIDER") if OS.get_environment("RIDER") != "" else "dev"
	sk.scripted = true
	sk.grind_lines = level.grind_lines
	add_child(sk)
	var xf: Transform3D = level.starts[start]
	xf.origin += offset
	sk.place_at(xf)
	await get_tree().physics_frame
	sk.velocity = vel
	if offset.y > 0.3:
		sk._enter_air()
		sk.yaw += deg_to_rad(yaw_off)
		sk.hdg = sk.heading_h()
		sk.air_time = 0.5


func _film(label: String) -> void:
	var every: float = float(OS.get_environment("FILM_EVERY")) if OS.get_environment("FILM_EVERY") != "" else 0.1
	var n: int = int(OS.get_environment("FILM_N")) if OS.get_environment("FILM_N") != "" else 20
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 600:
		if sk.state == Skater.State.BAIL:
			sk.inp.world_dir = Vector3.ZERO           # hands off once it has gone wrong
			sk.inp.move = Vector2.ZERO
			break
		_aim(sk.rider_position(), true)
		await get_tree().physics_frame
	var t: float = 0.0
	var next: float = 0.0
	var k: int = 0
	var counts: Dictionary = {"mod": 0, "upd": 0}
	if OS.get_environment("FILM_LOG") != "":
		var rg: RiderRig = sk.visual as RiderRig
		rg.ragdoll.sim.modification_processed.connect(func() -> void: counts["mod"] += 1)
		rg.skel.skeleton_updated.connect(func() -> void: counts["upd"] += 1)
	var side: Vector3 = sk.hdg.cross(Vector3.UP).normalized()
	var look: Vector3 = sk.rider_position()
	while k < n:
		await get_tree().process_frame
		t += get_process_delta_time()
		look = look.lerp(sk.rider_position() + Vector3.UP * 0.4, 0.15)
		cam.global_transform = Transform3D(Basis.looking_at(-side * film_dist + Vector3.DOWN * 1.0, Vector3.UP), look + side * film_dist + Vector3.UP * 1.0)
		if OS.get_environment("FILM_LOG") != "":
			var rig: RiderRig = sk.visual as RiderRig
			print("[film] t=%.3f state=%d mode=%s phase=%s sim=%s mod=%d upd=%d phys=%d" % [t, sk.state, sk.bail_mode, rig.phys_phase,
				rig.ragdoll.simulating(), counts["mod"], counts["upd"], Engine.get_physics_frames()])
			counts["mod"] = 0
			counts["upd"] = 0
		if t >= next:
			next += every
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("film_%s_%02d.png" % [label, k]))
			k += 1


func _aim(p: Vector3, _snap: bool) -> void:
	var side: Vector3 = sk.hdg.cross(Vector3.UP).normalized()
	cam.global_transform = Transform3D(Basis.looking_at(-side * film_dist + Vector3.DOWN * 1.0, Vector3.UP), p + side * film_dist + Vector3.UP * 1.4)


func _run() -> void:
	Game.steer_mode = "screen"
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/greybox.glb", "grey")
	GreyEnv.build(self)
	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	await get_tree().physics_frame
	var which: String = OS.get_environment("FILM") if OS.get_environment("FILM") != "" else "flat,tumble"
	for name in which.split(","):
		match name:
			"flat":         # a crooked landing at 12 m/s: a slam
				await _spawn("flat", Vector3(0, 1.2, 0), Vector3(0, 1.0, -12.0), 85.0)
			"tumble":       # high and fast, landing sideways: a full roll
				await _spawn("flat", Vector3(0, 2.8, 0), Vector3(0, 2.0, -15.0), 100.0)
			"halfpipe":     # coming down onto the far transition of the mini ramp, 80 degrees crooked
				await _spawn("mini", Vector3(0, 2.4, -6.1), Vector3(0, -2.0, 3.0), 80.0)
			"wall":         # riding into a wall
				await _spawn("wall", Vector3(0, 0, -2.0), Vector3(0, 0, -11.0), 0.0)
				sk.inp.world_dir = Vector3(0, 0, -1)
				sk.inp.move = Vector2(0, -1)
			"grind":        # onto the flat rail, no balancing: falls off the side
				await _spawn("rail", Vector3.ZERO, Vector3(0, 0, -7.5), 0.0)
				for i in 240:
					if sk.state == Skater.State.GROUND and sk.global_position.z < 0.6:
						sk.inp.ollie_pressed = true
					if sk.state == Skater.State.AIR:
						sk.inp.grind_pressed = true
					if sk.state == Skater.State.GRIND:
						sk.grind_speed = 3.0
						break
					await get_tree().physics_frame
			_:
				continue
		await _film(name)
		sk.inp.world_dir = Vector3.ZERO
		sk.inp.move = Vector2.ZERO
	get_tree().quit()
