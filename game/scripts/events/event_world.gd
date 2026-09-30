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
	hud.show_timer(true)
	hud.show_speed(false)
	hud.set_best(int(Game.best.get(String(ev["id"]), {}).get("score", 0)))
	runner = EventRunner.new()
	add_child(runner)
	runner.setup(event_id, level, skater, score)
	runner.changed.connect(_refresh_goals)
	runner.goal_done.connect(_on_goal)
	time_left = float(ev.get("session", 120.0))
	hud.set_timer(time_left, false)
	hud.set_hints([["W", "roll to start the clock", "STICK"], ["P", "rider"], ["R", "reset", "BACK"], ["ESC", "pause", "START"]])
	hud.announce(ev["title"], Hud.PAPER, 4.2, String(ev["blurb"]))
	Sound.play_music(Sound.gameplay_track())
	_refresh_goals()


func _refresh_goals() -> void:
	hud.set_goals(runner.goal_list())


func _on_goal(id: String, text: String) -> void:
	if id == "":
		hud.announce(text, Hud.BAD, 1.6)
		Sound.play("combo_lost")
	else:
		hud.announce("Goal: " + text, Hud.GOOD, 2.0)
		Sound.play("skate_done")
	_refresh_goals()


func _process(delta: float) -> void:
	super._process(delta)
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
	score.bank()
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
	super._unhandled_input(event)
