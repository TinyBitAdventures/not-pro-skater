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
	await _press("ui_accept")                 # first item: Birthday at the Park
	await _wait(1.5)
	_check("title -> birthday", _scene().ends_with("birthday.tscn"))
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
	for i in 3:
		await _press("ui_down")
	await _press("ui_accept")                 # Quit to title
	await _wait(1.5)
	_check("quit to title", _scene().ends_with("title.tscn") and not get_tree().paused)
	print("[flow] %d failed" % fails)
	get_tree().quit(fails)
