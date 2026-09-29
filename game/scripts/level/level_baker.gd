class_name LevelBaker
extends RefCounted
## Merges every static mesh of an imported level into a handful of chunked, toon-shaded meshes
## (one per material per map cell), so thousands of props cost a few dozen draw calls.

const CELL: float = 48.0
const CROWD_CELL: float = 24.0
const CROWD_PARAMS: Dictionary = {"bounce": 1.0, "bounce_speed": 5.0}


## Crowd people carry meta "crowd_phase" / "crowd_amp" / "crowd_foot" on their root; returns {} for everything else.
static func _crowd_info(n: Node) -> Dictionary:
	var p: Node = n
	for _i in 6:
		if p == null:
			break
		if p.has_meta("crowd_phase"):
			return {"phase": p.get_meta("crowd_phase"), "amp": p.get_meta("crowd_amp"), "foot": p.get_meta("crowd_foot")}
		p = p.get_parent()
	return {}


## Per-cell geometry that is drawn in a shared pass: all outlined surfaces (one cull_front draw) and all
## shadow casters (one SHADOWS_ONLY draw), instead of one outline + one shadow draw per material bucket.
class Cell:
	var ov: PackedVector3Array = PackedVector3Array()
	var oc: PackedColorArray = PackedColorArray()
	var oi: PackedInt32Array = PackedInt32Array()
	var sv: PackedVector3Array = PackedVector3Array()
	var si: PackedInt32Array = PackedInt32Array()
	var ouv: PackedVector2Array = PackedVector2Array()   # crowd only: hop phase and height
	var crowd: bool = false


class Bucket:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var idx: PackedInt32Array = PackedInt32Array()
	var mat_name: String = ""
	var color: Color = Color.WHITE
	var uv: PackedVector2Array = PackedVector2Array()
	var crowd: bool = false


## `root` must be inside the tree so global transforms are valid. Returns a Node3D with the baked meshes.
static func bake(root: Node3D) -> Node3D:
	var buckets: Dictionary = {}
	var cells: Dictionary = {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		var mesh: Mesh = inst.mesh
		if mesh == null or not inst.visible:
			continue
		var xf: Transform3D = inst.global_transform
		var center: Vector3 = xf * mesh.get_aabb().get_center()
		var crowd: Dictionary = _crowd_info(inst)
		var is_crowd: bool = not crowd.is_empty()
		var cell: String = "%d|%d" % [floori(center.x / CELL), floori(center.z / CELL)]
		if is_crowd:
			cell = "c%d|%d" % [floori(center.x / CROWD_CELL), floori(center.z / CROWD_CELL)]
		for s in mesh.get_surface_count():
			var old: Material = inst.get_active_material(s)
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
				b.crowd = is_crowd
				buckets[key] = b
			var uvs: PackedVector2Array = PackedVector2Array()
			if is_crowd:
				uvs.resize(count)
				for i in count:
					uvs[i] = Vector2(float(crowd["phase"]), clampf((wv[i].y - float(crowd["foot"])) / 0.85, 0.0, 1.0) * float(crowd["amp"]))
			var st: Dictionary = Toon.style(mname)
			var cg: Cell = cells.get(cell)
			if cg == null:
				cg = Cell.new()
				cg.crowd = is_crowd
				cells[cell] = cg
			var local_idx: PackedInt32Array = PackedInt32Array()
			if i_in is PackedInt32Array and (i_in as PackedInt32Array).size() > 0:
				local_idx = i_in as PackedInt32Array
			else:
				local_idx.resize(count)
				for ix in count:
					local_idx[ix] = ix
			var base: int = b.verts.size()
			b.verts.append_array(wv)
			b.norms.append_array(wn)
			if is_crowd:
				b.uv.append_array(uvs)
			for ix in local_idx:
				b.idx.append(base + ix)
			if st.get("outline", true):
				var obase: int = cg.ov.size()
				cg.ov.append_array(wv)
				cg.oc.append_array(Toon.outline_normals(wv, wn))
				if is_crowd:
					cg.ouv.append_array(uvs)
				for ix in local_idx:
					cg.oi.append(obase + ix)
			if not (st.get("flat", false) or mname == "FenceMesh"):
				var sbase: int = cg.sv.size()
				cg.sv.append_array(wv)
				for ix in local_idx:
					cg.si.append(sbase + ix)
	var out: Node3D = Node3D.new()
	out.name = "Baked"
	for key in buckets:
		var b: Bucket = buckets[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b.verts
		arrays[Mesh.ARRAY_NORMAL] = b.norms
		arrays[Mesh.ARRAY_INDEX] = b.idx
		if b.crowd:
			arrays[Mesh.ARRAY_TEX_UV] = b.uv
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, Toon.material(b.mat_name, b.color, true, false, CROWD_PARAMS if b.crowd else {}))
		var node: MeshInstance3D = MeshInstance3D.new()
		node.name = b.mat_name
		node.set_meta("mat", b.mat_name)
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.add_child(node)
	for ck in cells:
		var cg: Cell = cells[ck]
		if cg.oi.size() > 0:
			var outline_mat: ShaderMaterial = Toon.outline_material_crowd() if cg.crowd else Toon.outline_material()
			out.add_child(_pass_node("Outline_" + String(ck), cg.ov, cg.oc, cg.oi, outline_mat,
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, cg.ouv))
		if cg.si.size() > 0:
			out.add_child(_pass_node("Shadow_" + String(ck), cg.sv, PackedColorArray(), cg.si, Toon.shadow_material(),
				GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY))
	return out


static func _pass_node(node_name: String, v: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		mat: Material, shadow_mode: int, uv: PackedVector2Array = PackedVector2Array()) -> MeshInstance3D:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	if uv.size() > 0:
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if c.size() > 0:
		arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name.replace("|", "_")
	node.mesh = mesh
	node.cast_shadow = shadow_mode as GeometryInstance3D.ShadowCastingSetting
	return node
