class_name SkaterFx
extends Node3D
## Dust kicked up by pushes, powerslides, landings and crashes, and sparks off the trucks while grinding.
## Everything lives in world space, so it stays where it happened.

var skater: Skater
var _dust_land: CPUParticles3D
var _dust_push: CPUParticles3D
var _sparks: CPUParticles3D
var _grit: CPUParticles3D
var _contact: MeshInstance3D
var _contact_mat: ShaderMaterial
var _puff_tex: GradientTexture2D


func _ready() -> void:
	top_level = true
	_puff_tex = GradientTexture2D.new()
	_puff_tex.fill = GradientTexture2D.FILL_RADIAL
	_puff_tex.fill_from = Vector2(0.5, 0.5)
	_puff_tex.fill_to = Vector2(1.0, 0.5)
	_puff_tex.width = 64
	_puff_tex.height = 64
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_puff_tex.gradient = g
	_dust_land = _make_dust(14, 0.5, 2.6, 0.55)
	_dust_push = _make_dust(6, 0.35, 1.2, 0.4)
	_dust_push.one_shot = false
	_dust_push.explosiveness = 0.0
	_dust_push.emitting = false
	_make_sparks()
	_make_contact()


func _make_dust(amount: int, life: float, speed: float, size: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -1.0, 0)
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1.0, 1.2))
	p.scale_amount_curve = sc
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.95, 0.93, 0.88, 0.75))
	ramp.set_color(1, Color(0.95, 0.93, 0.88, 0.0))
	p.color_ramp = ramp
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1, 1)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff_tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _make_sparks() -> void:
	# thin streaks stretched along their velocity (align_y + a quad that turns about its own Y to face the
	# camera), hot white to orange, falling fast and gone in a fraction of a second
	_sparks = CPUParticles3D.new()
	_sparks.amount = 48
	_sparks.lifetime = 0.28
	_sparks.local_coords = false
	_sparks.emitting = false
	_sparks.direction = Vector3.UP
	_sparks.spread = 45.0
	_sparks.initial_velocity_min = 2.5
	_sparks.initial_velocity_max = 6.0
	_sparks.gravity = Vector3(0, -18, 0)
	_sparks.particle_flag_align_y = true
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.2
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.86, 0.45, 1.0))
	ramp.add_point(0.3, Color(1.0, 0.58, 0.14, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.25, 0.04, 0.0))
	_sparks.color_ramp = ramp
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.014, 0.075)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_sparks.mesh = q
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)
	# concrete ledges and curbs kick up a little grit instead
	_grit = _make_dust(10, 0.35, 1.0, 0.18)
	_grit.one_shot = false
	_grit.explosiveness = 0.0
	_grit.emitting = false


## Ambient occlusion under the board: a soft dark patch where the deck and wheels meet the ground, which
## the sun shadow cannot give in the shade (and the Compatibility renderer has no screen-space AO).
func _make_contact() -> void:
	_contact_mat = ShaderMaterial.new()
	_contact_mat.shader = preload("res://shaders/contact_shadow.gdshader")
	_contact_mat.render_priority = -1
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Y
	q.material = _contact_mat
	_contact = MeshInstance3D.new()
	_contact.mesh = q
	_contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_contact)


func _update_contact(s: Skater) -> void:
	if s.state == Skater.State.BAIL:
		_contact.visible = false
		return
	var from: Vector3 = s.render_position() + Vector3.UP * 0.4
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1)
	var hit: Dictionary = s.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_contact.visible = false
		return
	var height: float = from.y - 0.4 - (hit["position"] as Vector3).y
	var fade: float = 1.0 - clampf(height / 1.6, 0.0, 1.0)
	_contact.visible = fade > 0.02
	var n: Vector3 = hit["normal"]
	var f: Vector3 = s.facing()
	f = (f - n * f.dot(n)).normalized()
	if f.length() < 0.5:
		f = Vector3.FORWARD
	var right: Vector3 = f.cross(n).normalized()
	var spread: float = 1.0 + height * 0.6                 # a higher board casts a wider, softer patch
	var b: Basis = Basis(right * 0.62 * spread, n, -f * 1.25 * spread)
	_contact.global_transform = Transform3D(b, (hit["position"] as Vector3) + n * 0.04)   # clear of floor sheets laid over the collider
	_contact_mat.set_shader_parameter("strength", 0.5 * fade * fade)



## Called by Skater._process every frame.
func tick(_dt: float) -> void:
	if skater == null:
		return
	var s: Skater = skater
	_update_contact(s)
	var foot: Vector3 = s.global_position + Vector3.UP * 0.05
	# sparks off metal (rails, coping) while grinding; grit off concrete (ledges, curbs)
	var grinding: bool = s.state == Skater.State.GRIND and s.lip_kind == ""      # a lip stall does not slide
	var metal: bool = grinding and s.grind_line != null and (s.grind_line.kind == "rail" or s.grind_line.kind == "coping")
	_sparks.global_position = foot
	_sparks.emitting = metal
	if metal:                                   # thrown back off the trucks, away from the way it is going
		_sparks.direction = (-s.hdg * 0.8 + Vector3.UP * 0.6).normalized()
	_grit.global_position = foot
	_grit.emitting = grinding and not metal
	# push dust from the back wheels on the flat
	_dust_push.global_position = foot
	var kicking: bool = s.state == Skater.State.GROUND and s.pushing and not s.braking and s.velocity.length() < 7.0 and s.surface != "grass"
	var braking: bool = s.state == Skater.State.GROUND and s.braking and s.velocity.length() > 3.0
	_dust_push.emitting = kicking or braking


func landed(air: float) -> void:
	var s: Skater = skater
	if s == null:
		return
	_dust_land.global_position = s.global_position + Vector3.UP * 0.08
	_dust_land.amount = 8 + mini(int(air * 12.0), 18)
	_dust_land.restart()
	_dust_land.emitting = true


func bailed() -> void:
	if skater == null:
		return
	_dust_land.global_position = skater.global_position + Vector3.UP * 0.08
	_dust_land.amount = 22
	_dust_land.restart()
	_dust_land.emitting = true
