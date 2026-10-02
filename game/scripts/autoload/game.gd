extends Node
## Settings and saved bests. Dev scenes (anything launched from scenes/dev_*) never touch the real save.

const SAVE_PATH: String = "user://not_pro_skater.cfg"
const OLD_SAVE_PATH: String = "user://not_pro_skaters.cfg"     # before the rename to Not Pro Skater (2026-09-30)

var best: Dictionary = {}          # level id -> {"score": int, "combo": int}
var steer_mode: String = "tank"    # "tank" = skater steering (A/D turn, W push), "screen" = stick points where you go
var jump_mode: String = "hold"   # "hold" = crouch while held, jump on release (hold longer = higher); "tap" = jump on press
var music_choice: String = "cruise"   # "cruise" (125 BPM), "hype" (131) or "off"; see docs/audio_credits_music.md
var master_volume: float = 0.8
var rider: String = "dev"          # the playable character (assets/characters/<rider>.glb)
var stance: String = "regular"     # "regular" (left foot forward) or "goofy" (right foot forward): RiderRig.goofy
var event_choice: String = "birthday"   # the event the title menu's EVENT row is on
var level_choice: String = "park"       # the level the title menu's FREE SKATE row is on


## The playable archetypes (assets/characters/<key>.glb). Inspired by people who skate but never went pro;
## original characters, not likenesses.
const RIDERS: Array[String] = ["dev", "musician", "vlogger", "dad", "actor"]
const RIDER_INFO: Dictionary = {
	"dev": {"name": "The Dev", "blurb": "Ships code by day. Skates the office car park after stand-up."},
	"musician": {"name": "The Musician", "blurb": "Tours with a board in the van. Every loading dock is a ledge."},
	"vlogger": {"name": "The Vlogger", "blurb": "Films everything. One take, no bails, like and subscribe."},
	"dad": {"name": "The Dad", "blurb": "Picked it back up at forty. Birthday parties are home turf."},
	"actor": {"name": "The Actor", "blurb": "Between takes, the studio backlot is a skatepark."},
}


static func rider_name(key: String) -> String:
	return String(RIDER_INFO.get(key, {}).get("name", key.capitalize()))


const PREVIEW_SCENES: Dictionary = {"greybox": "res://scenes/greybox.tscn"}


var _fade: ColorRect
var _going: bool = false
var _loading: Label
var _dl: VBoxContainer                 # a level pack download: the level's name, progress, a bar (web)
var _dl_name: Label
var _dl_note: Label
var _dl_fill: ColorRect
const DL_BAR_W: float = 420.0
# update check (desktop builds): once a day, ask GitHub for the latest release; a newer one shows on the title menu
signal update_found(tag: String)
signal update_checked(ok: bool)              # a check finished (ok: GitHub answered)
const RELEASES_API: String = "https://api.github.com/repos/TinyBitAdventures/not-pro-skater/releases/latest"
const UPDATE_EVERY: int = 86400              # seconds between checks
var check_updates: bool = true               # saved; false: never ask (edit the save, [update] check=false)
var update_tag: String = ""                  # a newer release than this build ("v0.2.0"), once one is found
var update_url: String = ""                  # its release page
var update_checked_at: int = 0               # unix time of the last answer from GitHub
var last_release: Dictionary = {}            # GitHub's last answer (for the update test)
var _update_http: HTTPRequest = null
const UI_BASE: Vector2 = Vector2(1600, 900)   # the UI is laid out for this size and scales with the window...
const UI_MIN_SCALE: float = 0.75              # ...but no smaller than this: small windows (a web embed) get more room instead


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.02, 0.02, 0.03, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_loading = UiKit.label("LOADING", 22, UiKit.MUTED, "bold")
	_loading.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_loading.grow_horizontal = Control.GROW_DIRECTION_BEGIN     # right-aligned: "DOWNLOADING ... 42%" grows left
	_loading.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_loading.offset_right = -64.0
	_loading.offset_bottom = -40.0
	_loading.visible = false
	layer.add_child(_loading)
	_dl = VBoxContainer.new()
	_dl.set_anchors_preset(Control.PRESET_CENTER)
	_dl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dl.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dl.add_theme_constant_override("separation", 10)
	_dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dl.visible = false
	layer.add_child(_dl)
	_dl_name = UiKit.label("", 52, UiKit.PAPER, "display")
	_dl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dl.add_child(_dl_name)
	var bar: ColorRect = ColorRect.new()
	bar.custom_minimum_size = Vector2(DL_BAR_W, 6)
	bar.color = Color(UiKit.PAPER, 0.15)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dl.add_child(bar)
	_dl_fill = ColorRect.new()
	_dl_fill.color = UiKit.ACCENT
	_dl_fill.size = Vector2(0, 6)
	bar.add_child(_dl_fill)
	_dl_note = UiKit.label("", 22, UiKit.MUTED, "bold")
	_dl_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dl.add_child(_dl_note)
	get_tree().root.size_changed.connect(_fit_ui)
	_fit_ui()
	load_save()
	# web: index.html?scene=<event id>, park, school, ... or greybox opens that scene straight away; desktop builds
	# take the same as a user argument: NotProSkater -- --scene=rushhour
	var q: Variant = ""
	if OS.has_feature("web"):
		q = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('scene') || ''")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			q = a.trim_prefix("--scene=")
	if typeof(q) == TYPE_STRING and preview_scene(q) != "":
		go.call_deferred(preview_scene(q))
	if update_tag != "" and not newer_version(update_tag, version()):
		update_tag = ""                      # this build is that release (or newer): updated
		update_url = ""
	if _may_check_updates() and Time.get_unix_time_from_system() - update_checked_at >= UPDATE_EVERY:
		check_for_update.call_deferred()


