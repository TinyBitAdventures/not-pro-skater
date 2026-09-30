class_name Tricks
extends RefCounted
## Trick names and base scores. Direction words are relative to the way the board points.

const FLIPS: Dictionary = {
	"none": ["Kickflip", 300], "left": ["Heelflip", 300], "right": ["Pop Shove-it", 250],
	"forward": ["Hardflip", 450], "back": ["Impossible", 450],
}
const GRABS: Dictionary = {
	"none": ["Indy", 200], "left": ["Melon", 250], "right": ["Mute", 250],
	"forward": ["Nosegrab", 300], "back": ["Method", 500],
}
## Lip tricks: stalls on a quarter / half pipe's coping, by stick direction relative to the board:
## [name, points, comes back in fakie]
const LIPS: Dictionary = {
	"none": ["Rock to Fakie", 400, true], "forward": ["Nose Stall", 350, false], "back": ["Blunt to Fakie", 550, true],
	"left": ["Axle Stall", 400, false], "right": ["Disaster", 500, true],
}
const LIP_HOLD_RATE: float = 180.0
const GRIND_HOLD_RATE: float = 220.0
const GRAB_HOLD_RATE: float = 140.0
const MANUAL_HOLD_RATE: float = 110.0


static func spin_name(units: int) -> String:
	return "%d" % (units * 180)


static func spin_points(units: int) -> int:
	match units:
		1: return 150
		2: return 400
		3: return 700
		4: return 1100
	return 1100 + (units - 4) * 500


static func direction_word(stick: Vector3, heading: Vector3) -> String:
	if stick.length() < 0.5:
		return "none"
	var f: float = stick.dot(heading)
	var s: float = stick.dot(heading.cross(Vector3.UP))
	if absf(f) >= absf(s):
		return "forward" if f > 0.0 else "back"
	return "right" if s > 0.0 else "left"
