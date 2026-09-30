extends Node3D
## Title: Neighborhood Park under a slowly circling camera, the chosen rider on the board, the logo and menu on
## the left, the rider's card bottom right. Up / down choose, Enter goes, left / right change a setting, Esc jumps
## to Quit (desktop builds; a browser tab has nothing to quit to).

const PRACTICE_SCENE: String = "res://scenes/greybox.tscn"
const SPOT: Vector3 = Vector3(-18.0, 0.02, 4.0)      # where the rider stands: by the mini ramp, in the late sun
const ITEMS: Array[String] = ["event", "free", "practice", "rider", "steer", "jump", "music", "controls"]
const PLAY_ITEMS: int = 3                # the big entries (things to play) before the settings

var items: Array[String] = []         # ITEMS, plus Quit on desktop
var level: Level
var cam: Camera3D
var rider: Skater
var ui: CanvasLayer
var rows: Array[HBoxContainer] = []
var row_labels: Array[Label] = []
var row_values: Array[Label] = []
var selected: int = 0
var controls_layer: Control
var progress_label: Label
var rider_name: Label
var rider_blurb: Label
var _hint: Control
var _hint_root: Control
var _orbit: float = 0.0             # set in _ready: starts on the sunny side, the rider's front three-quarter
var _swing_t: float = 0.0           # the camera swings either side of that


func _ready() -> void:
	level = Level.new()
	add_child(level)
	level.load_glb("res://assets/levels/neighborhood.gltf", "real")
	RealEnv.build(self, level.lightmap_info)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	var sh: Vector3 = _sun_h()
	_orbit = atan2(sh.x, sh.z) - 0.45
	_spawn_rider()
	items = ITEMS.duplicate()
	if not OS.has_feature("web"):
		items.append("quit")
	_build_ui()
	Sound.play_music("title")
	Sound.play_ambience("park_ambience", -16.0)


func _spawn_rider() -> void:
	if rider != null:
		rider.queue_free()
	rider = Skater.new()
	rider.rider = Game.rider
	rider.scripted = true
	add_child(rider)
	# chest to the sun (a regular rider's chest faces the board's right): lit from the front on the title
	var sun_h: Vector3 = _sun_h()
	var hdg: Vector3 = Vector3.UP.cross(sun_h)
	var spot: Vector3 = SPOT
	if OS.get_environment("TITLE_AT") != "":
		var p: PackedStringArray = OS.get_environment("TITLE_AT").split(",")
		spot = Vector3(float(p[0]), 0.02, float(p[1]))
	rider.place_at(Transform3D(Basis.looking_at(hdg, Vector3.UP), spot))


func _sun_h() -> Vector3:
	var d: Array = level.lightmap_info.get("sun_dir", [0.7, 0.3, 0.6])
	var v: Vector3 = Vector3(d[0], 0.0, d[2])
	return v.normalized() if v.length() > 0.01 else Vector3(0, 0, 1)


