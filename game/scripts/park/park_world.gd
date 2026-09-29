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
var _done_at_ms: int = 0


## ParkWorld is PAUSABLE, so its own _input never fires while the tree is paused; this relay is not.
class PauseRelay extends Node:
	signal got(event: InputEvent)

	func _input(event: InputEvent) -> void:
		got.emit(event)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var relay: PauseRelay = PauseRelay.new()
	relay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(relay)
	relay.got.connect(_on_input)
	var sun: DirectionalLight3D = WorldEnv.build(self)
	level = Level.new()
	add_child(level)
	level.load_glb(LEVEL_PATH)

	score = ScoreKeeper.new()
	cam = IsoCamera.new()
	cam.shadow_light = sun
	add_child(cam)
	skater = Skater.new()
	skater.score = score
	skater.cam = cam
	skater.grind_lines = level.grind_lines
	add_child(skater)
	skater.place_at(level.spawn)
	cam.target = skater
	cam.follow_heading = Game.camera_mode == "follow"
	if cam.follow_heading:
		cam.face_heading(skater)
	cam.jump_to(skater.global_position)

	add_child(PostFx.new())
	add_child(AmbientLife.new())
	add_child(WorldLife.new(level))
	hud = Hud.new()
	add_child(hud)
	hud.set_best(int(Game.best.get(LEVEL_ID, {}).get("score", 0)))
	score.changed.connect(_on_score_changed)
	score.banked.connect(_on_banked)
	score.lost.connect(_on_lost)
	score.trick_added.connect(_on_trick_added)
	skater.bailed.connect(_on_bailed)
	skater.landed.connect(_on_landed)
	skater.sfx.connect(_on_sfx)
	Sound.play_music(Sound.gameplay_track())
	_build_pickups()
	_spawn_ambient_skaters(3)
	free_skate = Game.free_skate
	_refresh_hint()
	hud.announce("COMMUNITY PARK", Hud.YELLOW, 2.4)
	if Game.jump_mode == "tap":
		get_tree().create_timer(2.8).timeout.connect(func() -> void: hud.announce("TAP JUMP   (Y = hold to jump higher)", Hud.BLUE, 2.4))
	hud.set_timer(time_left, false)


func _spawn_ambient_skaters(count: int) -> void:
	for i in count:
		var s: Skater = Skater.new()
		s.is_player = false
		s.look = SkaterVisual.random_look(100 + i)
		var lane: float = [34.4, 36.0, 37.6][i % 3]
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		s.brain = SkaterBrain.new(lane, dir)
		s.steer_mode = "screen"
		s.grind_lines = level.grind_lines
		add_child(s)
		var a: float = deg_to_rad(20.0 + i * 130.0)
		var tangent: Vector3 = Vector3(-sin(a), 0.0, -cos(a)) * dir
		s.place_at(Transform3D(Basis.looking_at(tangent, Vector3.UP), Vector3(lane * cos(a), 0.1, -lane * sin(a))))


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
	hud.set_charge(skater.charge_frac())
	_update_audio(delta)
	hud.set_combo(score.mult, score.combo_text(), score.pending, score.live)

	match phase:
		Phase.READY:
			if skater.velocity.length() > 1.0 and not skater.scripted:
				phase = Phase.RUN
				Sound.play("go")
				hud.announce("GO!", Hud.GREEN, 0.9)
		Phase.RUN:
			if not free_skate:
				time_left = maxf(0.0, time_left - delta)
				hud.set_timer(time_left, true)
				if time_left <= 0.0:
					phase = Phase.WRAP
					_wrap_timer = 6.0
					Sound.play("time_up")
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


## Enter / R / Back restart. ui_accept alone is not enough: it includes Space, which is the ollie key.
func _is_restart(event: InputEvent) -> bool:
	return (event.is_action_pressed("ui_accept") and not event.is_action_pressed("ollie")) or event.is_action_pressed("respawn")


func _on_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and phase != Phase.DONE:
		_set_paused(not get_tree().paused)
	elif get_tree().paused and _is_restart(event):
		_restart()
	elif phase == Phase.DONE and _is_restart(event) and Time.get_ticks_msec() - _done_at_ms > 1000:
		_restart()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.physical_keycode == KEY_T:
			Game.steer_mode = "tank" if Game.steer_mode == "screen" else "screen"
			Game.save()
			_refresh_hint()
			hud.announce("SKATER STEERING" if Game.steer_mode == "tank" else "SCREEN STEERING", Hud.BLUE, 1.2)
		elif k.physical_keycode == KEY_Y:
			Game.jump_mode = "tap" if Game.jump_mode == "hold" else "hold"
			Game.save()
			_refresh_hint()
			hud.announce("HOLD TO JUMP HIGHER" if Game.jump_mode == "hold" else "TAP TO JUMP", Hud.BLUE, 1.2)
		elif k.physical_keycode == KEY_C:
			Game.camera_mode = "fixed" if Game.camera_mode == "follow" else "follow"
			Game.save()
			cam.follow_heading = Game.camera_mode == "follow"
			if cam.follow_heading:
				cam.yaw_offset = 0.0
			else:
				cam.yaw_target = cam.yaw
			hud.announce("FOLLOW CAMERA" if cam.follow_heading else "FIXED CAMERA", Hud.BLUE, 1.2)
		elif k.physical_keycode == KEY_Q and not get_tree().paused:
			cam.snap_yaw(-1)
		elif k.physical_keycode == KEY_E and not get_tree().paused:
			cam.snap_yaw(1)
		elif k.physical_keycode == KEY_N:
			var choice: String = Sound.cycle_music_choice()
			Sound.play_music(Sound.gameplay_track())
			hud.announce({"cruise": "MUSIC: CRUISE", "hype": "MUSIC: HYPE", "off": "MUSIC OFF"}[choice], Hud.BLUE, 1.0)
		elif k.physical_keycode == KEY_EQUAL:
			cam.ortho_size = clampf(cam.ortho_size - 2.0, 12.0, 40.0)
		elif k.physical_keycode == KEY_MINUS:
			cam.ortho_size = clampf(cam.ortho_size + 2.0, 12.0, 40.0)


