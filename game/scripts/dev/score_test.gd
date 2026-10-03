extends Node
## The combo rules (ScoreKeeper), standard and relaxed, without physics:
##   godot --headless --path . res://scenes/dev_score.tscn
## The window rolling on the ground keeps a combo alive for, a sketchy landing's cut to the multiplier, repeats
## paying less, holds keeping a combo alive, a bail losing it. Exit code = failures.

var fails: int = 0


func _ready() -> void:
	_window(false, ScoreKeeper.WINDOW)
	_window(true, ScoreKeeper.WINDOW_RELAXED)
	_sketchy()
	_repeats()
	_busy_and_bail()
	print("[score] %d failure(s)" % fails)
	get_tree().quit(fails)


func _check(what: String, ok: bool) -> void:
	print("[score] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _keeper(relaxed: bool) -> ScoreKeeper:
	var s: ScoreKeeper = ScoreKeeper.new()
	s.relaxed = relaxed
	return s


func _roll(s: ScoreKeeper, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds - 1e-6:
		s.tick(1.0 / 120.0, false)
		t += 1.0 / 120.0


func _window(relaxed: bool, w: float) -> void:
	var s: ScoreKeeper = _keeper(relaxed)
	s.add_trick("Kickflip", 100)
	s.landed()
	_roll(s, w - 0.1)
	_check("%s: still live %.2f s after landing" % ["relaxed" if relaxed else "standard", w - 0.1], s.live)
	_roll(s, 0.15)
	_check("%s: banked once the %.2f s window ran out (score %d)" % ["relaxed" if relaxed else "standard", w, s.score],
		not s.live and s.score == 100)


func _sketchy() -> void:
	var s: ScoreKeeper = _keeper(false)
	for t in ["Kickflip", "Indy", "50-50"]:
		s.add_trick(t, 100)
	var cuts: Array = [0]
	s.cut.connect(func() -> void: cuts[0] += 1)
	s.sketchy()
	_check("standard: a sketchy landing takes x3 to x2 (x%d)" % s.mult, s.mult == 2 and cuts[0] == 1)
	s.add_trick("Heelflip", 100)
	_check("standard: a new trick after it counts again: x3 (x%d)" % s.mult, s.mult == 3)
	for i in 5:
		s.sketchy()
	_check("standard: never below x1 (x%d)" % s.mult, s.mult == 1)
	s.bank()
	s.add_trick("Kickflip", 100)
	_check("standard: the cut ends with the combo (x%d)" % s.mult, s.mult == 1 and s.names.size() == 1)
	s.add_trick("Indy", 100)
	_check("standard: next combo multiplies in full (x%d)" % s.mult, s.mult == 2)
	var r: ScoreKeeper = _keeper(true)
	r.add_trick("Kickflip", 100)
	r.add_trick("Indy", 100)
	r.sketchy()
	_check("relaxed: a sketchy landing costs nothing (x%d)" % r.mult, r.mult == 2)


func _repeats() -> void:
	var s: ScoreKeeper = _keeper(false)
	s.add_trick("Kickflip", 100)
	s.add_trick("Kickflip", 100)
	s.add_trick("Kickflip", 100)
	_check("repeats pay 50%%, then 25%% (pending %d, x%d)" % [s.pending, s.mult], s.pending == 175 and s.mult == 1)


func _busy_and_bail() -> void:
	var s: ScoreKeeper = _keeper(false)
	s.add_trick("Manual", 100)
	for i in 600:
		s.tick(1.0 / 120.0, true)                 # five seconds in a manual
	_check("a manual keeps the combo alive however long", s.live)
	var lost: Array = [0]
	s.lost.connect(func() -> void: lost[0] += 1)
	s.bail()
	_check("a bail loses the combo (score %d)" % s.score, not s.live and s.score == 0 and lost[0] == 1)
