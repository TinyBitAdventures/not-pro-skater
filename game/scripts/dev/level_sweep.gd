extends Node
## Level sweep: rides a grid of start points across a level's hard ground, in several headings, with full
## physics (many skaters at once; skaters never collide with each other), and reports where skating breaks:
## stuck while pushing, bails on low lips, falling through or into geometry, position jumps and snaps, launches
## and hops on flat ground, a wall read as the floor, and the chase camera inside geometry. Findings are grouped
## by collider, each with a count and example spots in Godot and Blender coordinates (Blender = (x, -z, y)).
##   LEVEL=school godot --headless --path . --fixed-fps 120 res://scenes/dev_sweep.tscn   (exit code = serious findings)
## Env: LEVEL (default neighborhood), STEP grid spacing in m (2.5), HEADINGS per point (8; odd cells turn half a
##      step), TRIAL seconds per ride (4), SLOTS skaters riding at once (48), OLLIE=0 skips the extra ollie ride at
##      every point (it pops every 1.2 s), MAX_TRIALS caps the run, AREA="x0,z0,x1,z1" limits the grid (Godot x/z),
##      VERBOSE=1 prints every event, OUT=<file.json> writes the findings as JSON, AIR_RELEASE=1 lets go of the
##      stick while airborne (otherwise it is held in the ride direction the whole time, air included).
##      TRACE="x,z,deg[,ollie]" rides once from Godot (x, z) heading deg (0 = north/-z, 90 = east/+x) and prints
##      every tick (position, state, speed, floor normal, contacts, camera eye): for looking at one finding closely.
## Runs of about 3-7 min per level at the defaults; STEP=3 HEADINGS=6 keeps the big hard-surface levels near 3 min.

const R: float = Skater.CAPSULE_R
const LOW_LIP: float = 0.35          # an obstacle up to this high is a lip / curb / step, not a wall
const TINY_LIP: float = 0.12         # ...and up to this high it should just roll over
const STUCK_TIME: float = 2.0        # pushing without leaving a STUCK_RADIUS circle for this long = stuck
const STUCK_RADIUS: float = 0.6
const JUMP: float = 0.5              # one tick moving further than this = a teleport
const VSNAP: float = 0.2             # one tick moving vertically further than this (on the ground) = a snap
const CAM_EVERY: int = 3             # camera checks every n ticks
const CAM_CLIP: float = 0.1          # geometry this close to the eye crosses the near plane's corners
const HEIGHTS: Array[float] = [0.02, 0.04, 0.06, 0.08, 0.1, 0.12, 0.15, 0.18, 0.21, 0.25, 0.3, 0.35, 0.45, 0.6, 0.8,
	1.0, 1.4, 2.0, 3.0]
const SEVERITY: Array[String] = ["info", "low", "medium", "high"]

var level: Level
var lv: String = ""
var space: PhysicsDirectSpaceState3D
var verbose: bool = false
var trace: bool = false
var trial_time: float = 4.0
var air_release: bool = false        # AIR_RELEASE=1: let go of the stick while airborne (a player who doesn't steer in the air)
var trials: Array[Dictionary] = []
var next_trial: int = 0
var slots: Array[Dictionary] = []
var findings: Dictionary = {}        # "kind|collider" -> {kind, collider, sev, count, spots: [{p, count, note, info}]}
var stats: Dictionary = {"trials": 0, "ollie_trials": 0, "ticks": 0, "dist": 0.0, "edge_warps": 0, "bails": {},
	"stuck": 0, "flat_air": 0.0, "flat_air_events": 0, "cam_checks": 0, "starts": 0, "skipped_inside": 0,
	"skipped_grass": 0, "skipped_other": 0}
var _capsule: CapsuleShape3D
var _eye: SphereShape3D
const VIS_LAYER: int = 1 << 7        # the level's visible meshes as trimesh (layer 8): what the rider can see
## visible things that are fine to pass through (or never reachable): foliage cards, bunting, wires, far scenery
const VIS_SKIP: Array[String] = ["TreeLeaves", "Leaf", "Flag", "String", "Wire", "Far", "Grass", "Collision", "Line",
	"Crosswalk", "Glass", "Bunting", "Tape"]
var _vis_bodies: int = 0


func _ready() -> void:
	_run.call_deferred()


func _env(k: String, d: String) -> String:
	var v: String = OS.get_environment(k)
	return v if v != "" else d


