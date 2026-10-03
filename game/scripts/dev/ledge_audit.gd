extends Node3D
## Ledges that should be grindable but have no grind line: every convex top edge in a level's collision (a flat
## top meeting a steep side) that is long enough, 0.12 - 1.3 m above the ground in front of it, with room above,
## and not already covered by a rail from Blender (rails.json) or an earlier run of this audit (ledges.json):
##   LEVEL=warehouse godot --headless --path . res://scenes/dev_ledges.tscn        (LEVEL=all for every level)
## Prints each uncovered ledge (collider, surface, middle, length, height). WRITE=1 writes them all to
## assets/levels/<level>.ledges.json, which Level loads beside rails.json (kind "ledge", or "curb" under 0.25 m),
## each a few cm above its edge and 0.3 m in from the ends like the Blender rails.

const LEVELS: Array[String] = ["neighborhood", "school", "campus", "warehouse", "downtown", "backlot"]
const MIN_LEN: float = 1.5
const MIN_H: float = 0.12
const MAX_H: float = 1.3
const LIFT: float = 0.07          # the line above the edge (the Blender rails' convention)
const INSET: float = 0.3
const Q: float = 0.005            # vertices closer than this are the same
# not ledges: walls, vans and dumpsters ("Wall" surface), cars, glass; props collide with a loose bounds box
const SKIP_SURFACES: Array[String] = ["wall", "car", "glass", "hidden", "water"]
# stairs (each step's nosing; their handrails are authored), stairs' hidden slopes, market stalls and counters (goods on them)
const SKIP_NAMES: Array[String] = ["_Prop_", "step_", "Slope", "StallTable", "CafeCounter"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var want: String = OS.get_environment("LEVEL") if OS.get_environment("LEVEL") != "" else "all"
	var names: Array = LEVELS if want == "all" else Array(want.split(","))
	var total: int = 0
	for nm in names:
		total += await _audit(String(nm))
	print("[ledges] %d uncovered ledge(s)" % total)
	get_tree().quit()


func _path(nm: String) -> String:
	for ext in [".gltf", ".glb"]:
		if ResourceLoader.exists("res://assets/levels/" + nm + ext):
			return "res://assets/levels/" + nm + ext
	return ""


func _audit(nm: String) -> int:
	var level: Level = Level.new()
	add_child(level)
	level.load_glb(_path(nm), "grey")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var found: Array = []
	var kinds: Dictionary = {}
	for b in level.collision_root.get_children():
		for c in b.get_children():
			var kk: String = c.get_class() + (":" + (c as CollisionShape3D).shape.get_class() if c is CollisionShape3D and (c as CollisionShape3D).shape != null else "")
			kinds[kk] = int(kinds.get(kk, 0)) + 1
	print("[ledges] %s: %d bodies, %s, %d grind lines" % [nm, level.collision_root.get_child_count(), kinds, level.grind_lines.size()])
	for b in level.collision_root.get_children():
		var body: StaticBody3D = b as StaticBody3D
		if body == null:
			continue
		var surface: String = String(body.get_meta("surface", ""))
		if SKIP_SURFACES.has(surface.to_lower()) or bool(body.get_meta("vert", false)) \
				or SKIP_NAMES.any(func(k: String) -> bool: return String(body.name).contains(k)):
			continue
		for c in body.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or not (cs.shape is ConcavePolygonShape3D):
				continue
			for e in _edges((cs.shape as ConcavePolygonShape3D).get_faces(), cs.global_transform):
				e["body"] = String(body.name)
				e["surface"] = surface
				found.append(e)
	var out: Array = []
	for e in found:
		var a: Vector3 = e["a"]
		var bb: Vector3 = e["b"]
		var side: Vector3 = e["side"]
		var mid: Vector3 = (a + bb) * 0.5
		var len: float = a.distance_to(bb)
		if len < MIN_LEN:
			continue
		# the ground in front of the side (at the middle and both quarter points: the lowest is the drop)
		var ground: float = INF
		for t in [0.25, 0.5, 0.75]:
			var p: Vector3 = a.lerp(bb, t) + side * 0.4
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.05, p + Vector3.DOWN * 3.0, 1))
			if not hit.is_empty():
				ground = minf(ground, mid.y - (hit["position"] as Vector3).y)
		if ground == INF or ground < MIN_H or ground > MAX_H:
			continue
		# room in front of the side (not against a wall)
		var front: Vector3 = mid + side * 0.15 + Vector3.UP * 0.3
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(front, front + side * 1.2, 1)).is_empty():
			continue
		# the stretches of it with nothing on top (a cap stone, a roof: looked for from above, since a ray starting
		# inside a closed mesh sees nothing) and no rail already along them: each becomes its own ledge
		var step: float = 0.25
		var n: int = maxi(2, int(len / step))
		var free: Array[bool] = []
		for k in n + 1:
			var p2: Vector3 = a.lerp(bb, float(k) / n)
			var ok: bool = true
			var over: Vector3 = p2 - side * 0.15
			var hit2: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(over + Vector3.UP * 2.2, over + Vector3.DOWN * 0.1, 1))
			if not hit2.is_empty() and (hit2["position"] as Vector3).y > p2.y + 0.03:
				ok = false
			if ok:
				for line in level.grind_lines:
					if line.id.begins_with("auto_"):
						continue               # (this audit's own lines: a rerun writes the same set again)
					if (line.closest(p2)["point"] as Vector3).distance_to(p2 + Vector3.UP * LIFT) < 0.45:
						ok = false
						break
			free.append(ok)
		var k0: int = -1
		for k in n + 2:
			var on: bool = k <= n and free[k]
			if on and k0 < 0:
				k0 = k
			elif not on and k0 >= 0:
				var ra: Vector3 = a.lerp(bb, float(k0) / n)
				var rb: Vector3 = a.lerp(bb, float(k - 1) / n)
				if ra.distance_to(rb) >= MIN_LEN:
					out.append({"a": ra, "b": rb, "side": side, "body": e["body"], "surface": e["surface"],
						"mid": (ra + rb) * 0.5, "len": ra.distance_to(rb), "h": ground})
				k0 = -1
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["len"]) > float(y["len"]))
	for e in out:
		var m: Vector3 = e["mid"]
		print("[ledges] %s  %-34s %-9s mid (%.1f, %.2f, %.1f)  %.1f m long, %.2f m high" % [nm, e["body"], e["surface"],
			m.x, m.y, m.z, e["len"], e["h"]])
	print("[ledges] %s: %d uncovered (of %d convex top edges)" % [nm, out.size(), found.size()])
	if OS.get_environment("WRITE") != "":
		_write(nm, out)
	level.queue_free()
	await get_tree().physics_frame
	return out.size()


