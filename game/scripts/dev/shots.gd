extends Node
## Gameplay screenshot tour (windowed):  SHOTS=poses godot --path . res://scenes/dev_shots.tscn --resolution 1600x900
## Drives the real park scene with scripted input and saves PNGs to ../shots/.

var park: Node3D
var sk: Skater
var out_dir: String = ""
var n: int = 0


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_detach.call_deferred()


func _detach() -> void:
	var root: Node = get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	_run()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	n += 1
	var path: String = out_dir.path_join("g%02d_%s.png" % [n, label])
	img.save_png(path)
	print("[shots] ", path)


func _face(x: float, z: float, dir: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(x, 0.1, z))


## Runs `driver(t)` every physics frame for `dur` seconds; takes a shot at each (time, label).
func _scene(start: Transform3D, dur: float, shots: Array, driver: Callable) -> void:
	sk.scripted = true
	sk.inp = SkaterInput.new()
	sk.place_at(start)
	park.cam.jump_to(start.origin)
	await get_tree().physics_frame
	var t: float = 0.0
	var next: int = 0
	while t < dur:
		await get_tree().physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		driver.call(t)
		if next < shots.size() and t >= shots[next][0]:
			await _shot(shots[next][1])
			next += 1


func _run() -> void:
	var packed: PackedScene = load("res://scenes/park.tscn")
	park = packed.instantiate()
	add_child(park)
	await get_tree().process_frame
	await get_tree().process_frame
	sk = park.skater
	park.cam.ortho_size = float(OS.get_environment("ZOOM")) if OS.get_environment("ZOOM") != "" else 9.0
	park.phase = 3
	park.hud.hide_hint()
	var which: String = OS.get_environment("SHOTS")
	if which == "":
		which = "poses"
	if which == "poses":
		await _poses()
	elif which == "ramps":
		await _ramps()
	get_tree().quit()


func _poses() -> void:
	var east: Vector3 = Vector3(1, 0, 0)
	# ride + push + crouch on the plaza
	await _scene(_face(-1, 0, east), 3.0, [[0.35, "push"], [2.6, "ride"]],
		func(_t: float) -> void: sk.inp.world_dir = east)
	await _scene(_face(-1, 0, east), 2.2, [[1.55, "crouch"]],
		func(t: float) -> void:
			sk.inp.world_dir = east if t < 1.2 else Vector3.ZERO
			sk.inp.ollie_held = t > 1.3 and t < 1.6)
	# ollie, flip, grab in open plaza
	for flip in ["none", "left", "forward", "back"]:
		await _scene(_face(-3, 0, east), 2.0, [[0.8, "flip_" + flip]],
			func(t: float) -> void:
				sk.inp.world_dir = east
				if t > 1.0 and t < 1.01:
					pass
				sk.inp.ollie_pressed = absf(t - 0.5) < 0.005
				if flip == "left":
					sk.inp.world_dir = east
				sk.inp.flip_pressed = absf(t - 0.65) < 0.005
				sk.inp.world_dir = east if flip != "forward" else east * 1.0)
	await _scene(_face(-3, 0, east), 2.0, [[0.9, "grab"]],
		func(t: float) -> void:
			sk.inp.world_dir = east
			sk.inp.ollie_pressed = absf(t - 0.5) < 0.005
			sk.inp.grab_held = t > 0.62 and t < 1.3)
	await _scene(_face(-3, 0, east), 2.5, [[1.5, "manual"]],
		func(t: float) -> void:
			sk.inp.world_dir = east if t < 1.0 else Vector3.ZERO
			sk.inp.manual = t > 1.0)
	# grind the blue flat rail (Godot x=4, z from 4.75 to -0.75)
	var north: Vector3 = Vector3(0, 0, -1)
	await _scene(_face(4.0, 10.0, north), 3.0, [[1.55, "grind_a"], [1.75, "grind_b"]],
		func(t: float) -> void:
			sk.inp.world_dir = north
			sk.inp.ollie_pressed = sk.global_position.z < 7.6 and sk.global_position.z > 7.4 and sk.state == 0
			sk.inp.grind_pressed = sk.state == 1 and sk.air_time > 0.1)
	# bail: sideways landing
	await _scene(_face(-3, 0, east), 2.5, [[1.0, "bail_air"], [1.55, "bail_a"], [1.85, "bail_b"], [2.4, "bail_c"]],
		func(t: float) -> void:
			sk.inp.world_dir = east
			sk.inp.ollie_pressed = absf(t - 0.4) < 0.005
			sk.inp.move = Vector2(-1, 0) if (sk.state == 1 and t < 0.8) else Vector2.ZERO)


func _ramps() -> void:
	# small quarter pipe at Godot (-3.5, 8.7) climbing +Z
	var south: Vector3 = Vector3(0, 0, 1)
	await _scene(_face(-3.5, 1.0, south), 4.0, [[1.7, "qp_up"], [2.05, "qp_lip"], [2.4, "qp_air"]],
		func(_t: float) -> void:
			sk.inp.world_dir = south if sk.global_position.z < 12.5 else Vector3.ZERO)
