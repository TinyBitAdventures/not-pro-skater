class_name RealEnv
extends RefCounted
## Sky, sun and camera response for the realistic look, matched to the level's bake (`<level>.lightmap.json`):
## the same HDRI as the bake shows as the sky and lights moving things, the sun points where the HDRI's sun is.

const SKY_DIR: String = "res://assets/sky/"
const SKY_YAW: float = PI * 0.5


static func build(parent: Node, info: Dictionary) -> DirectionalLight3D:
	var pano: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	pano.panorama = load(SKY_DIR + String(info.get("hdri", "kloofendal_48d_partly_cloudy_puresky_1k.hdr")))
	pano.energy_multiplier = float(info.get("sky_energy", 1.0))
	var sky: Sky = Sky.new()
	sky.sky_material = pano
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Blender's and Godot's panorama mappings differ by a quarter turn about Y: without this the sun in the sky
	# image sits 90 degrees away from the baked sun (and the live one).
	env.sky_rotation = Vector3(0.0, SKY_YAW + float(info.get("sky_yaw", 0.0)), 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(info.get("exposure", 0.9))
	# drawn sky only (not the light it casts): photographs of sunny parks show the sky brighter than a
	# physically scaled HDRI next to sunlit concrete does
	env.background_energy_multiplier = float(info.get("sky_display", 1.7))
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.9)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = float(info.get("sun_energy", 1.0))
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	parent.add_child(sun)
	var d: Array = info.get("sun_dir", [0.3, 0.8, 0.4])
	var to_sun: Vector3 = Vector3(d[0], d[1], d[2]).normalized()
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	return sun
