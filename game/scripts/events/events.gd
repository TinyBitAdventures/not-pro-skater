class_name Events
extends RefCounted
## The community events. An event is a level plus a list of goals; EventRunner tracks them.
##
## Goal kinds:
##   letters    grab the floating balloon letters (markers Event_letter_<L>)
##   deliver    carry an item from one marker to another without bailing
##   trick_on   do a named grind on one rail (rails.json id)
##   show_kids  land a trick near each kid (markers Event_kid_<n>)
##   combo      bank one combo worth at least `points`
##   score      reach `points` in a session
##   laps       ride through the gates (markers Event_gate_<n>) in order and back to the first, `laps` times;
##              each lap adds `lap_points` as a trick
##
##   zone_combo bank one combo worth at least `points` inside the zone (marker Event_zone_<zone>, `radius` m)
##   marks      hit your marks: stop on each chalk mark (markers Event_mark_<n>)
##   timed_run  the one-take run: through the checkpoints (markers Event_check_<n>) in order within `limit`
##              seconds of the first; a bail or the clock ruins the take. `points` for finishing it
##   wallride   wallride a wall inside `area` (Rect2 in Godot x / z round the wall's face); `label` floats over
##              `label_at` (Godot coordinates) until it's done
##
## deliver takes `item` (a scene path; the cake by default) and `drop_text`.
## `money` (optional): the score is money raised, this many dollars a point (a fundraiser); the HUD, results
## and goal texts show dollars.
## trick_on takes `rail` (one id) or `rails` (any of them); `trick` "" means any grind.
##
## "music" (optional): the event's own soundtrack, assets/audio/music/<music>.ogg (it plays in Free Skate on the event's
## level too); without one, the cruise theme.
## "dressing" decorates the level for the event (Godot coordinates): balloon bunches tied to anchors, a banner on
## two poles, presents, and party hats for the kids.

## The events in menu order. Each is scenes/<id>.tscn (an EventWorld with event_id = id).
const ALL: Array[String] = ["birthday", "skateathon", "launchday", "recordrelease", "rushhour", "betweentakes"]
## Whose home event each one is ("" = everyone's): shown on the title menu.
const HOME: Dictionary = {"birthday": "dad", "skateathon": "", "launchday": "dev", "recordrelease": "musician", "rushhour": "vlogger", "betweentakes": "actor"}
## Free Skate: every level, no clock.
const LEVELS: Array[Dictionary] = [
	{"id": "park", "name": "Neighborhood Park", "scene": "res://scenes/neighborhood.tscn",
		"level": "res://assets/levels/neighborhood.gltf"},
	{"id": "school", "name": "Maple Grove Elementary", "scene": "res://scenes/school.tscn",
		"level": "res://assets/levels/school.gltf"},
	{"id": "campus", "name": "Hilltop Tech", "scene": "res://scenes/campus.tscn",
		"level": "res://assets/levels/campus.gltf"},
	{"id": "warehouse", "name": "The Warehouse District", "scene": "res://scenes/warehouse.tscn",
		"level": "res://assets/levels/warehouse.gltf"},
	{"id": "downtown", "name": "Downtown", "scene": "res://scenes/downtown.tscn",
		"level": "res://assets/levels/downtown.gltf"},
	{"id": "backlot", "name": "Big Moon Studios", "scene": "res://scenes/backlot.tscn",
		"level": "res://assets/levels/backlot.gltf"},
]


static func scene(id: String) -> String:
	return "res://scenes/%s.tscn" % id


## The level (glTF) a scene loads, "" for scenes without one of these levels (the title, the greybox).
static func level_of_scene(path: String) -> String:
	for id in ALL:
		if scene(id) == path:
			return String(get_event(id)["level"])
	for lv in LEVELS:
		if lv["scene"] == path:
			return String(lv["level"])
	return ""


## The soundtrack of the event held on a level (Free Skate there plays it too), "" for none.
static func music_for_level(gltf: String) -> String:
	for id in ALL:
		var e: Dictionary = get_event(id)
		if String(e["level"]) == gltf:
			return String(e.get("music", ""))
	return ""


## A level's name for the loading note ("Hilltop Tech").
static func level_name(gltf: String) -> String:
	for lv in LEVELS:
		if lv["level"] == gltf:
			return String(lv["name"])
	return "the level"


