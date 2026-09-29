class_name GreyLook
extends RefCounted
## Greybox materials: every mesh gets the world-space grid shader, tinted by what the Blender material was
## (ramps warm grey, metal light blue-grey, blocks dark), so shapes read without any art.

const GRID: Shader = preload("res://shaders/grid.gdshader")
const TINTS: Array = [
	# [substring of the Blender material name, colour, roughness]
	["Metal", Color(0.74, 0.78, 0.84), 0.35],
	["Coping", Color(0.74, 0.78, 0.84), 0.35],
	["Wood", Color(0.7, 0.66, 0.6), 0.8],
	["Navy", Color(0.42, 0.42, 0.46), 0.9],
	["GreyDark", Color(0.46, 0.46, 0.48), 0.9],
	["Collision", Color(1, 0, 1), 1.0],
]

static var _cache: Dictionary = {}


static func material_for(mat_name: String) -> ShaderMaterial:
	var col: Color = Color(0.62, 0.62, 0.63)
	var rough: float = 0.85
	for t in TINTS:
		if mat_name.contains(t[0]):
			col = t[1]
			rough = t[2]
			break
	var key: String = col.to_html(false)
	if not _cache.has(key):
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = GRID
		m.set_shader_parameter("base_color", col)
		m.set_shader_parameter("roughness", rough)
		_cache[key] = m
	return _cache[key]


static func apply(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		if inst.mesh == null:
			continue
		for s in inst.mesh.get_surface_count():
			var old: Material = inst.mesh.surface_get_material(s)
			var nm: String = old.resource_name if old != null else ""
			inst.set_surface_override_material(s, material_for(nm))
