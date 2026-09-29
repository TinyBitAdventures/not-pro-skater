extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://assets/levels/community_park.glb")
	var scene: Node3D = packed.instantiate()
	add_child(scene)
	for m in scene.find_children("*Plaza*", "", true, false):
		print("[probe] node ", m.name, " ", m.get_class(), " parent=", m.get_parent().name)
		if m is MeshInstance3D:
			var mesh: Mesh = (m as MeshInstance3D).mesh
			print("[probe]   surfaces=", mesh.get_surface_count(), " mat=", mesh.surface_get_material(0), " name=", mesh.surface_get_material(0).resource_name if mesh.surface_get_material(0) else "-", " visible=", (m as MeshInstance3D).visible)
			var arr: Array = mesh.surface_get_arrays(0)
			print("[probe]   verts=", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), " idx=", (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size())
		for c in m.get_children():
			print("[probe]   child ", c.name, " ", c.get_class())
	get_tree().quit()