## Below UI_MIN_SCALE the UI's canvas shrinks instead of the text: at 960x540 it's laid out for 1280x720, so text
## reads at 75% of its design size, not 60%.
func _fit_ui() -> void:
	var root: Window = get_tree().root
	if root.size.x <= 0 or root.size.y <= 0:     # minimized
		return
	var s: float = minf(root.size.x / UI_BASE.x, root.size.y / UI_BASE.y)
	var base: Vector2i = Vector2i((UI_BASE * minf(1.0, s / UI_MIN_SCALE)).round())
	if root.content_scale_size != base:
		root.content_scale_size = base


## This build's version (project.godot application/config/version), e.g. "0.1.0".
static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## True when release tag `a` ("v0.2.0", "0.2.0", "v1.0.0-beta") is a later version than `b`. Compares the numbers
## only: a suffix after "-" is ignored.
static func newer_version(a: String, b: String) -> bool:
	var pa: PackedStringArray = a.strip_edges().trim_prefix("v").split("-")[0].split(".")
	var pb: PackedStringArray = b.strip_edges().trim_prefix("v").split("-")[0].split(".")
	for i in maxi(pa.size(), pb.size()):
		var x: int = int(pa[i]) if i < pa.size() else 0
		var y: int = int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false


## Exported desktop builds check; the web build is always the latest, and dev and test runs (the editor binary)
## never go online unless asked to with a user argument: godot --path . -- --check-updates
func _may_check_updates() -> bool:
	if not check_updates or OS.has_feature("web") or is_dev_run():
		return false
	return OS.has_feature("template") or OS.get_cmdline_user_args().has("--check-updates")


