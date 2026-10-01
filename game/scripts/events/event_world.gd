extends "res://scripts/greybox/greybox_world.gd"
## A community event: the event's level with its goals (EventRunner), a two-minute session and a results
## screen. The clock starts when the skater first rolls. Enter / R restarts when it is over.

@export var event_id: String = "birthday"

var runner: EventRunner
var ev: Dictionary = {}
var time_left: float = 120.0
var running: bool = false
var finished: bool = false
var _last_tick: int = -1


func _ready() -> void:
	ev = Events.get_event(event_id)
	level_path = ev["level"]
	look = "real"
	super._ready()
	skater.place_at(level.spawn)           # events start at the level's spawn, not the first test spot
	if OS.get_environment("SHOT_START") != "":
		warp(start_names.find(OS.get_environment("SHOT_START")))     # screenshot mode
	(cam as ChaseCamera).snap_behind()
	hud.set_title(ev["title"])
	hud.set_money(float(ev.get("money", 0.0)))
	hud.show_timer(true)
	hud.show_speed(false)
	hud.set_best(int(Game.best.get(String(ev["id"]), {}).get("score", 0)))
	runner = EventRunner.new()
	add_child(runner)
	runner.setup(event_id, level, skater, score)
	runner.changed.connect(_refresh_goals)
	runner.goal_done.connect(_on_goal)
	runner.hint.connect(func(text: String, sub: String) -> void: hud.announce(text, Hud.PAPER, 1.8, sub))
	score.awarded.connect(func(award_name: String, points: int) -> void:
		hud.announce("%s  +%s" % [award_name.to_upper(), hud.amount(points)], Hud.GOOD, 1.6))
	var word: String = runner.letters_word()
	var colors: Array = []
	for l in word:
		colors.append(EventRunner.letter_color(l, word))
	hud.set_letters(word, colors)
	runner.letter_got.connect(func(l: String, at: Vector3) -> void:
		var from: Vector2 = get_viewport().get_visible_rect().size * 0.5
		if not cam.is_position_behind(at):
			from = cam.unproject_position(at)
		hud.grab_letter(l, from))
	time_left = float(ev.get("session", 120.0))
	hud.set_timer(time_left, false)
	hud.set_hints([["W", "roll to start the clock", "STICK"], ["P", "rider"], ["R", "reset", "BACK"], ["ESC", "pause", "START"]])
	hud.announce(ev["title"], Hud.PAPER, 4.2, String(ev["blurb"]))
	Sound.play_music(Sound.gameplay_track(String(ev.get("music", ""))))
	_refresh_goals()


func _refresh_goals() -> void:
	hud.set_goals(runner.goal_list())


func _on_goal(id: String, text: String) -> void:
	if id == "":
		# "CAKE DROPPED!  BACK TO THE STREET": the shout big, what to do next under it
		var parts: PackedStringArray = text.split("  ", false, 1)
		var sub: String = parts[1].strip_edges().to_lower() if parts.size() > 1 else ""
		if sub != "":
			sub = sub[0].to_upper() + sub.substr(1)
		hud.announce(parts[0], Hud.BAD, 1.8, sub)
		Sound.play("combo_lost")
	else:
		hud.announce("Goal: " + text, Hud.GOOD, 2.0)
		Sound.play("skate_done")
	_refresh_goals()


func _process(delta: float) -> void:
	super._process(delta)
	hud.set_take(runner.take_left())
	hud.set_pointer(get_viewport().get_camera_3d(), runner.objective())
	if finished:
		return
	if not running and skater.velocity.length() > 1.0:
		running = true
		hud.hide_hints()
		Sound.play("go")
	if running:
		time_left = maxf(0.0, time_left - delta)
		hud.set_timer(time_left, true)
		var sec: int = int(ceil(time_left))
		if sec <= 5 and sec >= 1 and sec != _last_tick:     # a soft tick through the last five seconds
			_last_tick = sec
			Sound.play("ui_ok", -9.0, 1.7)
		if time_left <= 0.0 and skater.state != Skater.State.AIR and skater.state != Skater.State.GRIND:
			_finish()


func _finish() -> void:
	finished = true
	score.bank()                  # a combo landed before the buzzer still counts (and can finish a goal)
	runner.active = false         # nothing after the buzzer completes or saves
	var new_best: bool = Game.record(String(ev["id"]), score.score, score.best_combo)
	Sound.play("time_up")
	Sound.fade_music(0.8)
	Sound.play_jingle("results", -2.0)
	if new_best and score.score > 0:
		get_tree().create_timer(1.4).timeout.connect(func() -> void: Sound.play_jingle("new_best", -3.0, 1))
	hud.show_results({"title": ev["title"], "score": score.score, "best_combo": score.best_combo,
		"new_best": new_best and score.score > 0, "goals": runner.goal_list()})
	skater.scripted = true
	skater.inp = SkaterInput.new()
	skater.inp.brake = true


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return                    # the results screen handles its own keys
	# only P (swap rider) from the free-skate keys: warping (1-9, 0, TAB) would carry an item or skip checkpoints
	var k: InputEventKey = event as InputEventKey
	if k != null and k.physical_keycode == KEY_P:
		super._unhandled_input(event)
