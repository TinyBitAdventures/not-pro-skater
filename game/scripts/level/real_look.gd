class_name RealLook
extends RefCounted
## The realistic look: surfaces that carry a lightmap UV set get the baked PBR shader (textures copied from the
## glTF's StandardMaterial3D, light from `<level>.lightmap.png`); everything else keeps its imported PBR material
## and is lit by the sky and the sun at runtime (metal rails, the skater, props).

const SHADER: Shader = preload("res://shaders/baked_pbr.gdshader")
const LEAVES: Shader = preload("res://shaders/leaf_sway.gdshader")

static var bake_energy: float = 1.0
static var _made: Array[ShaderMaterial] = []


## `lightmaps`: group name -> texture ("" = the level's single lightmap). A baked mesh belongs to the group in
## its node name (Blender's join_static names it "Baked_<group>").
static func apply(root: Node, lightmaps: Dictionary, info: Dictionary) -> void:
	_made.clear()
	var cache: Dictionary = {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		var mesh: Mesh = inst.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var src: BaseMaterial3D = mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			if src.resource_name == "TreeLeaves":
				if not cache.has("leaves"):
					var lm: ShaderMaterial = ShaderMaterial.new()
					lm.shader = LEAVES
					lm.set_shader_parameter("albedo_tex", src.albedo_texture)
					cache["leaves"] = lm
				inst.set_surface_override_material(s, cache["leaves"])
				continue
			var has_uv2: bool = (mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0
			var lightmap: Texture2D = lightmaps.get(_group_of(inst), lightmaps.get("", null))
			if not has_uv2 or lightmap == null:
				continue
			var key: String = "%d|%d" % [src.get_instance_id(), lightmap.get_instance_id()]
			if not cache.has(key):
				cache[key] = _baked(src, lightmap, info)
			inst.set_surface_override_material(s, cache[key])


static func _group_of(n: Node) -> String:
	while n != null:
		var nm: String = String(n.name)
		if nm.begins_with("Baked_"):
			return nm.trim_prefix("Baked_")
		n = n.get_parent()
	return ""


static func _baked(src: BaseMaterial3D, lightmap: Texture2D, info: Dictionary) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SHADER
	m.resource_name = src.resource_name
	m.set_shader_parameter("albedo_tex", src.albedo_texture)
	m.set_shader_parameter("albedo", src.albedo_color)
	m.set_shader_parameter("orm_tex", src.roughness_texture)
	m.set_shader_parameter("roughness", src.roughness if src.roughness_texture != null else src.roughness)
	m.set_shader_parameter("metallic", src.metallic)
	m.set_shader_parameter("has_normal", src.normal_enabled and src.normal_texture != null)
	m.set_shader_parameter("normal_tex", src.normal_texture)
	m.set_shader_parameter("normal_scale", src.normal_scale)
	m.set_shader_parameter("lightmap", lightmap)
	m.set_shader_parameter("lm_range", float(info.get("range", 2.0)))
	m.set_shader_parameter("bake_energy", bake_energy)
	_made.append(m)
	return m


static func set_bake_energy(e: float) -> void:
	bake_energy = e
	for m in _made:
		m.set_shader_parameter("bake_energy", e)
