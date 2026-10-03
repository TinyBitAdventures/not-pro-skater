extends Node3D
## Z-fighting: an upward face drawn twice at the same height (two slabs overlapping, a decal flush with what it's
## on). Their depths tie, so which one shows changes with the view and the camera's every move: a flicker (the
## school's court overlapped its plaza by 2 m). Every drawn mesh of every level:
##   godot --headless --path . res://scenes/dev_zfight.tscn          (LEVEL=school for one)
## Prints each overlap: where (Blender coordinates), its area, the two meshes. Exit code = overlaps found.

const LEVELS: Array[String] = ["neighborhood", "school", "campus", "warehouse", "downtown", "backlot"]
const TIE: float = 0.004          # m apart or less over the overlap: a tie in the depth buffer at a distance
const MIN_AREA: float = 0.02      # m² of overlap worth reporting
const CELL: float = 2.0
const TOP: float = 4.0            # m: faces higher than this (roofs, canopies) aren't checked

var _tri: PackedVector3Array = PackedVector3Array()     # 3 per triangle, world space
var _owner: PackedInt32Array = PackedInt32Array()
var _names: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var want: String = OS.get_environment("LEVEL") if OS.get_environment("LEVEL") != "" else "all"
	var names: Array = LEVELS if want == "all" else Array(want.split(","))
	var total: int = 0
	for nm in names:
		total += await _audit(String(nm))
	print("[zfight] %d overlap(s)" % total)
	get_tree().quit(total)


func _audit(nm: String) -> int:
	var path: String = "res://assets/levels/%s.gltf" % nm
	if not ResourceLoader.exists(path):
		path = "res://assets/levels/%s.glb" % nm
	var t0: int = Time.get_ticks_msec()
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	_tri.clear()
	_owner.clear()
	_names.clear()
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi != null and mi.mesh != null and mi.is_visible_in_tree():
			_add_mesh(mi)
	var grid: Dictionary = {}
	var count: int = _owner.size()
	for t in count:
		var lo: Vector2 = _lo(t)
		var hi: Vector2 = _hi(t)
		for gx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for gz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
				var k: Vector2i = Vector2i(gx, gz)
				if not grid.has(k):
					grid[k] = []
				(grid[k] as Array).append(t)
	var found: Dictionary = {}      # "meshA | meshB" -> [area, a point]
	for k in grid:
		var ts: Array = grid[k]
		for i in ts.size():
			for j in range(i + 1, ts.size()):
				var a: int = ts[i]
				var b: int = ts[j]
				# each pair once: in the cell holding the corner of where their bounds overlap
				var corner: Vector2 = _lo(a).max(_lo(b))
				if Vector2i(floori(corner.x / CELL), floori(corner.y / CELL)) != k:
					continue
				var r: Variant = _tie(a, b)
				if r == null:
					continue
				var nk: String = " | ".join([_names[_owner[a]], _names[_owner[b]]])
				var acc: Array = found.get(nk, [0.0, r[1]])
				acc[0] = float(acc[0]) + float(r[0])
				found[nk] = acc
	var bad: int = 0
	var lines: Array[String] = []
	for nk in found:
		var acc: Array = found[nk]
		if float(acc[0]) < MIN_AREA:
			continue
		bad += 1
		var p: Vector3 = acc[1]
		lines.append("  %.2f m² near (%.1f, %.1f, %.2f): %s" % [acc[0], p.x, -p.z, p.y, nk])
	print("[zfight] %-12s %d upward triangles, %d overlap(s), %.0f s" % [nm, count, bad, (Time.get_ticks_msec() - t0) / 1000.0])
	for l in lines:
		print(l)
	scene.queue_free()
	await get_tree().process_frame
	return bad


