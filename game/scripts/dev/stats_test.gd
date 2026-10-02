extends Node3D
## Rider stats and style (RiderProfiles, Game's stat points, Skater's use of them):
##   godot --headless --path . --fixed-fps 120 res://scenes/dev_stats.tscn
## The profiles add up and name real tricks; a stat of 5 changes nothing; points come from goals and can be
## taken back; the style bonuses pay what they say; and the stats move the real physics: an ollie's height, a
## spin's speed, a flip's time, by the amounts in RiderProfiles. Exit code = failures.

var level: Level
var fails: int = 0


func _ready() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("[stats] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _run() -> void:
	Game.steer_mode = "screen"
	_profiles()
	_points()
	_style()
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/greybox.glb", "grey")
	await get_tree().physics_frame
	var h5: float = await _ollie_height({})
	var h10: float = await _ollie_height({"ollie": 10})
	var h1: float = await _ollie_height({"ollie": 1})
	_check("ollie 10 pops 8%% higher (%.3f / %.3f m = %.3f)" % [h10, h5, h10 / h5], absf(h10 / h5 - 1.08) < 0.015)
	_check("ollie 1 pops 8%% lower (%.3f / %.3f m = %.3f)" % [h1, h5, h1 / h5], absf(h1 / h5 - 0.92) < 0.015)
	var s5: float = await _spin_rate({})
	var s10: float = await _spin_rate({"spin": 10})
	_check("spin 10 spins 15%% faster (%.2f / %.2f rad/s)" % [s10, s5], absf(s10 / s5 - 1.15) < 0.02)
	var f5: float = await _flip_time({})
	var f10: float = await _flip_time({"flip": 10})
	_check("flip 10 flips 15%% quicker (%.3f / %.3f s)" % [f10, f5], absf(f10 / f5 - 0.85) < 0.03)
	print("[stats] %d failed" % fails)
	get_tree().quit(fails)


func _profiles() -> void:
	var names: Array = []
	for d in [Tricks.FLIPS, Tricks.GRABS]:
		for k in d:
			names.append(String(d[k][0]))
	names.append_array(Skater.GRIND_TIP.keys())
	for key in Game.RIDERS:
		var p: Dictionary = RiderProfiles.profile(key)
		var sum: int = 0
		var all_in: bool = true
		for stat in RiderProfiles.STATS:
			var v: int = int((p["stats"] as Dictionary).get(stat, 0))
			sum += v
			all_in = all_in and v >= 1 and v <= RiderProfiles.MAX
		_check("%s: every stat set, 1..10, adding up to 50 (%d)" % [key, sum], all_in and sum == 50 \
			and (p["stats"] as Dictionary).size() == RiderProfiles.STATS.size())
		var sig_ok: bool = (p["signature"] as Array).size() == 3
		for t in p["signature"]:
			sig_ok = sig_ok and names.has(String(t))
		_check("%s: a %s %s %s rider, signature tricks that exist %s" % [key, p["stance"], p["push"], p["terrain"],
			p["signature"]], sig_ok and ["regular", "goofy"].has(p["stance"]) and ["regular", "mongo"].has(p["push"]) \
			and RiderProfiles.TERRAIN_NAMES.has(p["terrain"]))
	_check("a stat of 5 changes nothing; 1 and 10 are the ends", RiderProfiles.at(5, 0.5, 1.0, 2.0) == 1.0 \
		and RiderProfiles.at(1, 0.5, 1.0, 2.0) == 0.5 and RiderProfiles.at(10, 0.5, 1.0, 2.0) == 2.0 \
		and absf(RiderProfiles.at(3, 0.5, 1.0, 2.0) - 0.75) < 0.001)


func _points() -> void:
	var was_goals: Dictionary = Game.goals
	var was_spent: Dictionary = Game.stat_spent
	Game.goals = {}
	Game.stat_spent = {}
	_check("no goals, no points", Game.stat_points_free("dad") == 0 and not Game.spend_stat("dad", "spin", 1))
	Game.goals = {"birthday": {"a": true, "b": true}, "skateathon": {"c": true}}
	_check("three goals, three points for every rider", Game.stat_points_free("dad") == 3 \
		and Game.stat_points_free("actor") == 3)
	var spin0: int = int(Game.rider_stats("dad")["spin"])
	Game.spend_stat("dad", "spin", 1)
	Game.spend_stat("dad", "spin", 1)
	_check("two spent on the Dad's spin (%d -> %d), one left, the Actor still has three" % [spin0,
		int(Game.rider_stats("dad")["spin"])], int(Game.rider_stats("dad")["spin"]) == spin0 + 2 \
		and Game.stat_points_free("dad") == 1 and Game.stat_points_free("actor") == 3)
	Game.spend_stat("dad", "spin", -1)
	_check("a point taken back", Game.stat_points_free("dad") == 2 and not Game.spend_stat("dad", "flip", -1))
	Game.goals = {"x": {}}
	for i in 30:
		Game.goals["x"]["g%d" % i] = true
	while Game.spend_stat("actor", "air", 1):
		pass
	_check("a stat stops at 10 (Air %d, %d points left)" % [int(Game.rider_stats("actor")["air"]),
		Game.stat_points_free("actor")], int(Game.rider_stats("actor")["air"]) == RiderProfiles.MAX)
	var bad: Dictionary = Game._valid_spent({"nobody": {"spin": 2}, "dad": {"spin": 2, "wings": 4, "air": -1}, "actor": 3})
	_check("a save's spent points keep only real riders and stats %s" % [bad], bad == {"dad": {"spin": 2}})
	Game.goals = was_goals
	Game.stat_spent = was_spent


func _style() -> void:
	var sk: Skater = Skater.new()
	sk.with_visual = false
	_check("no style: no bonus", sk.style_k("street", "Kickflip") == 1.0)
	sk.terrain = "street"
	sk.signature = ["Kickflip"]
	_check("street: +20% on the street, nothing on vert", is_equal_approx(sk.style_k("street"), 1.2) \
		and is_equal_approx(sk.style_k("vert"), 1.0))
	_check("a signature trick: +50% on top", is_equal_approx(sk.style_k("street", "Kickflip"), 1.8) \
		and is_equal_approx(sk.style_k("vert", "Kickflip"), 1.5))
	sk.terrain = "all"
	_check("all-round: +8% anywhere", is_equal_approx(sk.style_k("vert"), 1.08) and is_equal_approx(sk.style_k("street"), 1.08))
	sk.free()


func _skater(stats: Dictionary) -> Skater:
	var sk: Skater = Skater.new()
	sk.with_visual = false
	sk.scripted = true
	sk.grind_lines = level.grind_lines
	sk.rider_stats = stats
	add_child(sk)
	sk.place_at(level.starts["flat"])
	return sk


## The highest a pop from standing on the flat goes above where it started.
func _ollie_height(stats: Dictionary) -> float:
	var sk: Skater = _skater(stats)
	for i in 30:
		await get_tree().physics_frame
	var y0: float = sk.global_position.y
	sk.inp.ollie_pressed = true
	await get_tree().physics_frame
	sk.inp.ollie_pressed = false
	var top: float = 0.0
	for i in 240:
		await get_tree().physics_frame
		top = maxf(top, sk.global_position.y - y0)
		if i > 10 and sk.state == Skater.State.GROUND:
			break
	sk.queue_free()
	await get_tree().physics_frame
	return top


## How fast a spin settles with the stick held across, in the air.
func _spin_rate(stats: Dictionary) -> float:
	var sk: Skater = _skater(stats)
	for i in 30:
		await get_tree().physics_frame
	var side: Vector3 = sk.hdg.cross(Vector3.UP)
	sk.inp.ollie_pressed = true
	await get_tree().physics_frame
	sk.inp.ollie_pressed = false
	var top: float = 0.0
	for i in 70:
		sk.inp.world_dir = side if sk.state == Skater.State.AIR else Vector3.ZERO
		await get_tree().physics_frame
		top = maxf(top, absf(sk.spin_vel))
	sk.queue_free()
	await get_tree().physics_frame
	return top


## Seconds from the flip starting to its end, popped high enough not to land first.
func _flip_time(stats: Dictionary) -> float:
	var sk: Skater = _skater(stats)
	for i in 30:
		await get_tree().physics_frame
	sk.velocity = Vector3.UP * 12.0
	sk._enter_air()
	sk.inp.flip_pressed = true
	await get_tree().physics_frame
	sk.inp.flip_pressed = false
	var t: float = 0.0
	var started: bool = false
	for i in 240:
		await get_tree().physics_frame
		if sk.flip_kind != "":
			started = true
			t += 1.0 / Engine.physics_ticks_per_second
		elif started:
			break
	sk.queue_free()
	await get_tree().physics_frame
	return t
