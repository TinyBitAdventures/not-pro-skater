class_name Level
extends Node3D
## Loads a Blender-built level glTF and makes it playable: collision bodies tagged with surface types, grind
## lines (the Rail_ curves in <level>.rails.json), event and start markers, and the look: "real" (PBR materials
## lit by the baked <level>.lightmap.*.png, see RealLook) or "grey" (greybox grid materials, see GreyLook).

const SURFACES: Dictionary = {
	"Grass": "grass", "Path": "asphalt", "Plaza": "concrete", "Concrete": "concrete", "Wood": "wood",
	"Metal": "metal", "Wall": "wall",
}

var spawn: Transform3D = Transform3D.IDENTITY
var grind_lines: Array[GrindLine] = []
var markers: Dictionary = {}             # Event_<name> markers (goals, props, NPCs): name -> Transform3D
var starts: Dictionary = {}              # Start_<name> markers (warp spots): name -> Transform3D
var collision_root: Node3D
var stats: Dictionary = {}
var lightmap_info: Dictionary = {}
var bounds: Rect2 = Rect2()              # the rideable ground seen from above (Godot x, z): skaters warp back before its edge
var grass: GrassField       # the bake's info (<level>.lightmap.json): sun direction, energies, groups


func load_glb(path: String, look: String = "real") -> void:
	var t0: int = Time.get_ticks_msec()
	var packed: PackedScene = load(path)
	var scene: Node3D = packed.instantiate()
	add_child(scene)
	collision_root = Node3D.new()
	collision_root.name = "Collision"
	add_child(collision_root)

	var bodies: Array[StaticBody3D] = []
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is StaticBody3D:
			bodies.append(n as StaticBody3D)
		elif n is Node3D and not (n is MeshInstance3D):
			var nm: String = String(n.name)
			if nm.begins_with("Event_"):
				markers[nm.trim_prefix("Event_")] = (n as Node3D).global_transform
			elif nm.begins_with("Start_"):
				starts[nm.trim_prefix("Start_")] = (n as Node3D).global_transform
			elif nm.begins_with("Spawn_Player"):
				spawn = (n as Node3D).global_transform

	for b in bodies:
		var sname: String = _surface_of(b)
		b.reparent(collision_root, true)
		b.set_meta("surface", sname)
		b.set_meta("vert", _is_transition(b))
		b.collision_layer = 1
		b.collision_mask = 0

	bounds = _ground_bounds(bodies)
	_load_rails(path.get_basename() + ".rails.json")
	link_rails()

	if look == "grey":
		GreyLook.apply(scene)
	else:
		var base: String = path.get_basename()
		if FileAccess.file_exists(base + ".lightmap.json"):
			lightmap_info = JSON.parse_string(FileAccess.get_file_as_string(base + ".lightmap.json"))
		if FileAccess.file_exists(base + ".look.json"):      # surface dressing: expansion joints and the like
			lightmap_info["look"] = JSON.parse_string(FileAccess.get_file_as_string(base + ".look.json"))
		var maps: Dictionary = {}
		if ResourceLoader.exists(base + ".lightmap.png"):
			maps[""] = load(base + ".lightmap.png")
		for g in lightmap_info.get("groups", []):
			var gp: String = "%s.lightmap.%s.png" % [base, g]
			if ResourceLoader.exists(gp):
				maps[String(g)] = load(gp)
		RealLook.apply(scene, maps, lightmap_info)
		_instance_repeats(scene)
		grass = GrassField.new()                      # clumps of grass on the lawns near the rider
		add_child(grass)
		add_child(Birds.new())                         # a few flocks wheeling overhead
	stats = {"bodies": bodies.size(), "grind": grind_lines.size(), "ms": Time.get_ticks_msec() - t0}
	print_verbose("[level] %s: %d bodies, %d grind lines, %d ms" % [path.get_file(), stats["bodies"], stats["grind"], stats["ms"]])


## The extent of the ground (lawn, paths, concrete) from the collision shapes. Past it there is only scenery.
func _ground_bounds(bodies: Array[StaticBody3D]) -> Rect2:
	var box: AABB = AABB()
	var first: bool = true
	for b in bodies:
		if not ["grass", "asphalt", "concrete"].has(String(b.get_meta("surface"))):
			continue
		for c in b.get_children():
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			var a: AABB = cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
			box = a if first else box.merge(a)
			first = false
	return Rect2() if first else Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


