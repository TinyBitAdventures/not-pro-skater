extends Node
## Settings and saved bests. Dev scenes (anything launched from scenes/dev_*) never touch the real save.

const SAVE_PATH: String = "user://not_pro_skater.cfg"
const OLD_SAVE_PATH: String = "user://not_pro_skaters.cfg"     # before the rename to Not Pro Skater (2026-09-30)

var best: Dictionary = {}          # level id -> {"score": int, "combo": int}
var steer_mode: String = "tank"    # "tank" = skater steering (A/D turn, W push), "screen" = stick points where you go
var jump_mode: String = "hold"   # "hold" = crouch while held, jump on release (hold longer = higher); "tap" = jump on press
var music_choice: String = "cruise"   # "cruise" (125 BPM), "hype" (131) or "off"; see docs/audio_credits_music.md
var master_volume: float = 0.8
var music_volume: float = 1.0      # on top of the music bus's own level (Options)
var sfx_volume: float = 1.0        # sound effects and ambience
var window_mode: String = "windowed"   # "windowed" or "fullscreen" (Alt+Enter / F11 toggle it anywhere)
var vsync: bool = true
var quality: String = "high"       # "high", "medium" or "low": anti-aliasing and shadow detail (QUALITY)
var camera_shake: bool = true      # a crash shakes the camera
var combo_rules: String = "standard"   # "standard" or "relaxed" (ScoreKeeper: the old, forgiving window)
var tutorial_done: bool = false    # Learn to Skate finished (the title stops suggesting it)
var rider: String = "dev"          # the playable character (assets/characters/<rider>.glb)
var stance: String = "own"         # "own" (each rider's, RiderProfiles), "regular" (left foot forward) or "goofy"
var stat_spent: Dictionary = {}    # rider -> {stat: points spent raising it} (RiderProfiles; points come from goals)
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
## Quality presets: MSAA (Viewport.MSAA_*), the sun's shadow map size and how soft its edges are filtered.
const QUALITY: Dictionary = {
	"high": {"msaa": Viewport.MSAA_4X, "shadow": 4096, "soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH},
	"medium": {"msaa": Viewport.MSAA_2X, "shadow": 2048, "soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW},
	"low": {"msaa": Viewport.MSAA_DISABLED, "shadow": 2048, "soft": RenderingServer.SHADOW_QUALITY_HARD},
}
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
	apply_display()
	apply_quality()
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


## Window or fullscreen, and vsync, as set (Options). Dev and test runs keep the window they were started with.
func apply_display() -> void:
	if is_dev_run() or DisplayServer.get_name() == "headless":
		return
	var full: bool = window_mode == "fullscreen"
	var now: int = DisplayServer.window_get_mode()
	var is_full: bool = now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


## Anti-aliasing and shadow detail for the quality preset (QUALITY).
func apply_quality() -> void:
	var q: Dictionary = QUALITY[quality]
	get_tree().root.msaa_3d = int(q["msaa"])
	RenderingServer.directional_shadow_atlas_set_size(int(q["shadow"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(q["soft"]))


## Alt+Enter or F11: fullscreen and back, anywhere (and remembered).
func toggle_fullscreen() -> void:
	window_mode = "windowed" if window_mode == "fullscreen" else "fullscreen"
	apply_display()
	save()


func _input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_F11 or (k.physical_keycode == KEY_ENTER and k.alt_pressed):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


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
	music_volume = clampf(float(cfg.get_value("settings", "music_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("settings", "sfx_volume", 1.0)), 0.0, 1.0)
	window_mode = String(cfg.get_value("settings", "window_mode", "windowed"))
	vsync = bool(cfg.get_value("settings", "vsync", true))
	quality = String(cfg.get_value("settings", "quality", "high"))
	camera_shake = bool(cfg.get_value("settings", "camera_shake", true))
	combo_rules = String(cfg.get_value("settings", "combo_rules", "standard"))
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	rider = cfg.get_value("settings", "rider", "dev")
	stance = cfg.get_value("settings", "stance", "own")
	stat_spent = _valid_spent(cfg.get_value("progress", "stat_spent", {}))
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
	if not ["own", "regular", "goofy"].has(stance):
		stance = "own"
	if not ["windowed", "fullscreen"].has(window_mode):
		window_mode = "windowed"
	if not QUALITY.has(quality):
		quality = "high"
	if not ["standard", "relaxed"].has(combo_rules):
		combo_rules = "standard"
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
	cfg.set_value("settings", "version", 4)
	cfg.set_value("settings", "steer_mode", steer_mode)
	cfg.set_value("settings", "jump_mode", jump_mode)
	cfg.set_value("settings", "music_choice", music_choice)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "window_mode", window_mode)
	cfg.set_value("settings", "vsync", vsync)
	cfg.set_value("settings", "quality", quality)
	cfg.set_value("settings", "camera_shake", camera_shake)
	cfg.set_value("settings", "combo_rules", combo_rules)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("settings", "rider", rider)
	cfg.set_value("settings", "stance", stance)
	cfg.set_value("progress", "stat_spent", stat_spent)
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


## Stat points: every event goal done (by anyone) gives each rider a point to spend on their own stats.
func stat_points_earned() -> int:
	var n: int = 0
	for e in goals:
		n += (goals[e] as Dictionary).size()
	return n


func stat_points_free(key: String) -> int:
	var used: int = 0
	for v in (stat_spent.get(key, {}) as Dictionary).values():
		used += int(v)
	return stat_points_earned() - used


## The rider's stats now: their own plus the points spent.
func rider_stats(key: String) -> Dictionary:
	return RiderProfiles.with_spent(key, stat_spent.get(key, {}))


## Raise a stat a point (`step` 1, while there are points and room) or take a spent point back (`step` -1).
## Returns whether it changed.
func spend_stat(key: String, stat: String, step: int) -> bool:
	var spent: Dictionary = (stat_spent.get(key, {}) as Dictionary).duplicate()
	var have: int = int(spent.get(stat, 0))
	var now: int = int(rider_stats(key)[stat])
	if step > 0 and (stat_points_free(key) <= 0 or now >= RiderProfiles.MAX):
		return false
	if step < 0 and have <= 0:
		return false
	spent[stat] = have + step
	if int(spent[stat]) == 0:
		spent.erase(stat)
	stat_spent[key] = spent
	save()
	return true


## Right foot forward? The stance setting, or the rider's own.
func rider_goofy(key: String) -> bool:
	if stance == "own":
		return String(RiderProfiles.profile(key)["stance"]) == "goofy"
	return stance == "goofy"


## Who the skater is for play: stats and the scoring style. (Stance and push style are drawn for every skater,
## Skater._make_visual.) Dev scenes and screenshot runs keep the tuning as it is unless PROFILE=1.
func apply_rider_profile(sk: Skater) -> void:
	if is_dev_run() and OS.get_environment("PROFILE") == "":
		return
	sk.rider_stats = rider_stats(sk.rider)
	var p: Dictionary = RiderProfiles.profile(sk.rider)
	sk.terrain = String(p["terrain"])
	sk.signature = (p["signature"] as Array).duplicate()


## A save's spent points, kept to riders and stats that exist (a corrupt or future save must not break the menu).
static func _valid_spent(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (v is Dictionary):
		return out
	for key in v:
		if not RIDERS.has(String(key)) or not (v[key] is Dictionary):
			continue
		var d: Dictionary = {}
		for stat in v[key]:
			if RiderProfiles.STATS.has(String(stat)) and int(v[key][stat]) > 0:
				d[String(stat)] = int(v[key][stat])
		out[String(key)] = d
	return out


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
