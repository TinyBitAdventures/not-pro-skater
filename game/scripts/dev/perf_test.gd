extends Node
## Windowed frame-time check: godot --path . res://scenes/dev_perf.tscn --resolution 1600x900

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var park: Node3D = (load("res://scenes/park.tscn") as PackedScene).instantiate()
	add_child(park)
	await get_tree().process_frame
	await get_tree().process_frame
	var sk: Skater = park.skater
	sk.scripted = true
	var last_a: Array = [0.0]
	var frames: int = 0
	var t: float = 0.0
	var dc: int = 0
	var prims: int = 0
	var start: int = Time.get_ticks_msec()
	while t < 8.0:
		await get_tree().process_frame
		var p: Vector3 = sk.global_position
		var a: float = atan2(-p.z, p.x)
		var ta: float = a + 0.16
		sk.inp.world_dir = (Vector3(36.0 * cos(ta), 0.0, -36.0 * sin(ta)) - p).normalized()
		frames += 1
		t = float(Time.get_ticks_msec() - start) / 1000.0
		if frames % 60 == 0:
			dc = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			prims = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("[perf] frames=%d avg_fps=%.0f draw_calls=%d primitives=%d" % [frames, frames / t, dc, prims])
	get_tree().quit()
