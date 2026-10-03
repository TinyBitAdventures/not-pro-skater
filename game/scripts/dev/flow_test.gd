extends Node
## Menu flow with real input events: title -> Birthday -> ESC pause -> Restart -> ESC -> Quit to title.
##   godot --headless --path . res://scenes/dev_flow.tscn          (exit code = failures)

var fails: int = 0


func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		# the scene node is freed by the first scene change: run from a copy parked on the root instead
		var runner: Node = Node.new()
		runner.set_script(get_script())
		runner.set_meta("runner", true)
		runner.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(runner)
		return
	_run.call_deferred()


func _press(action: String) -> void:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var r: InputEventAction = InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame


func _check(what: String, ok: bool) -> void:
	print("[flow] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _scene() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""


func _run() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	await _wait(1.0)
	_check("title loads", _scene().ends_with("title.tscn"))
	var title: Node = get_tree().current_scene
	# one push of the stick is a stream of motion events: it moves one row, not one per event
	var before: int = int(title.get("selected"))
	for v in [0.3, 0.55, 0.7, 0.85, 1.0, 1.0, 0.8, 0.2, 0.0]:
		var m: InputEventJoypadMotion = InputEventJoypadMotion.new()
		m.axis = JOY_AXIS_LEFT_Y
		m.axis_value = v
		Input.parse_input_event(m)
		await get_tree().process_frame
	_check("one stick push moves the title one row", int(title.get("selected")) == before + 1)
	await _press("ui_up")
	await _press("pause")                     # Esc on the title: onto Quit (not pressed: it would end the test)
	var items: Array[String] = title.get("items")
	_check("ESC on the title selects Quit", items[int(title.get("selected"))] == "quit")
	await _press("ui_down")                   # wraps round to the first item: Birthday at the Park
	await _press("ui_accept")
	await _wait(1.5)
	_check("title -> birthday", _scene().ends_with("birthday.tscn"))
	# screen steering: holding S (back, toward the camera) stops the rider, it doesn't spin them round
	var was_mode: String = Game.steer_mode
	Game.steer_mode = "screen"
	var sk: Skater = get_tree().current_scene.get("skater")
	var yaw0: float = sk.yaw
	var hold: InputEventAction = InputEventAction.new()
	hold.action = "move_down"
	hold.pressed = true
	hold.strength = 1.0
	Input.parse_input_event(hold)
	await _wait(1.5)
	var turned: float = absf(angle_difference(yaw0, sk.yaw))
	var up: InputEventAction = InputEventAction.new()
	up.action = "move_down"
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(0.1)
	Game.steer_mode = was_mode
	_check("screen steering: holding S stays put (turned %.2f rad, %.2f m/s)" % [turned, sk.velocity.length()],
		turned < 0.1 and sk.velocity.length() < 0.3)
	await _press("pause")
	await _wait(0.2)
	_check("ESC pauses", get_tree().paused)
	await _press("ui_down")
	await _press("ui_accept")                 # Restart
	await _wait(1.5)
	_check("restart reloads, unpaused", _scene().ends_with("birthday.tscn") and not get_tree().paused)
	await _press("pause")
	await _press("pause")
	await _wait(0.2)
	_check("ESC again resumes", not get_tree().paused)
	await _press("pause")
	for i in Hud.PAUSE_ITEMS.find("OPTIONS"):
		await _press("ui_down")
	await _press("ui_accept")                 # Options, over the pause menu
	await _wait(0.2)
	var ph: Hud = get_tree().current_scene.get("hud")
	_check("pause > options opens, still paused", ph.options_screen.visible and get_tree().paused)
	var shake: bool = Game.camera_shake
	while ph.options_screen._row_key() != "shake":
		await _press("ui_down")
	await _press("ui_right")
	_check("options: right changes the row (camera shake %s -> %s)" % [shake, Game.camera_shake], Game.camera_shake != shake)
	await _press("ui_right")
	await _press("ui_cancel")
	await _wait(0.2)
	_check("options: back to the pause menu, still paused", not ph.options_screen.visible and ph.pause_menu.visible
		and get_tree().paused)
	await _press("pause")
	await _wait(0.2)
	await _press("pause")
	for i in Hud.PAUSE_ITEMS.find("QUIT TO TITLE"):
		await _press("ui_down")
	await _press("ui_accept")                 # Quit to title
	await _wait(1.5)
	_check("quit to title", _scene().ends_with("title.tscn") and not get_tree().paused)
	# a session that runs out: results, then Enter restarts with the music back
	await _press("ui_accept")
	await _wait(1.5)
	var w: Node = get_tree().current_scene
	w.set("running", true)
	w.set("time_left", 0.3)
	await _wait(0.8)
	var hud: Hud = w.get("hud")
	_check("session end shows results", w.get("finished") and hud.results_layer.visible)
	await _press("ui_accept")                      # a jump pressed as the buzzer goes doesn't skip the results
	await _wait(0.3)
	_check("an instant press keeps the results up", _scene().ends_with("birthday.tscn") and hud.results_layer.visible)
	await _wait(1.0)
	await _press("ui_accept")
	await _wait(1.8)
	var music: AudioStreamPlayer = Sound.get("_music")
	_check("skate again: new session, music playing", _scene().ends_with("birthday.tscn") \
		and not get_tree().current_scene.get("finished") and music.playing and music.volume_db > -6.0)
	# the results' NEXT EVENT: on to the skate-a-thon
	var w2: Node = get_tree().current_scene
	w2.set("running", true)
	w2.set("time_left", 0.3)
	await _wait(2.0)
	var hud2: Hud = w2.get("hud")
	_check("results offer the next event", hud2.results_keys.has("next"))
	await _press("ui_right")
	await _press("ui_accept")
	await _wait(2.0)
	_check("next event: the skate-a-thon loads", _scene().ends_with("skateathon.tscn"))
	print("[flow] %d failed" % fails)
	get_tree().quit(fails)