func _add_mesh(mi: MeshInstance3D) -> void:
	var xf: Transform3D = mi.global_transform
	var label: String = String(mi.name)
	for s in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(v.size())
			for i in v.size():
				idx[i] = i
		var mat: Material = mi.get_active_material(s)
		var bm: BaseMaterial3D = mat as BaseMaterial3D
		if bm != null and bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue                                      # leaves, grass cards, hair: cut-outs overlap by design
		var own: int = _names.size()
		_names.append("%s[%s]" % [label, mat.resource_name if mat != null and mat.resource_name != "" else str(s)])
		for i in range(0, idx.size() - 2, 3):
			var a: Vector3 = xf * v[idx[i]]
			var b: Vector3 = xf * v[idx[i + 1]]
			var c: Vector3 = xf * v[idx[i + 2]]
			var nrm: Vector3 = (c - a).cross(b - a)      # Godot's front faces wind clockwise
			if nrm.length() < 1e-8 or nrm.normalized().y < 0.5:
				continue                                  # walls and undersides: not drawn over each other here
			if maxf(a.y, maxf(b.y, c.y)) > TOP:
				continue
			_tri.append(a)
			_tri.append(b)
			_tri.append(c)
			_owner.append(own)


func _lo(t: int) -> Vector2:
	var a: Vector3 = _tri[t * 3]
	var b: Vector3 = _tri[t * 3 + 1]
	var c: Vector3 = _tri[t * 3 + 2]
	return Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))


func _hi(t: int) -> Vector2:
	var a: Vector3 = _tri[t * 3]
	var b: Vector3 = _tri[t * 3 + 1]
	var c: Vector3 = _tri[t * 3 + 2]
	return Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))


## [area, a point] where triangles a and b overlap (seen from above) within TIE of each other's height, else null.
func _tie(a: int, b: int) -> Variant:
	var la: Vector2 = _lo(a)
	var ha: Vector2 = _hi(a)
	var lb: Vector2 = _lo(b)
	var hb: Vector2 = _hi(b)
	if la.x >= hb.x or lb.x >= ha.x or la.y >= hb.y or lb.y >= ha.y:
		return null
	var ya: Vector2 = Vector2(minf(_tri[a * 3].y, minf(_tri[a * 3 + 1].y, _tri[a * 3 + 2].y)), maxf(_tri[a * 3].y, maxf(_tri[a * 3 + 1].y, _tri[a * 3 + 2].y)))
	var yb: Vector2 = Vector2(minf(_tri[b * 3].y, minf(_tri[b * 3 + 1].y, _tri[b * 3 + 2].y)), maxf(_tri[b * 3].y, maxf(_tri[b * 3 + 1].y, _tri[b * 3 + 2].y)))
	if ya.x > yb.y + TIE or yb.x > ya.y + TIE:
		return null
	var poly: PackedVector2Array = _flat(a)
	var clip: PackedVector2Array = _flat(b)
	if _area(clip) < 0.0:
		clip.reverse()
	if _area(poly) < 0.0:
		poly.reverse()
	for e in 3:
		poly = _clip(poly, clip[e], clip[(e + 1) % 3])
		if poly.size() < 3:
			return null
	var area: float = _area(poly)
	if area < 1e-4:
		return null
	var pa: Plane = Plane(_tri[a * 3], _tri[a * 3 + 1], _tri[a * 3 + 2])
	var pb: Plane = Plane(_tri[b * 3], _tri[b * 3 + 1], _tri[b * 3 + 2])
	for q in poly:
		if absf(_height(pa, q) - _height(pb, q)) > TIE:
			return null
	var mid: Vector2 = Vector2.ZERO
	for q in poly:
		mid += q / poly.size()
	return [area, Vector3(mid.x, _height(pa, mid), mid.y)]


func _flat(t: int) -> PackedVector2Array:
	return PackedVector2Array([Vector2(_tri[t * 3].x, _tri[t * 3].z), Vector2(_tri[t * 3 + 1].x, _tri[t * 3 + 1].z),
		Vector2(_tri[t * 3 + 2].x, _tri[t * 3 + 2].z)])


func _height(p: Plane, q: Vector2) -> float:
	return (p.d - p.normal.x * q.x - p.normal.z * q.y) / p.normal.y


func _area(poly: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in poly.size():
		s += poly[i].cross(poly[(i + 1) % poly.size()])
	return s * 0.5


## Sutherland-Hodgman: the part of `poly` left of the edge a -> b (counter-clockwise clip polygon).
func _clip(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var d: Vector2 = b - a
	for i in poly.size():
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		var sp: float = d.cross(p - a)
		var sq: float = d.cross(q - a)
		if sp >= 0.0:
			out.append(p)
		if (sp >= 0.0) != (sq >= 0.0):
			out.append(p + (q - p) * (sp / (sp - sq)))
	return out
