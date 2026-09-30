class_name ScoreKeeper
extends RefCounted
## Combo rules: tricks pile up as "pending" points, the multiplier is the number of different tricks
## in the chain, and landing then leaving the combo idle for a moment banks it. A bail loses the pile.

signal changed
signal banked(points: int, combo_len: int)
signal lost
signal trick_added(trick_name: String, points: int)
signal awarded(award_name: String, points: int)   # points paid straight into the score (an event's lap, its one take)

const WINDOW: float = 1.25
const HOLD_CAP_SECONDS: float = 4.0   # one combo pays at most this many seconds of each hold (manual/grab/grind)

var score: int = 0
var pending: int = 0
var mult: int = 1
var names: Array[String] = []
var best_combo: int = 0
var best_trick: int = 0
var trick_count: int = 0
var live: bool = false           # a combo exists
var hold_kind: String = ""       # what is being held right now: grind / manual / grab
var _window: float = 0.0
var _hold_acc: float = 0.0
var _hold_paid: Dictionary = {}
var _seen: Dictionary = {}


func reset() -> void:
	score = 0
	best_combo = 0
	best_trick = 0
	trick_count = 0
	_clear()
	changed.emit()


func _clear() -> void:
	pending = 0
	mult = 1
	names.clear()
	live = false
	hold_kind = ""
	_window = 0.0
	_hold_acc = 0.0
	_hold_paid.clear()
	_seen.clear()


func add_trick(trick_name: String, points: int) -> void:
	var pts: int = points
	if _seen.has(trick_name):
		pts = int(points * 0.5 / float(_seen[trick_name]))   # repeats are worth less each time
		_seen[trick_name] += 1
	else:
		_seen[trick_name] = 1
		mult = _seen.size()
	names.append(trick_name)
	pending += pts
	trick_added.emit(trick_name, pts)
	best_trick = maxi(best_trick, pts)
	trick_count += 1
	live = true
	_window = 0.0
	changed.emit()


## Points for something that isn't a trick (a sponsored lap, a clean take): banked at once, outside any combo, so
## they aren't multiplied, halved as a repeat or lost in a bail.
func award(award_name: String, points: int) -> void:
	score += points
	awarded.emit(award_name, points)
	changed.emit()


func hold(kind: String, dt: float, rate: float) -> void:
	if not live:
		return
	hold_kind = kind                       # still "busy": keeps the combo alive, but stops paying at the cap
	var paid: float = _hold_paid.get(kind, 0.0)
	var room: float = rate * HOLD_CAP_SECONDS - paid
	if room <= 0.0:
		return
	var add: float = minf(rate * dt, room)
	_hold_paid[kind] = paid + add
	_hold_acc += add
	var whole: int = int(_hold_acc)
	if whole > 0:
		pending += whole
		_hold_acc -= whole
		changed.emit()


func release_hold(kind: String) -> void:
	if hold_kind == kind:
		hold_kind = ""


## Called when the skater is back on the ground and rolling (not mid-grind or manual).
func landed() -> void:
	if live:
		_window = WINDOW


func tick(dt: float, busy: bool) -> void:
	if not live:
		return
	if busy or hold_kind != "":
		_window = WINDOW
		return
	if _window > 0.0:
		_window -= dt
		if _window <= 0.0:
			bank()


func bank() -> void:
	if not live:
		return
	var total: int = pending * mult
	score += total
	best_combo = maxi(best_combo, total)
	banked.emit(total, names.size())
	_clear()
	changed.emit()


func bail() -> void:
	if live:
		lost.emit()
	_clear()
	changed.emit()


func combo_text() -> String:
	if names.is_empty():
		return ""
	var tail: Array[String] = names.slice(maxi(0, names.size() - 3))
	return " + ".join(tail)
