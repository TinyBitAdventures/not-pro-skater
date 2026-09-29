extends Node
## Settings and saved bests. Dev scenes (anything launched from scenes/dev_*) never touch the real save.

const SAVE_PATH: String = "user://skate_park.cfg"

var best: Dictionary = {}          # level id -> {"score": int, "combo": int}
var steer_mode: String = "screen"  # "screen" (camera-relative) or "tank"
var master_volume: float = 0.8


func _ready() -> void:
	load_save()


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
	steer_mode = cfg.get_value("settings", "steer_mode", "screen")
	master_volume = cfg.get_value("settings", "master_volume", 0.8)


func save() -> void:
	if is_dev_run():
		return
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("progress", "best", best)
	cfg.set_value("settings", "steer_mode", steer_mode)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.save(SAVE_PATH)


func record(level_id: String, score: int, combo: int) -> bool:
	var b: Dictionary = best.get(level_id, {"score": 0, "combo": 0})
	var new_best: bool = score > int(b["score"])
	b["score"] = maxi(score, int(b["score"]))
	b["combo"] = maxi(combo, int(b["combo"]))
	best[level_id] = b
	save()
	return new_best
