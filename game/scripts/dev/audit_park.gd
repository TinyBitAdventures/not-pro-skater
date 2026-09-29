extends Node
## Session-flow audit (headless):  AUDIT=<name> godot --headless --fixed-fps 120 --path . res://scenes/dev_audit_park.tscn
## names: pause done_space record keys
## The park scene is instantiated under the root and made current_scene so reload_current_scene() restarts it.

var park: Node = null


func _ready() -> void:
	_detach.call_deferred()


func _detach() -> void:
	var root: Node = get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	_run()


func _boot() -> void:
	if park != null and is_instance_valid(park):
		park.queue_free()
	var packed: PackedScene = load("res://scenes/park.tscn")
	park = packed.instantiate()
	get_tree().root.add_child(park)
	get_tree().current_scene = park
	for i in range(20):
		await get_tree().process_frame
	park.skater.scripted = true      # no real input in headless


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _key(code: Key, pressed: bool) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(3)
	_key(code, false)
	await _frames(3)


func _run() -> void:
	var which: String = OS.get_environment("AUDIT")
	if which == "pause":
		await _a_pause()
	elif which == "done_space":
		await _a_done_space()
	elif which == "record":
		await _a_record()
	elif which == "keys":
		_a_keys()
	get_tree().quit()


func _a_pause() -> void:
	print("[audit] pause: press Esc, press Esc again")
	await _boot()
	print("[audit]   before: paused=%s phase=%d" % [str(get_tree().paused), park.phase])
	await _tap(KEY_ESCAPE)
	print("[audit]   after 1st Esc: paused=%s pause_panel.visible=%s" % [str(get_tree().paused), str(park.hud.pause_panel.visible)])
	await _tap(KEY_ESCAPE)
	print("[audit]   after 2nd Esc: paused=%s pause_panel.visible=%s  (expected false/false)" % [str(get_tree().paused), str(park.hud.pause_panel.visible)])
	await _tap(KEY_ESCAPE)
	print("[audit]   after 3rd Esc: paused=%s" % str(get_tree().paused))
	var old: Node = park
	await _tap(KEY_SPACE)
	await _frames(10)
	print("[audit]   after Space (ollie key) while paused: scene restarted=%s paused=%s" % [str(get_tree().current_scene != old), str(get_tree().paused)])
	get_tree().paused = false


func _a_done_space() -> void:
	print("[audit] done_space: session ends while the player is mashing the ollie key")
	await _boot()
	park.phase = 1   # RUN
	park.time_left = 0.2
	await _frames(60)
	print("[audit]   phase=%d results_panel.visible=%s score=%d" % [park.phase, str(park.hud.results_panel.visible), park.score.score])
	var old: Node = park
	_key(KEY_SPACE, true)          # a real ollie press, not a menu press
	await _frames(6)
	_key(KEY_SPACE, false)
	await _frames(20)
	print("[audit]   after one Space press on the results screen: scene restarted=%s" % str(get_tree().current_scene != old))


func _a_record() -> void:
	print("[audit] record: save file from an older build has best[level] without 'combo'")
	await _boot()
	Game.best["community_park"] = {"score": 5}
	park.phase = 1
	park.time_left = 0.1
	await _frames(60)
	print("[audit]   phase=%d (DONE=3) results_panel.visible=%s Game.best=%s" % [park.phase, str(park.hud.results_panel.visible), str(Game.best)])
	Game.best = {}


func _a_keys() -> void:
	print("[audit] keys: which physical inputs also match ui_accept (restart)?")
	var sp: InputEventKey = InputEventKey.new()
	sp.keycode = KEY_SPACE
	sp.physical_keycode = KEY_SPACE
	sp.pressed = true
	print("[audit]   Space key: ollie=%s ui_accept=%s" % [str(sp.is_action_pressed("ollie")), str(sp.is_action_pressed("ui_accept"))])
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	print("[audit]   Gamepad A: ollie=%s ui_accept=%s" % [str(pad.is_action_pressed("ollie")), str(pad.is_action_pressed("ui_accept"))])
	var en: InputEventKey = InputEventKey.new()
	en.keycode = KEY_ENTER
	en.physical_keycode = KEY_ENTER
	en.pressed = true
	print("[audit]   Enter key: ollie=%s ui_accept=%s" % [str(en.is_action_pressed("ollie")), str(en.is_action_pressed("ui_accept"))])