func _run() -> void:
	Game.steer_mode = "screen"
	lv = _env("LEVEL", "neighborhood")
	verbose = _env("VERBOSE", "") != ""
	trial_time = float(_env("TRIAL", "4"))
	air_release = _env("AIR_RELEASE", "") != ""
	var t0: int = Time.get_ticks_msec()
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/%s.gltf" % lv, "grey")
	for i in 3:
		await get_tree().physics_frame
	space = get_viewport().get_world_3d().direct_space_state
	_capsule = CapsuleShape3D.new()
	_capsule.radius = R - 0.02
	_capsule.height = Skater.CAPSULE_H - 0.04
	_eye = SphereShape3D.new()
	_eye.radius = CAM_CLIP
	var b: Rect2 = level.bounds
	print("[sweep] %s: bounds x %.1f..%.1f  z %.1f..%.1f (%.0f x %.0f m), %d bodies" % [lv, b.position.x, b.end.x,
		b.position.y, b.end.y, b.size.x, b.size.y, level.stats.get("bodies", 0)])
	if _env("INFO", "") != "":                # list every collider's box (Godot and Blender) and quit
		for body in level.collision_root.get_children():
			for c in body.get_children():
				var cs: CollisionShape3D = c as CollisionShape3D
				if cs != null and cs.shape != null:
					var bb: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
					print("[info] %-40s %-9s godot x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f | blender x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f" % [
						body.name, body.get_meta("surface", ""), bb.position.x, bb.end.x, bb.position.y, bb.end.y, bb.position.z, bb.end.z,
						bb.position.x, bb.end.x, -bb.end.z, -bb.position.z, bb.position.y, bb.end.y])
		get_tree().quit(0)
		return
	var tr_env: PackedFloat64Array = _env("TRACE", "").split_floats(",")
	if tr_env.size() >= 3:
		trace = true
		verbose = true
		var a: float = deg_to_rad(tr_env[2])
		var top: Array[Dictionary] = _stack(tr_env[0], tr_env[1])
		var p: Vector3 = (top[0]["position"] as Vector3) if not top.is_empty() else Vector3(tr_env[0], 0.0, tr_env[1])
		trials.append({"p": p, "dir": Vector3(sin(a), 0.0, -cos(a)), "ollie": tr_env.size() >= 4 and tr_env[3] > 0.0})
		print("[trace] start %s on %s, heading %s" % [_fmt(p), (top[0]["collider"] as Node).name if not top.is_empty() else "-",
			(trials[0]["dir"] as Vector3).snappedf(0.01)])
	else:
		_calibrate()
		_build_visual_layer()
		_make_trials(float(_env("STEP", "2.5")), int(_env("HEADINGS", "8")), _env("OLLIE", "1") != "0")
	var cap: int = int(_env("MAX_TRIALS", "0"))
	if cap > 0 and trials.size() > cap:
		trials.resize(cap)
	print("[sweep] %d start points, %d rides of %.1f s (skipped: %d on grass, %d inside or against a collider, %d other)" % [
		stats["starts"], trials.size(), trial_time, stats["skipped_grass"], stats["skipped_inside"], stats["skipped_other"]])
	var n_slots: int = 1 if trace else int(_env("SLOTS", "48"))
	for i in n_slots:
		slots.append({"idx": i, "sk": null, "cam": null, "active": false})
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	var last_report: int = Time.get_ticks_msec()
	while true:
		var busy: int = 0
		for s in slots:
			if not s["active"] and next_trial < trials.size():
				_begin(s, trials[next_trial])
				next_trial += 1
			if s["active"]:
				busy += 1
		if busy == 0:
			break
		await get_tree().physics_frame
		stats["ticks"] += 1
		for s in slots:
			if s["active"]:
				_watch(s, dt)
		if Time.get_ticks_msec() - last_report > 30000:
			last_report = Time.get_ticks_msec()
			print("[sweep]   %d / %d rides, %.0f s" % [next_trial, trials.size(), (last_report - t0) / 1000.0])
	_report((Time.get_ticks_msec() - t0) / 1000.0)


# ------------------------------------------------------------------ start points

## Every surface straight down at (x, z), top first.
func _stack(x: float, z: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var excl: Array[RID] = []
	for i in 8:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, 200.0, z), Vector3(x, -40.0, z), 1, excl)
		var h: Dictionary = space.intersect_ray(q)
		if h.is_empty():
			break
		out.append(h)
		excl.append(h["rid"])
	return out


func _make_trials(step: float, headings: int, ollie: bool) -> void:
	var b: Rect2 = level.bounds
	var area: PackedFloat64Array = _env("AREA", "").split_floats(",")
	if area.size() == 4:
		b = Rect2(area[0], area[1], area[2] - area[0], area[3] - area[1])
	var inset: float = Skater.EDGE_MARGIN + 1.5
	var ix: int = 0
	var x: float = b.position.x + inset
	while x <= b.end.x - inset:
		var iz: int = 0
		var z: float = b.position.y + inset
		while z <= b.end.y - inset:
			var p: Vector3 = _start_at(x, z)
			if p.x < 1e8:
				stats["starts"] += 1
				var odd: bool = (ix + iz) % 2 == 1
				for k in headings:
					var a: float = TAU * k / headings + (PI / headings if odd else 0.0)
					trials.append({"p": p, "dir": Vector3(sin(a), 0.0, -cos(a)), "ollie": false})
				if ollie:
					var a2: float = TAU * float((ix * 3 + iz * 5) % 8) / 8.0
					trials.append({"p": p, "dir": Vector3(sin(a2), 0.0, -cos(a2)), "ollie": true})
			z += step
			iz += 1
		x += step
		ix += 1


## A start spot at (x, z): on top of hard, flat ground (not a prop, not a roof), with room for the rider.
func _start_at(x: float, z: float) -> Vector3:
	var none: Vector3 = Vector3(1e9, 0, 0)
	var st: Array[Dictionary] = _stack(x, z)
	if st.is_empty():
		stats["skipped_other"] += 1
		return none
	var top: Dictionary = st[0]
	var col: Node = top["collider"]
	var surf: String = String(col.get_meta("surface", "wall"))
	if surf == "grass":
		stats["skipped_grass"] += 1
		return none
	var n: Vector3 = top["normal"]
	var p: Vector3 = top["position"]
	var bottom: Vector3 = (st[st.size() - 1] as Dictionary)["position"]
	# (not on rails either: a start balanced on a bar tells nothing about the ground)
	if n.y < 0.95 or surf == "wall" or surf == "metal" or String(col.name).contains("Prop_") or p.y - bottom.y > 3.0:
		stats["skipped_other"] += 1
		return none
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = _capsule
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (Skater.CAPSULE_H * 0.5 + 0.08))
	q.collision_mask = 1
	if not space.intersect_shape(q, 1).is_empty():
		stats["skipped_inside"] += 1
		return none
	return p


# ------------------------------------------------------------------ geometry probes

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return space.intersect_ray(q)


