class_name OptionsScreen
extends ColorRect
## Options, over the title or the pause menu: display (window, vsync, quality), sound (three volumes, the music
## choice) and play (stance, steering, jump, combo rules, camera shake, the update check). Up / down pick a row,
## left / right (or Enter, or a click) change it, Esc / B closes. Every change applies at once and is saved.

signal closed
signal changed(key: String)             # a setting changed (the title respawns its rider on "stance", ...)

const STEP: float = 0.1                 # volume steps
const ROWS: Array = [
	["Display", ""],
	["window", "Window"],
	["vsync", "V-Sync"],
	["quality", "Quality"],
	["Sound", ""],
	["master", "Master volume"],
	["music_vol", "Music volume"],
	["sfx_vol", "Effects volume"],
	["music", "Music"],
	["Play", ""],
	["stance", "Stance"],
	["steer", "Steering"],
	["jump", "Jump"],
	["combo", "Combo rules"],
	["shake", "Camera shake"],
	["updates", "Check for updates"],
]
const ABOUT: Dictionary = {
	"window": "Fullscreen or a window. Alt+Enter or F11 switches any time.",
	"vsync": "Waits for the screen's refresh: no tearing. Off can feel a touch quicker on a fast display.",
	"quality": "Anti-aliasing and shadow detail. Lower it if the game stutters on an older computer.",
	"master": "Everything.",
	"music_vol": "The soundtrack.",
	"music_vol_off": "The soundtrack (Music is set to Off).",
	"sfx_vol": "The board, tricks, crashes, the crowd and the place around you.",
	"music": "Themes: each place's own soundtrack. Hype: the harder track everywhere.",
	"stance": "Rider's own: each rider's foot forward. Or every rider regular (left foot) or goofy (right foot).",
	"steer": "Skater: left / right turn the board, up pushes. Screen: the stick points where you want to go.",
	"jump": "Hold and release: hold longer to jump higher. Tap: jump the moment you press.",
	"combo": "Standard: half a second on the ground to keep a combo going, and sketchy landings cost the multiplier. Relaxed: about a second, and they don't.",
	"shake": "A crash shakes the camera as hard as it was.",
	"updates": "Once a day, ask GitHub whether there's a newer version (shown on the title menu).",
}

var selected: int = 1
var _labels: Array[Label] = []          # one per row (captions included, so indices match ROWS)
var _values: Array[Label] = []
var _about: Label


func _init() -> void:
	color = Color(UiKit.INK, 0.72)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS      # (opens over the pause menu)
	visible = false
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var p: PanelContainer = UiKit.panel(0.88, 8, UiKit.ACCENT)
	cc.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size = Vector2(640, 0)
	p.add_child(v)
	v.add_child(UiKit.label("OPTIONS", 52, UiKit.PAPER, "display"))
	for i in ROWS.size():
		var key: String = ROWS[i][0]
		if ROWS[i][1] == "":
			var gap: Control = Control.new()
			gap.custom_minimum_size = Vector2(0, 8 if i > 0 else 0)
			v.add_child(gap)
			var cap: Label = UiKit.caption(key, 19, UiKit.ACCENT)
			v.add_child(cap)
			_labels.append(cap)
			_values.append(null)
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_entered.connect(func() -> void:
			if selected != i:
				selected = i
				refresh())
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed:
				selected = i
				if e.button_index == MOUSE_BUTTON_LEFT:
					_change(1)
				elif e.button_index == MOUSE_BUTTON_RIGHT:
					_change(-1))
		var l: Label = UiKit.label("", 26, UiKit.PAPER, "bold")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var val: Label = UiKit.label("", 26, UiKit.PAPER, "body")
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		v.add_child(row)
		_labels.append(l)
		_values.append(val)
	var gap2: Control = Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap2)
	_about = UiKit.label("", 21, UiKit.MUTED, "body")
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about.custom_minimum_size = Vector2(640, 52)
	v.add_child(_about)
	v.add_child(UiKit.hints([["UP / DOWN", "choose", "D-PAD UP / DOWN"], ["LEFT / RIGHT", "change", "D-PAD LEFT / RIGHT"],
		["ESC", "back", "B"]]))


func open() -> void:
	selected = 1
	visible = true
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func _row_key() -> String:
	return String(ROWS[selected][0])


