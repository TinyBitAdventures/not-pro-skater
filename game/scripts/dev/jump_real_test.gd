extends Node
## Real-input jump check in the actual park scene: hold Space (no jump), release (jump).
##   godot --headless --path . res://scenes/dev_jump.tscn

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for mode in ["hold", "tap"]:
		Game.jump_mode = mode
		var park: Node3D = (load("res://scenes/park.tscn") as PackedScene).instantiate()
		add_child(park)
		await get_tree().create_timer(1.2).timeout
		var sk: Skater = park.skater
		var y0: float = sk.global_position.y
		var st: Dictionary = {"peak_held": 0.0, "peak_after": 0.0, "ollies": 0, "rel_ticks": 0}
		sk.sfx.connect(func(kind: String) -> void:
			if kind == "ollie":
				st["ollies"] += 1)
		Input.action_press("ollie")
		for i in 40:
			await get_tree().physics_frame
			st["peak_held"] = maxf(st["peak_held"], sk.global_position.y - y0)
		var charge_before: float = sk.charge_frac()
		Input.action_release("ollie")
		for i in 90:
			await get_tree().physics_frame
			if sk.inp.ollie_released:
				st["rel_ticks"] += 1
			if mode == "hold" and i < 8:
				print("[jump]   tick %d state=%d vy=%.2f rel_buf=%.3f charge=%.2f air=%.3f released=%s held=%s" % [i, sk.state, sk.velocity.y, sk._release_buf, sk.charge, sk.air_time, sk.inp.ollie_released, sk.inp.ollie_held])
			st["peak_after"] = maxf(st["peak_after"], sk.global_position.y - y0)
		print("[jump] mode=%s  held 0.33 s: rose %.2f m (charge meter %.2f)  after release: peak %.2f m  ollie sounds=%d  ticks with release edge=%d" % [mode, st["peak_held"], charge_before, st["peak_after"], st["ollies"], st["rel_ticks"]])
		park.queue_free()
		await get_tree().process_frame
	get_tree().quit()
