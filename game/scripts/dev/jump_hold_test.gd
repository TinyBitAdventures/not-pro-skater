extends Node
## Holding Space through the real input path (key events, frame by frame) must never jump until it is let go,
## and the POP charge must not reset under a held key:
##   godot --headless --path . --fixed-fps 60 res://scenes/dev_jumphold.tscn        (exit code = failures)
## Each case holds Space for a while (with macOS-style key repeat: echo events every 33 ms after 250 ms) while
## something else happens: riding with W held, tapping other keys, rolling over a curb, tile seams, up a quarter
## pipe, onto a kicker. Counts jumps while held and charge drops while held on the ground.

var world: Node3D
var sk: Skater
var ollies: int = 0
var fails: int = 0


func _ready() -> void:
	_run.call_deferred()


func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	e.echo = echo
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _settle() -> void:
	for i in 240:
		await get_tree().process_frame
		if sk.state == Skater.State.GROUND and sk.air_time == 0.0 and sk.is_on_floor():
			break
	await _frames(6)


## Hold Space for `frames` frames; `during(frame)` runs every frame. Returns [jumps while held, charge drops].
func _hold(frames: int, during: Callable) -> Array:
	var before: int = ollies
	var drops: int = 0
	var last_charge: float = 0.0
	_key(KEY_SPACE, true)
	for f in frames:
		if f > 15 and f % 2 == 0:
			_key(KEY_SPACE, true, true)          # key repeat
		during.call(f)
		await get_tree().process_frame
		if sk.state == Skater.State.GROUND:
			if sk.charge + 0.001 < last_charge and last_charge > 0.1:
				drops += 1
			last_charge = sk.charge
		else:
			last_charge = 0.0
	var jumped: int = ollies - before
	_key(KEY_SPACE, false)
	await _frames(40)
	return [jumped, drops]


func _case(name: String, lane: int, speed: float, frames: int, during: Callable) -> void:
	world.warp(lane)
	sk.velocity = sk.hdg * speed
	await _settle()
	var r: Array = await _hold(frames, during)
	var ok: bool = r[0] == 0
	if not ok:
		fails += 1
	print("[hold] %s  %-34s jumps while held %d, charge resets while held %d" % ["PASS" if ok else "FAIL", name, r[0], r[1]])


func _run() -> void:
	Game.jump_mode = "hold"
	world = (load("res://scenes/greybox.tscn") as PackedScene).instantiate()
	add_child(world)
	await _frames(10)
	sk = world.skater
	sk.sfx.connect(func(kind: String) -> void:
		if kind == "ollie":
			ollies += 1)
	var idx: Callable = func(n: String) -> int: return world.start_names.find(n)
	var nothing: Callable = func(_f: int) -> void: pass
	var push_w: Callable = func(f: int) -> void:
		if f == 0:
			_key(KEY_W, true)
		if f == 170:
			_key(KEY_W, false)
	var tap_keys: Callable = func(f: int) -> void:
		for k in [[KEY_W, 10], [KEY_A, 40], [KEY_D, 70], [KEY_SHIFT, 100], [KEY_W, 130]]:
			if f == k[1]:
				_key(k[0], true)
			if f == k[1] + 12:
				_key(k[0], false)
	await _case("flat, standing still", idx.call("flat"), 0.0, 180, nothing)
	await _case("flat, rolling 8 m/s", idx.call("flat"), 8.0, 180, nothing)
	await _case("flat, pushing with W held", idx.call("flat"), 3.0, 180, push_w)
	await _case("flat, tapping W A D Shift", idx.call("flat"), 6.0, 180, tap_keys)
	await _case("tile seams", idx.call("seam"), 9.0, 180, nothing)
	await _case("over the curb", idx.call("curb"), 7.0, 180, nothing)
	await _case("up the quarter pipe", idx.call("qp"), 10.0, 240, nothing)
	await _case("onto the kicker", idx.call("kicker"), 9.0, 180, nothing)
	await _case("manual with Space held", idx.call("flat"), 7.0, 150, func(f: int) -> void:
		if f == 20:
			sk._start_manual("manual"))
	# on a rail: press and hold Space during the grind; it must pop off on release, not on the press
	await _grind_case()
	print("[hold] %d failed" % fails)
	get_tree().quit(fails)


func _grind_case() -> void:
	# put the rider straight onto the longest rail, moving along it, then press and hold Space
	world.warp(world.start_names.find("rail"))
	await _settle()
	var line: GrindLine = null
	for g in sk.grind_lines:
		if g.kind == "rail" and (line == null or g.length > line.length):
			line = g
	var c: Dictionary = line.closest(line.point_at(1.0))
	sk.velocity = line.dir_at(1.0) * 6.0
	sk._start_grind(line, c)
	await _frames(6)
	if sk.state != Skater.State.GRIND:
		fails += 1
		print("[hold] FAIL  grind setup: not grinding")
		return
	var before: int = ollies
	_key(KEY_SPACE, true)
	await _frames(12)
	var popped_on_press: bool = ollies > before
	var held_on: bool = sk.state == Skater.State.GRIND
	_key(KEY_SPACE, false)
	await _frames(4)
	var popped_on_release: bool = ollies > before and not popped_on_press
	var ok: bool = not popped_on_press and popped_on_release
	if not ok:
		fails += 1
	print("[hold] %s  %-34s popped on press %s, on release %s, still grinding while held %s" % [
		"PASS" if ok else "FAIL", "Space held on a grind", popped_on_press, popped_on_release, held_on])
