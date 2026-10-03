extends Node
## The update check, headless:
##   godot --headless --path . res://scenes/dev_update.tscn            (offline: version compare, GitHub's answer, the title row)
##   NET=1 godot --headless --path . res://scenes/dev_update.tscn      (also asks GitHub for real)
## Exit code = failures.

var fails: int = 0


func _check(name: String, ok: bool) -> void:
	print("[update] %s  %s" % ["PASS" if ok else "FAIL", name])
	if not ok:
		fails += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_check("v0.2.0 is newer than 0.1.0", Game.newer_version("v0.2.0", "0.1.0"))
	_check("v0.1.0 is not newer than 0.1.0", not Game.newer_version("v0.1.0", "0.1.0"))
	_check("0.1.10 is newer than 0.1.9", Game.newer_version("0.1.10", "0.1.9"))
	_check("v1.0 is newer than 0.9.9", Game.newer_version("v1.0", "0.9.9"))
	_check("v0.1.0 is not newer than 0.2.0", not Game.newer_version("v0.1.0", "0.2.0"))
	_check("a suffix is ignored (v0.2.0-beta vs 0.2.0)", not Game.newer_version("v0.2.0-beta", "0.2.0"))
	_check("no checks in dev runs", not Game._may_check_updates())

	var found: Array[String] = []
	var on_found: Callable = func(tag: String) -> void: found.append(tag)
	Game.update_found.connect(on_found)
	var url: String = "https://github.com/TinyBitAdventures/not-pro-skater/releases/tag/v0.2.0"
	Game.apply_release({"tag_name": "v0.2.0", "html_url": url}, "0.1.0")
	_check("a newer release is remembered and announced", Game.update_tag == "v0.2.0" and Game.update_url == url and found == ["v0.2.0"])
	Game.apply_release({"tag_name": "v0.2.0", "html_url": url}, "0.1.0")
	_check("the same release is announced once", found.size() == 1)
	Game.apply_release({"tag_name": "v0.1.0", "html_url": url}, "0.1.0")
	_check("this build's own release clears it", Game.update_tag == "")
	Game.apply_release({"tag_name": "v0.3.0", "html_url": url, "prerelease": true}, "0.1.0")
	_check("a pre-release is ignored", Game.update_tag == "")
	Game.apply_release({"tag_name": "v0.3.0", "html_url": "http://example.com/x"}, "0.1.0")
	_check("a page off GitHub falls back to the releases page",
		Game.update_url == "https://github.com/TinyBitAdventures/not-pro-skater/releases/latest")
	Game.update_tag = ""
	Game.update_url = ""

	# the title: no row without an update; a check that finds one while the title is up adds it above Quit
	var title: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(title)
	for i in 5:
		await get_tree().process_frame
	var items: Array = title.get("items")
	_check("no NEW VERSION row without an update", not items.has("update"))
	title.set("selected", items.find("options"))
	Game.apply_release({"tag_name": "v9.9.9", "html_url": url}, "0.1.0")
	await get_tree().process_frame
	items = title.get("items")
	var rows: Array = title.get("rows")
	_check("the row appears above Quit", items.has("update") and items.find("update") == items.find("quit") - 1)
	_check("one row per item after the rebuild", rows.size() == items.size())
	_check("the same row stays selected", items[int(title.get("selected"))] == "options")
	title.set("selected", items.find("update"))
	title.call("_refresh")
	var footer: String = (title.get("progress_label") as Label).text
	_check("its footer says what it is", footer.begins_with("V9.9.9 IS OUT"))
	Game.update_found.disconnect(on_found)
	Game.update_tag = ""
	Game.update_url = ""

	if OS.get_environment("NET") != "":
		Game.check_for_update()
		var ok: Array = [null]
		Game.update_checked.connect(func(v: bool) -> void: ok[0] = v, CONNECT_ONE_SHOT)
		var t: float = 0.0
		while ok[0] == null and t < 20.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		var tag: String = String(Game.last_release.get("tag_name", ""))
		_check("GitHub answers with the latest release (%s; this build %s; update %s)" % [tag, Game.version(),
			Game.update_tag if Game.update_tag != "" else "none"], ok[0] == true and tag.begins_with("v"))
	print("[update] %d failed" % fails)
	get_tree().quit(fails)
