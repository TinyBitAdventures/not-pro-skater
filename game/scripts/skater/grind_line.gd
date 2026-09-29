class_name GrindLine
extends RefCounted
## A grindable polyline in world space (rail, ledge edge, coping, curb).

var id: String
var points: PackedVector3Array
var length: float = 0.0
var _cum: PackedFloat32Array = PackedFloat32Array()


func _init(p_id: String, p_points: PackedVector3Array) -> void:
	id = p_id
	points = p_points
	_cum.append(0.0)
	for i in range(1, points.size()):
		length += points[i].distance_to(points[i - 1])
		_cum.append(length)


func point_at(dist: float) -> Vector3:
	dist = clampf(dist, 0.0, length)
	for i in range(1, points.size()):
		if dist <= _cum[i]:
			var seg: float = _cum[i] - _cum[i - 1]
			var t: float = 0.0 if seg < 0.0001 else (dist - _cum[i - 1]) / seg
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]


func dir_at(dist: float) -> Vector3:
	dist = clampf(dist, 0.0, length)
	for i in range(1, points.size()):
		if dist <= _cum[i] or i == points.size() - 1:
			return (points[i] - points[i - 1]).normalized()
	return Vector3.FORWARD


## Closest point on the line to `p`: {dist, point, gap}.
func closest(p: Vector3) -> Dictionary:
	var best_gap: float = INF
	var best_dist: float = 0.0
	var best_pt: Vector3 = points[0]
	for i in range(1, points.size()):
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var ab: Vector3 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q: Vector3 = a + ab * t
		var g: float = q.distance_to(p)
		if g < best_gap:
			best_gap = g
			best_pt = q
			best_dist = _cum[i - 1] + ab.length() * t
	return {"dist": best_dist, "point": best_pt, "gap": best_gap}
