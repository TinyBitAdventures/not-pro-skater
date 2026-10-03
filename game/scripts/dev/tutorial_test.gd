extends Node
## Learn to Skate (TutorialWorld): every step's spot is somewhere to stand, the moves the spots are for really
## happen there with real physics (a grind on the low ledge, a revert and a lip trick on the quarter pipe, a
## wallride on the painted wall), and the steps go in order to the end (the ready screen, Game.tutorial_done):
##   godot --headless --path . --fixed-fps 120 res://scenes/dev_tutorial.tscn
## Exit code = failures.

const DT: float = 1.0 / 120.0

var world: Node
var sk: Skater
var fails: int = 0
var _landings: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("[tutorial] %s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _tick(n: int = 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.steer_mode = "screen"
	world = (load("res://scenes/tutorial.tscn") as PackedScene).instantiate()
	add_child(world)
	await _tick(10)
	sk = world.get("skater")
	sk.scripted = true
	sk.landing.connect(func(k: String) -> void: _landings.append(k))
	var steps: Array = world.get("STEPS")
	var spots: Dictionary = world.get("SPOTS")
	for s in steps:
		if String(s[4]) != "":
			_check("step %s: its spot (%s) is known" % [s[0], s[4]], spots.has(String(s[4])))
	for spot in spots:
		var p: Vector3 = spots[spot][0]
		_check("spot %s: ground to stand on at (%.1f, %.1f)" % [spot, p.x, p.z], sk._spot_ok(p))
	await _grind()
	await _revert()
	await _lip()
	await _wallride()
	await _sequence()
	print("[tutorial] %d failure(s)" % fails)
	get_tree().quit(fails)


func _go(id: String) -> void:
	var steps: Array = world.get("STEPS")
	for i in steps.size():
		if String(steps[i][0]) == id:
			world.set("step", i)
	world.call("warp", 0)
	sk.inp = SkaterInput.new()
	sk.velocity = Vector3.ZERO
	_landings.clear()
	await _tick(20)


func _push_toward(dir: Vector3) -> void:
	sk.inp.world_dir = dir
	sk.inp.move = Vector2(0, -1)


func _coast() -> void:
	sk.inp.world_dir = Vector3.ZERO
	sk.inp.move = Vector2.ZERO


func _grind() -> void:
	await _go("grind")
	var dir: Vector3 = world.get("SPOTS")["ledge"][1]
	var ground: bool = false
	for i in 600:
		_push_toward(dir)
		sk.inp.grind_pressed = sk.global_position.x > -15.0 and sk.state == Skater.State.GROUND
		await _tick()
		if sk.state == Skater.State.GRIND and not sk.wallriding:
			ground = true
			break
	sk.inp.grind_pressed = false
	_check("grind: ride along the low ledge, press grind beside it: %s (%s)" % ["grinding" if ground else "no grind", sk.grind_kind], ground)


func _revert() -> void:
	await _go("revert")
	var dir: Vector3 = world.get("SPOTS")["qp"][1]
	var aired: bool = false
	var pressed: bool = false
	for i in 900:
		if sk.state == Skater.State.AIR:
			aired = true
			_coast()
		elif not aired:
			_push_toward(dir)
		var was: int = sk.state
		await _tick()
		sk.inp.manual = false
		if aired and was == Skater.State.AIR and sk.state == Skater.State.GROUND and not pressed:
			await _tick(4)
			sk.inp.manual = true
			pressed = true
		if _landings.has("revert"):
			break
	sk.inp.manual = false
	_check("revert: up the quarter pipe, manual as it lands back on it: air %s, landings %s" % [aired, _landings],
		_landings.has("revert"))


func _lip() -> void:
	await _go("lip")
	var dir: Vector3 = world.get("SPOTS")["qp"][1]
	var stalled: String = ""
	var aired: bool = false
	for i in 900:
		if sk.state == Skater.State.AIR:
			aired = true
			_coast()
			sk.inp.grind_pressed = true
		elif not aired:
			_push_toward(dir)
		await _tick()
		if sk.lip_kind != "":
			stalled = sk.lip_kind
			break
		if aired and sk.state == Skater.State.GROUND:
			break
	sk.inp.grind_pressed = false
	_check("lip trick: up the quarter pipe, grind at the top: %s (vert air %s)" % [stalled if stalled != "" else "no stall", aired],
		stalled != "")


func _wallride() -> void:
	await _go("wallride")
	var dir: Vector3 = world.get("SPOTS")["wall"][1]
	var rode: float = 0.0
	var popped: bool = false
	for i in 900:
		var to_wall: float = 23.0 - 0.2 - sk.global_position.z          # the wall's face (Godot z 23.0)
		if not popped and to_wall < 2.2:
			sk.inp.ollie_pressed = true
			sk.inp.ollie_held = false
			popped = true
		elif popped:
			sk.inp.ollie_pressed = false
		if not popped:
			_push_toward(dir)
		else:
			_coast()
		sk.inp.grind_pressed = popped and sk.state == Skater.State.AIR
		await _tick()
		if sk.wallriding:
			rode += DT
		elif rode > 0.0:
			break
	sk.inp.grind_pressed = false
	_check("wallride: an ollie at the painted wall, grind: rode %.2f s" % rode, rode >= 0.25)


## The steps tick off in order (each completed the way the world does when its move is done) to the ready screen.
func _sequence() -> void:
	world.set("step", 0)
	world.set("done", false)
	var steps: Array = world.get("STEPS")
	var order: Array[int] = []
	for i in steps.size():
		order.append(int(world.get("step")))
		world.call("_complete")
		await _tick()
	var hud: Hud = world.get("hud")
	_check("the steps go in order: %s" % [order], order == range(steps.size()))
	_check("all done: the ready screen, NEXT to the first event", bool(world.get("done")) and hud.results_layer.visible \
		and hud.results_keys.has("next"))
	_check("Game.tutorial_done", Game.tutorial_done)