func _process(delta: float) -> void:
	# a slow swing either side of the opening view (a full circle spent half a minute of every two behind the
	# quarter pipe, looking through its handrail)
	_swing_t += delta
	var a: float = _orbit + sin(_swing_t * 0.09) * 0.9
	var at: Vector3 = rider.global_position + Vector3.UP * 1.0
	var pos: Vector3 = at + Vector3(sin(a) * 5.5, 1.2, cos(a) * 5.5)
	# the rider sits right of centre, clear of the menu: look a little to the camera's left of them
	var right: Vector3 = (at - pos).cross(Vector3.UP).normalized()
	cam.global_transform = Transform3D(Basis.looking_at(at - right * 1.4 - pos, Vector3.UP), pos)


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# a soft dark wash behind the left column keeps the text readable over a bright sky
	var wash: TextureRect = TextureRect.new()
	var grad: GradientTexture2D = GradientTexture2D.new()
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(UiKit.INK, 0.8))
	g.add_point(0.55, Color(UiKit.INK, 0.5))
	g.set_color(g.get_point_count() - 1, Color(UiKit.INK, 0.0))
	grad.gradient = g
	grad.fill_to = Vector2(1.0, 0.0)
	grad.width = 256
	grad.height = 4
	wash.texture = grad
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.anchor_bottom = 1.0
	wash.offset_right = 900.0
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wash)

	var col: VBoxContainer = VBoxContainer.new()
	col.position = Vector2(72, 64)
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var logo: VBoxContainer = VBoxContainer.new()
	logo.add_theme_constant_override("separation", -34)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(UiKit.label("NOT PRO", 108, UiKit.ACCENT, "display"))
	logo.add_child(UiKit.label("SKATER", 108, UiKit.PAPER, "display"))
	col.add_child(logo)
	col.add_child(UiKit.label("Skating for everyone else", 26, UiKit.MUTED, "body"))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 34)
	col.add_child(gap)

	for i in items.size():
		if i == PLAY_ITEMS or items[i] == "quit":
			var g2: Control = Control.new()
			g2.custom_minimum_size = Vector2(0, 18)
			col.add_child(g2)
		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(460, 0)
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var big: bool = i < PLAY_ITEMS
		var name_l: Label = UiKit.label("", 38 if big else 25, UiKit.PAPER, "bold")
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var val_l: Label = UiKit.label("", 25, UiKit.MUTED, "body")
		row.add_child(name_l)
		row.add_child(val_l)
		row.mouse_entered.connect(_hover.bind(i))
		row.gui_input.connect(_click.bind(i))
		col.add_child(row)
		rows.append(row)
		row_labels.append(name_l)
		row_values.append(val_l)
	var gap3: Control = Control.new()
	gap3.custom_minimum_size = Vector2(0, 22)
	col.add_child(gap3)
	progress_label = UiKit.label("", 21, UiKit.MUTED, "bold")
	col.add_child(progress_label)

	# the rider's card, bottom right
	var card_panel: PanelContainer = UiKit.panel(0.6, 6)
	card_panel.anchor_left = 1.0
	card_panel.anchor_right = 1.0
	card_panel.anchor_top = 1.0
	card_panel.anchor_bottom = 1.0
	card_panel.offset_left = -576.0          # wide enough that no blurb ends on a one-word line
	card_panel.offset_right = -56.0
	card_panel.offset_top = -196.0
	card_panel.offset_bottom = -52.0
	card_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(card_panel)
	var card: VBoxContainer = VBoxContainer.new()
	card.add_theme_constant_override("separation", -4)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(card)
	var cap: Label = UiKit.caption("Rider", 19, UiKit.ACCENT)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(cap)
	rider_name = UiKit.label("", 60, UiKit.PAPER, "display")
	rider_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(rider_name)
	rider_blurb = UiKit.label("", 23, UiKit.PAPER, "body")
	rider_blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rider_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(rider_blurb)

	_hint_root = root
	_build_hints()
	Controls.device_changed.connect(func(_pad: bool) -> void: _build_hints())

	controls_layer = ColorRect.new()
	(controls_layer as ColorRect).color = Color(UiKit.INK, 0.72)
	controls_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_layer.add_child(cc)
	var p: PanelContainer = UiKit.panel(0.85, 8, UiKit.ACCENT)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UiKit.label("CONTROLS", 44, UiKit.PAPER, "display"))
	v.add_child(UiKit.controls_grid())
	v.add_child(UiKit.label("ESC / B  back", 19, UiKit.MUTED, "bold"))
	cc.add_child(p)
	controls_layer.visible = false
	root.add_child(controls_layer)
	_refresh()


func _build_hints() -> void:
	if _hint != null:
		_hint.queue_free()
	var pairs: Array = [["UP / DOWN", "choose", "D-PAD UP / DOWN"], ["ENTER", "go", "A"], ["LEFT / RIGHT", "change", "D-PAD LEFT / RIGHT"]]
	if items.has("quit"):
		pairs.append(["ESC", "quit", "B"])
	_hint = UiKit.hints(pairs)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(72, -56)
	_hint_root.add_child(_hint)