func value_text(key: String) -> String:
	match key:
		"window":
			return "Fullscreen" if Game.window_mode == "fullscreen" else "Windowed"
		"vsync":
			return "On" if Game.vsync else "Off"
		"quality":
			return Game.quality.capitalize()
		"master":
			return "%d%%" % int(round(Game.master_volume * 100.0))
		"music_vol":
			return "%d%%" % int(round(Game.music_volume * 100.0))
		"sfx_vol":
			return "%d%%" % int(round(Game.sfx_volume * 100.0))
		"music":
			return {"cruise": "Themes", "hype": "Hype", "off": "Off"}[Game.music_choice]
		"stance":
			return {"own": "Rider's own", "regular": "Regular", "goofy": "Goofy"}[Game.stance]
		"steer":
			return "Skater" if Game.steer_mode == "tank" else "Screen"
		"jump":
			return "Hold, release" if Game.jump_mode == "hold" else "Tap"
		"combo":
			return Game.combo_rules.capitalize()
		"shake":
			return "On" if Game.camera_shake else "Off"
		"updates":
			return "On" if Game.check_updates else "Off"
	return ""


func refresh() -> void:
	for i in ROWS.size():
		if _values[i] == null:
			continue
		var on: bool = i == selected
		var key: String = ROWS[i][0]
		_labels[i].text = ("›  " if on else "") + String(ROWS[i][1]).to_upper()
		_labels[i].add_theme_color_override("font_color", UiKit.ACCENT if on else Color(UiKit.PAPER, 0.88))
		var val: String = value_text(key)
		_values[i].text = ("‹  %s  ›" % val) if on else val
		_values[i].add_theme_color_override("font_color", UiKit.ACCENT if on else Color(UiKit.PAPER, 0.8))
	var k: String = _row_key()
	if k == "music_vol" and Game.music_choice == "off":
		k = "music_vol_off"
	_about.text = String(ABOUT.get(k, ""))


func _step_row(step: int) -> void:
	var i: int = selected
	for n in ROWS.size():
		i = posmod(i + step, ROWS.size())
		if String(ROWS[i][1]) != "":
			break
	selected = i
	refresh()


## Left / right: step the selected setting (volumes by 10%, choices round in a loop) and apply it.
func _change(step: int) -> void:
	var key: String = _row_key()
	match key:
		"window":
			Game.window_mode = "windowed" if Game.window_mode == "fullscreen" else "fullscreen"
			Game.apply_display()
		"vsync":
			Game.vsync = not Game.vsync
			Game.apply_display()
		"quality":
			var order: Array[String] = ["low", "medium", "high"]
			Game.quality = order[posmod(order.find(Game.quality) + step, order.size())]
			Game.apply_quality()
		"master":
			Game.master_volume = clampf(snappedf(Game.master_volume + STEP * step, STEP), 0.0, 1.0)
			Sound.apply_settings()
		"music_vol":
			Game.music_volume = clampf(snappedf(Game.music_volume + STEP * step, STEP), 0.0, 1.0)
			Sound.apply_settings()
		"sfx_vol":
			Game.sfx_volume = clampf(snappedf(Game.sfx_volume + STEP * step, STEP), 0.0, 1.0)
			Sound.apply_settings()
		"music":
			Sound.cycle_music_choice(step)
		"stance":
			var order2: Array[String] = ["own", "regular", "goofy"]
			Game.stance = order2[posmod(order2.find(Game.stance) + step, order2.size())]
		"steer":
			Game.steer_mode = "tank" if Game.steer_mode == "screen" else "screen"
		"jump":
			Game.jump_mode = "tap" if Game.jump_mode == "hold" else "hold"
		"combo":
			Game.combo_rules = "relaxed" if Game.combo_rules == "standard" else "standard"
		"shake":
			Game.camera_shake = not Game.camera_shake
		"updates":
			Game.check_updates = not Game.check_updates
		_:
			return
	Game.save()
	Sound.play("ui_ok", -4.0, 1.1)
	changed.emit(key)
	refresh()


## The title (or the pause menu) forwards its input here while this is open. Returns whether it was used.
func handle(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_down") or Controls.nav_pressed(event, "ui_down"):
		_step_row(1)
		Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_up") or Controls.nav_pressed(event, "ui_up"):
		_step_row(-1)
		Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_right") or Controls.nav_pressed(event, "ui_right") \
			or (event.is_action_pressed("ui_accept") and not StatsScreen._is_space(event)):
		_change(1)
	elif Controls.nav_pressed(event, "move_left") or Controls.nav_pressed(event, "ui_left"):
		_change(-1)
	else:
		return event is InputEventKey or event is InputEventJoypadButton
	return true
