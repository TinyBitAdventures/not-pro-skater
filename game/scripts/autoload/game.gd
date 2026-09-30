extends Node
## Settings and saved bests. Dev scenes (anything launched from scenes/dev_*) never touch the real save.

const SAVE_PATH: String = "user://not_pro_skaters.cfg"

var best: Dictionary = {}          # level id -> {"score": int, "combo": int}
var steer_mode: String = "tank"    # "tank" = skater steering (A/D turn, W push), "screen" = stick points where you go
var jump_mode: String = "hold"   # "hold" = crouch while held, jump on release (hold longer = higher); "tap" = jump on press
var music_choice: String = "cruise"   # "cruise" (125 BPM), "hype" (131) or "off"; see docs/AUDIO_CREDITS_music.md
var master_volume: float = 0.8
var rider: String = "dev"          # the playable character (assets/characters/<rider>.glb)


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


const PREVIEW_SCENES: Dictionary = {
	"greybox": "res://scenes/greybox.tscn",
	"birthday": "res://scenes/birthday.tscn",
	"park": "res://scenes/neighborhood.tscn",
}


var _fade: ColorRect
var _going: bool = false
var _loading: Label


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
	_loading.position = Vector2(-150, -64)
	_loading.visible = false
	layer.add_child(_loading)
	load_save()
	# web: index.html?scene=greybox (or birthday, park) opens that scene straight away
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('scene') || ''")
		if typeof(q) == TYPE_STRING and PREVIEW_SCENES.has(q):
			get_tree().change_scene_to_file.call_deferred(PREVIEW_SCENES[q])


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


func is_dev_run() -> bool:
	for a in OS.get_cmdline_args():
		if a.contains("scenes/dev_"):
			return true
	return false


func load_save() -> void:
	if is_dev_run():
		return
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best = cfg.get_value("progress", "best", {})
	goals = cfg.get_value("progress", "goals", {})
	var version: int = int(cfg.get_value("settings", "version", 1))
	if version >= 2:
		steer_mode = cfg.get_value("settings", "steer_mode", "tank")
		music_choice = cfg.get_value("settings", "music_choice", "cruise")
	if version >= 3:
		# v3 reset a jump_mode of "tap" that was saved by accident from the title menu
		jump_mode = cfg.get_value("settings", "jump_mode", "hold")
	master_volume = cfg.get_value("settings", "master_volume", 0.8)
	rider = cfg.get_value("settings", "rider", "dev")


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
