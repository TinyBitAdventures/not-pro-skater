extends "res://scripts/greybox/greybox_world.gd"
## Learn to Skate: Neighborhood Park with no clock, one move at a time. Each step says what to do and which keys
## (or buttons) do it, ticks off when it's done and brings up the next; TAB goes to a good spot for the step (the
## low ledge, the quarter pipe, the painted wall). The last one done, the rider is ready: Game.tutorial_done, and
## the results offer the first event.
##   godot --path . res://scenes/tutorial.tscn          (STEP=<id> starts at that step)

## [id, title, what to do, key hints ([keys, what, pad]), spot ("" = anywhere; else SPOTS)]
const STEPS: Array = [
	["push", "Push", "Push to get rolling, and steer as you go. The keys for each step are along the bottom.",
		[["W", "push", "STICK UP"], ["A / D", "steer", "STICK"], ["S", "brake", "STICK DOWN"]], ""],
	["ollie", "Ollie", "Hold jump to crouch, let go to pop. The longer you hold, the higher you go.",
		[["SPACE", "hold, let go: ollie", "A"]], ""],
	["flip", "Flip trick", "Ollie, then flip in the air. Hold a direction with it for another flip.",
		[["SPACE", "ollie", "A"], ["J", "flip", "X"]], ""],
	["grab", "Grab", "Ollie, then hold grab in the air. Let go before you land.",
		[["SPACE", "ollie", "A"], ["K", "hold: grab", "B"]], ""],
	["grind", "Grind", "Ride along the low ledge and press grind beside it (or jump onto it). Steer to keep your balance.",
		[["L", "grind", "Y"], ["A / D", "balance", "STICK"]], "ledge"],
	["manual", "Manual", "Tap up then down to lift the nose (or press manual), then keep the meter in the middle with up and down.",
		[["W, S", "manual", "UP, DOWN"], ["M", "manual", "RT"], ["W / S", "balance", "STICK"]], ""],
	["combo", "Link a combo", "Three tricks in one combo: flip, land straight into a manual, then ollie out into another flip.",
		[["J", "flip", "X"], ["W, S", "manual", "UP, DOWN"], ["SPACE", "ollie out", "A"]], ""],
	["revert", "Revert", "Ride straight up the quarter pipe. As you land back on it, press manual to spin round.",
		[["W", "push", "STICK UP"], ["M", "revert", "RT"]], "qp"],
	["lip", "Lip trick", "Ride straight up the quarter pipe and press grind at the top: a stall on the coping. Jump to drop back in.",
		[["L", "lip trick", "Y"], ["SPACE", "drop in", "A"]], "qp"],
	["wallride", "Wallride", "Ollie toward the painted wall at an angle and press grind as you reach it.",
		[["SPACE", "ollie", "A"], ["L", "wallride", "Y"]], "wall"],
]
## Godot position and heading of each step's spot (Neighborhood Park).
const SPOTS: Dictionary = {
	"ledge": [Vector3(-21.0, 0.0, 3.3), Vector3(1.0, 0.0, 0.0)],          # west of the low ledge, beside its line
	"qp": [Vector3(2.0, 0.0, 5.0), Vector3(0.0, 0.0, 1.0)],                # a run-up straight at the quarter pipe
	"wall": [Vector3(-8.0, 0.0, 14.0), Vector3(-0.82, 0.0, 0.57)],         # angled at the painted wall
}
const PUSH_SPEED: float = 5.5            # m/s: rolling
const MANUAL_HOLD: float = 1.5           # s in one manual
const WALLRIDE_HOLD: float = 0.25        # s on the wall

var step: int = 0
var done: bool = false
var _manual_t: float = 0.0
var _wall_t: float = 0.0


func _ready() -> void:
	level_path = "res://assets/levels/neighborhood.gltf"
	look = "real"
	var want: String = OS.get_environment("STEP")
	for i in STEPS.size():
		if String(STEPS[i][0]) == want:
			step = i
	super._ready()
	hud.set_title("Learn to Skate")
	hud.show_speed(false)
	warp(0)                                     # the plaza, or the starting step's spot
	score.banked.connect(_on_banked)
	skater.landed.connect(func(air: float) -> void:
		if air > 0.3 and _id() == "ollie" and skater.state == Skater.State.GROUND:
			_complete())
	skater.landing.connect(func(kind: String) -> void:
		if kind == "revert" and _id() == "revert":
			_complete())
	hud.next_requested.connect(func() -> void:
		Game.event_choice = Events.ALL[0]
		Game.save()
		Game.go(Events.scene(Events.ALL[0])))
	_show_step(true)


