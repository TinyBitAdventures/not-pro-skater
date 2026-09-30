class_name Birds
extends Node3D
## A few small flocks wheeling over the park: dark bird silhouettes (a body and two flapping wings, built in
## code) that circle, drift and now and then glide. One MultiMesh for all of them, no shadows. They give the
## sky some life at a cost of one draw call.

const FLOCKS: int = 3
const PER_FLOCK: int = 7

var _mm: MultiMesh
var _mat: ShaderMaterial
var _t: float = 0.0
var _flocks: Array[Dictionary] = []
var _birds: Array[Dictionary] = []


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	for f in FLOCKS:
		_flocks.append({
			"centre": Vector3(rng.randf_range(-50.0, 50.0), rng.randf_range(8.0, 15.0), rng.randf_range(-40.0, 50.0)),
			"radius": rng.randf_range(14.0, 26.0),
			"speed": rng.randf_range(0.12, 0.2) * (1.0 if rng.randf() < 0.5 else -1.0),
			"drift": Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.6, 1.4),
			"phase": rng.randf() * TAU,
		})
		for b in PER_FLOCK:
			_birds.append({
				"flock": f,
				"offset": Vector3(rng.randf_range(-3.5, 3.5), rng.randf_range(-1.5, 1.5), rng.randf_range(-3.5, 3.5)),
				"lag": rng.randf_range(0.0, 0.35),
				"flap": rng.randf() * TAU,
				"size": rng.randf_range(1.4, 2.0),              # crows and gulls, ~0.7-1 m across
			})
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/bird.gdshader")
	var mesh: ArrayMesh = _bird_mesh()
	mesh.surface_set_material(0, _mat)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = mesh
	_mm.instance_count = _birds.size()
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 200.0
	add_child(mmi)


func _process(dt: float) -> void:
	_t += dt
	for i in _birds.size():
		var b: Dictionary = _birds[i]
		var f: Dictionary = _flocks[int(b["flock"])]
		var tt: float = _t - float(b["lag"])
		var a: float = float(f["phase"]) + tt * float(f["speed"])
		var c: Vector3 = f["centre"] + f["drift"] * sin(tt * 0.05) * 30.0
		var r: float = float(f["radius"]) * (1.0 + 0.15 * sin(tt * 0.3 + float(f["phase"])))
		var p: Vector3 = c + Vector3(cos(a) * r, sin(tt * 0.4 + float(f["phase"])) * 2.0, sin(a) * r) + b["offset"]
		var dir: Vector3 = Vector3(-sin(a), 0.0, cos(a)) * signf(float(f["speed"]))
		var bank: float = 0.35 * signf(float(f["speed"]))
		var basis: Basis = Basis.looking_at(dir, Vector3.UP).rotated(dir, bank).scaled(Vector3.ONE * float(b["size"]))
		_mm.set_instance_transform(i, Transform3D(basis, p))
		# flapping, with glides: custom data r = wing angle
		var glide: float = smoothstep(0.3, 0.8, sin(tt * 0.7 + float(b["flap"])))
		var wing: float = sin(tt * 11.0 + float(b["flap"])) * (1.0 - glide) * 0.9 + glide * 0.15
		_mm.set_instance_custom_data(i, Color(wing, 0, 0, 0))


## A bird about 0.5 m across: a thin body and two wings, each a quad hinged at the body. Wing vertices carry
## UV.x = their side (-1 / +1) so the shader can flap them.
static func _bird_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body: Array[Vector3] = [Vector3(0, 0, -0.18), Vector3(0.03, 0, 0.0), Vector3(0, 0, 0.14), Vector3(-0.03, 0, 0.0)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2(0, 0))
		st.add_vertex(body[idx])
	for side in [-1.0, 1.0]:
		var w: Array[Vector3] = [Vector3(side * 0.02, 0, -0.07), Vector3(side * 0.26, 0, -0.02),
			Vector3(side * 0.24, 0, 0.05), Vector3(side * 0.02, 0, 0.05)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(side, 0))
			st.add_vertex(w[idx])
	return st.commit()