## Ask GitHub for the latest release. Quiet on any failure (offline, rate limited): the next launch tries again.
func check_for_update() -> void:
	if _update_http != null:
		return
	_update_http = HTTPRequest.new()
	_update_http.timeout = 15.0
	add_child(_update_http)
	_update_http.request_completed.connect(_on_release_answer)
	var err: int = _update_http.request(RELEASES_API, ["User-Agent: NotProSkater/" + version(),
		"Accept: application/vnd.github+json"])
	if err != OK:
		_on_release_answer(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


func _on_release_answer(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _update_http != null:
		_update_http.queue_free()
		_update_http = null
	var data: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if typeof(data) != TYPE_DICTIONARY:
		update_checked.emit(false)
		return
	last_release = data as Dictionary
	apply_release(last_release, version())
	update_checked_at = int(Time.get_unix_time_from_system())
	save()
	update_checked.emit(true)


## What GitHub said the latest release is: remember it if it's newer than `current` (and tell the title menu).
func apply_release(release: Dictionary, current: String) -> void:
	var tag: String = String(release.get("tag_name", ""))
	if tag == "" or bool(release.get("draft", false)) or bool(release.get("prerelease", false)) or not newer_version(tag, current):
		update_tag = ""
		update_url = ""
		return
	var url: String = String(release.get("html_url", ""))
	if not url.begins_with("https://github.com/"):
		url = "https://github.com/TinyBitAdventures/not-pro-skater/releases/latest"
	var was: String = update_tag
	update_tag = tag
	update_url = url
	if tag != was:
		update_found.emit(tag)


## The scene a web preview link (?scene=...) opens: an event id, a Free Skate level id, or a dev scene.
static func preview_scene(q: String) -> String:
	if PREVIEW_SCENES.has(q):
		return PREVIEW_SCENES[q]
	if Events.ALL.has(q):
		return Events.scene(q)
	for lv in Events.LEVELS:
		if lv["id"] == q:
			return lv["scene"]
	return ""


## Change scene behind a quick fade to black and back ("" reloads the current scene).
func go(path: String) -> void:
	if _going:
		return
	_going = true
	var out: Tween = create_tween()
	out.tween_property(_fade, "color:a", 1.0, 0.22)
	await out.finished
	get_tree().paused = false
	Sound.set_paused(false)
	# loading blocks (the web build has no threads): draw the note first, then load
	_loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	# web: a level that isn't in the main package comes as its own resource pack, fetched the first time
	var level: String = Events.level_of_scene(path)
	if level != "" and not ResourceLoader.exists(level):
		if not await _fetch_pack(level):
			_loading.text = "COULDN'T LOAD %s. CHECK THE CONNECTION." % Events.level_name(level).to_upper()
			await get_tree().create_timer(2.5).timeout
			_loading.text = "LOADING"
			path = "res://scenes/title.tscn"
	if path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_loading.visible = false
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.4)
	_going = false


## Download levels/<level>.pck (next to index.html) and mount it. Shows progress on the loading note.
func _fetch_pack(level_gltf: String) -> bool:
	var pack: String = level_gltf.get_file().get_basename()
	var base: String = "levels/"
	if OS.has_feature("web"):
		var b: Variant = JavaScriptBridge.eval("new URL('levels/', document.baseURI).href")
		if typeof(b) == TYPE_STRING:
			base = String(b)
	var url: String = base + pack + ".pck?v=" + String(ProjectSettings.get_setting("application/config/version", "0"))
	var http: HTTPRequest = HTTPRequest.new()
	http.use_threads = false
	http.timeout = 90.0                              # a stalled connection fails to the title instead of hanging
	http.download_chunk_size = 4 * 1024 * 1024      # read per frame: the default 64 KB caps a 15 MB pack at ~4 MB/s
	add_child(http)
	var result: Array = []
	http.request_completed.connect(func(r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		result.append_array([r, code, body]))
	if http.request(url) != OK:
		http.queue_free()
		return false
	_dl_name.text = Events.level_name(level_gltf).to_upper()
	_dl.visible = true
	_loading.visible = false
	var t: float = 0.0
	while result.is_empty():
		var total: int = http.get_body_size()
		var got: int = http.get_downloaded_bytes()
		t += get_process_delta_time()
		if total > 0:
			_dl_fill.position.x = 0.0
			_dl_fill.size.x = DL_BAR_W * clampf(float(got) / total, 0.0, 1.0)
			_dl_note.text = "DOWNLOADING THE LEVEL  %d%%" % int(100.0 * got / total)
		else:                                  # no size given (the web often doesn't say): a sliding bar
			_dl_fill.size.x = DL_BAR_W * 0.25
			_dl_fill.position.x = (0.5 + 0.5 * sin(t * 2.4)) * DL_BAR_W * 0.75
			_dl_note.text = "DOWNLOADING THE LEVEL  %.1f MB" % (got / 1000000.0)
		await get_tree().process_frame
	http.queue_free()
	_dl.visible = false
	_loading.visible = true
	_loading.text = "LOADING"
	var data: PackedByteArray = result[2]
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200 or data.is_empty():
		push_warning("level pack %s: request result %d, HTTP %d, %d bytes" % [url, int(result[0]), int(result[1]), data.size()])
		return false
	# the body comes in memory and is written out here: HTTPRequest.download_file left an empty file on the web's
	# filesystem
	DirAccess.make_dir_recursive_absolute("user://packs")
	var file: String = "user://packs/%s.pck" % pack
	var f: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		push_warning("level pack %s: can't write (%d)" % [file, FileAccess.get_open_error()])
		return false
	f.store_buffer(data)
	f.close()
	if not ProjectSettings.load_resource_pack(file) or not ResourceLoader.exists(level_gltf):
		push_warning("level pack %s (%d bytes) didn't mount %s" % [file, data.size(), level_gltf])
		return false
	return true


func is_dev_run() -> bool:
	if OS.get_environment("SHOT") != "":       # screenshot runs of real scenes: the player's save stays out of them
		return true
	for a in OS.get_cmdline_args():
		if a.contains("scenes/dev_"):
			return true
	return false


func load_save() -> void:
	if is_dev_run():
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK and cfg.load(OLD_SAVE_PATH) != OK:
		return
	best = cfg.get_value("progress", "best", {})
	goals = cfg.get_value("progress", "goals", {})
	var save_version: int = int(cfg.get_value("settings", "version", 1))
	if save_version >= 2:
		steer_mode = cfg.get_value("settings", "steer_mode", "tank")
		music_choice = cfg.get_value("settings", "music_choice", "cruise")
	if save_version >= 3:
		# v3 reset a jump_mode of "tap" that was saved by accident from the title menu
		jump_mode = cfg.get_value("settings", "jump_mode", "hold")
	master_volume = cfg.get_value("settings", "master_volume", 0.8)
	rider = cfg.get_value("settings", "rider", "dev")
	stance = cfg.get_value("settings", "stance", "regular")
	event_choice = cfg.get_value("settings", "event_choice", "birthday")
	if not Events.ALL.has(event_choice):
		event_choice = "birthday"
	level_choice = cfg.get_value("settings", "level_choice", "park")
	# a corrupt or future save must not leave a value the menus can't show (a missing rider can't even load)
	if not RIDERS.has(rider):
		rider = "dev"
	if not ["cruise", "hype", "off"].has(music_choice):
		music_choice = "cruise"
	if not ["tank", "screen"].has(steer_mode):
		steer_mode = "tank"
	if not ["hold", "tap"].has(jump_mode):
		jump_mode = "hold"
	if not ["regular", "goofy"].has(stance):
		stance = "regular"
	if not Events.LEVELS.any(func(lv: Dictionary) -> bool: return lv["id"] == level_choice):
		level_choice = "park"
	master_volume = clampf(float(master_volume), 0.0, 1.0)
	check_updates = bool(cfg.get_value("update", "check", true))
	update_checked_at = int(cfg.get_value("update", "checked_at", 0))
	update_tag = String(cfg.get_value("update", "tag", ""))
	update_url = String(cfg.get_value("update", "url", ""))
	if not update_url.begins_with("https://github.com/"):
		update_tag = ""
		update_url = ""


func save() -> void:
	if is_dev_run():
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("progress", "best", best)
	cfg.set_value("progress", "goals", goals)
	cfg.set_value("settings", "version", 3)
	cfg.set_value("settings", "steer_mode", steer_mode)
	cfg.set_value("settings", "jump_mode", jump_mode)
	cfg.set_value("settings", "music_choice", music_choice)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "rider", rider)
	cfg.set_value("settings", "stance", stance)
	cfg.set_value("settings", "event_choice", event_choice)
	cfg.set_value("settings", "level_choice", level_choice)
	cfg.set_value("update", "check", check_updates)
	cfg.set_value("update", "checked_at", update_checked_at)
	cfg.set_value("update", "tag", update_tag)
	cfg.set_value("update", "url", update_url)
	cfg.save(SAVE_PATH)


var goals: Dictionary = {}         # event id -> {goal id: true}


func event_goals(event_id: String) -> Dictionary:
	return goals.get(event_id, {}).duplicate()


func record_goal(event_id: String, goal_id: String) -> void:
	var g: Dictionary = goals.get(event_id, {})
	g[goal_id] = true
	goals[event_id] = g
	save()


func record(level_id: String, score: int, combo: int) -> bool:
	var b: Dictionary = best.get(level_id, {})
	var old_score: int = int(b.get("score", 0))
	var new_best: bool = score > old_score
	b["score"] = maxi(score, old_score)
	b["combo"] = maxi(combo, int(b.get("combo", 0)))
	best[level_id] = b
	save()
	return new_best