## Convex top edges of a triangle soup (world space): {a, b, side} with `side` the outward horizontal normal of the
## steep face. Collinear pieces that touch are merged into one edge.
func _edges(faces: PackedVector3Array, xf: Transform3D) -> Array:
	var tris: Array = []
	var edges: Dictionary = {}
	for i in range(0, faces.size(), 3):
		var v: Array = [xf * faces[i], xf * faces[i + 1], xf * faces[i + 2]]
		var nrm: Vector3 = (v[2] - v[0]).cross(v[1] - v[0])     # (Godot's front faces wind clockwise)
		if nrm.length() < 1e-6:
			continue
		nrm = nrm.normalized()
		var ti: int = tris.size()
		tris.append([v, nrm, (v[0] + v[1] + v[2]) / 3.0])
		for k in 3:
			var p: Vector3 = v[k]
			var q: Vector3 = v[(k + 1) % 3]
			var ka: String = _key(p)
			var kb: String = _key(q)
			var key: String = ka + "|" + kb if ka < kb else kb + "|" + ka
			if not edges.has(key):
				edges[key] = [p, q, []]
			(edges[key][2] as Array).append(ti)
	var raw: Array = []
	for key in edges:
		var ed: Array = edges[key]
		var ts: Array = ed[2]
		if ts.size() != 2:
			continue
		var t1: Array = tris[ts[0]]
		var t2: Array = tris[ts[1]]
		var top: Array = t1 if (t1[1] as Vector3).y > 0.9 else (t2 if (t2[1] as Vector3).y > 0.9 else [])
		var sid: Array = t2 if top == t1 else t1
		if top.is_empty() or absf((sid[1] as Vector3).y) > 0.35:
			continue
		var p: Vector3 = ed[0]
		var q: Vector3 = ed[1]
		if absf(p.y - q.y) > 0.03 * maxf(p.distance_to(q), 0.1):
			continue
		var mid: Vector3 = (p + q) * 0.5
		var sn: Vector3 = sid[1]
		var tn: Vector3 = top[1]
		if ((sid[2] as Vector3) - mid).dot(tn) > -0.005 or ((top[2] as Vector3) - mid).dot(sn) > -0.005:
			continue                                       # concave (an inside corner), not a ledge
		var side: Vector3 = Vector3(sn.x, 0.0, sn.z).normalized()
		raw.append({"a": p, "b": q, "side": side})
	# merge touching collinear pieces with the same side: group by line (direction, side, height, offset), sort along
	# it and join pieces whose ends meet
	var groups: Dictionary = {}
	for e in raw:
		var d: Vector3 = ((e["b"] as Vector3) - (e["a"] as Vector3)).normalized()
		if d.x < -0.001 or (absf(d.x) <= 0.001 and d.z < 0.0):
			d = -d
		var off: Vector3 = (e["a"] as Vector3) - d * (e["a"] as Vector3).dot(d)
		var sd: Vector3 = e["side"]
		var key: String = "%d,%d|%d,%d,%d|%d,%d" % [roundi(d.x * 200), roundi(d.z * 200), roundi(off.x / 0.02),
			roundi(off.y / 0.02), roundi(off.z / 0.02), roundi(sd.x * 20), roundi(sd.z * 20)]
		if not groups.has(key):
			groups[key] = [d, []]
		var t0: float = (e["a"] as Vector3).dot(d)
		var t1: float = (e["b"] as Vector3).dot(d)
		(groups[key][1] as Array).append([minf(t0, t1), maxf(t0, t1), e])
	var out: Array = []
	for key in groups:
		var d: Vector3 = groups[key][0]
		var segs: Array = groups[key][1]
		segs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var cur: Array = segs[0]
		for k in range(1, segs.size()):
			var s2: Array = segs[k]
			if float(s2[0]) <= float(cur[1]) + 0.02:
				cur = [cur[0], maxf(float(cur[1]), float(s2[1])), cur[2]]
			else:
				out.append(_seg(cur, d))
				cur = s2
		out.append(_seg(cur, d))
	return out