## Every surface a ray meets from `from` to `to` (only faces that face the ray: Jolt skips a trimesh's back faces).
func _crossings(from: Vector3, to: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: Vector3 = (to - from).normalized()
	var p: Vector3 = from
	for i in 24:
		var h: Dictionary = _ray(p, to)
		if h.is_empty():
			break
		out.append(h)
		p = (h["position"] as Vector3) + dir * 0.003
		if p.distance_to(to) < 0.004 or (to - p).dot(dir) <= 0.0:
			break
	return out


## Inside a solid: some collider has more up-facing faces above p (entering it from the sky) than down-facing ones
## (leaving it from below). Below a one-sided ground reads as inside too. A one-sided surface overhead (a table top
## modelled as a plane) would as well: check the collider named.
func _inside(p: Vector3) -> Dictionary:
	var top: Vector3 = Vector3(p.x, maxf(p.y + 5.0, 90.0), p.z)
	var entries: Array[Dictionary] = _crossings(top, p)
	if entries.is_empty():
		return {}
	var per: Dictionary = {}
	var first: Dictionary = {}
	for h in entries:
		per[h["collider_id"]] = int(per.get(h["collider_id"], 0)) + 1
		first[h["collider_id"]] = h
	for h in _crossings(p, top):
		per[h["collider_id"]] = int(per.get(h["collider_id"], 0)) - 1
	for id in per:
		if per[id] > 0:
			return first[id]
	return {}


## The surface under a ground position (name, normal, height).
func _floor_at(p: Vector3) -> Dictionary:
	var h: Dictionary = _ray(p + Vector3.UP * 0.3, p + Vector3.DOWN * 0.6)
	if h.is_empty():
		return {"name": "(none)", "n": Vector3.ZERO, "y": p.y - 9.0}
	return {"name": String((h["collider"] as Node).name), "n": h["normal"], "y": (h["position"] as Vector3).y}


## What the board was resting on at p (the capsule can sit on an edge behind its centre): the highest of the
## surfaces under p and under p a capsule radius back.
func _support(p: Vector3, back: Vector3) -> Dictionary:
	var a: Dictionary = _floor_at(p)
	var b: Dictionary = _floor_at(p - back * R)
	return a if float(a["y"]) >= float(b["y"]) else b


## Every visible mesh surface of the level becomes a trimesh on its own layer, named "<mesh>/<material>", so the
## sweep can tell when the rider's body passes through something drawn that has no collider (a house wall, a
## tree trunk, a fence), and when the camera looks at the rider through one.
func _build_visual_layer() -> void:
	var root: Node3D = Node3D.new()
	root.name = "VisualLayer"
	add_child(root)
	var tris: int = 0
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null or String(m.name).begins_with("Far"):
			continue
		var xf: Transform3D = m.global_transform
		for si in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(si)
			var mname: String = mat.resource_name if mat != null else "?"
			var skip: bool = false
			for k in VIS_SKIP:
				if mname.contains(k):
					skip = true
			if skip or m.mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr: Array = m.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var faces: PackedVector3Array = PackedVector3Array()
			if idx.size() > 0:
				faces.resize(idx.size())
				for i in idx.size():
					faces[i] = xf * verts[idx[i]]
			else:
				faces.resize(verts.size())
				for i in verts.size():
					faces[i] = xf * verts[i]
			if faces.size() < 3:
				continue
			var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			shape.backface_collision = true
			var body: StaticBody3D = StaticBody3D.new()
			body.name = ("%s/%s" % [m.name, mname]).validate_node_name()
			body.set_meta("vis", "%s/%s" % [m.name, mname])
			body.collision_layer = VIS_LAYER
			body.collision_mask = 0
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			root.add_child(body)
			_vis_bodies += 1
			tris += faces.size() / 3
	print("[sweep] visual layer: %d mesh surfaces, %d triangles" % [_vis_bodies, tris])


## The rider's body (knee and chest height) crossing a visible surface this tick where no collider is near:
## drawn geometry the rider rides through.
func _vis_pass(prev: Vector3, pos: Vector3) -> Dictionary:
	if _vis_bodies == 0 or prev.distance_to(pos) < 0.001:
		return {}
	for h in [0.45, 0.95, 1.4]:
		var a: Vector3 = prev + Vector3.UP * h
		var b: Vector3 = pos + Vector3.UP * h
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, VIS_LAYER)
		q.hit_back_faces = true
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var hp: Vector3 = hit["position"]
		var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var sph: SphereShape3D = SphereShape3D.new()
		sph.radius = 0.35
		sq.shape = sph
		sq.transform = Transform3D(Basis.IDENTITY, hp)
		sq.collision_mask = 1
		if space.intersect_shape(sq, 1).is_empty():
			return {"name": String((hit["collider"] as Node).get_meta("vis", "?")), "p": hp, "h": h}
	return {}


func _calibrate() -> void:
	# the centres of the bigger wall colliders must read as inside, and a point above the spawn must not
	var tried: int = 0
	var inside: int = 0
	var names: Array[String] = []
	for body in level.collision_root.get_children():
		if not String(body.name).begins_with("Wall_") or tried >= 8:
			continue
		for c in body.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			var a: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
			if a.size.x < 0.8 or a.size.y < 0.8 or a.size.z < 0.8:
				continue
			tried += 1
			if not _inside(a.get_center()).is_empty():
				inside += 1
			else:
				names.append(String(body.name))
			break
	var sp: Vector3 = level.spawn.origin + Vector3.UP * 0.5
	print("[sweep] inside check: %d of %d wall collider centres read inside%s; spawn +0.5 m inside: %s" % [inside, tried,
		(" (not: %s)" % ", ".join(names)) if not names.is_empty() else "", "YES (bad)" if not _inside(sp).is_empty() else "no"])


