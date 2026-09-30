extends Node
## Flicker hunt: loads a level, parks the camera at fixed views and nudges it a millimetre per frame. Real
## geometry barely moves between frames; z-fighting and shadow acne flip. Writes ../shots/probe_<view>_<n>.png
## for tools/flicker_map.py.
##   VIEWS="x,y,z>x,y,z;..." STEP=0.001 FRAMES=8 godot --path . res://scenes/dev_flicker.tscn --resolution 1280x720
## (camera position > look-at point, Godot axes). SCENE=res://scenes/birthday.tscn adds the event's things, FOV=22
## zooms in, STEP=0 holds the camera still (then only moving things change: a bobbing balloon's shadow).

var world: Node3D
var cam: Camera3D


func _ready() -> void:
	world = (load(OS.get_environment("SCENE") if OS.get_environment("SCENE") != "" else "res://scenes/neighborhood.tscn") as PackedScene).instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	cam = get_viewport().get_camera_3d()
	(cam as ChaseCamera).target = null
	for h in world.find_children("*", "CanvasLayer", true, false):
		(h as CanvasLayer).visible = false
	var sk: Node3D = world.get("skater")
	if sk != null:
		sk.process_mode = Node.PROCESS_MODE_DISABLED
		sk.visible = false
	var step: float = float(OS.get_environment("STEP")) if OS.get_environment("STEP") != "" else 0.001
	var frames: int = int(OS.get_environment("FRAMES")) if OS.get_environment("FRAMES") != "" else 8
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	if OS.get_environment("FOV") != "":
		cam.fov = float(OS.get_environment("FOV"))
	var views: PackedStringArray = OS.get_environment("VIEWS").split(";", false)
	for vi in views.size():
		var parts: PackedStringArray = views[vi].split(">")
		var a: PackedStringArray = parts[0].split(",")
		var b: PackedStringArray = parts[1].split(",")
		var from: Vector3 = Vector3(float(a[0]), float(a[1]), float(a[2]))
		var to: Vector3 = Vector3(float(b[0]), float(b[1]), float(b[2]))
		for f in frames:
			var off: Vector3 = Vector3(step * f, step * 0.5 * f, -step * f)
			cam.global_transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from + off)
			for _k in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("probe_%d_%02d.png" % [vi, f]))
	get_tree().quit()
