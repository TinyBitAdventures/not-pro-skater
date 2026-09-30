extends Node3D
## Character viewer: a character glb standing on the plaza, lit like the game, screenshots from a few angles.
##   CHAR=dev godot --path . res://scenes/dev_char.tscn --resolution 1280x720      (shots -> ../shots/char_<name>_*.png)

var level: Level
var cam: Camera3D


func _ready() -> void:
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/neighborhood.gltf", "real")
	RealEnv.build(self, level.lightmap_info)
	var nm: String = OS.get_environment("CHAR") if OS.get_environment("CHAR") != "" else "dev"
	var ch: Node3D = (load("res://assets/characters/%s.glb" % nm) as PackedScene).instantiate()
	add_child(ch)
	RiderRig.prepare_character(ch, 1.0)       # as the game shows it (hair cutouts, shadows)
	ch.position = Vector3(-14.0, 0.0, 18.0)   # open plaza in Neighborhood Park
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	_tour.call_deferred(nm, ch)


func _tour(nm: String, ch: Node3D) -> void:
	var aabb: AABB = AABB()
	var first: bool = true
	for mi in ch.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var b: AABB = m.global_transform * m.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	print("[char] %s bounds size %s top %.2f" % [nm, aabb.size, aabb.end.y])
	var target: Vector3 = ch.global_position + Vector3(0, aabb.size.y * 0.55, 0)
	var angles: Array = [["front", 0.0], ["three_quarter", 40.0], ["side", 90.0], ["back", 180.0], ["face", 20.0]]
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	for a in angles:
		var yaw: float = deg_to_rad(a[1])
		var off: Vector3 = Vector3(sin(yaw), 0.15, cos(yaw)).normalized() * 4.2
		var aim: Vector3 = target
		if a[0] == "face":
			aim = ch.global_position + Vector3(0, aabb.end.y - 0.13, 0)
			off = off.normalized() * 0.7
		cam.global_transform = Transform3D(Basis.looking_at(-off, Vector3.UP), aim + off)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("char_%s_%s.png" % [nm, a[0]]))
	get_tree().quit()
