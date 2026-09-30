class_name GrassField
extends Node3D
## Grass clumps on the lawns, so the ground near the rider has some depth instead of a flat texture. Built at
## load: rays drop clumps onto collision bodies whose surface is "grass", in 20 m chunks (one MultiMesh each, a
## draw call per chunk in view) that are culled past `reach`. No shadow pass; the clumps receive shadows.

const SHADER: Shader = preload("res://shaders/grass_tuft.gdshader")
const CHUNK: float = 20.0

@export var area: Rect2 = Rect2(-60.0, -60.0, 120.0, 120.0)   # x, z in Godot space
@export var per_m2: float = 3.0
@export var reach: float = 46.0
var count: int = 0


func _ready() -> void:
	await get_tree().physics_frame                    # the level's bodies must be in the physics space first
	_build()


func _build() -> void:
	var mesh: ArrayMesh = _clump_mesh()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("blades", _blade_texture())
	mat.set_shader_parameter("fade_end", reach - 2.0)
	mat.set_shader_parameter("fade_start", reach - 14.0)
	mesh.surface_set_material(0, mat)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var cx0: int = int(floor(area.position.x / CHUNK))
	var cz0: int = int(floor(area.position.y / CHUNK))
	var cx1: int = int(ceil(area.end.x / CHUNK))
	var cz1: int = int(ceil(area.end.y / CHUNK))
	var per_chunk: int = int(CHUNK * CHUNK * per_m2)
	for cz in range(cz0, cz1):
		for cx in range(cx0, cx1):
			var xfs: Array[Transform3D] = []
			for i in per_chunk:
				var x: float = (cx + rng.randf()) * CHUNK
				var z: float = (cz + rng.randf()) * CHUNK
				if not area.has_point(Vector2(x, z)):
					continue
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -10.0, z), 1)
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty():
					continue
				var col: Object = hit["collider"]
				if col == null or String(col.get_meta("surface", "")) != "grass":
					continue
				var n: Vector3 = hit["normal"]
				var up: Vector3 = Vector3.UP.lerp(n, 0.5).normalized()
				var b: Basis = Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf() * TAU)
				var s: float = rng.randf_range(0.7, 1.35)
				xfs.append(Transform3D(b.scaled(Vector3(s, s * rng.randf_range(0.8, 1.25), s)), hit["position"] - up * 0.02))
			if xfs.is_empty():
				continue
			var mm: MultiMesh = MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
			var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# culled by distance to the chunk: its centre plus half its diagonal still has grass near you
			mmi.visibility_range_end = reach + CHUNK * 0.71
			add_child(mmi)
			count += xfs.size()


## Three cards crossing at 60 degrees, 0.48 m wide and 0.2 m tall (a lawn, not a meadow), rooted at the origin.
static func _clump_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = 0.24
	var h: float = 0.2
	for k in 3:
		var a: float = PI * k / 3.0
		var dx: Vector3 = Vector3(cos(a), 0.0, sin(a)) * w
		var p: Array[Vector3] = [-dx, dx, dx + Vector3.UP * h, -dx + Vector3.UP * h]
		var uv: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[idx])
			st.add_vertex(p[idx])
	return st.commit()


## A few dozen tapering blades, darker and bluer at the base, drawn into a small alpha texture.
static func _blade_texture() -> ImageTexture:
	var w: int = 128
	var h: int = 128
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.22, 0.3, 0.1, 0.0))                 # transparent, but a grass colour for the mip filtering
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for i in 34:
		var x0: float = rng.randf_range(6.0, w - 6.0)
		var tall: float = rng.randf_range(0.45, 1.0) * (h - 2)
		var lean: float = rng.randf_range(-22.0, 22.0)
		var width: float = rng.randf_range(2.2, 4.2)
		var tip: Color = Color(0.56, 0.68, 0.28).lerp(Color(0.66, 0.7, 0.34), rng.randf() * 0.5)
		var root: Color = Color(0.3, 0.42, 0.15)
		for yy in int(tall):
			var t: float = float(yy) / tall                 # 0 at the root
			var cx: float = x0 + lean * t * t
			var half: float = width * (1.0 - t) * 0.5 + 0.35
			for xx in range(int(cx - half - 1), int(cx + half + 2)):
				if xx < 0 or xx >= w:
					continue
				var cover: float = clampf(half - absf(xx + 0.5 - cx) + 0.5, 0.0, 1.0)
				if cover <= 0.0:
					continue
				var py: int = h - 1 - yy
				var c: Color = root.lerp(tip, t)
				var old: Color = img.get_pixel(xx, py)
				if cover > old.a:
					img.set_pixel(xx, py, Color(c.r, c.g, c.b, cover))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
