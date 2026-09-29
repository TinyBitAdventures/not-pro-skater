extends Node3D
## The greybox: a plain test level with every kind of obstacle, for tuning how skating feels.
##   godot --path . res://scenes/greybox.tscn
## Keys: 1-9 / 0 warp to a lane start, TAB / SHIFT+TAB next / previous start, R back to the start,
##       F3 tuning sliders, plus the normal skating keys.
## Screenshot mode (for checking visuals from the command line):
##   SHOT=name SHOT_START=vert SHOT_AT=2.5 PUSH=1 TUNING_OPEN=1 godot --path . res://scenes/greybox.tscn
## writes ../shots/<name>.png and quits.

const LEVEL_PATH: String = "res://assets/levels/greybox.glb"
const ORDER: Array[String] = ["flat", "seam", "curb", "miniqp", "qp", "vert", "mini", "rail", "rail_side", "kink",
	"curve", "ledge", "stairs", "funbox", "hip", "kicker"]

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
	var sun: DirectionalLight3D = GreyEnv.build(self)
	level = Level.new()
	add_child(level)
	level.load_glb(LEVEL_PATH, true)
	for n in ORDER:
		if level.starts.has(n):
			start_names.append(n)
	for n in level.starts:
		if not start_names.has(n):
			start_names.append(n)

	score = ScoreKeeper.new()
	cam = _make_camera(sun)
	skater = Skater.new()
	skater.score = score
	skater.cam = cam
	skater.grind_lines = level.grind_lines
	add_child(skater)
	cam.set("target", skater)

	hud = Hud.new()
	add_child(hud)
	hud.set_timer(0.0, false)
	hud.set_hint("1-9 / 0  WARP    TAB  NEXT SPOT    R  RESET    F3  TUNING")
	tuning = TuningPanel.new()
	add_child(tuning)
	score.changed.connect(func() -> void: hud.set_score(score.score))
	score.banked.connect(func(_p: int, _n: int) -> void:
		hud.set_score(score.score)
		Sound.play("bank"))
	score.lost.connect(func() -> void: Sound.play("combo_lost"))
	skater.sfx.connect(_on_sfx)

	var first: String = OS.get_environment("SHOT_START")
	warp(start_names.find(first) if first != "" and start_names.has(first) else 0)
	if OS.get_environment("SHOT") != "":
		_shot_t = float(OS.get_environment("SHOT_AT")) if OS.get_environment("SHOT_AT") != "" else 2.0
		if OS.get_environment("PUSH") != "":
			skater.scripted = true
	if OS.get_environment("TUNING_OPEN") != "":
		tuning.get_child(0).visible = true


## The iso camera for now; the chase camera replaces it.
func _make_camera(sun: DirectionalLight3D) -> Camera3D:
	var c: IsoCamera = IsoCamera.new()
	c.shadow_light = sun
	c.follow_heading = true
	add_child(c)
	return c


func warp(i: int) -> void:
	if start_names.is_empty():
		skater.place_at(level.spawn)
		return
	start_i = posmod(i, start_names.size())
	var nm: String = start_names[start_i]
	skater.place_at(level.starts[nm])
	if cam is IsoCamera:
		(cam as IsoCamera).face_heading(skater)
		(cam as IsoCamera).jump_to(skater.global_position)
	elif cam.has_method("snap_behind"):
		cam.call("snap_behind")
	hud.announce(nm.to_upper().replace("_", " "), Hud.BLUE, 1.0)


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


func _process(delta: float) -> void:
	hud.set_speed(skater.velocity.length())
	hud.set_charge(skater.charge_frac())
	hud.set_combo(score.mult, score.combo_text(), score.pending, score.live)
	Sound.set_rolling(skater.velocity.length(), skater.surface, skater.state == Skater.State.GROUND, delta)
	Sound.set_grinding(skater.state == Skater.State.GRIND, skater.grind_speed, delta)
	if _shot_t >= 0.0:
		if skater.scripted:
			skater.inp.move = Vector2(0, -1)
			skater.inp.world_dir = skater.hdg
		_shot_t -= delta
		if _shot_t < 0.0:
			_take_shot.call_deferred()


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join(OS.get_environment("SHOT") + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[greybox] shot ", path)
	get_tree().quit()


func _on_sfx(kind: String) -> void:
	match kind:
		"ollie", "flip", "trick", "grab", "manual", "grind_start", "bail":
			Sound.play(kind)
