// Hair: the strand texture cut out with alpha to coverage (MSAA smooths the edges), a soft wrapped diffuse (light
// rolls round a head of hair), two Kajiya-Kay highlights along the strands (a tight bright one and a broad one
// tinted by the hair's own colour, shifted toward the tips), and the ambient occlusion baked into the vertex colour
// by blender/character.py (dark between the layers, under the crown and at the nape). Built from the imported hair
// material by RiderRig.hair_material(). Works in the Compatibility renderer.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.85;
uniform float wrap : hint_range(0.0, 1.0) = 0.45;
uniform float shift_1 = 0.08;           // the bright highlight, nudged toward the roots
uniform float shift_2 = -0.14;          // the tinted one, toward the tips
uniform float exponent_1 = 500.0;
uniform float exponent_2 = 72.0;
// (the sun's light is several times 1, and these sit on the sky's own sheen (SPECULAR): small numbers. At 0.3 they
// turned black hair silver)
uniform float strength_1 : hint_range(0.0, 1.0) = 0.015;
uniform float strength_2 : hint_range(0.0, 1.0) = 0.0;
uniform float jitter = 0.25;            // how far each strand's highlight moves along it (from the texture's detail)

varying vec3 strand;                    // view space: which way the strands run here
varying vec3 hair_tint;
varying float detail;                   // the texture against its own blurred self: ~1, more on bright strands

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_color;
	float ao = mix(1.0, pow(COLOR.r, 0.7), ao_strength);
	ALBEDO = tex.rgb * ao;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_tex, 0));
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	// strands run down and back over the head (the character faces +Z): that direction slid along the surface. At
	// the crown, where "down" is straight into the head, the "back" part keeps it defined
	vec3 flow = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, -0.75, -0.65, 0.0)).xyz);
	vec3 n = normalize(NORMAL);
	strand = normalize(flow - n * dot(flow, n) + vec3(1e-4));
	hair_tint = mix(vec3(1.0), clamp(tex.rgb * 2.2, vec3(0.0), vec3(1.0)), 0.75) * ao;
	// the strand pattern: each texel against its neighbourhood (a smooth tangent field put one sheet of highlight
	// over the whole head; real hair breaks it up strand by strand)
	float here = dot(tex.rgb, vec3(0.333));
	float round_here = dot(textureLod(albedo_tex, UV, 5.0).rgb * albedo_color.rgb, vec3(0.333));
	detail = clamp(here / max(round_here, 0.01), 0.2, 2.0);
}

float kajiya(vec3 t, vec3 h, float e) {
	float th = dot(t, h);
	return pow(sqrt(max(1.0 - th * th, 0.0)), e);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
	vec3 h = normalize(LIGHT + VIEW);
	float j = (detail - 1.0) * jitter;
	vec3 t1 = normalize(strand + NORMAL * (shift_1 + j));
	vec3 t2 = normalize(strand + NORMAL * (shift_2 + j));
	float lit = smoothstep(-0.15, 0.35, ndl);
	vec3 spec = vec3(strength_1 * kajiya(t1, h, exponent_1)) + hair_tint * strength_2 * kajiya(t2, h, exponent_2);
	SPECULAR_LIGHT += spec * clamp(detail, 0.25, 1.6) * lit * ATTENUATION * LIGHT_COLOR;
}