## What the skater ran into, seen from the capsule's axis along -n: which heights are blocked (horizontal rays
## that hit a steep face). An obstacle standing on the ground is blocked from the bottom up to its top.
func _profile(sk: Skater, n: Vector3) -> Dictionary:
	var d: Vector3 = Vector3(-n.x, 0.0, -n.z)
	if d.length() < 0.05:
		d = Vector3(sk.hdg.x, 0.0, sk.hdg.z)
	d = d.normalized()
	var base: Vector3 = sk.global_position
	var blocked: Array[bool] = []
	var lowest_blocked: float = -1.0
	for h in HEIGHTS:
		var hit: Dictionary = _ray(base + Vector3.UP * h, base + Vector3.UP * h + d * (R + 0.3))
		var b: bool = not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.6
		blocked.append(b)
		if b and lowest_blocked < 0.0:
			lowest_blocked = h
	# an obstacle standing on the ground is blocked from the lowest rays up to its top, clear above
	var on_ground: bool = lowest_blocked >= 0.0 and lowest_blocked <= 0.06
	var top: float = 0.0
	var clear: float = 99.0
	if on_ground:
		var i0: int = HEIGHTS.find(lowest_blocked)
		for i in range(i0, HEIGHTS.size()):
			if blocked[i]:
				top = HEIGHTS[i]
			else:
				clear = HEIGHTS[i]
				break
	return {"on_ground": on_ground, "top": top, "clear": clear, "lowest": lowest_blocked}


func _cols(sk: Skater) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in sk.get_slide_collision_count():
		var c: KinematicCollision3D = sk.get_slide_collision(i)
		var o: Object = c.get_collider()
		var nm: String = String((o as Node).name) if o is Node else "?"
		out.append({"name": nm, "n": c.get_normal(), "p": c.get_position(),
			"surf": String((o as Node).get_meta("surface", "")) if o is Node else ""})
	return out


static func _cols_str(cols: Array) -> String:
	var parts: Array[String] = []
	for c in cols:
		parts.append("%s n=%s" % [c["name"], (c["n"] as Vector3).snappedf(0.01)])
	return "[" + ", ".join(parts) + "]"


# ------------------------------------------------------------------ rides

func _begin(s: Dictionary, tr: Dictionary) -> void:
	if s["sk"] != null:
		(s["sk"] as Node).queue_free()
		(s["cam"] as Node).queue_free()
	var sk: Skater = Skater.new()
	sk.with_visual = false
	sk.scripted = true
	sk.bounds = level.bounds
	add_child(sk)
	var dir: Vector3 = tr["dir"]
	sk.place_at(Transform3D(Basis.looking_at(dir, Vector3.UP), (tr["p"] as Vector3) + Vector3.UP * 0.04))
	sk.inp.world_dir = dir
	sk.inp.move = Vector2(0, -1)
	var cam: ChaseCamera = ChaseCamera.new()
	add_child(cam)
	cam.attach(sk)
	sk.bailed.connect(func(reason: String) -> void: s["bail"] = reason)
	sk.warped.connect(func() -> void: s["warped"] = true)
	s.merge({"sk": sk, "cam": cam, "active": true, "trial": tr, "t": 0.0, "tick": 0, "prev": sk.global_position,
		"anchor": sk.global_position, "anchor_t": 0.0, "bail": "", "warped": false, "prev_state": Skater.State.GROUND,
		"prev_floor_ny": 1.0, "floor": "", "edge": [], "air": {}, "cam_bad": {}, "hidden": 0, "last_ollie": -9.0,
		"flagged": {}, "recent": {}, "slope_t": -9.0, "flat_floor": "?"}, true)
	stats["trials"] += 1
	if tr["ollie"]:
		stats["ollie_trials"] += 1


func _end(s: Dictionary) -> void:
	s["active"] = false
	var sk: Skater = s["sk"]
	sk.process_mode = Node.PROCESS_MODE_DISABLED
	(s["cam"] as Node).process_mode = Node.PROCESS_MODE_DISABLED


