extends Node
## The title screen after 3 s -> ../shots/title_new.png. TITLE_SWING="0,17.5,52.4" also shoots the camera's swing
## at those times (its two ends are at 17.5 s and 52.4 s) -> title_swing_<i>.png.
func _ready() -> void:
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(t)
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	get_viewport().get_texture().get_image().save_png(dir.path_join("title_new.png"))
	var swings: PackedStringArray = OS.get_environment("TITLE_SWING").split(",", false)
	for i in swings.size():
		t.set("_swing_t", float(swings[i]))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("title_swing_%d.png" % i))
	get_tree().quit()
