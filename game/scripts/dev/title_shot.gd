extends Node
## The title screen after 3 s -> ../shots/title_new.png (TITLE_OUT=<name> for another name). TITLE_SWING="0,17.5,52.4" also shoots the camera's swing
## at those times (its two ends are at 17.5 s and 52.4 s) -> title_swing_<i>.png.
## UPDATE_TAG=v0.2.0 shows the title as it is when a newer release is out (the NEW VERSION row, selected).
func _ready() -> void:
	if OS.get_environment("UPDATE_TAG") != "":
		Game.update_tag = OS.get_environment("UPDATE_TAG")
		Game.update_url = "https://github.com/TinyBitAdventures/not-pro-skater/releases/latest"
	# TITLE_RIDER=<key> shows that rider; TITLE_GOALS=<n> pretends n goals are done (stat points to spend);
	# TITLE_SELECT=<row> selects a row; TITLE_STATS=1 opens the stats screen (a dev run never saves any of it)
	if OS.get_environment("TITLE_RIDER") != "":
		Game.rider = OS.get_environment("TITLE_RIDER")
	if OS.get_environment("TITLE_GOALS") != "":
		var g: Dictionary = {}
		for i in int(OS.get_environment("TITLE_GOALS")):
			g["g%d" % i] = true
		Game.goals = {"birthday": g}
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	t.ready.connect(func() -> void:
		if OS.get_environment("TITLE_SELECT") != "":
			t.set("selected", (t.get("items") as Array).find(OS.get_environment("TITLE_SELECT")))
			t.call("_refresh")
		if OS.get_environment("TITLE_STATS") != "":
			(t.get("stats_screen") as StatsScreen).open(Game.rider))
	if OS.get_environment("UPDATE_TAG") != "":
		t.ready.connect(func() -> void:
			t.set("selected", (t.get("items") as Array).find("update"))
			t.call("_refresh"))
	add_child(t)
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	var out: String = OS.get_environment("TITLE_OUT") if OS.get_environment("TITLE_OUT") != "" else "title_new"
	get_viewport().get_texture().get_image().save_png(dir.path_join(out + ".png"))
	var swings: PackedStringArray = OS.get_environment("TITLE_SWING").split(",", false)
	for i in swings.size():
		t.set("_swing_t", float(swings[i]))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("title_swing_%d.png" % i))
	get_tree().quit()
