extends Node
## Screenshot tour of the level: `godot --path . res://scenes/dev_view.tscn`  (windowed)
## VIEWS=name,name picks views. Output goes to ../shots/.

var out_dir: String = ""


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join("%s.png" % label)
	img.save_png(path)
	print("[view] ", path)


func _run() -> void:
	WorldEnv.build(self)
	var level: Level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/community_park.glb")
	print("[view] level ", level.stats)
	var cam: IsoCamera = IsoCamera.new()
	add_child(cam)
	var views: Array = [
		["top", Vector3(0, 0, 0), 0.0, 90.0, 125.0],
		["gate_n", Vector3(0, 0, -18.3), 45.0, 35.264, 7.0],
		["gate_n_b", Vector3(0.013, 0, -18.3), 45.0, 35.264, 7.0],
		["gate_e", Vector3(20.3, 0, 0), 45.0, 35.264, 7.0],
		["top_plaza", Vector3(0, 0, 0), 0.0, 90.0, 40.0],
		["iso_plaza", Vector3(0, 0, 0), 45.0, 35.264, 36.0],
		["iso_west", Vector3(-11, 1, -2), 45.0, 35.264, 24.0],
		["iso_east", Vector3(11, 1, 4), 45.0, 35.264, 24.0],
		["iso_ring", Vector3(24, 0, 24), 45.0, 35.264, 34.0],
		["iso_shop", Vector3(-24, 0, -34), 45.0, 35.264, 30.0],
	]
	var only: String = OS.get_environment("VIEWS")
	for v in views:
		if only != "" and not (v[0] in only.split(",")):
			continue
		cam.pitch_deg = v[3]
		cam.yaw = deg_to_rad(v[2])
		cam.yaw_target = cam.yaw
		cam.ortho_size = v[4]
		cam.jump_to(v[1])
		RenderingServer.global_shader_parameter_set("player_pos", Vector3(10000, -1000, 10000))
		await _wait(6)
		await _shot(v[0])
	get_tree().quit()
