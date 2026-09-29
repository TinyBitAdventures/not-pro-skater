shader_type spatial;
// Static level surfaces with baked light (blender/realism.py). The live sun adds direct light and shadows;
// the lightmap (second UV set) supplies everything else: sky light, bounce light and soft occlusion.
// Ambient light is disabled here so the sky is not counted twice. Works in the Compatibility renderer.
render_mode ambient_light_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform float normal_scale = 1.0;
uniform sampler2D lightmap : hint_default_black, filter_linear_mipmap;
uniform float lm_range = 2.0;       // the PNG stores sqrt(light / lm_range)
uniform float bake_energy = 1.0;

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo;
	ALBEDO = a.rgb;
	vec4 orm = texture(orm_tex, UV);
	ROUGHNESS = orm.g * roughness;
	METALLIC = orm.b * metallic;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	vec3 lm = texture(lightmap, UV2).rgb;
	EMISSION = a.rgb * lm * lm * lm_range * bake_energy;
}
