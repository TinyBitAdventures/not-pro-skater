extends Node3D
## The greybox: a plain test level with every kind of obstacle, for tuning how skating feels.
##   godot --path . res://scenes/greybox.tscn
## Keys: 1-9 / 0 warp to a lane start, TAB / SHIFT+TAB next / previous start, P next rider, R back to the start,
##       F3 tuning sliders, plus the normal skating keys.
## Screenshot mode (for checking visuals from the command line):
##   SHOT=name SHOT_START=vert SHOT_AT=2.5 PUSH=1 TUNING_OPEN=1 godot --path . res://scenes/greybox.tscn
## writes ../shots/<name>.png and quits. SHOT_EYE / SHOT_LOOK ("x,y,z") / SHOT_FOV frame a fixed camera instead.

@export var level_path: String = "res://assets/levels/greybox.glb"
@export var look: String = "grey"          # "grey" (grid materials) or "real" (PBR + baked light)
const ORDER: Array[String] = ["flat", "seam", "curb", "miniqp", "qp", "vert", "mini", "rail", "rail_side", "kink",
	"curve", "ledge", "stairs", "funbox", "hip", "kicker", "wall"]

var level: Level
var skater: Skater
var cam: Camera3D
var hud: Hud
var score: ScoreKeeper
var tuning: TuningPanel
var start_names: Array[String] = []
var start_i: int = 0
var _shot_t: float = -1.0


func _ready() -> void:
	level = Level.new()
	add_child(level)
	level.load_glb(level_path, look)
	var sun: DirectionalLight3D = RealEnv.build(self, level.lightmap_info) if look == "real" else GreyEnv.build(self)
	for n in ORDER:
		if level.starts.has(n):
			start_names.append(n)
	for n in level.starts:
		if not start_names.has(n):
			start_names.append(n)

	score = ScoreKeeper.new()
	cam = _make_camera(sun)
	skater = Skater.new()
	skater.rider = OS.get_environment("RIDER") if OS.get_environment("RIDER") != "" else Game.rider
	skater.score = score
	skater.cam = cam
	skater.grind_lines = level.grind_lines
	skater.bounds = level.bounds
	add_child(skater)

	hud = Hud.new()
	add_child(hud)
	hud.show_speed(look == "grey")
	hud.set_hints([["1-9", "warp"], ["TAB", "next spot"], ["P", "rider"], ["R", "reset", "BACK"], ["F3", "tuning"],
		["ESC", "pause", "START"]])
	hud.restart_requested.connect(func() -> void: Game.go(""))
	hud.quit_requested.connect(func() -> void: Game.go("res://scenes/title.tscn"))
	tuning = TuningPanel.new()
	add_child(tuning)
	score.changed.connect(func() -> void: hud.set_score(score.score))
	score.banked.connect(func(p: int, _n: int) -> void:
		hud.set_score(score.score)
		hud.combo_banked(p)
		Sound.play("bank"))
	score.lost.connect(func() -> void:
		hud.combo_lost()
		Sound.play("combo_lost"))
	skater.sfx.connect(_on_sfx)
	skater.thud.connect(_on_thud)
	skater.bailed.connect(func(_r: String) -> void: _cracked = false)
	skater.warped.connect(func() -> void:
		(cam as ChaseCamera).snap_behind()
		hud.blink())
	Sound.play_ambience("park_ambience" if look == "real" else "")
	Sound.play_music(Sound.gameplay_track(Events.music_for_level(level_path)))

	var first: String = OS.get_environment("SHOT_START")
	warp(start_names.find(first) if first != "" and start_names.has(first) else 0)
	(cam as ChaseCamera).attach(skater)
	if OS.get_environment("SHOT") != "":
		_shot_t = float(OS.get_environment("SHOT_AT")) if OS.get_environment("SHOT_AT") != "" else 2.0
		if OS.get_environment("PUSH") != "":
			skater.scripted = true
	if OS.get_environment("CAM_AT_SUN") != "" and not level.lightmap_info.is_empty():
		var d: Array = level.lightmap_info["sun_dir"]
		(cam as ChaseCamera).target = null
		cam.fov = 50.0
		cam.global_transform = Transform3D(Basis.looking_at(Vector3(d[0], d[1], d[2]), Vector3.UP), Vector3(0, 1.7, 0))
	if OS.get_environment("SHOT_EYE") != "":      # a fixed camera: SHOT_EYE="x,y,z" SHOT_LOOK="x,y,z" (Godot coordinates)
		var eye: PackedFloat64Array = OS.get_environment("SHOT_EYE").split_floats(",")
		var at: PackedFloat64Array = OS.get_environment("SHOT_LOOK").split_floats(",")
		(cam as ChaseCamera).target = null
		cam.fov = float(OS.get_environment("SHOT_FOV")) if OS.get_environment("SHOT_FOV") != "" else 55.0
		cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(eye[0], eye[1], eye[2])).looking_at(
			Vector3(at[0], at[1], at[2]), Vector3.UP)
	if OS.get_environment("BAKE_ENERGY") != "":
		RealLook.set_bake_energy(float(OS.get_environment("BAKE_ENERGY")))
	if OS.get_environment("TUNING_OPEN") != "":
		tuning.get_child(0).visible = true