## Rails authored as Blender curves (blender/lib.py rail()) arrive as a JSON sidecar next to the glb.
func _load_rails(json_path: String) -> void:
	if not FileAccess.file_exists(json_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("bad rails file " + json_path)
		return
	for r in (data as Dictionary).get("rails", []):
		var pts: PackedVector3Array = PackedVector3Array()
		for p in r["points"]:
			pts.append(Vector3(p[0], p[1], p[2]))
		if pts.size() >= 2:
			grind_lines.append(GrindLine.new(String(r["id"]), pts, String(r.get("kind", ""))))


const LINK_GAP: float = 0.35
const LINK_ANGLE: float = 0.61      # 35 degrees

## Rails whose ends meet (a kinked handrail drawn in pieces, a ledge corner) carry a grind across the joint.
func link_rails() -> void:
	for a in grind_lines:
		a.links.clear()
	for a in grind_lines:
		for end_a in ["start", "end"]:
			var pa: Vector3 = a.point_at(0.0 if end_a == "start" else a.length)
			var out_a: Vector3 = -a.dir_at(0.0) if end_a == "start" else a.dir_at(a.length)
			for b in grind_lines:
				if b == a:
					continue
				for end_b in ["start", "end"]:
					var pb: Vector3 = b.point_at(0.0 if end_b == "start" else b.length)
					if pa.distance_to(pb) > LINK_GAP:
						continue
					var into_b: Vector3 = b.dir_at(0.0) if end_b == "start" else -b.dir_at(b.length)
					if out_a.angle_to(into_b) <= LINK_ANGLE:
						a.links[end_a] = [b, end_b == "start"]


## A quarter pipe, half pipe or vert wall: its riding surface curves up past VERT_TAG_ANGLE. Kickers, hips,
## banks and pyramids stay shallower (a kicker tops out around 35 degrees), so they still launch you.
const VERT_TAG_ANGLE: float = 57.0

static func _is_transition(b: StaticBody3D) -> bool:
	var limit: float = cos(deg_to_rad(VERT_TAG_ANGLE))
	for c in b.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or not (cs.shape is ConcavePolygonShape3D):
			continue
		var basis: Basis = cs.global_transform.basis
		var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
		for i in range(0, faces.size(), 3):
			var n: Vector3 = (basis * (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])).normalized()
			var ny: float = absf(n.y)
			if ny > 0.05 and ny < limit:          # a sloped face (not a floor, not a wall) steeper than the limit
				return true
	return false


func _surface_of(b: Node) -> String:
	var n: Node = b
	while n != null and n != self:
		var head: String = String(n.name).split("_")[0]
		if SURFACES.has(head):
			return SURFACES[head]
		n = n.get_parent()
	return "wall"


## Props placed more than once share one mesh in the glb: draw all copies of each as a single MultiMesh (one
## draw call per material for every street lamp in the park, instead of one per lamp).
func _instance_repeats(scene: Node3D) -> void:
	var by_mesh: Dictionary = {}
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null or _has_override(m) or m.skeleton != NodePath(""):
			continue
		if not by_mesh.has(m.mesh):
			by_mesh[m.mesh] = []
		by_mesh[m.mesh].append(m)
	for mesh in by_mesh:
		var copies: Array = by_mesh[mesh]
		if copies.size() < 2:
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = copies.size()
		for i in copies.size():
			mm.set_instance_transform(i, global_transform.affine_inverse() * (copies[i] as MeshInstance3D).global_transform)
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "Repeat_" + String((copies[0] as Node).name).rstrip("0123456789._")
		mmi.multimesh = mm
		if String(mmi.name).begins_with("Repeat_FarTree"):
			# spread over the whole map: its bounds would put every copy in every shadow pass (and they stand far
			# past the shadows' range anyway)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		for c in copies:
			(c as Node).queue_free()


static func _has_override(m: MeshInstance3D) -> bool:
	for s in m.get_surface_override_material_count():
		if m.get_surface_override_material(s) != null:
			return true
	return false