func _refresh() -> void:
	var ev: Dictionary = Events.get_event(Game.event_choice)
	var level_name: String = String(_level()["name"])
	var names: Dictionary = {"event": String(ev["title"]), "free": "Free Skate", "practice": "Practice",
		"rider": "Rider", "steer": "Steering", "jump": "Jump", "music": "Music", "controls": "Controls", "quit": "Quit"}
	var values: Dictionary = {
		"event": "%d / %d" % [Events.ALL.find(Game.event_choice) + 1, Events.ALL.size()],
		"free": level_name,
		"rider": Game.rider_name(Game.rider),
		"steer": "Skater" if Game.steer_mode == "tank" else "Screen",
		"jump": "Hold, release" if Game.jump_mode == "hold" else "Tap",
		"music": {"cruise": "Cruise", "hype": "Hype", "off": "Off"}[Game.music_choice],
	}
	for i in items.size():
		var on: bool = i == selected
		var key: String = items[i]
		row_labels[i].text = ("›  " if on else "") + String(names[key]).to_upper()
		row_labels[i].add_theme_color_override("font_color", UiKit.ACCENT if on else Color(UiKit.PAPER, 0.88))
		var val: String = String(values.get(key, ""))
		row_values[i].text = ("‹  %s  ›" % val) if (on and val != "") else val
		row_values[i].add_theme_color_override("font_color", UiKit.ACCENT if on else Color(UiKit.PAPER, 0.8))
	# the chosen event: whose home it is, its goals so far and the best; then every event's goals together
	var home: String = String(Events.HOME.get(Game.event_choice, ""))
	var done: int = Game.event_goals(Game.event_choice).size()
	var best: int = int(Game.best.get(Game.event_choice, {}).get("score", 0))
	var money: float = float(ev.get("money", 0.0))
	var best_text: String = ("$" + UiKit.commas(int(round(best * money)))) if money > 0.0 else UiKit.commas(best)
	var all_done: int = 0
	var all_goals: int = 0
	for eid in Events.ALL:
		all_done += Game.event_goals(eid).size()
		all_goals += (Events.get_event(eid)["goals"] as Array).size()
	var lines: Array[String] = [
		(Game.rider_name(home) + "'s home event" if home != "" else "Everyone's event").to_upper()
			+ "    %d / %d GOALS" % [done, (ev["goals"] as Array).size()] + (("    BEST  " + best_text) if best > 0 else ""),
		"ALL EVENTS  %d / %d GOALS" % [all_done, all_goals],
	]
	# the footer follows the row: Free Skate describes its level, Rider the rider's own event
	match items[selected] if selected < items.size() else "":
		"free":
			lines[0] = "%s    NO CLOCK, NO GOALS: JUST SKATE" % level_name.to_upper()
		"practice":
			lines[0] = "THE GREY TEST LEVEL: EVERY RAMP AND RAIL IN ROWS"
		"rider":
			var own: String = ""
			for eid in Events.HOME:
				if Events.HOME[eid] == Game.rider:
					own = eid
			if own != "":
				var oev: Dictionary = Events.get_event(own)
				lines[0] = "%s'S HOME EVENT: %s    %d / %d GOALS" % [Game.rider_name(Game.rider).to_upper(),
					String(oev["title"]), Game.event_goals(own).size(), (oev["goals"] as Array).size()]
	progress_label.text = "\n".join(lines)
	rider_name.text = Game.rider_name(Game.rider).to_upper()
	rider_blurb.text = String(Game.RIDER_INFO.get(Game.rider, {}).get("blurb", ""))


func _hover(i: int) -> void:
	if selected != i:
		selected = i
		_refresh()


func _click(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = i
		_activate(1)


func _input(event: InputEvent) -> void:
	if controls_layer.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			controls_layer.visible = false
			get_viewport().set_input_as_handled()
		return
	if Controls.nav_pressed(event, "move_down") or Controls.nav_pressed(event, "ui_down"):
		selected = (selected + 1) % items.size()
		_refresh()
		Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_up") or Controls.nav_pressed(event, "ui_up"):
		selected = (selected - 1 + items.size()) % items.size()
		_refresh()
		Sound.play("ui_ok", -6.0, 0.9)
	elif (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and items.has("quit"):
		if items[selected] != "quit":
			selected = items.find("quit")          # Esc on the title: onto Quit (Enter then quits)
			_refresh()
			Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_left") or Controls.nav_pressed(event, "ui_left"):
		_change(-1)
	elif Controls.nav_pressed(event, "move_right") or Controls.nav_pressed(event, "ui_right"):
		_change(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ollie"):
		# Space is the jump key: it only starts a session, it never flips a setting (use Enter or the mouse)
		var is_space: bool = event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE
		if is_space and selected >= PLAY_ITEMS:
			return
		_activate(1)


func _level() -> Dictionary:
	for lv in Events.LEVELS:
		if lv["id"] == Game.level_choice:
			return lv
	return Events.LEVELS[0]


## Left / right: a setting steps; on the rider row it swaps the rider, on EVENT the event, on FREE SKATE the level.
func _change(step: int) -> void:
	match items[selected]:
		"event":
			Game.event_choice = Events.ALL[posmod(Events.ALL.find(Game.event_choice) + step, Events.ALL.size())]
			Game.save()
		"free":
			var ids: Array = Events.LEVELS.map(func(lv: Dictionary) -> String: return String(lv["id"]))
			Game.level_choice = ids[posmod(ids.find(Game.level_choice) + step, ids.size())]
			Game.save()
		"rider":
			var i: int = Game.RIDERS.find(Game.rider)
			Game.rider = Game.RIDERS[posmod(i + step, Game.RIDERS.size())]
			Game.save()
			_spawn_rider()
		"steer":
			Game.steer_mode = "tank" if Game.steer_mode == "screen" else "screen"
			Game.save()
		"jump":
			Game.jump_mode = "tap" if Game.jump_mode == "hold" else "hold"
			Game.save()
		"music":
			Sound.cycle_music_choice()
		_:
			return
	Sound.play("ui_ok", -4.0, 1.1)
	_refresh()


func _activate(step: int) -> void:
	Sound.play("ui_ok")
	match items[selected]:
		"event":
			Game.go(Events.scene(Game.event_choice))
		"free":
			Game.go(String(_level()["scene"]))
		"practice":
			Game.go(PRACTICE_SCENE)
		"controls":
			controls_layer.visible = true
		"quit":
			get_tree().quit()
		_:
			_change(step)