func _watch(s: Dictionary, dt: float) -> void:
	var sk: Skater = s["sk"]
	var tr: Dictionary = s["trial"]
	s["t"] += dt
	s["tick"] += 1
	var t: float = s["t"]
	var pos: Vector3 = sk.global_position
	var prev: Vector3 = s["prev"]
	var st: int = sk.state
	var cols: Array[Dictionary] = _cols(sk)
	var base: Dictionary = {"p": prev, "dir": tr["dir"], "t": t, "ollie": tr["ollie"], "start": tr["p"]}
	var hdir: Vector3 = Vector3(sk.velocity.x, 0.0, sk.velocity.z)
	hdir = hdir.normalized() if hdir.length() > 0.1 else Vector3(sk.hdg.x, 0.0, sk.hdg.z).normalized()
	if trace:
		print("[trace] %.3f %s %-6s v=%s |v|=%.2f floor_n=%s vert=%s surf=%s %s cam=%s" % [t, _fmt(pos),
			["GROUND", "AIR", "GRIND", "BAIL"][st], sk.velocity.snappedf(0.01), sk.velocity.length(), sk.floor_n.snappedf(0.01),
			sk.floor_vert, sk.surface, _cols_str(cols), (s["cam"] as Node3D).global_position.snappedf(0.01)])
		if st == Skater.State.AIR:
			var hh: Vector3 = sk.heading_h()
			print("[trace]       air: heading %.0f deg, vert_air %s, vert_out %s, air_time %.2f" % [
				fposmod(rad_to_deg(atan2(hh.x, -hh.z)), 360.0), sk.vert_air, sk.vert_out.snappedf(0.01), sk.air_time])

	if s["warped"]:
		if prev.y < -7.0:
			_add("fell_out_of_level", s["floor"], 3, base, "fell below y = -8 (warped back)")
		else:
			stats["edge_warps"] += 1
		_end(s)
		return

	# teleports and snaps
	var dp: Vector3 = pos - prev
	if dp.length() > JUMP:
		_add("position_jump", _name_of(cols, s["floor"]), 3, _with(base, {"jump": dp.length(), "state": st}),
			"moved %.2f m in one tick (%s)" % [dp.length(), _cols_str(cols)])
	elif absf(dp.y) > VSNAP and st != Skater.State.AIR and s["prev_state"] != Skater.State.AIR:
		var sup: Dictionary = _support(prev, hdir)
		var now: Dictionary = _floor_at(pos)
		_add("vertical_snap", sup["name"], 2, _with(base, {"dy": dp.y}),
			"dropped %.2f m in one tick on the ground, off %s onto %s at %.1f m/s" % [-dp.y, sup["name"], now["name"],
			Vector2(sk.velocity.x, sk.velocity.z).length()])
	stats["dist"] += Vector2(dp.x, dp.z).length()
	if not s["flagged"].has("vis") and st != Skater.State.BAIL:
		var vp: Dictionary = _vis_pass(prev, pos)
		if not vp.is_empty():
			s["flagged"]["vis"] = true
			_add("rides_through_visible_geometry", vp["name"], 2, _with(base, {"p": vp["p"]}),
				"the rider's body (%.2f m up) passes through a drawn surface at %s with no collider within 0.35 m" % [vp["h"],
				(vp["p"] as Vector3).snappedf(0.01)])

	# below the world / inside geometry / a wall taken for the floor
	if pos.y < -1.0 and not s["flagged"].has("low"):
		s["flagged"]["low"] = true
		_add("below_y_minus_1", s["floor"], 3, _with(base, {"p": pos}), "skater origin below y = -1")
	if s["tick"] % 4 == 0 and st != Skater.State.BAIL and not s["flagged"].has("inside"):
		var ins: Dictionary = _inside(pos + Vector3.UP * 0.12)
		if not ins.is_empty():
			s["flagged"]["inside"] = true
			_add("skater_inside_collider", String((ins["collider"] as Node).name), 3, _with(base, {"p": pos, "state": st}),
				"wheels (0.12 m up) inside a closed collider or under a one-sided surface, state %d" % st)
	if st == Skater.State.GROUND and sk.floor_n.y < 0.3 and not sk.floor_vert and not s["flagged"].has("wallfloor"):
		s["flagged"]["wallfloor"] = true
		_add("edge_rollover", s["flat_floor"], 2, _with(base, {"p": pos}),
			"still on the ground with floor_n %s (the round capsule rolled over the edge of %s and the floor normal followed it down), %.1f m/s, contacts %s" % [
			sk.floor_n.snappedf(0.01), s["flat_floor"], sk.velocity.length(), _cols_str(cols)])

	if st == Skater.State.GROUND:
		s["floor"] = _floor_at(pos)["name"]
		if sk.floor_n.y < 0.985:
			s["slope_t"] = t
		elif sk.floor_n.y > 0.995:
			s["flat_floor"] = _support(pos, hdir)["name"]
	for c in cols:
		var ny0: float = (c["n"] as Vector3).y
		if ny0 < 0.9 and ny0 > -0.3:
			s["recent"] = _with(c, {"t": t, "ch": (c["p"] as Vector3).y - pos.y})

	# bails
	if st == Skater.State.BAIL and s["bail"] != "":
		_on_bail(s, cols, base)
		_end(s)
		return

	# air: take-off, flight, landing
	var air: Dictionary = s["air"]
	if st == Skater.State.AIR and s["prev_state"] != Skater.State.AIR:
		var edge: Array = []
		for c in cols:
			if (c["n"] as Vector3).y < 0.9:
				edge.append("%s ny=%.2f" % [c["name"], (c["n"] as Vector3).y])
		air = {"from": prev, "vy0": sk.velocity.y, "vy": sk.velocity.y, "floor_ny": s["prev_floor_ny"],
			"floor": _support(prev, hdir)["name"], "apex": pos.y, "t0": t, "edge": edge + s["edge"],
			"popped": sk._air_popped or t - float(s["last_ollie"]) < 0.3, "vert": sk.vert_air, "hit": false,
			"settled": t - float(s.get("land_t", -9.0)) > 0.4 and not s["flagged"].has("wallfloor")}
		s["air"] = air
	if st == Skater.State.AIR and not air.is_empty():
		air["apex"] = maxf(air["apex"], pos.y)
		air["vy"] = maxf(air["vy"], sk.velocity.y)
		air["popped"] = air["popped"] or sk._air_popped or float(s["last_ollie"]) > float(air["t0"]) - 0.3
		air["vert"] = air["vert"] or sk.vert_air
		air["hit"] = air["hit"] or not cols.is_empty()
		if t - float(air["t0"]) > 3.0 and not s["flagged"].has("longair"):
			s["flagged"]["longair"] = true
			_add("long_air", air["floor"], 2, _with(base, {"p": pos}), "in the air for over 3 s (wedged or falling far)")
	if st == Skater.State.GROUND and s["prev_state"] == Skater.State.AIR and not air.is_empty():
		s["land_t"] = t
		_on_land(air, pos, t, base)
		s["air"] = {}

	# stuck: pushing without getting anywhere
	if pos.distance_to(s["anchor"]) > STUCK_RADIUS:
		s["anchor"] = pos
		s["anchor_t"] = t
	elif t - float(s["anchor_t"]) > STUCK_TIME:
		_on_stuck(s, cols, base)
		_end(s)
		return

	# camera
	if s["tick"] % CAM_EVERY == 0 and s["tick"] > 12:
		_check_cam(s, base)

	if air_release:
		var free: bool = st == Skater.State.AIR
		sk.inp.world_dir = Vector3.ZERO if free else (tr["dir"] as Vector3)
		sk.inp.move = Vector2.ZERO if free else Vector2(0, -1)
	# ollie rides: pop every 1.2 s
	if tr["ollie"]:
		var k: int = int(t / 1.2)
		if k >= 1 and k != int((t - dt) / 1.2):
			sk.inp.ollie_pressed = true
			sk.inp.ollie_held = true
			s["last_ollie"] = t
		else:
			if sk.inp.ollie_held:
				sk.inp.ollie_released = true
			sk.inp.ollie_held = false

	var edge_now: Array = []
	for c in cols:
		var ny2: float = (c["n"] as Vector3).y
		if ny2 < 0.9 and ny2 > -0.2:
			edge_now.append("%s ny=%.2f" % [c["name"], ny2])
	s["edge"] = edge_now
	s["prev"] = pos
	s["prev_state"] = st
	s["prev_floor_ny"] = sk.floor_n.y if st == Skater.State.GROUND else 0.0
	if t >= trial_time:
		_end(s)


