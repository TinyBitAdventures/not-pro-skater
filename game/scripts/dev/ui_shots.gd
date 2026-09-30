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
	hud.open_pause()
	await _wait(0.3)
	await _shot("pause")
	hud._pause_select(2)
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
	get_tree().quit()
