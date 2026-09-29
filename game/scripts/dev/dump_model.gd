extends Node
## Print a model's node tree with local transforms: MODEL=res://assets/models/spectator.glb godot --headless ...

func _ready() -> void:
	var packed: PackedScene = load(OS.get_environment("MODEL"))
	var n: Node = packed.instantiate()
	add_child(n)
	_dump(n, 0)
	get_tree().quit()

func _dump(n: Node, depth: int) -> void:
	var extra: String = ""
	if n is Node3D:
		var t: Transform3D = (n as Node3D).transform
		extra = " pos=%s rot=%s" % [t.origin.snapped(Vector3(0.001, 0.001, 0.001)), (t.basis.get_euler() * 57.2958).snapped(Vector3(0.1, 0.1, 0.1))]
	var mat: String = ""
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).mesh.get_surface_count() > 0:
		var m: Material = (n as MeshInstance3D).mesh.surface_get_material(0)
		mat = " mat=%s" % (m.resource_name if m != null else "-")
	print("[dump] ", "  ".repeat(depth), n.name, " ", n.get_class(), extra, mat)
	for c in n.get_children():
		_dump(c, depth + 1)
