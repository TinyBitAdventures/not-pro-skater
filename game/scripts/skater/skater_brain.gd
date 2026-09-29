class_name SkaterBrain
extends RefCounted
## A tiny autopilot: cruises the ring path in a lane, popping the odd ollie with a flip or a grab.
## Drives the title-screen skater and the park's ambient skaters through the same SkaterInput as a player.

var lane: float = 36.0
var dir: float = 1.0                 # +1 counter-clockwise (seen from above), -1 clockwise
var trick_every: Vector2 = Vector2(3.0, 7.0)
var wait: float = 2.0
var plan: String = ""
var air: float = 0.0


func _init(p_lane: float = 36.0, p_dir: float = 1.0) -> void:
	lane = p_lane
	dir = p_dir
	wait = randf_range(1.0, 4.0)


func think(sk: Skater, dt: float) -> void:
	var inp: SkaterInput = sk.inp
	inp.clear_edges()
	inp.grab_held = false
	inp.move = Vector2.ZERO
	var p: Vector3 = sk.global_position
	var a: float = atan2(-p.z, p.x)
	var r: float = Vector2(p.x, p.z).length()
	var ahead: float = 0.16 * dir
	var target_r: float = lane if absf(r - lane) < 8.0 else lane
	var ta: float = a + ahead
	var tgt: Vector3 = Vector3(target_r * cos(ta), 0.0, -target_r * sin(ta))
	inp.world_dir = (tgt - p).normalized()
	match sk.state:
		Skater.State.GROUND:
			air = 0.0
			wait -= dt
			if wait <= 0.0 and sk.velocity.length() > 6.0:
				inp.ollie_pressed = true
				plan = ["flip", "grab", "none"][randi() % 3]
				wait = randf_range(trick_every.x, trick_every.y)
		Skater.State.AIR:
			air += dt
			if plan == "flip" and air > 0.12 and air < 0.2:
				inp.flip_pressed = true
			elif plan == "grab" and air > 0.15 and air < 0.5:
				inp.grab_held = true
		Skater.State.BAIL:
			wait = maxf(wait, 1.5)