func _with(a: Dictionary, b: Dictionary) -> Dictionary:
	var o: Dictionary = a.duplicate()
	o.merge(b, true)
	return o


func _name_of(cols: Array[Dictionary], fallback: String) -> String:
	for c in cols:
		if absf((c["n"] as Vector3).y) < 0.9:
			return c["name"]
	return cols[0]["name"] if not cols.is_empty() else fallback


## The steep contact the body ran into (the one facing most against the way it was going).
func _wall_contact(cols: Array, v: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var score: float = 0.0
	for c in cols:
		var n: Vector3 = c["n"]
		if n.y > 0.9:
			continue
		var sc: float = -Vector3(v.x, 0.0, v.z).normalized().dot(Vector3(n.x, 0.0, n.z)) + 0.001
		if best.is_empty() or sc > score:
			best = c
			score = sc
	return best


func _obstacle_note(pr: Dictionary, c: Dictionary, sk: Skater) -> String:
	var ch: float = (c["p"] as Vector3).y - sk.global_position.y
	if pr["on_ground"]:
		return "obstacle %.2f-%.2f m high (contact %.2f m up, n=%s)" % [pr["top"], pr["clear"], ch, (c["n"] as Vector3).snappedf(0.01)]
	if pr["lowest"] >= 0.0:
		return "raised obstacle from %.2f m up (contact %.2f m up, n=%s)" % [pr["lowest"], ch, (c["n"] as Vector3).snappedf(0.01)]
	return "thin or angled obstacle, no face on the probe rays (contact %.2f m up, n=%s)" % [ch, (c["n"] as Vector3).snappedf(0.01)]


## Sorts what the body ran into: a lip that should roll, a low step (ollie it), a prop or skate feature, a wall.
func _classify_hit(prefix: String, sk: Skater, c: Dictionary, info: Dictionary, extra: String) -> void:
	var pr: Dictionary = _profile(sk, c["n"])
	var note: String = _obstacle_note(pr, c, sk) + extra
	info["n"] = c["n"]
	var ch: float = (c["p"] as Vector3).y - sk.global_position.y
	# the body hit something well above the low obstacle the probe rays found (a handrail over a ramp's thin edge,
	# a table top over a curb): that is what stopped it, not the lip
	if pr["on_ground"] and ch > float(pr["top"]) + 0.2:
		pr = {"on_ground": false, "top": 0.0, "clear": 99.0, "lowest": ch}
		note = _obstacle_note(pr, c, sk) + extra
	if pr["on_ground"] and float(pr["top"]) <= TINY_LIP:
		_add(prefix + "_tiny_lip", c["name"], 3, info, note)
	elif pr["on_ground"] and float(pr["top"]) < LOW_LIP:
		_add(prefix + "_low_step", c["name"], 1, info, note)
	elif not pr["on_ground"] and pr["lowest"] < 0.0 and ch < TINY_LIP:
		_add(prefix + "_low_edge", c["name"], 2, info, note)
	elif String(c["name"]).contains("Prop_") or c["surf"] != "wall":
		_add(prefix + "_prop_or_feature", c["name"], 0, info, note)
	else:
		_add(prefix + "_wall", c["name"], 0, info, note)


func _on_bail(s: Dictionary, cols: Array[Dictionary], base: Dictionary) -> void:
	var sk: Skater = s["sk"]
	var reason: String = s["bail"]
	stats["bails"][reason] = int(stats["bails"].get(reason, 0)) + 1
	var info: Dictionary = _with(base, {"p": sk.global_position, "speed": sk.bail_velocity.length()})
	if reason == "crash":
		var c: Dictionary = _wall_contact(cols, sk.bail_velocity)
		if c.is_empty():
			_add("bail_crash_unknown", s["floor"], 2, info, "wall-crash bail with no steep contact")
			return
		_classify_hit("bail_on", sk, c, info, ", %.1f m/s" % sk.bail_velocity.length())
	elif reason == "sideways":
		var air: Dictionary = s["air"]
		var planned: bool = not air.is_empty() and bool(air["popped"])
		var flat: bool = float(air.get("floor_ny", 0.0)) > 0.97
		var rise: float = float(air.get("apex", 0.0)) - (air.get("from", Vector3.ZERO) as Vector3).y
		var note2: String = "landing bail after %s: took off from %s (floor ny %.2f, vert lock %s, contacts %s), rose %.2f m, %.2f s air, landed on %s" % [
			"an ollie" if planned else "unplanned air", air.get("floor", "?"), float(air.get("floor_ny", 0.0)), air.get("vert", false),
			str(air.get("edge", [])), rise, float(base["t"]) - float(air.get("t0", 0.0)), _floor_at(sk.global_position)["name"]]
		var kind: String = "bail_landing_after_ollie"
		var sev: int = 0
		if planned and flat and bool(air.get("settled", false)) and not bool(air.get("hit", true)) \
				and _floor_at(sk.global_position)["n"].y > 0.97:
			kind = "bail_after_clean_flat_ollie"
			sev = 3
		elif not planned and flat:
			kind = "bail_landing_after_flat_launch"
			sev = 3
		elif not planned:
			kind = "bail_landing_after_ramp_air"
			sev = 1
		_add(kind, String(air.get("floor", "?")), sev, info, note2)
	else:
		_add("bail_" + reason, s["floor"], 2, info, "bail: " + reason)


func _on_land(air: Dictionary, pos: Vector3, t: float, base: Dictionary) -> void:
	var from: Vector3 = air["from"]
	var dy: float = pos.y - from.y
	var rise: float = float(air["apex"]) - from.y
	var at: float = t - float(air["t0"])
	var flat: bool = float(air["floor_ny"]) > 0.97
	if air["popped"] or not flat:
		return
	var info: Dictionary = _with(base, {"p": from, "land": pos, "rise": rise, "dy": dy, "air_t": at, "vy": air["vy"]})
	var ea: Array = air["edge"]
	var edge: String = str(ea) if not ea.is_empty() else "none"
	var who: String = air["floor"]
	if not ea.is_empty():
		who = String(ea[0]).split(" ")[0]
	if rise > 0.12 or float(air["vy"]) > 2.0:
		_add("launch_off_flat", who, 3 if rise > 0.3 else 2, info,
			"unplanned take-off from flat %s: rose %.2f m, vy %.1f m/s, %.2f s air, contacts %s" % [air["floor"], rise, air["vy"], at, edge])
	elif absf(dy) < 0.05 and at >= 0.08:
		stats["flat_air"] += at
		stats["flat_air_events"] += 1
		_add("hop_on_flat", who, 1 if at < 0.2 else 2, info,
			"left flat %s for %.2f s and came down at the same height (dy %.2f), contacts %s" % [air["floor"], at, dy, edge])
	elif dy < -0.05 and dy > -0.12 and at >= 0.1:
		_add("air_off_tiny_drop", who, 1, info, "a %.2f m drop gave %.2f s of air" % [-dy, at])


func _on_stuck(s: Dictionary, cols: Array[Dictionary], base: Dictionary) -> void:
	var sk: Skater = s["sk"]
	var t: float = s["t"]
	stats["stuck"] += 1
	var info: Dictionary = _with(base, {"p": sk.global_position, "state": sk.state, "floor_ny": sk.floor_n.y})
	var recent: Dictionary = s["recent"]
	var rc: String = "last steep contact %s n=%s %.1f s ago" % [recent["name"], (recent["n"] as Vector3).snappedf(0.01),
		t - float(recent["t"])] if not recent.is_empty() else "no steep contact"
	if sk.state == Skater.State.AIR:
		var bounce: bool = bool(base["ollie"]) and (sk.vert_air or t - float(s["last_ollie"]) < 1.3)
		_add("ollie_bounce_on_ramp" if bounce else "stuck_in_air", recent.get("name", s["floor"]), 0 if bounce else 3, info, "held in the AIR state %.1f s without moving, on %s; contacts %s; %s" % [
			STUCK_TIME, _floor_at(sk.global_position)["name"], _cols_str(cols), rc])
		return
	var c: Dictionary = _wall_contact(cols, sk.inp.world_dir)
	if c.is_empty() and not recent.is_empty() and t - float(recent["t"]) < 0.6:
		c = recent
	if t - float(s["slope_t"]) < STUCK_TIME:
		_add("stalled_on_ramp", s["floor"], 0, info, "pushing into a slope it can't climb (floor ny %.2f); %s" % [sk.floor_n.y, rc])
		return
	if c.is_empty():
		_add("stuck_no_obstacle", s["floor"], 3, info, "not moving on flat ground with nothing in front (surface %s, speed %.2f); %s" % [
			sk.surface, sk.velocity.length(), rc])
		return
	_classify_hit("stuck_on", sk, c, info, ", surface %s, speed %.2f" % [sk.surface, sk.velocity.length()])


func _check_cam(s: Dictionary, base: Dictionary) -> void:
	var cam: ChaseCamera = s["cam"]
	var sk: Skater = s["sk"]
	stats["cam_checks"] += 1
	var cp: Vector3 = cam.global_position
	var bad: Dictionary = s["cam_bad"]
	var ins: Dictionary = _inside(cp)
	if not ins.is_empty():
		bad["inside"] = int(bad.get("inside", 0)) + 1
		if bad["inside"] == 2:            # on two checks in a row (3+ frames): not a one-frame graze
			_add("camera_inside_collider", String((ins["collider"] as Node).name), 3, _with(base, {"p": sk.global_position, "cam": cp}),
				"camera eye at %s inside a closed collider (rider state %d)" % [cp.snappedf(0.01), sk.state])
		return
	bad["inside"] = 0
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = _eye
	q.transform = Transform3D(Basis.IDENTITY, cp)
	q.collision_mask = 1
	var hits: Array[Dictionary] = space.intersect_shape(q, 1)
	if not hits.is_empty():
		bad["clip"] = int(bad.get("clip", 0)) + 1
		if bad["clip"] == 3:
			_add("camera_near_clip", String((hits[0]["collider"] as Node).name), 1, _with(base, {"p": sk.global_position, "cam": cp}),
				"geometry within %.2f m of the camera eye at %s for 9+ frames (the near plane cuts it)" % [CAM_CLIP, cp.snappedf(0.01)])
	else:
		bad["clip"] = 0
	# does something drawn (with no collider, so the camera does not avoid it) stand between camera and rider?
	var chest0: Vector3 = sk.global_position + Vector3.UP * 1.0
	var vq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cp, chest0, VIS_LAYER)
	var vh: Dictionary = space.intersect_ray(vq) if _vis_bodies > 0 else {}
	if not vh.is_empty() and _ray(cp, chest0).is_empty() and sk.state != Skater.State.BAIL:
		s["vis_hidden"] = int(s.get("vis_hidden", 0)) + 1
		if s["vis_hidden"] == 10:
			_add("camera_behind_drawn_geometry", String((vh["collider"] as Node).get_meta("vis", "?")), 1,
				_with(base, {"p": sk.global_position, "cam": cp}),
				"a drawn surface with no collider hides the rider from the camera at %s for 30+ frames" % cp.snappedf(0.01))
	else:
		s["vis_hidden"] = 0
	# can the camera see the rider's chest?
	var chest: Vector3 = sk.global_position + Vector3.UP * 1.0
	var h: Dictionary = _ray(cp, chest)
	if not h.is_empty() and sk.state != Skater.State.BAIL:
		s["hidden"] += 1
		if s["hidden"] == 10:
			_add("camera_view_blocked", String((h["collider"] as Node).name), 1, _with(base, {"p": sk.global_position, "cam": cp}),
				"rider's chest hidden from the camera at %s for 30+ frames" % cp.snappedf(0.01))
	else:
		s["hidden"] = 0


