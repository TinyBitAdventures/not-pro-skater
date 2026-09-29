class_name GreyEnv
extends RefCounted
## A neutral daylight setup for the greybox: procedural sky, sky-lit ambient, one shadowed sun.


static func build(parent: Node) -> DirectionalLight3D:
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.9)
	sky_mat.ground_horizon_color = Color(0.6, 0.62, 0.66)
	sky_mat.ground_bottom_color = Color(0.3, 0.3, 0.32)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.8, 0.9)
	env.fog_density = 0.0025
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 80.0
	parent.add_child(sun)
	sun.global_transform = Transform3D(Basis.looking_at(Vector3(0.35, -0.8, -0.45), Vector3.UP), Vector3.ZERO)
	return sun
