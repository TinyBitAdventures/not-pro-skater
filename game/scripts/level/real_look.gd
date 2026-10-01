class_name RealLook
extends RefCounted
## The realistic look: surfaces that carry a lightmap UV set get the baked PBR shader (textures copied from the
## glTF's StandardMaterial3D, light from `<level>.lightmap.png`); everything else keeps its imported PBR material
## and is lit by the sky and the sun at runtime (metal rails, the skater, props).

const SHADER: Shader = preload("res://shaders/baked_pbr.gdshader")
const LEAVES: Shader = preload("res://shaders/leaf_sway.gdshader")
const GLASS: Shader = preload("res://shaders/window_glass.gdshader")

static var bake_energy: float = 1.15       # a touch above the physical bake: cameras lift shade
const WALL_FILL: float = 2.2
const PLY_TILE: float = 1.2               # metres per texture tile of the "wood" set (blender/realism.py SETS)
static var _made: Array[ShaderMaterial] = []
static var _macro: Texture2D

## A floor on roughness per texture set: under a low sun the maps' glossier texels read as a wet sheen.
const ROUGH_MIN: Dictionary = {"grass": 0.92, "concrete": 0.7, "concrete_rough": 0.75, "asphalt": 0.75, "paving": 0.72,
	"wood": 0.6, "wood_side": 0.6, "roof": 0.9, "roof_dark": 0.9, "roof_brown": 0.9, "brick": 0.8, "siding": 0.6, "siding_blue": 0.6, "siding_sage": 0.6,
	"siding_cream": 0.6, "siding_grey": 0.6, "dirt": 0.9, "packed_dirt": 0.85, "steel_plate": 0.62, "side_paint": 0.7}

## Large-scale variation per texture set (baked_pbr.gdshader): [amount, tint, tint amount]. Grass gets dry
## yellow patches, concrete and asphalt faint stains, everything else a whisper so no tile repeats exactly.
const MACRO: Dictionary = {
	"grass": [0.2, Color(1.2, 1.1, 0.55), 0.4],
	"concrete": [0.12, Color(0.8, 0.78, 0.74), 0.5],
	"concrete_rough": [0.08, Color(0.9, 0.88, 0.85), 0.3],
	"asphalt": [0.12, Color(0.82, 0.82, 0.85), 0.3],
	"paving": [0.08, Color(0.9, 0.87, 0.82), 0.3],
}


