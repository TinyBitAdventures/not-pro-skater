extends Node
## Close-ups of the riders' faces in the title's light (the neighborhood park, late sun):
##   godot --path . res://scenes/dev_faces.tscn --resolution 1200x900 --audio-driver Dummy --position -3000,-3000
## -> ../shots/face_<rider>.png (front three-quarter, head and shoulders) and face_<rider>_side.png (profile).
## RIDERS=dev,dad picks some; FACE_DIST=<m> backs the camera off (0.75 = head and shoulders).

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(t)
	await get_tree().process_frame
	(t.get("ui") as CanvasLayer).visible = false
	t.set_process(false)
	var cam: Camera3D = t.get("cam")
	cam.fov = 30.0
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	var want: String = OS.get_environment("RIDERS")
	var keys: Array = Array(want.split(",")) if want != "" else Game.RIDERS
	var dist: float = float(OS.get_environment("FACE_DIST")) if OS.get_environment("FACE_DIST") != "" else 0.75
	for key in keys:
		Game.rider = String(key)
		t.call("_spawn_rider")
		for i in 40:
			await get_tree().process_frame
		var sk: Skater = t.get("rider")
		var rig: RiderRig = sk.visual
		var skel: Skeleton3D = rig.skel
		var head: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("head")).origin
		var face_dir: Vector3 = _face_dir(skel)
		var at: Vector3 = head + Vector3.UP * float(OS.get_environment("FACE_UP") if OS.get_environment("FACE_UP") != "" else "0.08") \
			+ face_dir * (0.08 if dist < 0.5 else 0.0)        # (close in: the eyes, in front of the head bone)
		for view in [["", 0.5], ["_side", 1.45]]:
			var d: Vector3 = face_dir.rotated(Vector3.UP, float(view[1]) - 0.5)
			var pos: Vector3 = at + d * dist + Vector3.UP * 0.03
			cam.global_transform = Transform3D(Basis.looking_at(at - pos, Vector3.UP), pos)
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join("face_%s%s.png" % [key, view[0]]))
	get_tree().quit()


## Which way the face looks (horizontal): the head bone's local forward. The skeleton's rest faces +Z.
func _face_dir(skel: Skeleton3D) -> Vector3:
	var g: Transform3D = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("head"))
	var rest: Transform3D = skel.global_transform * skel.get_bone_global_rest(skel.find_bone("head"))
	var f: Vector3 = (g.basis * rest.basis.inverse()) * (skel.global_transform.basis * Vector3(0, 0, 1))
	f.y = 0.0
	return f.normalized() if f.length() > 0.1 else Vector3(0, 0, 1)
