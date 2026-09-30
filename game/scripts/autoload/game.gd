extends Node
## Settings and saved bests. Dev scenes (anything launched from scenes/dev_*) never touch the real save.

const SAVE_PATH: String = "user://not_pro_skaters.cfg"

var best: Dictionary = {}          # level id -> {"score": int, "combo": int}
var steer_mode: String = "tank"    # "tank" = skater steering (A/D turn, W push), "screen" = stick points where you go
var jump_mode: String = "hold"   # "hold" = crouch while held, jump on release (hold longer = higher); "tap" = jump on press
var music_choice: String = "cruise"   # "cruise" (Grip Tape Summer), "hype" (Rail Rush) or "off"
var camera_mode: String = "follow" # "follow" swings behind the skater, "fixed" keeps one isometric angle
var master_volume: float = 0.8
var free_skate: bool = false       # no timer: just cruise and practise
var rider: String = "dev"          # the playable character (assets/characters/<rider>.glb)


const PREVIEW_SCENES: Dictionary = {
	"greybox": "res://scenes/greybox.tscn",
	"birthday": "res://scenes/birthday.tscn",
	"park": "res://scenes/neighborhood.tscn",
}


func _ready() -> void:
	load_save()
	# web: index.html?scene=greybox (or birthday, park) opens that scene straight away
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('scene') || ''")
		if typeof(q) == TYPE_STRING and PREVIEW_SCENES.has(q):
			get_tree().change_scene_to_file.call_deferred(PREVIEW_SCENES[q])


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
		camera_mode = cfg.get_value("settings", "camera_mode", "follow")
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
	cfg.set_value("settings", "camera_mode", camera_mode)
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