## `lightmaps`: group name -> texture ("" = the level's single lightmap). A baked mesh belongs to the group in
## its node name (Blender's join_static names it "Baked_<group>").
static func apply(root: Node, lightmaps: Dictionary, info: Dictionary) -> void:
	_made.clear()
	# the level's look can set how strong the baked light is (a low sun's sky gives dim shade: lift it)
	if info.get("look", {}).has("bake_energy") and OS.get_environment("BAKE_ENERGY") == "":
		bake_energy = float(info["look"]["bake_energy"])
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
			if src.resource_name == "Glass":                 # house windows: sky reflection over a dark room
				if not cache.has("glass"):
					var gm: ShaderMaterial = ShaderMaterial.new()
					gm.shader = GLASS
					var sd: Array = info.get("sun_dir", [0.76, 0.33, 0.56])
					gm.set_shader_parameter("sun_dir", Vector3(sd[0], sd[1], sd[2]))
					cache["glass"] = gm
				mesh.surface_set_material(s, cache["glass"])
				continue
			if src.resource_name == "TreeLitter":            # fallen leaves: the leaf texture, dry and brown
				if not cache.has("litter"):
					var tm: StandardMaterial3D = StandardMaterial3D.new()
					tm.albedo_texture = src.albedo_texture
					tm.albedo_color = Color(0.58, 0.42, 0.24)
					tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					tm.alpha_scissor_threshold = 0.45
					tm.cull_mode = BaseMaterial3D.CULL_DISABLED
					tm.roughness = 0.95
					cache["litter"] = tm
				mesh.surface_set_material(s, cache["litter"])
				continue
			if src.resource_name == "PBR_grass_far":         # past the edge (live): no sheen toward a low sun
				if not cache.has("far_grass"):
					var fg: StandardMaterial3D = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					fg.roughness_texture = null
					fg.roughness = 1.0
					fg.metallic_specular = 0.15
					cache["far_grass"] = fg
				mesh.surface_set_material(s, cache["far_grass"])
				continue
			if src.resource_name == "TreeLeaves":
				if not cache.has("leaves"):
					var lm: ShaderMaterial = ShaderMaterial.new()
					lm.shader = LEAVES
					lm.set_shader_parameter("albedo_tex", src.albedo_texture)
					cache["leaves"] = lm
				mesh.surface_set_material(s, cache["leaves"])    # on the mesh: instanced copies (MultiMesh) share it
				continue
			var has_uv2: bool = (mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0
			var lightmap: Texture2D = lightmaps.get(_group_of(inst), lightmaps.get("", null))
			if not has_uv2 or lightmap == null:
				continue
			var key: String = "%d|%d" % [src.get_instance_id(), lightmap.get_instance_id()]
			if not cache.has(key):
				cache[key] = _baked(src, lightmap, info)
				_dress(cache[key], src.resource_name, info.get("look", {}))
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
	m.set_shader_parameter("wall_fill", float(info.get("wall_fill", WALL_FILL)))
	m.set_shader_parameter("shade_floor", float(OS.get_environment("SHADE_FLOOR")) if OS.get_environment("SHADE_FLOOR") != "" \
		else float(info.get("look", {}).get("shade_floor", 0.0)))
	_made.append(m)
	return m


## Macro variation and saw-cut joints for one baked material. `look` comes from <level>.look.json:
## {"joints": {"<material>": {"grid": [x, z], "rect": [min x, min z, max x, max z], "along_x": m}}}
static func _dress(m: ShaderMaterial, mat_name: String, look: Dictionary) -> void:
	var set_name: String = mat_name.trim_prefix("PBR_")
	var mc: Array = MACRO.get(set_name, [0.05, Color(1, 1, 1), 0.0])
	m.set_shader_parameter("rough_min", float(ROUGH_MIN.get(set_name, 0.0)))
	if set_name.begins_with("roof"):             # tile rows at grazing angles shimmered: flatter normals
		m.set_shader_parameter("normal_scale", 0.45)
	m.set_shader_parameter("macro_tex", _macro_texture())
	m.set_shader_parameter("macro_amount", mc[0])
	var tint: Color = mc[1]
	m.set_shader_parameter("macro_tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("macro_tint_amount", mc[2])
	if set_name == "concrete":                     # a skated slab: a shade darker and warmer, scuffed where people ride
		m.set_shader_parameter("albedo", Color(0.84, 0.83, 0.8))
		m.set_shader_parameter("scuff", 0.16)
	if set_name == "wood":                         # ramp surfaces: plywood sheets, screws, wheel wear
		m.set_shader_parameter("uv_tile", PLY_TILE)
		m.set_shader_parameter("wear", 0.07)
		m.set_shader_parameter("albedo", Color(0.95, 0.93, 0.86))   # Wood094 read peach-pink as a ramp
	var j: Dictionary = look.get("joints", {}).get(mat_name, {})
	if not j.is_empty():
		var g: Array = j.get("grid", [0.0, 0.0])
		var r: Array = j.get("rect", [0.0, 0.0, 0.0, 0.0])
		m.set_shader_parameter("joint_grid", Vector2(g[0], g[1]))
		m.set_shader_parameter("joint_rect", Vector4(r[0], r[1], r[2], r[3]))
		m.set_shader_parameter("joint_along_x", float(j.get("along_x", 0.0)))


static func _macro_texture() -> Texture2D:
	if _macro == null:
		var n: FastNoiseLite = FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.012
		n.fractal_octaves = 4
		n.seed = 7
		var img: Image = n.get_seamless_image(256, 256)
		img.generate_mipmaps()
		_macro = ImageTexture.create_from_image(img)
	return _macro


static func set_bake_energy(e: float) -> void:
	bake_energy = e
	for m in _made:
		m.set_shader_parameter("bake_energy", e)