func _seg(sg: Array, d: Vector3) -> Dictionary:
	var e: Dictionary = sg[2]
	var a: Vector3 = e["a"]
	var base: Vector3 = a - d * a.dot(d)
	return {"a": base + d * float(sg[0]), "b": base + d * float(sg[1]), "side": e["side"]}


func _key(p: Vector3) -> String:
	return "%d,%d,%d" % [roundi(p.x / Q), roundi(p.y / Q), roundi(p.z / Q)]


func _write(nm: String, ledges: Array) -> void:
	var rails: Array = []
	var i: int = 0
	for e in ledges:
		var a: Vector3 = e["a"]
		var b: Vector3 = e["b"]
		var d: Vector3 = (b - a).normalized()
		var side: Vector3 = e["side"]
		# on the edge, a hair in from the side, LIFT above it, INSET in from each end
		var p0: Vector3 = a + d * INSET - side * 0.03 + Vector3.UP * LIFT
		var p1: Vector3 = b - d * INSET - side * 0.03 + Vector3.UP * LIFT
		i += 1
		rails.append({"id": "auto_%s_%d" % [String(e["body"]).to_lower(), i], "kind": "curb" if float(e["h"]) < 0.25 else "ledge",
			"points": [[snappedf(p0.x, 0.001), snappedf(p0.y, 0.001), snappedf(p0.z, 0.001)],
				[snappedf(p1.x, 0.001), snappedf(p1.y, 0.001), snappedf(p1.z, 0.001)]]})
	var f: FileAccess = FileAccess.open("res://assets/levels/%s.ledges.json" % nm, FileAccess.WRITE)
	f.store_string(JSON.stringify({"rails": rails}, "  "))
	f.close()
	print("[ledges] wrote %d to assets/levels/%s.ledges.json" % [rails.size(), nm])
