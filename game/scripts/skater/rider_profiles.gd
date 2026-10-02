class_name RiderProfiles
extends RefCounted
## Who each rider is on a board: ten stats from 1 to 10 and a style. A stat of 5 is the game's tuning as it is
## (SkateTuning); higher and lower move it a little either way, never so far that a gap or a ledge a level was
## built around goes out of reach. Riders start with their own strengths (each adds up to 50) and every event
## goal done anywhere gives each rider a point to spend (Game.stat_spent).
##
## Style: a stance (left or right foot forward), a push (regular, or mongo: the front foot pushes), a terrain
## (tricks there pay 20% more; an all-rounder gets 8% on everything) and signature tricks (50% more).

const STATS: Array[String] = ["ollie", "air", "hang", "speed", "spin", "flip", "landing", "rails", "lip", "manual"]
const STAT_INFO: Dictionary = {
	"ollie": ["Ollie", "Pop height on the flat"],
	"air": ["Air", "Height out of a ramp"],
	"hang": ["Hang time", "Float at the top of a jump"],
	"speed": ["Speed", "Pushing and pumping top speed"],
	"spin": ["Spin", "How fast a spin goes round"],
	"flip": ["Flip", "How fast a flip goes round"],
	"landing": ["Landing", "How crooked a landing still rolls away"],
	"rails": ["Rail balance", "Grinds tip off balance slower"],
	"lip": ["Lip balance", "Stalls on the coping tip slower"],
	"manual": ["Manual balance", "Manuals tip off balance slower"],
}
const MAX: int = 10
const TERRAIN_BONUS: float = 1.2          # a trick on the rider's own terrain
const ALL_ROUND_BONUS: float = 1.08       # an all-rounder: every trick
const SIGNATURE_BONUS: float = 1.5
const TERRAIN_NAMES: Dictionary = {"street": "Street", "vert": "Vert", "all": "All-round"}

const PROFILES: Dictionary = {
	"dev": {"stats": {"ollie": 5, "air": 4, "hang": 4, "speed": 6, "spin": 5, "flip": 6, "landing": 5, "rails": 5,
		"lip": 4, "manual": 6},
		"stance": "regular", "push": "regular", "terrain": "street", "signature": ["Kickflip", "Indy", "50-50"]},
	"musician": {"stats": {"ollie": 6, "air": 4, "hang": 4, "speed": 5, "spin": 4, "flip": 5, "landing": 6, "rails": 7,
		"lip": 4, "manual": 5},
		"stance": "goofy", "push": "regular", "terrain": "street", "signature": ["Pop Shove-it", "Melon", "Boardslide"]},
	"vlogger": {"stats": {"ollie": 4, "air": 5, "hang": 6, "speed": 5, "spin": 5, "flip": 4, "landing": 7, "rails": 4,
		"lip": 4, "manual": 6},
		"stance": "regular", "push": "mongo", "terrain": "all", "signature": ["Hardflip", "Nosegrab", "Noseslide"]},
	"dad": {"stats": {"ollie": 5, "air": 6, "hang": 6, "speed": 4, "spin": 4, "flip": 3, "landing": 6, "rails": 4,
		"lip": 7, "manual": 5},
		"stance": "regular", "push": "regular", "terrain": "vert", "signature": ["Impossible", "Method", "Tailslide"]},
	"actor": {"stats": {"ollie": 5, "air": 7, "hang": 5, "speed": 6, "spin": 7, "flip": 5, "landing": 4, "rails": 4,
		"lip": 4, "manual": 3},
		"stance": "goofy", "push": "regular", "terrain": "vert", "signature": ["Heelflip", "Mute", "Lip Slide"]},
}


static func profile(rider: String) -> Dictionary:
	return PROFILES.get(rider, PROFILES["dev"])


## The rider's stats before any points are spent.
static func base(rider: String) -> Dictionary:
	return (profile(rider)["stats"] as Dictionary).duplicate()


## Base plus spent points (`spent`: stat -> points), each kept within 1..MAX.
static func with_spent(rider: String, spent: Dictionary) -> Dictionary:
	var s: Dictionary = base(rider)
	for k in STATS:
		s[k] = clampi(int(s[k]) + int(spent.get(k, 0)), 1, MAX)
	return s


## A stat's effect: `at1` at 1, nothing at 5 (`at5`, the tuning as it is), `at10` at 10, in a straight line
## either side of 5.
static func at(level: int, at1: float, at5: float, at10: float) -> float:
	var l: float = clampf(float(level), 1.0, float(MAX))
	if l <= 5.0:
		return lerpf(at1, at5, (l - 1.0) / 4.0)
	return lerpf(at5, at10, (l - 5.0) / 5.0)


static func stat_name(stat: String) -> String:
	return String(STAT_INFO.get(stat, [stat.capitalize()])[0])
