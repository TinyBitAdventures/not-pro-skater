extends Node
## UI screenshots on Birthday at the Park: the HUD mid-combo, a title card, the pause menu, results, the title.
##   godot --path . res://scenes/dev_ui.tscn --resolution 1600x900        (-> ../shots/ui_*.png)

var world: Node
var hud: Hud


func _ready() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("ui_%s.png" % name))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _run() -> void:
	world = (load("res://scenes/birthday.tscn") as PackedScene).instantiate()
	add_child(world)
	await _wait(0.6)
	hud = world.get("hud")
	await _wait(0.9)
	await _shot("card")
	# a bonus and the goal it finished, in the same frame: both show, one after the other
	await _wait(3.6)
	(world.get("score") as ScoreKeeper).award("One Take", 2000)
	world.call("_on_goal", "onetake", "The one-take run: every checkpoint in 45 s")
	await _wait(0.4)
	await _shot("queue_1")
	await _wait(1.3)
	await _shot("queue_2")
	await _wait(2.6)
	# carrying (a long goal line wraps in the panel), then dropping it: the shout big, what to do under it
	var r0: EventRunner = world.get("runner")
	r0._cake_state = "carried"
	r0.changed.emit()
	world.call("_on_goal", "", "CAKE DROPPED!  BACK TO THE CAR PARK")
	await _wait(0.5)
	await _shot("drop")
	await _wait(2.4)
	await _shot("carry")                     # still carrying: the edge pointer toward the drop, off screen
	r0._cake_state = "waiting"
	r0.changed.emit()
	# the kids in their party hats, close up
	var runner: EventRunner = world.get("runner")
	var kid: Node3D = runner._kids[0]
	var kc: Camera3D = Camera3D.new()
	kc.fov = 35.0
	world.add_child(kc)
	var at: Vector3 = kid.global_position + Vector3.UP * 1.25
	kc.global_transform = Transform3D(Basis.looking_at(-kid.global_basis.z * -1.0 * -1.0, Vector3.UP), at + kid.global_basis.z * 2.6 + Vector3.UP * 0.2).looking_at(at, Vector3.UP)
	kc.current = true
	await _wait(0.3)
	await _shot("kid")
	kc.queue_free()
	(world.get("cam") as Camera3D).current = true
	world.set_process(false)                 # the world would reset the meters every frame
	var names: Array[String] = ["Kickflip", "50-50 Grind", "Manual", "Pop Shove-it", "Indy"]
	hud.set_combo(4, names, 1850, true)
	hud.set_balance(0.35, true)
	hud.set_charge(0.6)
	hud.set_score(12450)
	await _wait(0.8)
	await _shot("combo")
	hud.set_balance(0.0, false)
	hud.set_charge(0.0)
	hud.combo_banked(7400)
	await _wait(0.25)
	await _shot("banked")
	hud.set_edge_warning(0.7)                # riding out of the level
	await _wait(0.5)
	await _shot("wrong_way")
	hud.set_edge_warning(0.0)
	# letters: two in, the R flying home from mid-screen
	var word: String = runner.letters_word()
	var cols: Array = []
	for l in word:
		cols.append(EventRunner.letter_color(l, word))
	hud.set_letters(word, cols, "PA")
	hud.grab_letter("R", Vector2(900, 420))
	await _wait(0.3)
	await _shot("letter_fly")
	await _wait(0.6)
	await _shot("letters")
	# a real pickup (the event's signal): the T leaves from its balloon on screen
	var tb: Node3D = runner._letters["T"]
	runner.letter_got.emit("T", tb.global_position)
	await _wait(0.06)
	await _shot("letter_from_balloon")
	# a gamepad press: hints switch to pad buttons
	var jb: InputEventJoypadButton = InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_DPAD_LEFT
	jb.pressed = true
	Input.parse_input_event(jb)
	await _wait(0.2)
	await _shot("pad")
	var kb: InputEventKey = InputEventKey.new()
	kb.physical_keycode = KEY_SHIFT
	kb.pressed = true
	Input.parse_input_event(kb)
	await _wait(0.1)
	hud.open_pause()
	await _wait(0.3)
	await _shot("pause")
	hud._pause_select(Hud.PAUSE_ITEMS.find("OPTIONS"))
	hud._pause_activate()
	await _wait(0.2)
	await _shot("pause_options")
	hud.options_screen.close()
	hud._pause_select(Hud.PAUSE_ITEMS.find("CONTROLS"))
	hud._pause_activate()
	await _wait(0.2)
	await _shot("controls")
	hud.close_pause()
	hud.show_results({"title": "Birthday at the Park", "score": 26350, "best_combo": 9120, "new_best": true,
		"goals": [{"text": "Grab the P-A-R-T-Y balloons", "done": true}, {"text": "Bring the cake to the party", "done": false},
			{"text": "Boardslide the party bench", "done": true}]})
	await _wait(0.8)
	await _shot("results")
	world.queue_free()
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(t)
	await _wait(2.5)
	await _shot("title")
	(t.get("options_screen") as OptionsScreen).open()
	await _wait(0.3)
	await _shot("title_options")
	get_tree().quit()
