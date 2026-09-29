class_name AmbientLife
extends Node3D
## Little touches of life: a flock of birds circling the park (their shadows sweep the plaza) and leaves
## drifting through the air around the camera.

var _birds: Array[Dictionary] = []
var _leaves: CPUParticles3D
var _t: float = 0.0


func _ready() -> void:
	_make_birds(6)
	_make_leaves()


func _make_birds(count: int) -> void:
	var colors: Array[Color] = [Color(0.96, 0.97, 1.0), Color(0.55, 0.62, 0.75), Color(0.85, 0.7, 0.5), Color(0.96, 0.97, 1.0)]
	var body_mesh: SphereMesh = SphereMesh.new()
	body_mesh.radius = 0.22
	body_mesh.height = 0.44
	body_mesh.radial_segments = 8
	body_mesh.rings = 4
	var wing_mesh: BoxMesh = BoxMesh.new()
	wing_mesh.size = Vector3(0.62, 0.03, 0.3)
	var beak_mesh: CylinderMesh = CylinderMesh.new()
	beak_mesh.top_radius = 0.0
	beak_mesh.bottom_radius = 0.05
	beak_mesh.height = 0.14
	beak_mesh.radial_segments = 5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	for i in count:
		var col: Color = colors[i % colors.size()]
		var bird: Node3D = Node3D.new()
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = Toon.styled_mesh(body_mesh, "BirdBody", col, false)
		body.scale = Vector3(1.0, 0.85, 1.6)
		bird.add_child(body)
		var beak: MeshInstance3D = MeshInstance3D.new()
		beak.mesh = Toon.styled_mesh(beak_mesh, "BirdBeak", Color(1.0, 0.65, 0.2), false)
		beak.position = Vector3(0, 0, -0.42)
		beak.rotation.x = -PI * 0.5
		bird.add_child(beak)
		var wings: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var pivot: Node3D = Node3D.new()
			pivot.position = Vector3(side * 0.14, 0.04, 0.0)
			var w: MeshInstance3D = MeshInstance3D.new()
			w.mesh = Toon.styled_mesh(wing_mesh, "BirdWing", col.darkened(0.08), false)
			w.position = Vector3(side * 0.31, 0, 0)
			pivot.add_child(w)
			bird.add_child(pivot)
			wings.append(pivot)
		add_child(bird)
		var radius: float = rng.randf_range(16.0, 58.0)
		_birds.append({
			"node": bird, "wings": wings, "radius": radius, "speed": rng.randf_range(4.5, 7.5) * (1.0 if i % 2 == 0 else -1.0),
			"phase": rng.randf() * TAU, "alt": rng.randf_range(8.0, 15.0), "flap": rng.randf_range(9.0, 13.0),
			"cx": rng.randf_range(-6.0, 6.0), "cz": rng.randf_range(-6.0, 6.0),
		})


func _make_leaves() -> void:
	_leaves = CPUParticles3D.new()
	_leaves.amount = 34
	_leaves.lifetime = 9.0
	_leaves.preprocess = 9.0
	_leaves.local_coords = false
	_leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_leaves.emission_box_extents = Vector3(30, 3, 30)
	_leaves.direction = Vector3(1.0, -0.15, 0.35)
	_leaves.spread = 25.0
	_leaves.initial_velocity_min = 0.6
	_leaves.initial_velocity_max = 1.6
	_leaves.gravity = Vector3(0, -0.5, 0)
	_leaves.angular_velocity_min = -160.0
	_leaves.angular_velocity_max = 160.0
	_leaves.scale_amount_min = 0.7
	_leaves.scale_amount_max = 1.2
	var ramp: Gradient = Gradient.new()
	ramp.colors = PackedColorArray([Color(0.45, 0.8, 0.3), Color(0.95, 0.8, 0.3), Color(0.9, 0.55, 0.25)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_leaves.color_initial_ramp = ramp
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.2, 0.28)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	_leaves.mesh = q
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_leaves)


func _process(delta: float) -> void:
	_t += delta
	for b in _birds:
		var ang: float = b["phase"] + _t * b["speed"] / b["radius"]
		var c: Vector3 = Vector3(b["cx"], 0.0, b["cz"])
		var pos: Vector3 = c + Vector3(cos(ang) * b["radius"], b["alt"] + sin(_t * 0.7 + b["phase"]) * 0.8, sin(ang) * b["radius"])
		var node: Node3D = b["node"]
		var tangent: Vector3 = Vector3(-sin(ang), 0.0, cos(ang)) * signf(b["speed"])
		node.global_position = pos
		node.look_at(pos + tangent, Vector3.UP)
		var flap: float = sin(_t * b["flap"]) * 0.7
		var wings: Array = b["wings"]
		(wings[0] as Node3D).rotation.z = -flap
		(wings[1] as Node3D).rotation.z = flap
	_leaves.global_position = Toon.focus_pos + Vector3(-8.0, 9.0, -8.0)