# ------------------------------------------------------------------ findings

func _add(kind: String, collider: String, sev: int, info: Dictionary, note: String) -> void:
	var key: String = kind + "|" + collider
	if not findings.has(key):
		findings[key] = {"kind": kind, "collider": collider, "sev": sev, "count": 0, "spots": []}
	var f: Dictionary = findings[key]
	f["count"] += 1
	f["sev"] = maxi(f["sev"], sev)
	var p: Vector3 = info["p"]
	# group events at the same spot (within 1.5 m) so a finding lists its distinct places
	var spot: Dictionary = {}
	for sp in f["spots"]:
		if (sp["p"] as Vector3).distance_to(p) < 1.5:
			spot = sp
			break
	if spot.is_empty():
		spot = {"p": p, "count": 0, "note": note, "info": info}
		f["spots"].append(spot)
	spot["count"] += 1
	if verbose:
		print("[sweep]   %-6s %-24s %-32s %s  %s" % [SEVERITY[sev], kind, collider, _fmt(p), note])


static func _fmt(p: Vector3) -> String:
	return "godot (%.1f, %.2f, %.1f) blender (%.1f, %.1f, %.2f)" % [p.x, p.y, p.z, p.x, -p.z, p.y]


func _report(secs: float) -> void:
	var list: Array = findings.values()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["sev"] > b["sev"] if a["sev"] != b["sev"] else a["count"] > b["count"])
	var serious: int = 0
	print("[sweep] ===== %s: %d rides (%d with ollies), %.0f m ridden, %d edge warps, %d stuck, bails %s, flat-ground air %.1f s in %d hops, %.0f s" % [
		lv, stats["trials"], stats["ollie_trials"], stats["dist"], stats["edge_warps"], stats["stuck"], str(stats["bails"]),
		stats["flat_air"], stats["flat_air_events"], secs])
	for f in list:
		if f["sev"] >= 3:
			serious += 1
		var spots: Array = f["spots"]
		spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["count"] > b["count"])
		print("[sweep] %-6s %-30s %-34s x%d at %d spot(s)" % [SEVERITY[f["sev"]].to_upper(), f["kind"], f["collider"], f["count"], spots.size()])
		for i in mini(spots.size(), 5):
			var sp: Dictionary = spots[i]
			var inf: Dictionary = sp["info"]
			var d: Vector3 = inf["dir"]
			var st: Vector3 = inf["start"]
			print("[sweep]          x%d %s heading %.0f deg%s from (%.1f, %.1f): %s" % [sp["count"], _fmt(sp["p"]),
				fposmod(rad_to_deg(atan2(d.x, -d.z)), 360.0), " ollie" if inf["ollie"] else "", st.x, st.z, sp["note"]])
	var out: String = _env("OUT", "")
	if out != "":
		var js: Array = []
		for f in list:
			var spots2: Array = []
			for sp in f["spots"]:
				var p: Vector3 = sp["p"]
				var inf2: Dictionary = sp["info"]
				var d2: Vector3 = inf2["dir"]
				var st2: Vector3 = inf2["start"]
				spots2.append({"count": sp["count"], "godot": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
					"blender": [snappedf(p.x, 0.01), snappedf(-p.z, 0.01), snappedf(p.y, 0.01)], "note": sp["note"],
					"heading_deg": snappedf(fposmod(rad_to_deg(atan2(d2.x, -d2.z)), 360.0), 0.1),
					"start": [snappedf(st2.x, 0.01), snappedf(st2.z, 0.01)], "ollie": inf2["ollie"]})
			js.append({"kind": f["kind"], "collider": f["collider"], "severity": SEVERITY[f["sev"]], "count": f["count"], "spots": spots2})
		var fa: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		if fa != null:
			fa.store_string(JSON.stringify({"level": lv, "stats": stats, "findings": js}, " "))
			fa.close()
	print("[sweep] %s: %d serious finding(s)" % [lv, serious])
	get_tree().quit(serious)