static func get_event(id: String) -> Dictionary:
	match id:
		"birthday":
			return {
				"id": "birthday",
				"title": "BIRTHDAY AT THE PARK",
				"blurb": "Leo turns ten today. Help the party along.",
				"level": "res://assets/levels/neighborhood.gltf",
				"session": 120.0,
				"kids": ["kid_leo", "kid_maya", "kid_sam"],
				# grown-ups at the party (Godot coordinates, facing yaw in degrees)
				"guests": [
					{"char": "guest_mom", "pos": Vector3(24.5, 0.0, 3.2), "yaw": 200.0},
					{"char": "guest_grandpa", "pos": Vector3(30.2, 0.0, -2.8), "yaw": 250.0},
				],
				"dressing": {
					"banner": {"text": "HAPPY BIRTHDAY LEO!", "a": Vector3(16.6, 0.0, -0.6), "b": Vector3(16.6, 0.0, 4.6),
						"height": 2.5},
					"balloons": [Vector3(21.9, 0.78, 6.4), Vector3(27.9, 0.78, 6.4), Vector3(21.9, 0.78, -0.1),
						Vector3(28.7, 0.8, -0.9), Vector3(17.25, 1.0, -6.75), Vector3(32.75, 1.0, -6.75),
						Vector3(16.9, 1.1, -0.6), Vector3(16.9, 1.1, 4.6)],
					"gifts": Vector3(26.9, 0.0, -2.6),
					"party_hats": true,
				},
				"goals": [
					{"id": "party", "kind": "letters", "text": "Grab the P-A-R-T-Y balloons", "letters": "PARTY"},
					{"id": "cake", "kind": "deliver", "text": "Bring the cake from the street to the party",
						"from": "cake_pickup", "to": "cake_drop"},
					{"id": "bench", "kind": "trick_on", "text": "Boardslide the party bench (ride at it across)", "rail": "party_bench",
						"trick": "Boardslide"},
					{"id": "kids", "kind": "show_kids", "text": "Show the kids a trick"},
					{"id": "combo", "kind": "combo", "text": "Party trick: a 10,000 combo", "points": 10000},
					{"id": "score", "kind": "score", "text": "Score 25,000", "points": 25000},
				],
			}
		"skateathon":
			return {
				"id": "skateathon",
				"title": "SKATE-A-THON",
				"blurb": "Maple Grove Elementary needs a new playground. Every trick raises money.",
				"level": "res://assets/levels/school.gltf",
				"session": 150.0,
				"money": 0.1,
				"kids": ["principal"],
				"guests": [
					{"char": "guest_mom", "pos": Vector3(9.6, 0.0, -2.4), "yaw": 20.0},
					{"char": "kid_sam", "pos": Vector3(7.0, 0.0, -2.8), "yaw": -10.0},
					{"char": "kid_maya", "pos": Vector3(21.5, 0.0, 2.6), "yaw": 0.0},
					{"char": "guest_grandpa", "pos": Vector3(-31.5, 0.0, -8.5), "yaw": -90.0},
				],
				"dressing": {
					"banner": {"text": "MAPLE GROVE SKATE-A-THON", "a": Vector3(-12.9, 0.0, 13.8), "b": Vector3(-7.1, 0.0, 13.8),
						"height": 2.6},
					"balloons": [Vector3(-15.2, 1.14, -4.8), Vector3(-4.8, 1.14, -4.8), Vector3(10.0, 0.8, -1.0),
						Vector3(6.0, 0.8, -1.0)],
					"thermometer": {"pos": Vector3(-1.0, 0.0, -3.2), "yaw": 10.0, "goal": 2500.0},
					"gifts": Vector3(11.2, 0.0, -2.2),
				},
				"goals": [
					{"id": "laps", "kind": "laps", "text": "Ride 3 sponsored laps of the school", "laps": 3,
						"lap_points": 800},
					{"id": "handrail", "kind": "trick_on", "text": "Grind a front-steps handrail",
						"rails": ["steps_rail_l", "steps_rail_c", "steps_rail_r"], "trick": ""},
					{"id": "cake", "kind": "deliver", "text": "Bring the bake-sale cake from the car park",
						"from": "cake_pickup", "to": "cake_drop", "drop_text": "CAKE DROPPED!  BACK TO THE CAR PARK"},
					{"id": "donate", "kind": "letters", "text": "Collect D-O-N-A-T-E", "letters": "DONATE"},
					{"id": "principal", "kind": "show_kids", "text": "Impress the principal"},
					{"id": "raise", "kind": "score", "text": "Raise $2,500", "points": 25000},
				],
			}
		"launchday":
			return {
				"id": "launchday",
				"title": "LAUNCH DAY",
				"music": "launchday",
				"blurb": "The app ships today. The team is out on the lawn, and the whole campus is yours.",
				"level": "res://assets/levels/campus.gltf",
				"session": 150.0,
				"kids": ["coworker_ana", "coworker_raj", "coworker_june"],
				"dressing": {
					"banner": {"text": "HILLTOP LAUNCH DAY", "a": Vector3(-34.5, 0.0, -2.5), "b": Vector3(-34.5, 0.0, 3.5),
						"height": 2.6},
					"balloons": [Vector3(-43.0, 0.78, 2.0), Vector3(-43.0, 0.78, 8.0), Vector3(-43.0, 0.78, 14.0),
						Vector3(-34.3, 1.0, -2.5), Vector3(-34.3, 1.0, 3.5), Vector3(STAGE_GODOT.x - 3.0, 1.2, STAGE_GODOT.z + 1.6),
						Vector3(STAGE_GODOT.x + 3.0, 1.2, STAGE_GODOT.z + 1.6)],
				},
				"goals": [
					{"id": "deploy", "kind": "letters", "text": "Collect D-E-P-L-O-Y", "letters": "DEPLOY"},
					{"id": "pizza", "kind": "deliver", "text": "Bring the pizzas from the food truck to the picnic",
						"from": "pizza_pickup", "to": "pizza_drop", "item": "res://assets/models/pizza.glb",
						"drop_text": "PIZZAS DROPPED!  BACK TO THE TRUCK"},
					{"id": "planters", "kind": "trick_on", "text": "Grind a long planter ledge",
						"rails": ["planter_1a", "planter_1b", "planter_2a", "planter_2b"], "trick": ""},
					{"id": "team", "kind": "show_kids", "text": "Show the team a trick"},
					{"id": "demo", "kind": "zone_combo", "text": "The demo: a 6,000 combo at the stage", "zone": "stage",
						"radius": 9.0, "points": 6000, "label": "DEMO STAGE"},
					{"id": "score", "kind": "score", "text": "Score 30,000", "points": 30000},
				],
			}
		"recordrelease":
			return {
				"id": "recordrelease",
				"title": "RECORD RELEASE",
				"music": "recordrelease",
				"blurb": "The band's new record comes out tonight at the Foundry. Warm up the crowd.",
				"level": "res://assets/levels/warehouse.gltf",
				"session": 150.0,
				"kids": ["fan_zoe", "fan_mo", "fan_ike"],
				"dressing": {
					"banner": {"text": "RECORD RELEASE TONIGHT", "a": Vector3(-5.0, 0.0, 18.0), "b": Vector3(1.0, 0.0, 18.0),
						"height": 2.6},
					"balloons": [Vector3(36.5, 1.1, 9.5), Vector3(36.5, 1.1, -1.5), Vector3(30.0, 0.8, -6.0),
						Vector3(-4.8, 1.0, 18.0), Vector3(0.8, 1.0, 18.0)],
				},
				"goals": [
					{"id": "vinyl", "kind": "letters", "text": "Collect V-I-N-Y-L", "letters": "VINYL"},
					{"id": "merch", "kind": "deliver", "text": "Get the merch from the van to the table",
						"from": "merch_pickup", "to": "merch_drop", "item": "res://assets/models/merch.glb",
						"drop_text": "MERCH DROPPED!  BACK TO THE VAN"},
					{"id": "dock", "kind": "trick_on", "text": "Grind the Foundry's loading dock", "rails": ["dock_ledge"],
						"trick": ""},
					{"id": "fans", "kind": "show_kids", "text": "Hype the fans"},
					{"id": "front", "kind": "zone_combo", "text": "A 7,000 combo in front of the stage", "zone": "stage",
						"radius": 9.0, "points": 7000, "label": "FRONT OF STAGE"},
					{"id": "graffiti", "kind": "wallride", "text": "Wallride the graffiti wall in the alley",
						"area": Rect2(9.0, -44.0, 1.6, 28.0), "label": "WALLRIDE", "label_at": Vector3(8.6, 4.2, -24.0)},
					{"id": "score", "kind": "score", "text": "Score 35,000", "points": 35000},
				],
			}
		"rushhour":
			return {
				"id": "rushhour",
				"title": "RUSH HOUR",
				"music": "rushhour",
				"blurb": "One take, no bails. Film the city before the morning market packs up.",
				"level": "res://assets/levels/downtown.gltf",
				"session": 150.0,
				"guests": [
					{"char": "principal", "pos": Vector3(-9.2, 0.15, -3.0), "yaw": 110.0},
					{"char": "guest_grandpa", "pos": Vector3(-11.0, 0.15, -7.6), "yaw": 70.0},
					{"char": "guest_mom", "pos": Vector3(-9.0, 0.15, -11.2), "yaw": 100.0},
				],
				"dressing": {
					"banner": {"text": "MARKET MORNING", "a": Vector3(-7.0, 0.0, -8.0), "b": Vector3(7.0, 0.0, -8.0),
						"height": 3.0},
					"balloons": [Vector3(-7.0, 1.0, 22.0), Vector3(7.0, 1.0, 22.0)],
				},
				"goals": [
					{"id": "viral", "kind": "letters", "text": "Collect V-I-R-A-L", "letters": "VIRAL"},
					{"id": "onetake", "kind": "timed_run", "text": "The one-take run: every checkpoint in 45 s",
						"limit": 45.0, "points": 2000},
					{"id": "coffee", "kind": "deliver", "text": "Take the coffee order from the café to the office lobby",
						"from": "coffee_pickup", "to": "coffee_drop", "item": "res://assets/models/coffee.glb",
						"drop_text": "COFFEE SPILLED!  BACK TO THE CAFÉ"},
					{"id": "intro", "kind": "zone_combo", "text": "Film the intro: a 5,000 combo on camera", "zone": "camera",
						"radius": 7.0, "points": 5000, "label": "ROLLING"},
					{"id": "bigrail", "kind": "trick_on", "text": "Grind the big rail at the civic plaza",
						"rails": ["plaza_rail_c", "plaza_rail_side"], "trick": ""},
					{"id": "bankwall", "kind": "wallride", "text": "Wallride off the bank to wall",
						"area": Rect2(12.8, 4.0, 1.6, 18.0), "label": "WALLRIDE", "label_at": Vector3(13.0, 4.6, 13.0)},
					{"id": "score", "kind": "score", "text": "Score 35,000", "points": 35000},
				],
			}
		"betweentakes":
			return {
				"id": "betweentakes",
				"title": "BETWEEN TAKES",
				"music": "betweentakes",
				"blurb": "Forty minutes while they relight the next scene. The whole backlot is a skatepark.",
				"level": "res://assets/levels/backlot.gltf",
				"session": 150.0,
				"kids": ["director_lou", "crew_rita", "crew_ray"],
				"dressing": {
					"banner": {"text": "QUIET ON SET", "a": Vector3(-3.0, 0.0, 12.0), "b": Vector3(3.0, 0.0, 12.0),
						"height": 3.0},
				},
				"goals": [
					{"id": "action", "kind": "letters", "text": "Collect A-C-T-I-O-N", "letters": "ACTION"},
					{"id": "marks", "kind": "marks", "text": "Hit your marks (stop on each one)"},
					{"id": "script", "kind": "deliver", "text": "Bring the script pages from the trailer to the director's chair",
						"from": "script_pickup", "to": "script_drop", "item": "res://assets/models/script.glb",
						"drop_text": "PAGES EVERYWHERE!  BACK TO THE TRAILER"},
					{"id": "dolly", "kind": "trick_on", "text": "Grind the dolly track",
						"rails": ["dolly_track_a", "dolly_track_b"], "trick": ""},
					{"id": "brownstone", "kind": "wallride", "text": "Wallride a brownstone on the New York street",
						"area": Rect2(20.5, -20.0, 19.0, 40.0), "label": "WALLRIDE", "label_at": Vector3(30.0, 5.0, 0.0)},
					{"id": "crew", "kind": "show_kids", "text": "Impress the director and the crew"},
					{"id": "score", "kind": "score", "text": "Score 40,000", "points": 40000},
				],
			}
	return {}


## Launch Day's stage (the amphitheatre's centre) in Godot coordinates, for placing its dressing.
const STAGE_GODOT: Vector3 = Vector3(38.0, 0.0, 17.0)
