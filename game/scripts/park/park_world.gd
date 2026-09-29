extends Node3D
## The playable park: level, skater, camera, HUD and the two-minute session.

const LEVEL_ID: String = "community_park"
const LEVEL_PATH: String = "res://assets/levels/community_park.glb"
const SESSION_SECONDS: float = 120.0

enum Phase { READY, RUN, WRAP, DONE }

var level: Level
var skater: Skater
var cam: IsoCamera
var hud: Hud
var score: ScoreKeeper
var phase: int = Phase.READY
var time_left: float = SESSION_SECONDS
var letters: Array = [false, false, false, false, false]
var pickups: Array[Node3D] = []
var _wrap_timer: float = 0.0
var _hint_timer: float = 0.0
var _shake: float = 0.0
var free_skate: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	WorldEnv.build(self)
	level = Level.new()
	add_child(level)
	level.load_glb(LEVEL_PATH)

	score = ScoreKeeper.new()
	cam = IsoCamera.new()
	add_child(cam)
	skater = Skater.new()
	skater.score = score
	skater.cam = cam
	skater.grind_lines = level.grind_lines
	add_child(skater)
	skater.place_at(level.spawn)
	cam.target = skater
	cam.jump_to(skater.global_position)

	hud = Hud.new()
	add_child(hud)
	hud.set_best(int(Game.best.get(LEVEL_ID, {}).get("score", 0)))
	score.changed.connect(_on_score_changed)
	score.banked.connect(_on_banked)
	score.lost.connect(_on_lost)
	skater.bailed.connect(_on_bailed)
	skater.landed.connect(_on_landed)
	skater.sfx.connect(_on_sfx)
	Sound.play_music()
	_build_pickups()
	hud.announce("COMMUNITY PARK", Hud.YELLOW, 2.4)
	hud.set_timer(time_left, false)


func _build_pickups() -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	var styled: ArrayMesh = Toon.styled_mesh(box, "Yellow", Color(1.0, 0.82, 0.25))
	for p in level.pickups:
		var nm: String = p["name"]
		if nm.length() != 1:
			continue
		var n: Node3D = Node3D.new()
		n.position = p["pos"]
		n.set_meta("letter", nm)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = styled
		n.add_child(mi)
		var l: Label3D = Label3D.new()
		l.text = nm
		l.font_size = 96
		l.pixel_size = 0.012
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.outline_size = 16
		l.outline_modulate = Color(0.09, 0.11, 0.19)
		l.position = Vector3(0, 0.95, 0)
		l.no_depth_test = true
		n.add_child(l)
		add_child(n)
		pickups.append(n)


func _process(delta: float) -> void:
	for n in pickups:
		if is_instance_valid(n):
			n.rotation.y += delta * 2.2
			n.position.y += sin(Time.get_ticks_msec() * 0.004 + n.position.x) * 0.002
	if get_tree().paused:
		return
	var v_h: Vector3 = skater.velocity
	v_h.y = 0.0
	cam.look_ahead = cam.look_ahead.lerp((v_h * 0.28).limit_length(4.0), 1.0 - exp(-3.0 * delta))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.5
		cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.5
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	hud.set_speed(skater.velocity.length())
	_update_audio(delta)
	hud.set_combo(score.mult, score.combo_text(), score.pending, score.live)

	match phase:
		Phase.READY:
			if skater.velocity.length() > 1.0 and not skater.scripted:
				phase = Phase.RUN
				Sound.play("go", -4.0)
				hud.announce("GO!", Hud.GREEN, 0.9)
		Phase.RUN:
			if not free_skate:
				time_left = maxf(0.0, time_left - delta)
				hud.set_timer(time_left, true)
				if time_left <= 0.0:
					phase = Phase.WRAP
					_wrap_timer = 6.0
					Sound.play("time_up", -3.0)
					hud.announce("TIME!", Hud.RED, 1.4)
		Phase.WRAP:
			_wrap_timer -= delta
			if not score.live or _wrap_timer <= 0.0:
				score.bank()
				_finish()
	_check_pickups()
	_hint_timer += delta
	if _hint_timer > 12.0 and _hint_timer < 12.5:
		hud.hide_hint()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and phase != Phase.DONE:
		_set_paused(not get_tree().paused)
	elif get_tree().paused and event.is_action_pressed("ui_accept"):
		_restart()
	elif phase == Phase.DONE and event.is_action_pressed("ui_accept"):
		_restart()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.physical_keycode == KEY_T:
			Game.steer_mode = "tank" if Game.steer_mode == "screen" else "screen"
			Game.save()
			hud.announce("TANK STEERING" if Game.steer_mode == "tank" else "SCREEN STEERING", Hud.BLUE, 1.2)
		elif k.physical_keycode == KEY_Q and not get_tree().paused:
			cam.snap_yaw(-1)
		elif k.physical_keycode == KEY_E and not get_tree().paused:
			cam.snap_yaw(1)
		elif k.physical_keycode == KEY_N:
			hud.announce("MUSIC ON" if Sound.toggle_music() else "MUSIC OFF", Hud.BLUE, 1.0)
		elif k.physical_keycode == KEY_EQUAL:
			cam.ortho_size = clampf(cam.ortho_size - 2.0, 12.0, 40.0)
		elif k.physical_keycode == KEY_MINUS:
			cam.ortho_size = clampf(cam.ortho_size + 2.0, 12.0, 40.0)


