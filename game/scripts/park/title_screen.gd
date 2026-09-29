extends Node3D
## Attract-mode title: the park with a few AI skaters, a slowly turning camera and a chunky menu.

const PARK_SCENE: String = "res://scenes/park.tscn"

var level: Level
var cam: IsoCamera
var star: Skater
var ui: CanvasLayer
var menu_panels: Array[PanelContainer] = []
var menu_labels: Array[Label] = []
var selected: int = 0
var controls_panel: PanelContainer
var best_label: Label


func _ready() -> void:
	WorldEnv.build(self)
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/community_park.glb")
	cam = IsoCamera.new()
	cam.ortho_size = 17.0
	add_child(cam)
	for i in 4:
		var s: Skater = Skater.new()
		s.is_player = (i == 0)
		s.look = {} if i == 0 else SkaterVisual.random_look(200 + i)
		var lane: float = [36.0, 34.6, 37.4, 35.4][i]
		var dir: float = 1.0 if i != 2 else -1.0
		s.brain = SkaterBrain.new(lane, dir)
		s.steer_mode = "screen"
		s.brain.trick_every = Vector2(1.6, 4.0) if i == 0 else Vector2(3.0, 7.0)
		s.grind_lines = level.grind_lines
		add_child(s)
		var a: float = deg_to_rad(-70.0 + i * 95.0)
		var tangent: Vector3 = Vector3(-sin(a), 0.0, -cos(a)) * dir
		s.place_at(Transform3D(Basis.looking_at(tangent, Vector3.UP), Vector3(lane * cos(a), 0.1, -lane * sin(a))))
		if i == 0:
			star = s
	cam.target = star
	cam.jump_to(star.global_position)
	add_child(PostFx.new())
	add_child(AmbientLife.new())
	add_child(WorldLife.new(level))
	_build_ui()
	Sound.play_music("boardwalk_morning")


func _process(delta: float) -> void:
	cam.yaw_target += delta * 0.07
	cam.yaw = cam.yaw_target
	var v: Vector3 = star.velocity
	v.y = 0.0
	cam.look_ahead = cam.look_ahead.lerp((v * 0.3).limit_length(4.0), 1.0 - exp(-2.0 * delta))


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 90)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var logo: PanelContainer = UiKit.panel(UiKit.NAVY, 24)
	var lv: VBoxContainer = VBoxContainer.new()
	lv.add_theme_constant_override("separation", -8)
	logo.add_child(lv)
	var t1: Label = UiKit.label("SKATE", 84, UiKit.YELLOW, 12)
	var t2: Label = UiKit.label("PARK", 84, UiKit.WHITE, 12)
	lv.add_child(t1)
	lv.add_child(t2)
	lv.add_child(UiKit.label("an isometric skateboarding game", 20, UiKit.BLUE, 4))
	col.add_child(logo)

	var items: Array[String] = ["PLAY  2:00 SESSION", "FREE SKATE", "", "", "", "", "CONTROLS"]
	for i in items.size():
		var p: PanelContainer = UiKit.panel(UiKit.NAVY, 14)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var l: Label = UiKit.label(items[i], 28, UiKit.WHITE, 5)
		p.add_child(l)
		p.mouse_entered.connect(_hover.bind(i))
		p.gui_input.connect(_click.bind(i))
		col.add_child(p)
		menu_panels.append(p)
		menu_labels.append(l)
	_refresh_labels()

	var bp: PanelContainer = UiKit.panel(UiKit.NAVY, 12)
	best_label = UiKit.label("", 20, UiKit.YELLOW, 4)
	bp.add_child(best_label)
	col.add_child(bp)
	var best: int = int(Game.best.get("community_park", {}).get("score", 0))
	best_label.text = "BEST SCORE  %s" % Hud._commas(best)

	controls_panel = UiKit.panel(UiKit.NAVY, 20)
	controls_panel.set_anchors_preset(Control.PRESET_CENTER)
	controls_panel.visible = false
	var cv: VBoxContainer = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	controls_panel.add_child(cv)
	cv.add_child(UiKit.label("CONTROLS", 46, UiKit.YELLOW, 8))
	for line in UiKit.CONTROL_LINES:
		cv.add_child(UiKit.label(line, 20, UiKit.WHITE, 4))
	cv.add_child(UiKit.label("ESC  back", 20, UiKit.GREEN, 4))
	root.add_child(controls_panel)

	var hint: PanelContainer = UiKit.panel(UiKit.NAVY, 12)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(24, -64)
	hint.add_child(UiKit.label("UP / DOWN choose     ENTER go", 16, UiKit.WHITE, 4))
	root.add_child(hint)


func _refresh_labels() -> void:
	menu_labels[2].text = "STEERING:  %s" % ("SKATER" if Game.steer_mode == "tank" else "SCREEN")
	menu_labels[3].text = "CAMERA:  %s" % ("FOLLOW" if Game.camera_mode == "follow" else "FIXED")
	menu_labels[4].text = "JUMP:  %s" % ("HOLD, RELEASE" if Game.jump_mode == "hold" else "TAP")
	menu_labels[5].text = "MUSIC:  %s" % {"cruise": "CRUISE", "hype": "HYPE", "off": "OFF"}[Game.music_choice]
	for i in menu_panels.size():
		var on: bool = i == selected
		menu_panels[i].add_theme_stylebox_override("panel", UiKit.style(UiKit.BLUE if on else UiKit.NAVY, 14))
		menu_labels[i].add_theme_color_override("font_color", UiKit.YELLOW if on else UiKit.WHITE)


func _hover(i: int) -> void:
	selected = i
	_refresh_labels()


func _click(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = i
		_activate()


func _input(event: InputEvent) -> void:
	if controls_panel.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			controls_panel.visible = false
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		selected = (selected + 1) % menu_panels.size()
		_refresh_labels()
		Sound.play("ui_ok", -4.0, 0.9)
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		selected = (selected - 1 + menu_panels.size()) % menu_panels.size()
		_refresh_labels()
		Sound.play("ui_ok", -4.0, 0.9)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ollie"):
		# Space is the jump key: it only starts a session, it never flips a setting (use Enter or the mouse)
		var is_space: bool = event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE
		if is_space and selected >= 2:
			return
		_activate()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_T:
		_toggle_steer()


func _toggle_steer() -> void:
	Game.steer_mode = "tank" if Game.steer_mode == "screen" else "screen"
	Game.save()
	_refresh_labels()


func _activate() -> void:
	Sound.play("ui_ok")
	match selected:
		0:
			Game.free_skate = false
			get_tree().change_scene_to_file(PARK_SCENE)
		1:
			Game.free_skate = true
			get_tree().change_scene_to_file(PARK_SCENE)
		2:
			_toggle_steer()
		3:
			Game.camera_mode = "fixed" if Game.camera_mode == "follow" else "follow"
			Game.save()
			_refresh_labels()
		4:
			Game.jump_mode = "tap" if Game.jump_mode == "hold" else "hold"
			Game.save()
			_refresh_labels()
		5:
			Sound.cycle_music_choice()
			_refresh_labels()
		6:
			controls_panel.visible = true