func _make_camera(_sun: DirectionalLight3D) -> Camera3D:
	var c: ChaseCamera = ChaseCamera.new()
	add_child(c)
	return c


func warp(i: int) -> void:
	if start_names.is_empty():
		skater.place_at(level.spawn)
		return
	start_i = posmod(i, start_names.size())
	var nm: String = start_names[start_i]
	var xf: Transform3D = level.starts[nm]
	if OS.get_environment("FACE_DEG") != "":
		xf.basis = xf.basis.rotated(Vector3.UP, deg_to_rad(float(OS.get_environment("FACE_DEG"))))
	skater.place_at(xf)
	if OS.get_environment("V0") != "":
		skater.velocity = skater.hdg * float(OS.get_environment("V0"))
	if OS.get_environment("DROP_DEG") != "":      # screenshot mode: drop in crooked to see a bail
		skater.global_position += Vector3.UP * float(OS.get_environment("DROP_H"))
		if OS.get_environment("DROP_FWD") != "":
			skater.global_position += skater.hdg * float(OS.get_environment("DROP_FWD"))
		skater.velocity = skater.hdg * float(OS.get_environment("DROP_V")) + Vector3.UP * float(OS.get_environment("DROP_UP") if OS.get_environment("DROP_UP") != "" else "1.5")
		skater._enter_air()
		skater.yaw += deg_to_rad(float(OS.get_environment("DROP_DEG")))
		skater.hdg = skater.heading_h()
	if cam.has_method("snap_behind"):
		cam.call("snap_behind")
	hud.announce(nm.replace("_", " "), Hud.PAPER, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9:
		warp(k.physical_keycode - KEY_1)
	elif k.physical_keycode == KEY_0:
		warp(9)
	elif k.physical_keycode == KEY_TAB:
		warp(start_i + (-1 if k.shift_pressed else 1))
	elif k.physical_keycode == KEY_P:
		if skater.state == Skater.State.BAIL:
			return                # mid-crash the new rider would start the fall over at the world's origin
		var carried: Node3D = skater.visual.get("carry_item") if skater.visual != null else null
		var i: int = (Game.RIDERS.find(skater.rider) + 1) % Game.RIDERS.size()
		skater.set_rider(Game.RIDERS[i])
		if carried != null and skater.visual != null:
			skater.visual.set("carry_item", carried)     # the new rider holds the cake (the pizzas, ...) too
		hud.announce(Game.rider_name(Game.RIDERS[i]), Hud.PAPER, 1.0)


func _process(delta: float) -> void:
	hud.set_speed(skater.velocity.length())
	hud.set_charge(skater.charge_frac())
	hud.set_balance(skater.balance_value(), skater.balancing())
	hud.set_combo(score.mult, score.names, score.pending, score.live)
	# a crashed board rolling away on its own wheels still sounds like rolling
	var roll_v: float = skater.velocity.length()
	var rolling: bool = skater.state == Skater.State.GROUND or skater.wallriding
	var rg: RiderRig = skater.visual
	if skater.state == Skater.State.BAIL and rg != null and rg.loose != null and is_instance_valid(rg.loose):
		roll_v = rg.loose.linear_velocity.length()
		rolling = rg.loose.wheels_down
	Sound.set_rolling(roll_v, skater.surface, rolling, delta)
	Sound.set_grinding(skater.state == Skater.State.GRIND and not skater.wallriding, skater.grind_speed, delta)
	if _shot_t >= 0.0:
		if skater.scripted:
			skater.inp.move = Vector2(0, -1)
			skater.inp.world_dir = skater.hdg if skater.state == Skater.State.GROUND else Vector3.ZERO
			if OS.get_environment("GRAB_IN_AIR") != "":
				skater.inp.grab_held = skater.state == Skater.State.AIR and skater.air_time > 0.12
				if skater.state == Skater.State.AIR:
					skater.inp.world_dir = Vector3.ZERO
					skater.inp.move = Vector2.ZERO
			if OS.get_environment("SHOT_WHEN") == "lip":
				# lip trick: grind at the top of the air; LIP_STICK = forward/back/left/right picks the stall
				var stick: String = OS.get_environment("LIP_STICK")
				var up_wall: Vector3 = -skater.vert_out
				var dirs: Dictionary = {"forward": up_wall, "back": -up_wall, "left": -up_wall.cross(Vector3.UP), "right": up_wall.cross(Vector3.UP)}
				if skater.vert_air:
					skater.inp.world_dir = dirs.get(stick, Vector3.ZERO)
					skater.inp.move = Vector2.ZERO
					skater.inp.grind_pressed = skater.global_position.y > 1.3
				elif skater.lip_kind != "":
					skater.inp.move = Vector2.ZERO
					skater.inp.world_dir = Vector3.ZERO
			if OS.get_environment("SHOT_WHEN") == "grind":
				var st: Transform3D = level.starts[start_names[start_i]]
				var run: float = (skater.global_position - st.origin).dot(-st.basis.z)
				skater.inp.ollie_pressed = skater.state == Skater.State.GROUND and run > float(OS.get_environment("OLLIE_AT"))
				skater.inp.grind_pressed = skater.state == Skater.State.AIR
		_shot_t -= delta
		var when: String = OS.get_environment("SHOT_WHEN")
		var ready: bool = _shot_t < 0.0
		if when == "apex":
			ready = skater.state == Skater.State.AIR and skater.velocity.y < 0.3 and skater.air_time > 0.2
		elif when == "grind":
			ready = skater.state == Skater.State.GRIND and skater.grind_dist > 1.5
		elif when == "lip":
			_lip_t = _lip_t + delta if skater.lip_kind != "" else 0.0
			ready = _lip_t > 0.45
		if ready:
			_shot_t = -1.0
			_take_shot.call_deferred()


var _seq_n: int = 0
var _cracked: bool = false          # (one crack per crash)
var _lip_t: float = 0.0


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var seq: int = int(OS.get_environment("SHOT_SEQ")) if OS.get_environment("SHOT_SEQ") != "" else 0
	if seq > 0:
		var d: String = ProjectSettings.globalize_path("res://").path_join("../shots")
		DirAccess.make_dir_recursive_absolute(d)
		get_viewport().get_texture().get_image().save_png(d.path_join("%s_%02d.png" % [OS.get_environment("SHOT"), _seq_n]))
		_seq_n += 1
		if _seq_n >= seq:
			get_tree().quit()
		else:
			_shot_t = float(OS.get_environment("SHOT_EVERY")) if OS.get_environment("SHOT_EVERY") != "" else 0.25
		return
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join(OS.get_environment("SHOT") + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[greybox] shot ", path)
	get_tree().quit()


func _on_sfx(kind: String) -> void:
	match kind:
		"ollie", "flip", "trick", "grab", "manual", "grind_start":
			Sound.play(kind)
		"bail":
			Sound.play(kind, 0.0, randf_range(0.92, 1.08))
		"wallride":
			Sound.play("grind_start", -5.0, 0.8)           # the wheels hitting the wall
		"land", "land_hard":
			# louder and a touch lower the harder it comes down (a vert air rolls in quietly)
			var k: float = clampf(skater.land_impact / Skater.HARD_LANDING, 0.0, 1.4)
			Sound.play(kind, lerpf(-9.0, 0.0, minf(k, 1.0)), lerpf(1.08, 0.94, k / 1.4) * randf_range(0.97, 1.03))


## A crash: the body thumping into the ground (a crack on the first big hit of a bad one), the loose board
## clattering off things.
func _on_thud(kind: String, _at: Vector3, strength: float) -> void:
	var k: float = clampf(strength / 8.0, 0.0, 1.0)
	if kind == "body":
		Sound.play("land_hard", lerpf(-12.0, -2.0, k), randf_range(0.8, 0.95))
		if strength > 5.0 and skater.bail_severity > 0.7 and not _cracked:
			_cracked = true
			Sound.play("crack", -4.0, randf_range(0.9, 1.05))
	else:
		Sound.play("crack", lerpf(-16.0, -6.0, k), randf_range(1.3, 1.6))