func _set_paused(p: bool) -> void:
	get_tree().paused = p
	hud.show_pause(p)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _check_pickups() -> void:
	for n in pickups:
		if not is_instance_valid(n):
			continue
		if n.global_position.distance_to(skater.global_position + Vector3.UP * 0.9) < 1.6:
			var ch: String = n.get_meta("letter")
			var i: int = "SKATE".find(ch)
			if i >= 0:
				letters[i] = true
				Sound.play("pickup", -4.0, 1.0 + i * 0.06)
				hud.set_letters(letters)
				hud.toast(ch, Hud.YELLOW, Vector2(get_viewport().get_visible_rect().size.x - 170.0 + i * 30.0, 130.0))
				if not letters.has(false):
					score.score += 2500
					hud.set_score(score.score)
					Sound.play("skate_done", -3.0)
					hud.announce("S.K.A.T.E!  +2,500", Hud.YELLOW, 2.2)
			pickups.erase(n)
			n.queue_free()


func _finish() -> void:
	phase = Phase.DONE
	var new_best: bool = Game.record(LEVEL_ID, score.score, score.best_combo)
	var s: Dictionary = skater.stats
	var lines: Array[String] = [
		"SCORE        %s%s" % [Hud._commas(score.score), "   NEW BEST!" if new_best else ""],
		"BEST COMBO   %s" % Hud._commas(score.best_combo),
		"TRICKS       %d" % score.trick_count,
		"GRINDS       %d" % int(s["grinds"]),
		"LONGEST AIR  %.1f s" % float(s["max_air"]),
		"TOP SPEED    %.0f" % float(s["max_speed"]),
		"BAILS        %d" % int(s["bails"]),
	]
	hud.show_results("\n".join(lines))
	hud.set_best(int(Game.best.get(LEVEL_ID, {}).get("score", 0)))
	skater.scripted = true
	skater.inp.world_dir = Vector3.ZERO
	skater.inp.brake = true


var _roll_dist: float = 0.0


func _update_audio(delta: float) -> void:
	var on_ground: bool = skater.state == Skater.State.GROUND
	var spd: float = skater.velocity.length()
	Sound.set_rolling(spd, skater.surface, on_ground, delta)
	Sound.set_grinding(skater.state == Skater.State.GRIND, skater.grind_speed, delta)
	if on_ground and skater.surface != "grass" and skater.surface != "wood":
		var before: float = _roll_dist
		_roll_dist += spd * delta
		if int(_roll_dist / 3.1) != int(before / 3.1) and spd > 3.0:
			Sound.play("crack", lerpf(-22.0, -8.0, clampf(spd / 12.0, 0.0, 1.0)), randf_range(0.9, 1.15))


func _on_sfx(kind: String) -> void:
	match kind:
		"ollie":
			Sound.play("ollie", -4.0, randf_range(0.95, 1.08))
		"flip":
			Sound.play("flip", -8.0, randf_range(0.95, 1.1))
		"trick":
			Sound.play("trick", -6.0)
		"grab":
			Sound.play("grab", -8.0)
		"manual":
			Sound.play("manual", -8.0)
		"grind_start":
			Sound.play("land", -6.0, 1.7)
		"bail":
			Sound.play("bail", -1.0)


func _on_score_changed() -> void:
	hud.set_score(score.score)


func _on_banked(points: int, combo_len: int) -> void:
	hud.set_score(score.score)
	Sound.play("bank_big" if points >= 2500 else "bank", -6.0)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	hud.toast("+%s" % Hud._commas(points), Hud.GREEN if combo_len < 4 else Hud.YELLOW, Vector2(280, 40))
	if points >= 5000:
		hud.announce("SICK!", Hud.YELLOW, 1.2)


func _on_lost() -> void:
	Sound.play("combo_lost", -6.0)
	hud.toast("COMBO LOST", Hud.RED, Vector2(280, 40))


func _on_bailed(_reason: String) -> void:
	_shake = 0.6


func _on_landed(air: float) -> void:
	_shake = maxf(_shake, 0.12)
	Sound.play("land_hard" if air > 0.8 else "land", -4.0, randf_range(0.95, 1.05))
