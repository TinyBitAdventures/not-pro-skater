extends Node
## Performance and smoothness probe on an event (Birthday at the Park unless SCENE=skateathon): the skater cruises
## a loop round the spawn while this records frame times, draw calls and how evenly the rider moves on screen.
##   godot --path . res://scenes/dev_perf.tscn --resolution 1600x900          (vsync off, uncapped)
##   FPS=144 godot --path . res://scenes/dev_perf.tscn --resolution 1600x900  (capped: a 144 Hz display)
## "judder" is the spread of the rider's per-frame movement against its speed: 0 is perfectly even motion;
## without interpolation, 120 Hz physics on a 144 Hz display shows ~0.4.

const WARMUP: float = 2.0
const DURATION: float = 12.0

var world: Node
var sk: Skater
var _t: float = 0.0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _ratios: PackedFloat32Array = PackedFloat32Array()
var _draws: int = 0
var _prims: int = 0
var _objs: int = 0
var _samples: int = 0
var _last_pos: Vector3 = Vector3.ZERO
var _beat: int = -1
var _cpu: Dictionary = {"process": 0.0, "physics": 0.0, "render_cpu": 0.0, "render_gpu": 0.0}


func _ready() -> void:
	process_priority = 1000                     # after the skater and camera have moved this frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(OS.get_environment("FPS")) if OS.get_environment("FPS") != "" else 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var scene: String = OS.get_environment("SCENE") if OS.get_environment("SCENE") != "" else "birthday"
	world = (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	sk = world.get("skater")
	sk.scripted = true
	if OS.get_environment("DUMP") != "":
		_dump()
	if OS.get_environment("COST") != "":
		await get_tree().create_timer(1.0).timeout
		_cost()


## Time our own per-frame scripts directly (wall-clock fps is too noisy on a shared machine).
func _cost() -> void:
	var n: int = 200
	var t0: int = Time.get_ticks_usec()
	for i in n:
		sk.visual.sync_from(sk, 1.0 / 60.0)
	var rig_us: float = float(Time.get_ticks_usec() - t0) / n
	var npcs: Array = world.find_children("*", "Npc", true, false)
	t0 = Time.get_ticks_usec()
	for i in n:
		for c in npcs:
			(c as Npc)._process(1.0 / 60.0)
	var npc_us: float = float(Time.get_ticks_usec() - t0) / n
	t0 = Time.get_ticks_usec()
	for i in n:
		sk._physics_process(1.0 / 120.0)
	var phys_us: float = float(Time.get_ticks_usec() - t0) / n
	t0 = Time.get_ticks_usec()
	var hud: Node = world.get("hud")
	for i in n:
		world.call("_process", 1.0 / 60.0)
	var world_us: float = float(Time.get_ticks_usec() - t0) / n
	var runner: Node = world.get("runner")
	t0 = Time.get_ticks_usec()
	for i in n:
		runner.call("_process", 1.0 / 60.0)
	var runner_us: float = float(Time.get_ticks_usec() - t0) / n
	t0 = Time.get_ticks_usec()
	for i in n:
		sk.fx.tick(1.0 / 60.0)
	var fx_us: float = float(Time.get_ticks_usec() - t0) / n
	var cam: Node = world.get("cam")
	t0 = Time.get_ticks_usec()
	for i in n:
		cam.call("_process", 1.0 / 60.0)
	var cam_us: float = float(Time.get_ticks_usec() - t0) / n
	t0 = Time.get_ticks_usec()
	for i in n:
		hud.call("_process", 1.0 / 60.0)
	var hud_us: float = float(Time.get_ticks_usec() - t0) / n
	print("[cost] world %.0f us, event runner %.0f us, fx %.0f us, camera %.0f us, hud %.0f us" % [world_us, runner_us, fx_us, cam_us, hud_us])
	print("[cost] rider rig %.0f us/frame   %d bystanders %.0f us/frame   skater physics step %.0f us (x2 per frame)" % [rig_us, npcs.size(), npc_us, phys_us])


## What the scene is made of: mesh instances and surfaces grouped by name prefix, plus the lights.
func _dump() -> void:
	var groups: Dictionary = {}
	for mi in world.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var key: String = String(m.name).get_slice("_", 0).rstrip("0123456789.")
		var p: Node = m.get_parent()
		while p != null and p != world and not (String(p.name).begins_with("Prop") or p is Npc or p is Skater):
			p = p.get_parent()
		if p != null and p != world:
			key = (p.get_class() if p is Npc or p is Skater else String(p.name).get_slice("_", 1)) + "/" + key
		var g: Array = groups.get(key, [0, 0, 0])
		g[0] += 1
		g[1] += m.mesh.get_surface_count()
		g[2] += int(m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		groups[key] = g
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a][1] > groups[b][1])
	for k in keys.slice(0, 30):
		print("[dump] %-40s nodes %4d  surfaces %4d  shadow %4d" % [k, groups[k][0], groups[k][1], groups[k][2]])
	var kinds: Dictionary = {}
	for v in get_tree().root.find_children("*", "VisualInstance3D", true, false):
		var k: String = v.get_class() + (" (hidden)" if not (v as Node3D).is_visible_in_tree() else "")
		kinds[k] = int(kinds.get(k, 0)) + 1
	print("[dump] visual instances: ", kinds)
	for l in world.find_children("*", "DirectionalLight3D", true, false):
		var d: DirectionalLight3D = l
		print("[dump] sun shadow mode %d  max distance %.0f  splits %s" % [d.directional_shadow_mode, d.directional_shadow_max_distance, [d.directional_shadow_split_1, d.directional_shadow_split_2, d.directional_shadow_split_3]])