func _refresh_hint() -> void:
	var jump: String = "HOLD SPACE, RELEASE TO JUMP" if Game.jump_mode == "hold" else "SPACE JUMP"
	if Game.steer_mode == "tank":
		hud.set_hint("W PUSH   A/D TURN   S BRAKE   %s   J FLIP   K GRAB   L GRIND   M MANUAL" % jump)
	else:
		hud.set_hint("WASD ROLL   %s   J FLIP   K GRAB   L GRIND   M MANUAL   SHIFT BRAKE" % jump)


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
				Sound.play("pickup", 0.0, pow(2.0, [0, 2, 4, 7, 9][i] / 12.0))
				hud.set_letters(letters)
				hud.toast(ch, Hud.YELLOW, Vector2(get_viewport().get_visible_rect().size.x - 170.0 + i * 30.0, 130.0))
				if not letters.has(false):
					score.score += 2500
					hud.set_score(score.score)
					Sound.play("skate_done")
					hud.announce("S.K.A.T.E!  +2,500", Hud.YELLOW, 2.2)
			pickups.erase(n)
			n.queue_free()


func _finish() -> void:
	phase = Phase.DONE
	_done_at_ms = Time.get_ticks_msec()
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
	Sound.fade_music(0.6)
	Sound.play_jingle("results-jingle")
	if new_best:
		# the sting sits on the jingle's last chord (10 s in); -5 dB keeps the two from clipping together
		get_tree().create_timer(10.0).timeout.connect(func() -> void: Sound.play_jingle("new-best", -5.0, 1))
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
			Sound.play("crack", lerpf(-10.0, -2.0, clampf(spd / 12.0, 0.0, 1.0)), randf_range(0.9, 1.15))


func _on_sfx(kind: String) -> void:
	match kind:
		"ollie":
			Sound.play("ollie", 0.0, randf_range(0.95, 1.08))
		"flip":
			Sound.play("flip", 0.0, randf_range(0.95, 1.1))
		"trick":
			Sound.play("trick")
		"grab":
			Sound.play("grab")
		"manual":
			Sound.play("manual")
		"grind_start":
			Sound.play("grind_start")
		"bail":
			Sound.play("bail")


var _popup_t: float = 0.0
var _popup_n: int = 0


## A floating "KICKFLIP +300" over the rider: rises, pops in with a little overshoot, fades out.
func _on_trick_added(trick_name: String, points: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _popup_t > 0.9:
		_popup_n = 0
	_popup_t = now
	var l: Label3D = Label3D.new()
	l.text = "%s  +%d" % [trick_name.to_upper(), points]
	l.font_size = 72
	l.pixel_size = 0.0075
	l.outline_size = 16
	l.outline_modulate = Color(0.09, 0.11, 0.19)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.render_priority = 10
	l.modulate = Color(1, 1, 1) if points < 300 else (Color(1.0, 0.85, 0.3) if points < 500 else Color(1.0, 0.55, 0.2))
	var start: Vector3 = skater.global_position + Vector3(0, 2.3 + 0.55 * _popup_n, 0)
	_popup_n += 1
	l.position = start
	l.scale = Vector3(0.5, 0.5, 0.5)
	add_child(l)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", start.y + 1.1, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.75)
	tw.chain().tween_callback(l.queue_free)


func _on_score_changed() -> void:
	hud.set_score(score.score)


func _on_banked(points: int, combo_len: int) -> void:
	hud.set_score(score.score)
	Sound.play("bank_big" if points >= 2500 else "bank")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	hud.toast("+%s" % Hud._commas(points), Hud.GREEN if combo_len < 4 else Hud.YELLOW, Vector2(280, 40))
	if points >= 5000:
		hud.announce("SICK!", Hud.YELLOW, 1.2)


func _on_lost() -> void:
	Sound.play("combo_lost")
	hud.toast("COMBO LOST", Hud.RED, Vector2(280, 40))


func _on_bailed(_reason: String) -> void:
	_shake = 0.6


func _on_landed(air: float) -> void:
	_shake = maxf(_shake, 0.12)
	Sound.play("land_hard" if air > 0.8 else "land", 0.0, randf_range(0.95, 1.05))
