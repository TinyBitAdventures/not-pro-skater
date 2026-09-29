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
var _labels: Array[Label3D] = []
var duck_marks: Array[Transform3D] = []
var car_routes: Dictionary = {}          # route letter -> Array[Vector3] (ordered closed loop at road height)
var swings: Array[Node3D] = []
var dynamic_root: Node3D
var _crowd_marks: Array[Dictionary] = []


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
			elif nm.begins_with("SpectatorSit_") or nm.begins_with("Spectator_"):
				var sb: PackedStringArray = nm.split("_")
				_crowd_marks.append({"xf": (n as Node3D).global_transform, "variant": sb[1].to_int(), "n": sb[2].to_int(),
					"sit": nm.begins_with("SpectatorSit_")})
			elif nm.begins_with("Duck_"):
				duck_marks.append((n as Node3D).global_transform)
			elif nm.begins_with("CarRoute_"):
				var cb: PackedStringArray = nm.split("_")
				if not car_routes.has(cb[1]):
					car_routes[cb[1]] = []
				car_routes[cb[1]].append([cb[2].to_int(), (n as Node3D).global_position])
			elif nm.begins_with("Swing_") and n.get_child_count() > 0:
				swings.append(n as Node3D)

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

	# things that move stay live nodes (swings); the crowd is baked and hops in the shader
	dynamic_root = Node3D.new()
	dynamic_root.name = "Dynamic"
	add_child(dynamic_root)
	for sw in swings:
		sw.reparent(dynamic_root, true)
	Toon.skin(dynamic_root, {}, true)
	for r in car_routes:
		var lst: Array = car_routes[r]
		lst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var pts: Array[Vector3] = []
		for e in lst:
			pts.append(e[1])
		car_routes[r] = pts
	_build_crowd(scene)

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
	var front_dir: Vector3 = -marker.global_transform.basis.z
	for side in 2:
		var l: Label3D = Label3D.new()
		l.text = text
		l.font_size = 96
		l.pixel_size = 0.0068
		l.modulate = Color(1, 1, 1)
		l.outline_size = 14
		l.outline_modulate = Color(0.09, 0.11, 0.19)
		l.double_sided = false
		l.shaded = false
		add_child(l)
		_labels.append(l)
		l.global_transform = marker.global_transform
		if side == 0:
			l.rotate_object_local(Vector3.UP, PI)
		else:
			l.global_position -= front_dir * 0.09


## Label3D text is not a Toon material, so the see-through hole in occlude.gdshaderinc cannot reach it: a sign
## board would dither away while its lettering stayed solid over the skater. Fade the text with the same maths.
func _process(_delta: float) -> void:
	if _labels.is_empty():
		return
	var pp: Vector3 = Toon.player_pos
	var vd: Vector3 = Toon.view_dir
	var chest: Vector3 = pp + Vector3(0.0, 0.9, 0.0)
	for l in _labels:
		var u: Vector3 = l.global_position - chest
		var along: float = u.dot(vd)
		var dist: float = (u - vd * along).length()
		var in_front: float = 1.0 - smoothstep(-1.6, -0.4, along)
		var hole: float = (1.0 - smoothstep(1.4, 3.0, dist)) * in_front   # labels are ~4 m wide: wider than the toon hole
		l.modulate.a = 1.0 - hole


const SPECTATOR: PackedScene = preload("res://assets/models/spectator.glb")


## Instance a posed, tinted person on every crowd marker. They join the level bake (a few draws in total)
## and hop in the vertex shader; see LevelBaker's crowd path.
func _build_crowd(scene: Node3D) -> void:
	if _crowd_marks.is_empty():
		return
	var crowd_root: Node3D = Node3D.new()
	crowd_root.name = "Crowd"
	scene.add_child(crowd_root)
	var mats: Dictionary = {}
	for sp in _crowd_marks:
		var seed_v: int = int(sp["variant"]) * 1000 + int(sp["n"]) + 7
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_v
		var look: Dictionary = SkaterVisual.random_look(seed_v)
		var tints: Dictionary = {"Skin": look["Skin"], "Shirt": look["Shirt"], "ShirtB": look["ShirtB"], "Pants": look["Pants"], "Hair": look["Hair"]}
		var person: Node3D = SPECTATOR.instantiate()
		crowd_root.add_child(person)
		person.global_transform = sp["xf"]
		var sit: bool = sp["sit"]
		var body: Node3D = person.find_child("Body", true, false)
		var arm_l: Node3D = person.find_child("ArmL", true, false)
		var arm_r: Node3D = person.find_child("ArmR", true, false)
		var fore_l: Node3D = person.find_child("ForeL", true, false)
		var fore_r: Node3D = person.find_child("ForeR", true, false)
		var leg_l: Node3D = person.find_child("LegL", true, false)
		var leg_r: Node3D = person.find_child("LegR", true, false)
		var shin_l: Node3D = person.find_child("ShinL", true, false)
		var shin_r: Node3D = person.find_child("ShinR", true, false)
		var cheer: float = rng.randf()
		if sit:
			body.position.y += 0.06
			leg_l.rotation.x = PI * 0.5
			leg_r.rotation.x = PI * 0.5
			shin_l.rotation.x = -PI * 0.5
			shin_r.rotation.x = -PI * 0.5
			if cheer < 0.32:
				arm_l.rotation.z = -2.5
				arm_r.rotation.z = 2.5
			else:
				arm_l.rotation.x = -0.5
				arm_r.rotation.x = -0.5
				fore_l.rotation.x = -1.0
				fore_r.rotation.x = -1.0
		else:
			person.rotate_y(rng.randf_range(-0.3, 0.3))
			if cheer < 0.55:
				arm_l.rotation.z = -2.55
				arm_r.rotation.z = 2.55
			elif cheer < 0.85:
				arm_r.rotation.z = 2.55
				arm_l.rotation.z = -0.35
			else:
				arm_l.rotation.z = -0.5
				arm_r.rotation.z = 0.5
		person.set_meta("crowd_phase", rng.randf() * TAU)
		person.set_meta("crowd_amp", 0.05 if sit else 0.17)
		person.set_meta("crowd_foot", (sp["xf"] as Transform3D).origin.y)
		for mi in person.find_children("*", "MeshInstance3D", true, false):
			var inst: MeshInstance3D = mi as MeshInstance3D
			for s in inst.mesh.get_surface_count():
				var old: Material = inst.mesh.surface_get_material(s)
				var mname: String = old.resource_name
				var col: Color = (old as BaseMaterial3D).albedo_color
				if tints.has(mname):
					col = tints[mname]
				var key: String = "%s|%s" % [mname, col.to_html(false)]
				if not mats.has(key):
					var m: StandardMaterial3D = StandardMaterial3D.new()
					m.resource_name = mname
					m.albedo_color = col
					mats[key] = m
				inst.set_surface_override_material(s, mats[key])
