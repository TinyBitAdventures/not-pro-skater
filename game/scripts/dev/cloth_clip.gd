class_name ClothClip
extends RefCounted
## Where one garment comes through another on a posed rider (the Dad's khakis showed through the back of his polo
## in the riding crouch): both meshes skinned on the CPU as the rig has posed them, then every vertex of the inner
## garment that is well under the outer one and out past its surface counts. "Under" is measured at rest, as
## blender/character.py does when it tucks one in: the outer garment's points more than COVER past where it ends
## round the body (a shirt's hem, its lowest point in each direction; a waistband, its highest). Which garment is
## outer is the one the other stays under at rest (a shirt worn out, or tucked in). Only the inner garment's
## vertices under the outer one at rest count: a thigh pressed into the belly in a grab is the body folding into
## itself, not one layer coming through another.
## Used by rig_tour.gd with CLOTH=1.

const TOPS: Array[String] = ["shirt", "sweater"]
const BOTTOMS: Array[String] = ["pants", "jeans", "shorts"]
const CELL: float = 0.04
const NEAR: float = 0.03          # m: only the other garment's surface this close counts as over it
const COVER: float = 0.008        # m past the outer garment's edge: covered (at the edge itself, it drapes)
const THROUGH: float = 0.0015     # m out past it: showing
const BINS: int = 32


## [{"inner": name, "outer": name, "through": vertices showing, "worst": m}] for each top / bottom pair under `root`.
static func measure(root: Node) -> Array:
	var tops: Array[MeshInstance3D] = []
	var bottoms: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null or mi.skin == null:
			continue
		var nm: String = String(mi.name).to_lower()
		if TOPS.any(func(k: String) -> bool: return nm.contains(k)):
			tops.append(mi)
		elif BOTTOMS.any(func(k: String) -> bool: return nm.contains(k)):
			bottoms.append(mi)
	var out: Array = []
	for t in tops:
		for b in bottoms:
			# at rest (the glb's own positions: every garment shares the skeleton's bind space there)
			var worn_out: Array = _through(_garment(b, false, false), _garment(t, false, true))
			var tucked: Array = _through(_garment(t, false, true), _garment(b, false, false))
			var outer: MeshInstance3D = t if int(worn_out[0]) <= int(tucked[0]) else b
			var inner: MeshInstance3D = b if outer == t else t
			var r: Array = _through(_garment(inner, true, inner == t), _garment(outer, true, outer == t),
				worn_out[2] if outer == t else tucked[2])
			out.append({"inner": String(inner.name), "outer": String(outer.name), "through": r[0], "worst": r[1]})
	return out


## Positions (skeleton space as posed, or the mesh's own at rest), triangles (outward = Godot's clockwise front),
## and how far past its edge each vertex is at rest (above the hem of a top, below the waistband of a bottom).
static func _garment(mi: MeshInstance3D, posed: bool, top: bool) -> Dictionary:
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var pos: PackedVector3Array = v.duplicate()
	if posed:
		var skel: Skeleton3D = mi.get_node(mi.skeleton) as Skeleton3D
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / v.size()
		var mats: Array[Transform3D] = []
		for i in mi.skin.get_bind_count():
			var bone: int = mi.skin.get_bind_bone(i)
			if bone < 0:
				bone = skel.find_bone(mi.skin.get_bind_name(i))
			mats.append(skel.get_bone_global_pose(bone) * mi.skin.get_bind_pose(i))
		for i in v.size():
			var p: Vector3 = Vector3.ZERO
			for k in per:
				var w: float = weights[i * per + k]
				if w > 0.0:
					p += (mats[bones[i * per + k]] * v[i]) * w
			pos[i] = p
	# where it ends round the body: the lowest (highest) torso point in each direction, and its neighbours'
	var mid: Vector2 = Vector2.ZERO
	for p in v:
		mid += Vector2(p.x, p.z) / v.size()
	var ends: Array = []
	ends.resize(BINS)
	for p in v:
		var off: Vector2 = Vector2(p.x, p.z) - mid
		if off.length() > 0.3:
			continue
		var k: int = _bin(off)
		if ends[k] == null or (p.y < float(ends[k]) if top else p.y > float(ends[k])):
			ends[k] = p.y
	var edge: PackedFloat32Array = PackedFloat32Array()
	edge.resize(BINS)
	for k in BINS:
		var e: float = INF if top else -INF
		for j in [k - 1, k, k + 1]:
			var y: Variant = ends[posmod(j, BINS)]
			if y != null:
				e = minf(e, float(y)) if top else maxf(e, float(y))
		edge[k] = e
	var past: PackedFloat32Array = PackedFloat32Array()
	past.resize(v.size())
	for i in v.size():
		var e: float = edge[_bin(Vector2(v[i].x, v[i].z) - mid)]
		past[i] = (v[i].y - e) if top else (e - v[i].y)
	var grid: Dictionary = {}
	for i in range(0, idx.size(), 3):
		var lo: Vector3 = pos[idx[i]].min(pos[idx[i + 1]]).min(pos[idx[i + 2]])
		var hi: Vector3 = pos[idx[i]].max(pos[idx[i + 1]]).max(pos[idx[i + 2]])
		for x in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for y in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
				for z in range(floori(lo.z / CELL), floori(hi.z / CELL) + 1):
					var c: Vector3i = Vector3i(x, y, z)
					if not grid.has(c):
						grid[c] = []
					(grid[c] as Array).append(i)
	return {"pos": pos, "idx": idx, "past": past, "grid": grid}


static func _bin(off: Vector2) -> int:
	return posmod(int((off.angle() + PI) / TAU * BINS), BINS)


## [vertices of `inner` out through `outer`, the worst (m), which of them are under it], of those in `only` if given.
static func _through(inner: Dictionary, outer: Dictionary, only: PackedByteArray = PackedByteArray()) -> Array:
	var pos: PackedVector3Array = inner["pos"]
	var opos: PackedVector3Array = outer["pos"]
	var oidx: PackedInt32Array = outer["idx"]
	var past: PackedFloat32Array = outer["past"]
	var grid: Dictionary = outer["grid"]
	var through: int = 0
	var worst: float = 0.0
	var under: PackedByteArray = PackedByteArray()
	under.resize(pos.size())
	for vi in pos.size():
		if not only.is_empty() and only[vi] == 0:
			continue
		var p: Vector3 = pos[vi]
		var c0: Vector3i = Vector3i((p / CELL).floor())
		var best: float = NEAR
		var bt: int = -1
		var bc: Vector3 = Vector3.ZERO
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var cell: Vector3i = c0 + Vector3i(dx, dy, dz)
					if not grid.has(cell):
						continue
					for t in grid[cell]:
						var q: Vector3 = _closest(p, opos[oidx[t]], opos[oidx[t + 1]], opos[oidx[t + 2]])
						var d: float = p.distance_to(q)
						if d < best:
							best = d
							bt = t
							bc = q
		if bt < 0 or minf(past[oidx[bt]], minf(past[oidx[bt + 1]], past[oidx[bt + 2]])) < COVER:
			continue
		under[vi] = 1
		var n: Vector3 = (opos[oidx[bt + 2]] - opos[oidx[bt]]).cross(opos[oidx[bt + 1]] - opos[oidx[bt]]).normalized()
		var s: float = (p - bc).dot(n)
		if s > THROUGH:
			through += 1
			worst = maxf(worst, s)
	return [through, worst, under]


## The closest point to p on triangle abc (Ericson, Real-Time Collision Detection 5.1.5).
static func _closest(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = p - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = p - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp: Vector3 = p - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den: float = 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)
