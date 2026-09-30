class_name RealEnv
extends RefCounted
## Sky, sun and camera response for the realistic look, matched to the level's bake (`<level>.lightmap.json`):
## the same HDRI as the bake shows as the sky and lights moving things, the sun points where the HDRI's sun is.

const SKY_DIR: String = "res://assets/sky/"
const SKY_YAW: float = PI * 0.5
const VIGNETTE: Shader = preload("res://shaders/vignette.gdshader")


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
	# Moving things (riders, bystanders, props, the board) get their fill from a flat sky-coloured ambient. In the
	# Compatibility renderer the sky's own ambient barely reaches them, so anything out of the sun went nearly black
	# (the Vlogger's red shirt turned black as she turned away from the sun). The baked world ignores ambient
	# (baked_pbr), so this lifts only live-lit things. `fill` / `fill_color` in <level>.look.json; FILL=<energy> to try.
	var look: Dictionary = info.get("look", {})
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(String(look.get("fill_color", "#9eb0cc")))
	env.ambient_light_energy = float(OS.get_environment("FILL")) if OS.get_environment("FILL") != "" else float(look.get("fill", 1.0))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(info.get("look", {}).get("exposure", info.get("exposure", 0.9)))
	# drawn sky only (not the light it casts): photographs of sunny parks show the sky brighter than a
	# physically scaled HDRI next to sunlit concrete does
	env.background_energy_multiplier = float(info.get("look", {}).get("sky_display", info.get("sky_display", 1.7)))
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.9)
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	if OS.get_environment("FOG") != "old":
		# haze takes the sky's colour in each direction and glows warm toward the low sun
		env.fog_aerial_perspective = 0.6
		env.fog_sun_scatter = 0.25
		env.fog_light_color = Color(0.74, 0.8, 0.9)
		env.fog_density = float(OS.get_environment("FOG")) if OS.get_environment("FOG") != "" else 0.0022
	# a gentle grade: a touch more contrast and colour than the physical render, like a camera's picture profile
	var grade: String = OS.get_environment("GRADE")
	if grade != "off":
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.08 if grade == "" else float(grade.get_slice(",", 0))
		env.adjustment_saturation = 1.1 if grade == "" else float(grade.get_slice(",", 1))
		env.adjustment_brightness = 1.0
		if OS.get_environment("TONE") != "off":
			env.adjustment_color_correction = _split_tone()
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	if OS.get_environment("VIGNETTE") != "off":
		_vignette(parent)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = float(info.get("sun_energy", 1.0))
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	if OS.get_environment("SH_OPACITY") != "":
		sun.shadow_opacity = float(OS.get_environment("SH_OPACITY"))
	sun.shadow_blur = float(OS.get_environment("SH_BLUR")) if OS.get_environment("SH_BLUR") != "" else 2.5
	# two blended splits over 40 m: every split redraws the shadow casters, and four cost more than the sharpness
	# they add at chase-camera distances. A low sun stretches each shadow texel along the ground: the shorter
	# range, a wider first split and more blur keep shadow edges from stair-stepping (SH_* env vars to compare)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = float(OS.get_environment("SH_SPLIT")) if OS.get_environment("SH_SPLIT") != "" else 0.2
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = float(OS.get_environment("SH_DIST")) if OS.get_environment("SH_DIST") != "" else 40.0
	sun.directional_shadow_fade_start = 0.85
	parent.add_child(sun)
	var d: Array = info.get("sun_dir", [0.3, 0.8, 0.4])
	var to_sun: Vector3 = Vector3(d[0], d[1], d[2]).normalized()
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP), Vector3.ZERO)
	return sun


## Darkens the corners a little: pulls the eye to the rider in the middle of the frame.
static func _vignette(parent: Node) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 5                                   # under the HUD (10)
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = VIGNETTE
	rect.material = sm
	layer.add_child(rect)
	parent.add_child(layer)


## A colour-correction ramp by brightness: shadows lean a touch cool, mid-tones and highlights warm, like late
## afternoon film. Keeps the ends at black and white so contrast is untouched.
static func _split_tone() -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 0.85, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0), Color(0.19, 0.215, 0.25), Color(0.59, 0.55, 0.48),
		Color(0.9, 0.85, 0.74), Color(1, 0.99, 0.96)])
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t

