extends Node3D
## Title: Neighborhood Park under a slowly circling camera, the chosen rider standing on the board, and the menu.

const EVENT_SCENE: String = "res://scenes/birthday.tscn"
const FREE_SCENE: String = "res://scenes/neighborhood.tscn"
const PRACTICE_SCENE: String = "res://scenes/greybox.tscn"
const RIDERS: Array[String] = ["dev", "musician", "vlogger", "dad", "actor"]
const CENTRE: Vector3 = Vector3(-12.0, 0.0, 4.0)

var level: Level
var cam: Camera3D
var rider: Skater
var ui: CanvasLayer
var menu_panels: Array[PanelContainer] = []
var menu_labels: Array[Label] = []
var selected: int = 0
var controls_panel: PanelContainer
var best_label: Label
var _orbit: float = 0.6


func _ready() -> void:
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/neighborhood.glb", "real")
	RealEnv.build(self, level.lightmap_info)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	_spawn_rider()
	_build_ui()
	Sound.play_music("boardwalk_morning")


func _spawn_rider() -> void:
	if rider != null:
		rider.queue_free()
	rider = Skater.new()
	rider.rider = Game.rider
	rider.scripted = true
	rider.is_player = false
	add_child(rider)
	rider.place_at(Transform3D(Basis(Vector3.UP, 0.5), Vector3(-12.0, 0.02, 6.0)))


func _process(delta: float) -> void:
	_orbit += delta * 0.05
	var at: Vector3 = rider.global_position + Vector3.UP * 1.0
	var pos: Vector3 = at + Vector3(sin(_orbit) * 5.5, 1.2, cos(_orbit) * 5.5)
	cam.global_transform = Transform3D(Basis.looking_at(at - pos + Vector3(-1.2, 0.0, 0.0), Vector3.UP), pos)


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
	lv.add_child(UiKit.label("NOT PRO", 72, UiKit.YELLOW, 12))
	lv.add_child(UiKit.label("SKATERS", 72, UiKit.WHITE, 12))
	lv.add_child(UiKit.label("skating for everyone else", 20, UiKit.BLUE, 4))
	col.add_child(logo)

	var items: Array[String] = ["BIRTHDAY AT THE PARK", "FREE SKATE", "PRACTICE", "", "", "", "", "CONTROLS"]
	for i in items.size():
		var p: PanelContainer = UiKit.panel(UiKit.NAVY, 14)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var l: Label = UiKit.label(items[i], 26, UiKit.WHITE, 5)
		p.add_child(l)
		p.mouse_entered.connect(_hover.bind(i))
		p.gui_input.connect(_click.bind(i))
		col.add_child(p)
		menu_panels.append(p)
		menu_labels.append(l)

	var bp: PanelContainer = UiKit.panel(UiKit.NAVY, 12)
	best_label = UiKit.label("", 18, UiKit.YELLOW, 4)
	bp.add_child(best_label)
	col.add_child(bp)
	_refresh_labels()

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
	hint.add_child(UiKit.label("UP / DOWN choose     ENTER go     LEFT / RIGHT change rider", 16, UiKit.WHITE, 4))
	root.add_child(hint)


func _rider_name(key: String) -> String:
	return "THE " + key.to_upper()


func _refresh_labels() -> void:
	menu_labels[3].text = "RIDER:  %s" % _rider_name(Game.rider)
	menu_labels[4].text = "STEERING:  %s" % ("SKATER" if Game.steer_mode == "tank" else "SCREEN")
	menu_labels[5].text = "JUMP:  %s" % ("HOLD, RELEASE" if Game.jump_mode == "hold" else "TAP")
	menu_labels[6].text = "MUSIC:  %s" % {"cruise": "CRUISE", "hype": "HYPE", "off": "OFF"}[Game.music_choice]
	for i in menu_panels.size():
		var on: bool = i == selected
		menu_panels[i].add_theme_stylebox_override("panel", UiKit.style(UiKit.BLUE if on else UiKit.NAVY, 14))
		menu_labels[i].add_theme_color_override("font_color", UiKit.YELLOW if on else UiKit.WHITE)
	var done: int = Game.event_goals("birthday").size()
	var goals: int = (Events.get_event("birthday")["goals"] as Array).size()
	var best: int = int(Game.best.get("birthday", {}).get("score", 0))
	best_label.text = "BIRTHDAY GOALS  %d/%d     BEST  %s" % [done, goals, Hud._commas(best)]


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
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_cycle_rider(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_cycle_rider(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ollie"):
		# Space is the jump key: it only starts a session, it never flips a setting (use Enter or the mouse)
		var is_space: bool = event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE
		if is_space and selected >= 3:
			return
		_activate()


func _cycle_rider(step: int) -> void:
	var i: int = RIDERS.find(Game.rider)
	Game.rider = RIDERS[posmod(i + step, RIDERS.size())]
	Game.save()
	_spawn_rider()
	_refresh_labels()
	Sound.play("ui_ok", -4.0, 1.1)


func _activate() -> void:
	Sound.play("ui_ok")
	match selected:
		0:
			get_tree().change_scene_to_file(EVENT_SCENE)
		1:
			get_tree().change_scene_to_file(FREE_SCENE)
		2:
			get_tree().change_scene_to_file(PRACTICE_SCENE)
		3:
			_cycle_rider(1)
		4:
			Game.steer_mode = "tank" if Game.steer_mode == "screen" else "screen"
			Game.save()
			_refresh_labels()
		5:
			Game.jump_mode = "tap" if Game.jump_mode == "hold" else "hold"
			Game.save()
			_refresh_labels()
		6:
			Sound.cycle_music_choice()
			_refresh_labels()
		7:
			controls_panel.visible = true
