class_name LevelBaker
extends RefCounted
## Merges every static mesh of an imported level into a handful of chunked, toon-shaded meshes
## (one per material per map cell), so thousands of props cost a few dozen draw calls.

const CELL: float = 48.0


class Bucket:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	var mat_name: String = ""
	var color: Color = Color.WHITE


## `root` must be inside the tree so global transforms are valid. Returns a Node3D with the baked meshes.
static func bake(root: Node3D) -> Node3D:
	var buckets: Dictionary = {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		var mesh: Mesh = inst.mesh
		if mesh == null or not inst.visible:
			continue
		var xf: Transform3D = inst.global_transform
		var center: Vector3 = xf * mesh.get_aabb().get_center()
		var cell: String = "%d|%d" % [floori(center.x / CELL), floori(center.z / CELL)]
		for s in mesh.get_surface_count():
			var old: Material = mesh.surface_get_material(s)
			var mname: String = old.resource_name if old != null else "Default"
			if mname == "Collision":
				continue
			var color: Color = Color.WHITE
			if old is BaseMaterial3D:
				color = (old as BaseMaterial3D).albedo_color
			var arrays: Array = mesh.surface_get_arrays(s)
			var v_in: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var n_in: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var i_in: Variant = arrays[Mesh.ARRAY_INDEX]
			var count: int = v_in.size()
			var wv: PackedVector3Array = PackedVector3Array()
			var wn: PackedVector3Array = PackedVector3Array()
			wv.resize(count)
			wn.resize(count)
			var basis: Basis = xf.basis
			for i in count:
				wv[i] = xf * v_in[i]
				wn[i] = (basis * n_in[i]).normalized()
			var key: String = "%s|%s|%s" % [mname, color.to_html(false), cell]
			var b: Bucket = buckets.get(key)
			if b == null:
				b = Bucket.new()
				b.mat_name = mname
				b.color = color
				buckets[key] = b
			var base: int = b.verts.size()
			b.verts.append_array(wv)
			b.norms.append_array(wn)
			if Toon.style(mname).get("outline", true):
				b.cols.append_array(Toon.outline_normals(wv, wn))
			else:
				var pad: PackedColorArray = PackedColorArray()
				pad.resize(count)
				b.cols.append_array(pad)
			if i_in is PackedInt32Array and (i_in as PackedInt32Array).size() > 0:
				for ix in (i_in as PackedInt32Array):
					b.idx.append(base + ix)
			else:
				for ix in count:
					b.idx.append(base + ix)
	var out: Node3D = Node3D.new()
	out.name = "Baked"
	for key in buckets:
		var b: Bucket = buckets[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b.verts
		arrays[Mesh.ARRAY_NORMAL] = b.norms
		arrays[Mesh.ARRAY_COLOR] = b.cols
		arrays[Mesh.ARRAY_INDEX] = b.idx
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, Toon.material(b.mat_name, b.color, true))
		var node: MeshInstance3D = MeshInstance3D.new()
		node.name = b.mat_name
		node.set_meta("mat", b.mat_name)
		node.mesh = mesh
		if Toon.style(b.mat_name).get("flat", false) or b.mat_name == "FenceMesh":
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.add_child(node)
	return out
