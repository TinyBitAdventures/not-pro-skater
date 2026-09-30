extends Node
## Quick Space taps through the real input path (key events, frame by frame) on the greybox:
##   godot --headless --path . --fixed-fps 60 res://scenes/dev_jumptap.tscn
## Counts how many taps give a jump, by tap length (frames held) and by when the tap lands (on flat,
## just after a landing, rolling onto a kicker).

var world: Node3D
var sk: Skater
var ollies: int = 0


func _ready() -> void:
	_run.call_deferred()


func _key(pressed: bool) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = KEY_SPACE
	e.keycode = KEY_SPACE
	e.pressed = pressed
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


func _tap(hold_frames: int) -> bool:
	var before: int = ollies
	_key(true)
	if hold_frames > 0:
		await _frames(hold_frames)
	_key(false)
	await _frames(40)
	return ollies > before


func _run() -> void:
	Game.jump_mode = OS.get_environment("JUMP_MODE") if OS.get_environment("JUMP_MODE") != "" else "hold"
	world = (load("res://scenes/greybox.tscn") as PackedScene).instantiate()
	add_child(world)
	await _frames(10)
	sk = world.skater
	sk.sfx.connect(func(kind: String) -> void:
		if kind == "ollie":
			ollies += 1)
	var report: Array[String] = []
	# 1: taps on the flat at speed, by hold length
	for hold in [0, 1, 2, 3, 5, 10]:
		var ok: int = 0
		for rep in 6:
			world.warp(0)
			sk.velocity = sk.hdg * 8.0
			await _settle()
			await _frames(rep)          # vary the phase against physics ticks
			if await _tap(hold):
				ok += 1
		report.append("flat, held %2d frames: %d / 6 jumped" % [hold, ok])
	# 2: taps just after landing an ollie
	for delay in [0, 2, 4, 8, 12]:
		var ok2: int = 0
		for rep in 4:
			world.warp(0)
			sk.velocity = sk.hdg * 8.0
			await _settle()
			await _tap(3)                    # first jump
			var landed_wait: int = 0
			while sk.state != Skater.State.GROUND and landed_wait < 120:
				await get_tree().process_frame
				landed_wait += 1
			# _tap waited 40 frames already; the skater may have landed during it
			await _frames(delay)
			if await _tap(2):
				ok2 += 1
		report.append("tap %2d frames after the first jump lands: %d / 4" % [delay, ok2])
	# 2b: taps while still falling, some time before touchdown (chaining ollies)
	for before_ms in [50, 100, 150, 200, 250, 300]:
		var ok4: int = 0
		var heights: Array[float] = []
		for rep in 4:
			world.warp(0)
			sk.velocity = sk.hdg * 8.0
			await _settle()
			_key(true)
			await _frames(2)
			_key(false)
			# wait for the fall, then tap when the skater is about `before_ms` from the ground
			var tapped: bool = false
			for f in 120:
				await get_tree().process_frame
				if sk.state == Skater.State.AIR and sk.velocity.y < 0.0:
					var h: float = sk.global_position.y - 0.0
					var vy: float = -sk.velocity.y
					var g: float = sk.tune.air_gravity_down
					var t_land: float = (-vy + sqrt(vy * vy + 2.0 * g * maxf(h, 0.0))) / g
					if t_land <= before_ms / 1000.0:
						var before: int = ollies
						_key(true)
						await _frames(2)
						_key(false)
						await _frames(50)
						if ollies > before:
							ok4 += 1
						tapped = true
						break
			if not tapped:
				heights.append(-1.0)
		report.append("tap %3d ms before landing: %d / 4 jumped on landing" % [before_ms, ok4])
	# 3: taps rolling up the kicker / onto the curb
	for spot in ["kicker", "curb"]:
		var ok3: int = 0
		for rep in 6:
			world.warp(world.start_names.find(spot))
			sk.velocity = sk.hdg * 9.0
			await _settle()
			await _frames(20 + rep * 4)
			if await _tap(2):
				ok3 += 1
		report.append("tap rolling toward the %s: %d / 6" % [spot, ok3])
	for r in report:
		print("[tap] ", r)
	get_tree().quit()
