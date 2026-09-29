class_name WorldEnv
extends RefCounted
## The shared sky, ambient light and sun for every scene that shows the park.

const SUN_DIR: Vector3 = Vector3(0.164, -0.93, -0.328)


static func build(parent: Node) -> DirectionalLight3D:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.56, 0.83, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.78, 1.0)
	env.ambient_light_energy = float(OS.get_environment("AMB")) if OS.get_environment("AMB") != "" else 0.21
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = float(OS.get_environment("SUN")) if OS.get_environment("SUN") != "" else 0.5
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 150.0
	parent.add_child(sun)
	sun.global_transform = Transform3D(Basis.looking_at(SUN_DIR, Vector3.UP), Vector3.ZERO)
	return sun
