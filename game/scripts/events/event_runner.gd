class_name EventRunner
extends Node3D
## Runs one community event (Events.get_event) in a level: puts its things into the world (balloon letters,
## the cake, the kids), watches the skater and the score, and ticks goals off. Completed goals are saved.

signal goal_done(goal_id: String, text: String)
signal changed

const CAKE_SCENE: PackedScene = preload("res://assets/models/cake.glb")
const PICK_RADIUS: float = 1.7
const LETTER_RADIUS: float = 1.5
const KID_RADIUS: float = 6.0

var ev: Dictionary = {}
var level: Level
var skater: Skater
var score: ScoreKeeper
var done: Dictionary = {}          # goal id -> true
var saved: Dictionary = {}         # goals completed in earlier sessions
var _letters: Dictionary = {}      # letter -> Node3D balloon
var _got_letters: String = ""
var _kids: Array[Npc] = []
var _kids_shown: Dictionary = {}
var _cake: Node3D
var _cake_state: String = "waiting"    # waiting / carried / delivered
var _t: float = 0.0


func setup(event_id: String, p_level: Level, p_skater: Skater, p_score: ScoreKeeper) -> void:
	ev = Events.get_event(event_id)
	level = p_level
	skater = p_skater
	score = p_score
	saved = Game.event_goals(ev["id"])
	score.banked.connect(_on_banked)
	score.trick_added.connect(_on_trick)
	skater.bailed.connect(_on_bailed)
	for g in ev["goals"]:
		match String(g["kind"]):
			"letters":
				for l in String(g["letters"]):
					if level.markers.has("letter_" + l):
						_letters[l] = _balloon(l, (level.markers["letter_" + l] as Transform3D).origin)
			"deliver":
				_cake = CAKE_SCENE.instantiate()
				add_child(_cake)
				_cake.global_position = (level.markers[String(g["from"])] as Transform3D).origin
			"show_kids":
				var keys: Array = ev.get("kids", [])
				for i in keys.size():
					var mk: String = "kid_%d" % (i + 1)
					if not level.markers.has(mk):
						continue
					var kid: Npc = Npc.new()
					kid.char_key = keys[i]
					kid.watch = skater
					add_child(kid)
					kid.global_transform = level.markers[mk]
					_kids.append(kid)


## For the HUD: [{"text", "done"}], with progress in the text.
func goal_list() -> Array:
	var out: Array = []
	for g in ev.get("goals", []):
		var id: String = g["id"]
		var text: String = g["text"]
		match String(g["kind"]):
			"letters":
				text += "  %s" % _letter_progress(String(g["letters"]))
			"show_kids":
				text += "  %d/%d" % [_kids_shown.size(), _kids.size()]
			"deliver":
				if _cake_state == "carried" and not done.has(id):
					text += "  (carrying!)"
		out.append({"text": text, "done": done.has(id) or saved.has(id)})
	return out


func _letter_progress(all: String) -> String:
	var s: String = ""
	for l in all:
		s += (l if _got_letters.contains(l) else "_") + " "
	return s.strip_edges()


func _complete(id: String) -> void:
	if done.has(id):
		return
	done[id] = true
	var text: String = ""
	for g in ev["goals"]:
		if g["id"] == id:
			text = g["text"]
	Game.record_goal(ev["id"], id)
	goal_done.emit(id, text)
	changed.emit()


func _process(dt: float) -> void:
	_t += dt
	var rider: Vector3 = skater.rider_position()
	# balloons bob and are grabbed by riding (or flying) through them
	for l in _letters.keys():
		var b: Node3D = _letters[l]
		b.position.y = b.get_meta("y0") + sin(_t * 2.0 + b.get_meta("phase")) * 0.12
		if skater.state != Skater.State.BAIL and (rider + Vector3.UP * 0.9).distance_to(b.global_position) < LETTER_RADIUS:
			_got_letters += l
			b.queue_free()
			_letters.erase(l)
			Sound.play("pickup")
			changed.emit()
			for g in ev["goals"]:
				if g["kind"] == "letters" and _letter_progress(String(g["letters"])).find("_") < 0:
					_complete(g["id"])
	_cake_tick()
	for g in ev["goals"]:
		var id: String = g["id"]
		if done.has(id):
			continue
		match String(g["kind"]):
			"trick_on":
				if skater.state == Skater.State.GRIND and skater.grind_line != null \
						and skater.grind_line.id == String(g["rail"]) and skater.grind_kind == String(g["trick"]):
					_complete(id)
			"score":
				if score.score >= int(g["points"]):
					_complete(id)


