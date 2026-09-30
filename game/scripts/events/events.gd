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
## `money` (optional): the score is money raised, this many dollars a point (a fundraiser); the HUD, results
## and goal texts show dollars.
## trick_on takes `rail` (one id) or `rails` (any of them); `trick` "" means any grind.
##
## "dressing" decorates the level for the event (Godot coordinates): balloon bunches tied to anchors, a banner on
## two poles, presents, and party hats for the kids.

## The events in menu order. Each is scenes/<id>.tscn (an EventWorld with event_id = id).
const ALL: Array[String] = ["birthday", "skateathon"]
## Whose home event each one is ("" = everyone's): shown on the title menu.
const HOME: Dictionary = {"birthday": "dad", "skateathon": ""}
## Free Skate: every level, no clock.
const LEVELS: Array[Dictionary] = [
	{"id": "park", "name": "Neighborhood Park", "scene": "res://scenes/neighborhood.tscn"},
	{"id": "school", "name": "Maple Grove Elementary", "scene": "res://scenes/school.tscn"},
]


static func scene(id: String) -> String:
	return "res://scenes/%s.tscn" % id


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
					{"id": "bench", "kind": "trick_on", "text": "Boardslide the party bench", "rail": "party_bench",
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
						"from": "cake_pickup", "to": "cake_drop", "drop_text": "CAKE DROPPED!  BACK TO THE CAR"},
					{"id": "donate", "kind": "letters", "text": "Collect D-O-N-A-T-E", "letters": "DONATE"},
					{"id": "principal", "kind": "show_kids", "text": "Impress the principal"},
					{"id": "raise", "kind": "score", "text": "Raise $2,500", "points": 25000},
				],
			}
	return {}