func _process(dt: float) -> void:
	if sk == null:
		return
	_t += dt
	# cruise: push, weave gently; STRESS=1 also jumps, flips and crashes now and then
	sk.inp.move = Vector2(sin(_t * 0.5) * 0.35, -1.0 if sk.velocity.length() < 6.0 else 0.0)
	sk.inp.world_dir = sk.hdg
	if OS.get_environment("STRESS") != "":
		var beat: int = int(_t * 2.0)
		if beat != _beat:
			_beat = beat
			if beat % 3 == 0 and sk.state == Skater.State.GROUND:
				sk.inp.ollie_pressed = true
				sk.inp.ollie_released = true
			if beat % 5 == 1 and sk.state == Skater.State.AIR:
				sk.inp.flip_pressed = true
			if beat % 17 == 8 and sk.state == Skater.State.GROUND:
				sk._start_bail("crash")
	var p: Vector3 = sk.visual.global_position if sk.visual != null else sk.global_position
	if _t > WARMUP:
		_frames.append(dt)
		var speed: float = sk.velocity.length()
		if speed > 2.0 and dt > 0.0:
			_ratios.append(p.distance_to(_last_pos) / (speed * dt))
		_draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		_prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		_objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		_samples += 1
		var vp: RID = get_viewport().get_viewport_rid()
		_cpu["process"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_cpu["physics"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_cpu["render_cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		_cpu["render_gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	_last_pos = p
	if _t > WARMUP + DURATION:
		_report()
		set_process(false)
		get_tree().quit()


func _report() -> void:
	var sorted: Array = Array(_frames)
	sorted.sort()
	var total: float = 0.0
	for f in _frames:
		total += f
	var avg_ms: float = total / _frames.size() * 1000.0
	var p99: float = float(sorted[int(sorted.size() * 0.99)]) * 1000.0
	var mean_r: float = 0.0
	for r in _ratios:
		mean_r += r
	mean_r /= maxf(1.0, _ratios.size())
	var var_r: float = 0.0
	for r in _ratios:
		var_r += (r - mean_r) * (r - mean_r)
	var judder: float = sqrt(var_r / maxf(1.0, _ratios.size()))
	print("[perf] window %s  viewport %s  screen scale %.1f" % [DisplayServer.window_get_size(), get_viewport().get_visible_rect().size, DisplayServer.screen_get_scale()])
	print("[perf] frames %d  avg %.2f ms (%.0f fps)  p99 %.2f ms  worst %.2f ms" % [_frames.size(), avg_ms, 1000.0 / avg_ms, p99, float(sorted[-1]) * 1000.0])
	print("[perf] draw calls %.0f  primitives %.0fk  objects %.0f" % [float(_draws) / _samples, float(_prims) / _samples / 1000.0, float(_objs) / _samples])
	print("[perf] per frame: scripts %.2f ms  physics %.2f ms  render cpu %.2f ms  render gpu %.2f ms" % [_cpu["process"] / _samples, _cpu["physics"] / _samples, _cpu["render_cpu"] / _samples, _cpu["render_gpu"] / _samples])
	print("[perf] judder %.3f (0 = even motion)  video mem %.0f MB" % [judder, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
