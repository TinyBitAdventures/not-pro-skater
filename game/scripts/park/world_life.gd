class_name WorldLife
extends Node3D
## The parts of the park that move on their own: ducks paddling on the pond, cars driving round the
## block, swings swinging. (The cheering crowd is baked into the level and hops in the shader.)

const DUCK: PackedScene = preload("res://assets/models/duck.glb")
const CAR_MODELS: Array[PackedScene] = [
	preload("res://assets/models/car_hatch.glb"),
	preload("res://assets/models/car_van.glb"),
	preload("res://assets/models/car_pickup.glb"),
]
const CAR_COLORS: Array[String] = ["3d9bff", "ffd23f", "1fc2b0", "f4f7fb", "ff8a3d", "3fc66d", "8a5cf0", "ff7eb6"]

var level: Level
var _t: float = 0.0
var _ducks: Array[Dictionary] = []
var _cars: Array[Dictionary] = []
var _swings: Array[Dictionary] = []


func _init(p_level: Level = null) -> void:
	level = p_level


func _ready() -> void:
	if level == null:
		return
	_make_ducks()
	_make_cars()
	for i in level.swings.size():
		var sw: Node3D = level.swings[i]
		_swings.append({"node": sw, "basis": sw.basis, "phase": i * 1.3, "amp": 0.45 + 0.1 * i})


func _make_ducks() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for i in level.duck_marks.size():
		var xf: Transform3D = level.duck_marks[i]
		var d: Node3D = DUCK.instantiate()
		Toon.skin(d, {}, true)
		add_child(d)
		d.global_transform = xf
		_ducks.append({"node": d, "center": xf.origin, "r": rng.randf_range(1.6, 3.2), "w": rng.randf_range(0.25, 0.42) * (1.0 if i % 2 == 0 else -1.0),
			"phase": rng.randf() * TAU, "head": d.find_child("Head", true, false)})


func _make_cars() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for route in level.car_routes:
		var pts: Array = level.car_routes[route]
		if pts.size() < 3:
			continue
		var cum: Array[float] = [0.0]
		for i in range(1, pts.size() + 1):
			cum.append(cum[i - 1] + (pts[i % pts.size()] as Vector3).distance_to(pts[i - 1]))
		var total: float = cum[cum.size() - 1]
		for k in 2:
			var car: Node3D = (CAR_MODELS[rng.randi() % CAR_MODELS.size()] as PackedScene).instantiate()
			Toon.skin(car, {"CarBody": Color.html(CAR_COLORS[rng.randi() % CAR_COLORS.size()])}, true)
			add_child(car)
			var wheels: Array[Node3D] = []
			for wn in ["WheelFL", "WheelFR", "WheelBL", "WheelBR"]:
				var w: Node3D = car.find_child(wn, true, false)
				if w != null:
					wheels.append(w)
			_cars.append({"node": car, "pts": pts, "cum": cum, "total": total, "s": total * (float(k) / 2.0) + rng.randf() * 10.0,
				"speed": rng.randf_range(6.0, 8.5), "wheels": wheels})


static func _point_at(pts: Array, cum: Array[float], total: float, dist: float) -> Vector3:
	dist = fposmod(dist, total)
	for i in range(1, cum.size()):
		if dist <= cum[i]:
			var seg: float = cum[i] - cum[i - 1]
			var t: float = 0.0 if seg < 0.0001 else (dist - cum[i - 1]) / seg
			return (pts[i - 1] as Vector3).lerp(pts[i % pts.size()], t)
	return pts[0]


func _process(delta: float) -> void:
	_t += delta
	for d in _ducks:
		var a: float = d["phase"] + _t * d["w"]
		var c: Vector3 = d["center"]
		var node: Node3D = d["node"]
		var pos: Vector3 = c + Vector3(cos(a), 0.0, sin(a)) * d["r"]
		pos.y += sin(_t * 2.6 + d["phase"]) * 0.015
		var tangent: Vector3 = Vector3(-sin(a), 0.0, cos(a)) * signf(d["w"])
		node.global_position = pos
		node.look_at(pos + tangent, Vector3.UP)
		var head: Node3D = d["head"]
		if head != null:
			head.rotation.x = sin(_t * 3.1 + d["phase"]) * 0.18
	for c in _cars:
		c["s"] += c["speed"] * delta
		var node: Node3D = c["node"]
		var pos: Vector3 = _point_at(c["pts"], c["cum"], c["total"], c["s"])
		var ahead: Vector3 = _point_at(c["pts"], c["cum"], c["total"], c["s"] + 2.2)
		node.global_position = pos
		if ahead.distance_to(pos) > 0.01:
			node.look_at(ahead, Vector3.UP)
		for w in c["wheels"]:
			(w as Node3D).rotation.x -= c["speed"] * delta / 0.37
	for s in _swings:
		var sw: Node3D = s["node"]
		sw.basis = (s["basis"] as Basis) * Basis(Vector3.RIGHT, sin(_t * 1.5 + s["phase"]) * s["amp"])
