class_name GrindLine
extends RefCounted
## A grindable line in world space (rail, ledge edge, coping, curb), backed by a Curve3D.
## Levels author these as Blender curves (see blender/lib.py rail()); the builder samples them densely into
## `<level>.rails.json`, so straight rails stay straight and curved rails follow the curve smoothly.
## `kind` is one of "rail", "ledge", "coping", "curb".

const BAKE: float = 0.05
const TANGENT_STEP: float = 0.08

var id: String
var kind: String = "rail"
var curve: Curve3D
var points: PackedVector3Array
var length: float = 0.0
## Rails whose ends meet this one's ends (see Level.link_rails): {"start": [GrindLine, at_start: bool], "end": ...}
var links: Dictionary = {}


func _init(p_id: String, p_points: PackedVector3Array, p_kind: String = "") -> void:
	id = p_id
	points = p_points
	kind = p_kind if p_kind != "" else kind_from_id(p_id)
	curve = Curve3D.new()
	curve.bake_interval = BAKE
	for p in p_points:
		curve.add_point(p)
	length = curve.get_baked_length()


static func kind_from_id(gid: String) -> String:
	var head: String = gid.trim_prefix("Grind_").split("_")[0].to_lower()
	match head:
		"coping":
			return "coping"
		"ledge", "bench", "funbox":
			return "ledge"
		"curb":
			return "curb"
	return "rail"


func point_at(dist: float) -> Vector3:
	return curve.sample_baked(clampf(dist, 0.0, length))


## Unit direction of travel for increasing `dist`.
func dir_at(dist: float) -> Vector3:
	var a: float = clampf(dist - TANGENT_STEP, 0.0, length)
	var b: float = clampf(dist + TANGENT_STEP, 0.0, length)
	if b - a < 0.001:
		return (points[points.size() - 1] - points[0]).normalized()
	return (curve.sample_baked(b) - curve.sample_baked(a)).normalized()


## Closest point on the line to `p`: {dist, point, gap}.
func closest(p: Vector3) -> Dictionary:
	var off: float = curve.get_closest_offset(p)
	var q: Vector3 = curve.sample_baked(off)
	return {"dist": off, "point": q, "gap": q.distance_to(p)}
