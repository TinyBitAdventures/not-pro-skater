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
var _guests: Array[Npc] = []
var _cake: Node3D
var _cake_state: String = "waiting"    # waiting / carried / delivered
var _t: float = 0.0
var _bunches: Array[Node3D] = []


func setup(event_id: String, p_level: Level, p_skater: Skater, p_score: ScoreKeeper) -> void:
	ev = Events.get_event(event_id)
	level = p_level
	skater = p_skater
	score = p_score
	saved = Game.event_goals(ev["id"])
	score.banked.connect(_on_banked)
	score.trick_added.connect(_on_trick)
	skater.bailed.connect(_on_bailed)
	_dress(ev.get("dressing", {}))
	for gd in ev.get("guests", []):
		var guest: Npc = Npc.new()
		guest.char_key = gd["char"]
		guest.watch = skater
		add_child(guest)
		guest.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(gd["yaw"]))), gd["pos"])
		_guests.append(guest)
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
					if ev.get("dressing", {}).get("party_hats", false):
						kid.wear_party_hat(PARTY_COLORS[i % PARTY_COLORS.size()])


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
	for b in _bunches:                          # tied balloons lean and turn a little in the breeze
		var ph: float = b.get_meta("phase")
		b.rotation = Vector3(sin(_t * 0.9 + ph) * 0.07, sin(_t * 0.4 + ph) * 0.3, cos(_t * 0.7 + ph) * 0.07)
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
	for gst in _guests:
		if Vector2(p.x - gst.global_position.x, p.z - gst.global_position.z).length() < KID_RADIUS:
			gst.cheer(2.0)
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


const PARTY_COLORS: Array[Color] = [Color(0.92, 0.2, 0.25), Color(0.2, 0.5, 0.95), Color(1.0, 0.78, 0.15),
	Color(0.25, 0.75, 0.4), Color(0.85, 0.35, 0.8), Color(1.0, 0.55, 0.2), Color(0.97, 0.97, 0.95)]


## The event's decorations: balloon bunches, a banner, presents.
func _dress(d: Dictionary) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for at in d.get("balloons", []):
		_bunch(at, rng)
	if d.has("banner"):
		_banner(d["banner"])
	if d.has("gifts"):
		_gifts(d["gifts"], rng)


static func _latex(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.2
	m.clearcoat_enabled = true
	m.rim_enabled = true
	m.rim = 0.25
	return m


## Three to five balloons on strings tied to one point; the bunch sways about the knot.
func _bunch(at: Vector3, rng: RandomNumberGenerator) -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	root.global_position = at
	root.set_meta("phase", rng.randf() * TAU)
	_bunches.append(root)
	var string_mat: StandardMaterial3D = StandardMaterial3D.new()
	string_mat.albedo_color = Color(0.95, 0.95, 0.95)
	var n: int = rng.randi_range(3, 5)
	for i in n:
		var a: float = TAU * i / n + rng.randf_range(-0.3, 0.3)
		var top: Vector3 = Vector3(cos(a) * 0.28, rng.randf_range(1.5, 2.1), sin(a) * 0.28)
		var sph: SphereMesh = SphereMesh.new()
		sph.radius = 0.2
		sph.height = 0.46
		sph.radial_segments = 16
		sph.rings = 10
		sph.material = _latex(PARTY_COLORS[rng.randi_range(0, PARTY_COLORS.size() - 1)])
		var b: MeshInstance3D = MeshInstance3D.new()
		b.mesh = sph
		b.position = top
		b.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
		root.add_child(b)
		var line: CylinderMesh = CylinderMesh.new()
		line.top_radius = 0.003
		line.bottom_radius = 0.003
		line.height = top.length()
		line.radial_segments = 4
		line.material = string_mat
		var s_mi: MeshInstance3D = MeshInstance3D.new()
		s_mi.mesh = line
		s_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(s_mi)
		# a cylinder stands along Y: turn it to run from the knot to the balloon
		s_mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, top.normalized())), top * 0.5)


## A cloth banner with lettering between two poles, readable from the plaza side.
func _banner(bd: Dictionary) -> void:
	var a: Vector3 = bd["a"]
	var b: Vector3 = bd["b"]
	var h: float = float(bd.get("height", 2.4))
	var pole_mat: StandardMaterial3D = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.93, 0.93, 0.9)
	pole_mat.roughness = 0.5
	for p in [a, b]:
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = 0.035
		c.bottom_radius = 0.04
		c.height = h + 0.9
		c.material = pole_mat
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = c
		add_child(mi)
		mi.global_position = p + Vector3.UP * (h + 0.9) * 0.5
	var span: Vector3 = b - a
	var cloth: QuadMesh = QuadMesh.new()
	cloth.size = Vector2(span.length() - 0.1, 0.8)
	var cm: StandardMaterial3D = StandardMaterial3D.new()
	cm.albedo_color = Color(0.98, 0.95, 0.88)
	cm.roughness = 0.9
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material = cm
	var q: MeshInstance3D = MeshInstance3D.new()
	q.mesh = cloth
	add_child(q)
	var mid: Vector3 = (a + b) * 0.5 + Vector3.UP * (h + 0.35)
	var along: Vector3 = span.normalized()
	var facing: Vector3 = along.cross(Vector3.UP)          # the side the text reads from
	if facing.x > 0.0:
		facing = -facing                                    # toward the plaza (west)
	q.global_transform = Transform3D(Basis(along if facing.cross(Vector3.UP).dot(along) < 0.0 else -along, Vector3.UP, facing), mid)
	var l: Label3D = Label3D.new()
	l.text = String(bd["text"])
	l.font = UiKit.FONT_DISPLAY
	l.font_size = 160
	l.pixel_size = 0.0028
	l.modulate = Color(0.9, 0.22, 0.28)
	l.outline_size = 0
	l.double_sided = false
	l.shaded = true
	add_child(l)
	l.global_transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), mid + facing * 0.012)


## A little pile of presents: wrapped boxes with a ribbon each way.
func _gifts(at: Vector3, rng: RandomNumberGenerator) -> void:
	var ribbon: StandardMaterial3D = StandardMaterial3D.new()
	ribbon.albedo_color = Color(1.0, 0.85, 0.3)
	ribbon.roughness = 0.35
	var y: float = 0.0
	for i in 5:
		var size: Vector3 = Vector3(rng.randf_range(0.28, 0.5), rng.randf_range(0.18, 0.34), rng.randf_range(0.28, 0.45))
		var off: Vector3 = Vector3(rng.randf_range(-0.55, 0.55), 0.0, rng.randf_range(-0.45, 0.45))
		var stacked: bool = i >= 3
		var base_y: float = y if stacked else 0.0
		var root: Node3D = Node3D.new()
		add_child(root)
		root.global_transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + (off * 0.3 if stacked else off) + Vector3.UP * base_y)
		var wrap: StandardMaterial3D = StandardMaterial3D.new()
		wrap.albedo_color = PARTY_COLORS[(i * 3 + 1) % PARTY_COLORS.size()]
		wrap.roughness = 0.45
		for part in [[size, wrap], [Vector3(size.x + 0.01, size.y + 0.005, 0.05), ribbon], [Vector3(0.05, size.y + 0.006, size.z + 0.01), ribbon]]:
			var bm: BoxMesh = BoxMesh.new()
			bm.size = part[0]
			bm.material = part[1]
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = bm
			mi.position = Vector3.UP * (part[0] as Vector3).y * 0.5
			root.add_child(mi)
		if i == 2:
			y = size.y


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