func _id() -> String:
	return String(STEPS[step][0]) if not done else ""


## Warps go to the current step's spot (the level's own starts aren't part of the lesson).
func warp(_i: int) -> void:
	var spot: String = String(STEPS[step][4]) if not done else ""
	if spot == "" or not SPOTS.has(spot):
		if level.starts.has("plaza"):
			skater.place_at(level.starts["plaza"])
		return
	var at: Vector3 = SPOTS[spot][0]
	var dir: Vector3 = SPOTS[spot][1]
	skater.place_at(Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), at + Vector3.UP * 0.02))
	if cam.has_method("snap_behind"):
		cam.call("snap_behind")


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_TAB:
		warp(0)
	elif k.physical_keycode == KEY_P:
		super._unhandled_input(event)


func _show_step(first: bool) -> void:
	var items: Array = []
	for i in mini(step + 1, STEPS.size()):
		items.append({"text": String(STEPS[i][1]), "done": i < step or done})
	hud.set_goals(items)
	if done:
		return
	var s: Array = STEPS[step]
	var hints: Array = (s[3] as Array).duplicate()
	if String(s[4]) != "":
		hints.append(["TAB", "take me there"])
	hints.append(["ESC", "pause", "START"])
	hud.set_hints(hints)
	hud.announce("%d. %s" % [step + 1, String(s[1])], Hud.PAPER, 4.5 if first else 4.0, String(s[2]))


func _complete() -> void:
	if done:
		return
	Sound.play("skate_done")
	hud.announce("Nice!", Hud.GOOD, 1.0)
	step += 1
	_manual_t = 0.0
	_wall_t = 0.0
	if step >= STEPS.size():
		step = STEPS.size() - 1
		_finish()
		return
	_show_step(false)


func _on_banked(_points: int, _n: int) -> void:
	var names: Array[String] = score.names         # (still the banked combo's: bank() clears after this)
	var flips: Array = Tricks.FLIPS.values().map(func(e: Array) -> String: return String(e[0]))
	var grabs: Array = Tricks.GRABS.values().map(func(e: Array) -> String: return String(e[0]))
	var lips: Array = Tricks.LIPS.values().map(func(e: Array) -> String: return String(e[0]))
	match _id():
		"flip":
			if names.any(func(t: String) -> bool: return flips.has(t)):
				_complete()
		"grab":
			if names.any(func(t: String) -> bool: return grabs.has(t)):
				_complete()
		"grind":
			if names.any(func(t: String) -> bool: return Skater.GRIND_TIP.has(t) and t != "Lip Slide"):
				_complete()
		"combo":
			if names.size() >= 3 and (names.has("Manual") or names.has("Nose Manual")):
				_complete()
		"lip":
			if names.any(func(t: String) -> bool: return lips.has(t)):
				_complete()


func _process(delta: float) -> void:
	super._process(delta)
	if done:
		return
	match _id():
		"push":
			if skater.velocity.length() >= PUSH_SPEED and skater.state == Skater.State.GROUND:
				_complete()
		"manual":
			_manual_t = _manual_t + delta if skater.manual_on else 0.0
			if _manual_t >= MANUAL_HOLD:
				_complete()
		"wallride":
			_wall_t = _wall_t + delta if skater.wallriding else 0.0
			if _wall_t >= WALLRIDE_HOLD:
				_complete()
	# the step's spot, from the edge of the screen while it's far off
	var spot: String = String(STEPS[step][4])
	var target: Dictionary = {}
	if spot != "" and SPOTS.has(spot) and skater.global_position.distance_to(SPOTS[spot][0]) > 14.0:
		target = {"pos": (SPOTS[spot][0] as Vector3) + (SPOTS[spot][1] as Vector3) * 8.0, "text": "TAB"}
	hud.set_pointer(get_viewport().get_camera_3d(), target)


func _finish() -> void:
	done = true
	score.bank()
	Game.tutorial_done = true
	Game.save()
	_show_step(false)
	Sound.play_jingle("results", -2.0)
	var all: Array = []
	for s in STEPS:
		all.append({"text": String(s[1]), "done": true})
	hud.show_results({"title": "Learn to Skate", "heading": "YOU'RE READY", "score": score.score,
		"best_combo": score.best_combo, "goals": all, "next_title": String(Events.get_event(Events.ALL[0])["title"])})
	skater.scripted = true
	skater.inp = SkaterInput.new()
	skater.inp.brake = true


func _session_over() -> bool:
	return done