func _cake_tick() -> void:
	if _cake == null:
		return
	var goal: Dictionary = {}
	for g in ev["goals"]:
		if g["kind"] == "deliver":
			goal = g
	var from: Vector3 = (level.markers[String(goal["from"])] as Transform3D).origin
	var to: Vector3 = (level.markers[String(goal["to"])] as Transform3D).origin
	match _cake_state:
		"waiting":
			_cake.global_position = from
			_cake.rotation.y += 0.01
			var d: Vector2 = Vector2(skater.global_position.x - from.x, skater.global_position.z - from.z)
			if d.length() < PICK_RADIUS and skater.state != Skater.State.BAIL:
				_cake_state = "carried"
				Sound.play("grab")
				changed.emit()
		"carried":
			# held in front of the chest (the chest faces the board's +X in the rider's frame)
			var v: Node3D = skater.visual
			if v != null:
				_cake.global_transform = v.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.32, 1.15, -0.05))
			var d2: Vector2 = Vector2(skater.global_position.x - to.x, skater.global_position.z - to.z)
			if d2.length() < PICK_RADIUS + 0.4:
				_cake_state = "delivered"
				_cake.global_transform = Transform3D(Basis.IDENTITY, to)
				_complete(goal["id"])
		"delivered":
			pass


func _on_bailed(_reason: String) -> void:
	if _cake_state == "carried":
		_cake_state = "waiting"          # dropped it: it goes back to the table at the street
		changed.emit()
		goal_done.emit("", "CAKE DROPPED!  BACK TO THE STREET")


func _on_trick(_name: String, _points: int) -> void:
	var p: Vector3 = skater.rider_position()
	for i in _kids.size():
		var k: Npc = _kids[i]
		if _kids_shown.has(i):
			continue
		if Vector2(p.x - k.global_position.x, p.z - k.global_position.z).length() < KID_RADIUS:
			_kids_shown[i] = true
			k.cheer(3.0)
			changed.emit()
			if _kids_shown.size() >= _kids.size():
				for g in ev["goals"]:
					if g["kind"] == "show_kids":
						_complete(g["id"])


func _on_banked(points: int, _n: int) -> void:
	for g in ev["goals"]:
		if g["kind"] == "combo" and points >= int(g["points"]):
			_complete(g["id"])


## A party balloon with its letter: a glossy latex sphere, a knot, a string and the letter on it.
func _balloon(letter: String, at: Vector3) -> Node3D:
	var root: Node3D = Node3D.new()
	add_child(root)
	root.global_position = at
	root.set_meta("y0", root.position.y)
	root.set_meta("phase", randf() * TAU)
	var colors: Array = [Color(0.9, 0.15, 0.2), Color(0.15, 0.45, 0.95), Color(1.0, 0.75, 0.1), Color(0.2, 0.75, 0.35), Color(0.8, 0.3, 0.85)]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = colors["PARTY".find(letter) % colors.size()]
	m.roughness = 0.18
	m.clearcoat_enabled = true
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.32
	sph.height = 0.74
	sph.material = m
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = sph
	root.add_child(mi)
	var line: CylinderMesh = CylinderMesh.new()
	line.top_radius = 0.004
	line.bottom_radius = 0.004
	line.height = 1.1
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.albedo_color = Color(0.95, 0.95, 0.95)
	line.material = lm
	var string_mi: MeshInstance3D = MeshInstance3D.new()
	string_mi.mesh = line
	string_mi.position = Vector3(0, -0.92, 0)
	root.add_child(string_mi)
	var l: Label3D = Label3D.new()
	l.text = letter
	l.font_size = 128
	l.pixel_size = 0.004
	l.outline_size = 18
	l.modulate = Color(1, 1, 1)
	l.outline_modulate = Color(0.1, 0.1, 0.15)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true                 # always readable, even through its own balloon
	l.render_priority = 5
	l.position = Vector3(0, 0.02, 0)
	root.add_child(l)
	return root
