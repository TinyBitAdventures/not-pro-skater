class_name Level
extends Node3D
## Loads a Blender-built level glTF and turns it into a playable, toon-shaded world:
## batched visuals, collision bodies tagged with surface types, grind lines, spawn and pickup markers.

const SURFACES: Dictionary = {
	"Grass": "grass", "Path": "asphalt", "Plaza": "concrete", "Concrete": "concrete", "Wood": "wood",
	"Metal": "metal", "Wall": "wall",
}

var spawn: Transform3D = Transform3D.IDENTITY
var grind_lines: Array[GrindLine] = []
var pickups: Array[Dictionary] = []
var collision_root: Node3D
var stats: Dictionary = {}


func load_glb(path: String) -> void:
	var t0: int = Time.get_ticks_msec()
	var packed: PackedScene = load(path)
	var scene: Node3D = packed.instantiate()
	add_child(scene)
	collision_root = Node3D.new()
	collision_root.name = "Collision"
	add_child(collision_root)

	var grind_pts: Dictionary = {}
	var texts: Array[Node3D] = []
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
			if nm.begins_with("Grind_"):
				var parts: PackedStringArray = nm.rsplit("_", true, 1)
				var gid: String = parts[0]
				if not grind_pts.has(gid):
					grind_pts[gid] = []
				grind_pts[gid].append([parts[1].to_int(), (n as Node3D).global_position])
			elif nm.begins_with("Spawn_Player"):
				spawn = (n as Node3D).global_transform
			elif nm.begins_with("Pickup_"):
				var bits: PackedStringArray = nm.split("_")
				pickups.append({"name": bits[1], "pos": (n as Node3D).global_position})
			elif nm.begins_with("Text_"):
				texts.append(n as Node3D)

	for b in bodies:
		var sname: String = _surface_of(b)
		b.reparent(collision_root, true)
		b.set_meta("surface", sname)
		b.collision_layer = 1
		b.collision_mask = 0

	for gid in grind_pts:
		var lst: Array = grind_pts[gid]
		lst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var pts: PackedVector3Array = PackedVector3Array()
		for e in lst:
			pts.append(e[1])
		if pts.size() >= 2:
			grind_lines.append(GrindLine.new(gid, pts))

	for t in texts:
		_make_label(t)

	var baked: Node3D = LevelBaker.bake(scene)
	add_child(baked)
	scene.queue_free()
	stats = {"bodies": bodies.size(), "grind": grind_lines.size(), "meshes": baked.get_child_count(),
		"ms": Time.get_ticks_msec() - t0}


func _surface_of(b: Node) -> String:
	var n: Node = b
	while n != null and n != self:
		var head: String = String(n.name).split("_")[0]
		if SURFACES.has(head):
			return SURFACES[head]
		n = n.get_parent()
	return "wall"


func _make_label(marker: Node3D) -> void:
	var words: PackedStringArray = String(marker.name).split("_")
	var text: String = " ".join(words.slice(1, words.size() - 1))
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.0068
	l.modulate = Color(1, 1, 1)
	l.outline_size = 14
	l.outline_modulate = Color(0.09, 0.11, 0.19)
	l.double_sided = true
	l.shaded = false
	l.no_depth_test = false
	add_child(l)
	l.global_transform = marker.global_transform
	l.rotate_object_local(Vector3.UP, PI)
	l.position += l.global_transform.basis.z * 0.0
