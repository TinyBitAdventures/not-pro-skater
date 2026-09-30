extends "res://scripts/greybox/greybox_world.gd"
## A community event: the event's level with its goals (EventRunner), a two-minute session and a results
## screen. The clock starts when the skater first rolls. Enter / R restarts when it is over.

@export var event_id: String = "birthday"

var runner: EventRunner
var ev: Dictionary = {}
var time_left: float = 120.0
var running: bool = false
var finished: bool = false


func _ready() -> void:
	ev = Events.get_event(event_id)
	level_path = ev["level"]
	look = "real"
	super._ready()
	skater.place_at(level.spawn)           # events start at the level's spawn, not the first test spot
	(cam as ChaseCamera).snap_behind()
	hud.level_label.text = ev["title"]
	runner = EventRunner.new()
	add_child(runner)
	runner.setup(event_id, level, skater, score)
	runner.changed.connect(_refresh_goals)
	runner.goal_done.connect(_on_goal)
	time_left = float(ev.get("session", 120.0))
	hud.set_timer(time_left, false)
	hud.set_hint("ROLL TO START THE CLOCK    P  RIDER    R  RESET    F3  TUNING")
	hud.announce(ev["title"], Hud.YELLOW, 2.4)
	Sound.play_music(Sound.gameplay_track())
	get_tree().create_timer(2.6).timeout.connect(func() -> void: hud.announce(String(ev["blurb"]).to_upper(), Hud.BLUE, 2.6))
	_refresh_goals()


func _refresh_goals() -> void:
	hud.set_goals(runner.goal_list())


func _on_goal(id: String, text: String) -> void:
	if id == "":
		hud.announce(text, Hud.RED, 1.6)
		Sound.play("combo_lost")
	else:
		hud.announce("GOAL!  " + text.to_upper(), Hud.GREEN, 2.0)
		Sound.play("skate_done")
	_refresh_goals()


func _process(delta: float) -> void:
	super._process(delta)
	if finished:
		return
	if not running and skater.velocity.length() > 1.0:
		running = true
		Sound.play("go")
	if running:
		time_left = maxf(0.0, time_left - delta)
		hud.set_timer(time_left, true)
		if time_left <= 0.0 and skater.state != Skater.State.AIR and skater.state != Skater.State.GRIND:
			_finish()


func _finish() -> void:
	finished = true
	score.bank()
	var lines: Array[String] = ["SCORE        %s" % Hud._commas(score.score), "BEST COMBO   %s" % Hud._commas(score.best_combo), ""]
	for g in runner.goal_list():
		lines.append(("DONE   " if g["done"] else "       ") + String(g["text"]))
	lines.append("")
	lines.append("ENTER  PLAY AGAIN")
	hud.show_results("\n".join(lines))
	Game.record(String(ev["id"]), score.score, score.best_combo)
	skater.scripted = true
	skater.inp = SkaterInput.new()
	skater.inp.brake = true


func _unhandled_input(event: InputEvent) -> void:
	if finished and (event.is_action_pressed("ui_accept") or event.is_action_pressed("respawn")):
		get_tree().reload_current_scene()
		return
	super._unhandled_input(event)
