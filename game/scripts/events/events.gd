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

const ALL: Array[String] = ["birthday"]


static func get_event(id: String) -> Dictionary:
	match id:
		"birthday":
			return {
				"id": "birthday",
				"title": "BIRTHDAY AT THE PARK",
				"blurb": "Leo turns ten today. Help the party along.",
				"level": "res://assets/levels/neighborhood.glb",
				"session": 120.0,
				"kids": ["kid_leo", "kid_maya", "kid_sam"],
				# grown-ups at the party (Godot coordinates, facing yaw in degrees)
				"guests": [
					{"char": "guest_mom", "pos": Vector3(24.5, 0.0, 3.2), "yaw": 200.0},
					{"char": "guest_grandpa", "pos": Vector3(30.2, 0.0, -2.8), "yaw": 250.0},
				],
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
	return {}
