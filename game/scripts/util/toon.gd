class_name Toon
extends RefCounted
## Turns Blender's flat-colour glTF meshes into the game's cel-shaded, outlined look.
## Material NAMES from Blender pick the style; the colour comes from the Blender base colour.

const TOON_SHADER: Shader = preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://shaders/outline.gdshader")
const FENCE_SHADER: Shader = preload("res://shaders/fence.gdshader")

## Per-material tweaks. outline=false skips the black hull; flat=true means "ground-like, casts no shadow".
const STYLES: Dictionary = {
	"Grass": {"noise_scale": 0.55, "noise_amount": 0.05, "outline": false, "flat": true},
	"GrassB": {"noise_scale": 0.55, "noise_amount": 0.05, "outline": false, "flat": true},
	"Plaza": {"grid_scale": 3.0, "grid_amount": 0.13, "noise_scale": 5.0, "noise_amount": 0.025, "outline": false, "flat": true},
	"Path": {"noise_scale": 5.0, "noise_amount": 0.025, "outline": false, "flat": true},
	"PathB": {"outline": false, "flat": true},
	"Line": {"outline": false, "flat": true},
	"Curb": {"outline": false},
	"Road": {"noise_scale": 4.0, "noise_amount": 0.02, "outline": false, "flat": true},
	"Window": {"emission": 0.2, "outline": false},
	"Lamp": {"emission": 1.0, "outline": false},
	"Collision": {"outline": false},
	"FenceMesh": {"fence": true, "outline": false},
}

static var _cache: Dictionary = {}
static var _outlines: Array[ShaderMaterial] = []
static var _outline_width: float = 0.05


## The two shader globals occlude.gdshaderinc reads. RenderingServer.global_shader_parameter_get() is
## editor-only (it errors at runtime), so everything else reads these mirrors; the set only fires on change.
static var player_pos: Vector3 = Vector3(0.0, -100.0, 0.0)
static var view_dir: Vector3 = Vector3(0.0, -0.577, -0.816)


static func set_player_pos(p: Vector3) -> void:
	if p != player_pos:
		player_pos = p
		RenderingServer.global_shader_parameter_set("player_pos", p)


static func set_view_dir(d: Vector3) -> void:
	if d != view_dir:
		view_dir = d
		RenderingServer.global_shader_parameter_set("view_dir", d)


static func style(mat_name: String) -> Dictionary:
	return STYLES.get(mat_name, {})


static func material(mat_name: String, color: Color, fade: bool = true, with_outline: bool = true) -> Material:
	var key: String = "%s|%s|%d|%d" % [mat_name, color.to_html(false), 1 if fade else 0, 1 if with_outline else 0]
	if _cache.has(key):
		return _cache[key]
	var st: Dictionary = STYLES.get(mat_name, {})
	var m: ShaderMaterial = ShaderMaterial.new()
	if st.get("fence", false):
		m.shader = FENCE_SHADER
		m.set_shader_parameter("albedo", color)
		_cache[key] = m
		return m
	m.shader = TOON_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("fade_enabled", 1.0 if fade else 0.0)
	for k in st:
		if k != "outline" and k != "flat":
			m.set_shader_parameter(k, st[k])
	if with_outline and st.get("outline", true):
		var o: ShaderMaterial = ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("fade_enabled", 1.0 if fade else 0.0)
		o.set_shader_parameter("width", _outline_width)
		m.next_pass = o
		_outlines.append(o)
	_cache[key] = m
	return m


## One shared outline material for baked levels: LevelBaker draws every outlined surface of a cell in a
## single cull_front pass instead of chaining a next_pass onto each toon material.
static var _outline_shared: ShaderMaterial = null
static var _shadow_shared: StandardMaterial3D = null


static func outline_material() -> ShaderMaterial:
	if _outline_shared == null:
		_outline_shared = ShaderMaterial.new()
		_outline_shared.shader = OUTLINE_SHADER
		_outline_shared.set_shader_parameter("fade_enabled", 1.0)
		_outline_shared.set_shader_parameter("width", _outline_width)
		_outlines.append(_outline_shared)
	return _outline_shared


## Any opaque material will do for a SHADOWS_ONLY mesh: the shadow pass ignores colour.
static func shadow_material() -> Material:
	if _shadow_shared == null:
		_shadow_shared = StandardMaterial3D.new()
	return _shadow_shared


## Outline thickness in world metres (the camera recomputes this from its zoom so lines stay N pixels).
static func set_outline_width(w: float) -> void:
	if absf(w - _outline_width) < 0.0005:
		return
	_outline_width = w
	for o in _outlines:
		o.set_shader_parameter("width", w)


## Smoothed per-vertex normals, packed into COLOR for the outline shader. Vertices that share a position
## (the corners of a flat-shaded box) all get the same averaged direction, so the hull doesn't split.
static func outline_normals(verts: PackedVector3Array, norms: PackedVector3Array) -> PackedColorArray:
	var acc: Dictionary = {}
	var keys: Array[Vector3i] = []
	keys.resize(verts.size())
	for i in verts.size():
		var v: Vector3 = verts[i]
		var k: Vector3i = Vector3i(roundi(v.x * 400.0), roundi(v.y * 400.0), roundi(v.z * 400.0))
		keys[i] = k
		var n: Vector3 = norms[i]
		var lst: Array = acc.get(k, [])
		var found: bool = false
		for e in lst:
			if (e as Vector3).dot(n) > 0.995:
				found = true
				break
		if not found:
			lst.append(n)
			acc[k] = lst
	var sums: Dictionary = {}
	for k in acc:
		var s: Vector3 = Vector3.ZERO
		for e in acc[k]:
			s += e as Vector3
		sums[k] = s.normalized() if s.length_squared() > 0.0001 else Vector3.UP
	var out: PackedColorArray = PackedColorArray()
	out.resize(verts.size())
	for i in verts.size():
		var n: Vector3 = sums[keys[i]]
		out[i] = Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0)
	return out


## Re-skin every mesh under `root` in place (used for characters; the level goes through LevelBaker).
## tints: material name -> Color override.
static func skin(root: Node, tints: Dictionary = {}, fade: bool = false) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var src: ArrayMesh = (mi as MeshInstance3D).mesh as ArrayMesh
		if src == null:
			continue
		var out: ArrayMesh = ArrayMesh.new()
		for s in src.get_surface_count():
			var arrays: Array = src.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			arrays[Mesh.ARRAY_COLOR] = outline_normals(verts, norms)
			arrays[Mesh.ARRAY_TEX_UV] = null
			var old: Material = src.surface_get_material(s)
			var mname: String = old.resource_name if old != null else "Default"
			var col: Color = Color.WHITE
			if old is BaseMaterial3D:
				col = (old as BaseMaterial3D).albedo_color
			if tints.has(mname):
				col = tints[mname]
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(s, material(mname, col, fade))
		(mi as MeshInstance3D).mesh = out


## A procedural mesh (BoxMesh, SphereMesh...) with outline normals and the toon look applied.
static func styled_mesh(src: Mesh, mat_name: String, color: Color, fade: bool = false) -> ArrayMesh:
	var out: ArrayMesh = ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		arrays[Mesh.ARRAY_COLOR] = outline_normals(verts, norms)
		arrays[Mesh.ARRAY_TEX_UV] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(s, material(mat_name, color, fade))
	return out
