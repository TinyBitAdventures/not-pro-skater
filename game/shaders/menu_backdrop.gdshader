shader_type canvas_item;
// Behind the pause and results menus: the game view blurred (the screen texture's mip chain, sampled a few
// times around each pixel) and darkened, so the menu sits on the scene instead of a flat wash.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.5;
uniform float darken = 0.55;
uniform vec3 tint = vec3(0.05, 0.06, 0.08);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * exp2(lod);
	vec3 c = vec3(0.0);
	c += textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.4;
	c += textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV - vec2(px.x, 0.0), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, px.y), lod).rgb * 0.15;
	COLOR = vec4(mix(c, tint, darken), 1.0);
}
