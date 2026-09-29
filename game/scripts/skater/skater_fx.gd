class_name SkaterFx
extends Node3D
## Juice around the rider: an air trail, dust kicked up by pushes and landings, grind sparks and a
## shockwave ring on big landings. Everything lives in world space, so it stays where it happened.

const TRAIL_POINTS: int = 18

var skater: Skater
var _dust_land: CPUParticles3D
var _dust_push: CPUParticles3D
var _sparks: CPUParticles3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_t: float = -1.0
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _points: Array[Vector3] = []
var _trail_life: float = 0.0
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
	_make_ring()
	_make_trail()


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
	_sparks = CPUParticles3D.new()
	_sparks.amount = 36
	_sparks.lifetime = 0.4
	_sparks.local_coords = false
	_sparks.emitting = false
	_sparks.direction = Vector3.UP
	_sparks.spread = 65.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 5.5
	_sparks.gravity = Vector3(0, -14, 0)
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	ramp.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	_sparks.color_ramp = ramp
	var b: BoxMesh = BoxMesh.new()
	b.size = Vector3(0.07, 0.07, 0.07)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b.material = m
	_sparks.mesh = b
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


func _make_ring() -> void:
	_ring = MeshInstance3D.new()
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 6
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1, 1, 1, 0.8)
	t.material = _ring_mat
	_ring.mesh = t
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _make_trail() -> void:
	_trail = MeshInstance3D.new()
	_trail_mesh = ImmediateMesh.new()
	_trail.mesh = _trail_mesh
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = m
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.extra_cull_margin = 50.0
	add_child(_trail)


## Called by Skater._process every frame.
func tick(dt: float) -> void:
	if skater == null:
		return
	var s: Skater = skater
	var foot: Vector3 = s.global_position + Vector3.UP * 0.05
	# sparks ride the board while grinding
	_sparks.global_position = foot
	_sparks.emitting = s.state == Skater.State.GRIND
	# push dust from the back wheels on the flat
	_dust_push.global_position = foot
	var kicking: bool = s.state == Skater.State.GROUND and s.pushing and not s.braking and s.velocity.length() < 7.0 and s.surface != "grass"
	var braking: bool = s.state == Skater.State.GROUND and s.braking and s.velocity.length() > 3.0
	_dust_push.emitting = kicking or braking
	# ring animation
	if _ring_t >= 0.0:
		_ring_t += dt / 0.32
		var k: float = clampf(_ring_t, 0.0, 1.0)
		var r: float = lerpf(0.4, 2.1, 1.0 - pow(1.0 - k, 3.0))
		_ring.scale = Vector3(r, 1.0, r)
		_ring_mat.albedo_color.a = 0.8 * (1.0 - k)
		if _ring_t >= 1.0:
			_ring_t = -1.0
			_ring.visible = false
	_update_trail(s, dt)


func landed(air: float) -> void:
	var s: Skater = skater
	if s == null:
		return
	_dust_land.global_position = s.global_position + Vector3.UP * 0.08
	_dust_land.amount = 8 + mini(int(air * 12.0), 18)
	_dust_land.restart()
	_dust_land.emitting = true
	if air > 0.7:
		_ring.global_position = s.global_position + Vector3.UP * 0.1
		_ring.visible = true
		_ring_t = 0.0


func bailed() -> void:
	if skater == null:
		return
	_dust_land.global_position = skater.global_position + Vector3.UP * 0.08
	_dust_land.amount = 22
	_dust_land.restart()
	_dust_land.emitting = true


func _update_trail(s: Skater, dt: float) -> void:
	var active: bool = s.state == Skater.State.AIR and s.air_time > 0.08
	if active:
		_trail_life = 0.28
	else:
		_trail_life = maxf(0.0, _trail_life - dt)
	if _trail_life > 0.0:
		_points.push_front(s.global_position + Vector3.UP * 0.9)
		if _points.size() > TRAIL_POINTS:
			_points.pop_back()
	elif not _points.is_empty():
		_points.pop_back()
		if not _points.is_empty():
			_points.pop_back()
	_trail_mesh.clear_surfaces()
	if _points.size() < 3:
		return
	var vd: Vector3 = Toon.view_dir
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n: int = _points.size()
	for i in n:
		var p: Vector3 = _points[i]
		var dir: Vector3 = (_points[maxi(i - 1, 0)] - _points[mini(i + 1, n - 1)])
		if dir.length() < 0.001:
			dir = Vector3.UP
		var side: Vector3 = vd.cross(dir).normalized()
		var t: float = float(i) / float(n - 1)
		var w: float = 0.16 * (1.0 - t) * (1.0 if active else _trail_life / 0.28)
		var a: float = (1.0 - t) * 0.85
		_trail_mesh.surface_set_color(Color(1, 1, 1, a))
		_trail_mesh.surface_add_vertex(p + side * w)
		_trail_mesh.surface_set_color(Color(1, 1, 1, a))
		_trail_mesh.surface_add_vertex(p - side * w)
	_trail_mesh.surface_end()
