class_name Hud
extends CanvasLayer
## Chunky rounded-panel HUD: score, combo chip, trick ticker, level name, timer, SKATE letters,
## floating banked / bail messages, pause and results panels.

const NAVY: Color = Color(0.17, 0.22, 0.4)
const NAVY_DK: Color = Color(0.09, 0.11, 0.2)
const YELLOW: Color = Color(1.0, 0.82, 0.25)
const BLUE: Color = Color(0.24, 0.6, 1.0)
const GREEN: Color = Color(0.3, 0.85, 0.5)
const RED: Color = Color(1.0, 0.35, 0.35)
const WHITE: Color = Color(0.96, 0.98, 1.0)

signal restart_requested
signal resume_requested

var _font: FontVariation
var root: Control
var score_value: Label
var chip: PanelContainer
var chip_label: Label
var trick_panel: PanelContainer
var trick_label: Label
var pending_label: Label
var level_label: Label
var timer_label: Label
var best_label: Label
var letters: Array[Label] = []
var speed_bar: ProgressBar
var center_label: Label
var toast_layer: Control
var hint_label: Label
var pause_panel: PanelContainer
var results_panel: PanelContainer
var results_body: Label
var _shown_score: float = 0.0
var _target_score: int = 0
var _chip_bump: float = 0.0
var _center_t: float = 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 0.9
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_left()
	_build_top_right()
	_build_bottom()
	_build_center()
	_build_pause()
	_build_results()


# ------------------------------------------------------------------ builders

func _style(fill: Color, radius: int = 14, border: Color = NAVY_DK, bw: int = 4) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _panel(fill: Color, radius: int = 14) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(fill, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(text: String, size: int, color: Color = WHITE, outline: int = 5) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", NAVY_DK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_top_left() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.position = Vector2(24, 20)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)

	var sp: PanelContainer = _panel(NAVY)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	sp.add_child(h)
	h.add_child(_label("SCORE:", 26))
	score_value = _label("0", 34, YELLOW)
	score_value.custom_minimum_size = Vector2(150, 0)
	h.add_child(score_value)
	col.add_child(sp)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip = _panel(BLUE, 12)
	chip.custom_minimum_size = Vector2(84, 0)
	chip_label = _label("X1", 44, YELLOW, 7)
	chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(chip_label)
	row.add_child(chip)
	trick_panel = _panel(NAVY, 12)
	var tv: VBoxContainer = VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	trick_label = _label("", 24, WHITE)
	trick_label.custom_minimum_size = Vector2(300, 0)
	pending_label = _label("", 20, YELLOW)
	tv.add_child(trick_label)
	tv.add_child(pending_label)
	trick_panel.add_child(tv)
	row.add_child(trick_panel)
	col.add_child(row)

	var lp: PanelContainer = _panel(NAVY, 12)
	level_label = _label("LVL 01 - COMMUNITY PARK", 20)
	lp.add_child(level_label)
	col.add_child(lp)
	chip.modulate.a = 0.0
	trick_panel.modulate.a = 0.0


func _build_top_right() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.position = Vector2(-220, 20)
	col.custom_minimum_size = Vector2(196, 0)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	var tp: PanelContainer = _panel(NAVY)
	timer_label = _label("2:00", 40, WHITE, 6)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tp.add_child(timer_label)
	col.add_child(tp)
	var bp: PanelContainer = _panel(NAVY, 12)
	best_label = _label("BEST 0", 20, YELLOW)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bp.add_child(best_label)
	col.add_child(bp)
	var lp: PanelContainer = _panel(NAVY, 12)
	var lh: HBoxContainer = HBoxContainer.new()
	lh.add_theme_constant_override("separation", 6)
	lp.add_child(lh)
	for ch in "SKATE":
		var l: Label = _label(ch, 26, Color(0.5, 0.55, 0.7))
		lh.add_child(l)
		letters.append(l)
	col.add_child(lp)


func _build_bottom() -> void:
	var bp: PanelContainer = _panel(NAVY, 12)
	bp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bp.position = Vector2(24, -64)
	hint_label = _label("WASD ROLL   SPACE OLLIE   J FLIP   K GRAB   L GRIND   M MANUAL   SHIFT BRAKE   Q/E CAMERA", 16, WHITE, 4)
	bp.add_child(hint_label)
	root.add_child(bp)
	hint_label.set_meta("panel", bp)
	var sp: PanelContainer = _panel(NAVY, 12)
	sp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sp.position = Vector2(-236, -64)
	var sh: HBoxContainer = HBoxContainer.new()
	sh.add_theme_constant_override("separation", 8)
	sp.add_child(sh)
	sh.add_child(_label("SPEED", 16, WHITE, 4))
	speed_bar = ProgressBar.new()
	speed_bar.custom_minimum_size = Vector2(120, 16)
	speed_bar.show_percentage = false
	speed_bar.max_value = 16.0
	var bg: StyleBoxFlat = _style(NAVY_DK, 8, NAVY_DK, 0)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fg: StyleBoxFlat = _style(YELLOW, 8, YELLOW, 0)
	fg.shadow_size = 0
	speed_bar.add_theme_stylebox_override("background", bg)
	speed_bar.add_theme_stylebox_override("fill", fg)
	sh.add_child(speed_bar)
	root.add_child(sp)


func _build_center() -> void:
	center_label = _label("", 72, YELLOW, 10)
	center_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center_label.position = Vector2(-300, 150)
	center_label.custom_minimum_size = Vector2(600, 0)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(center_label)
	toast_layer = Control.new()
	toast_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_layer)


func _build_pause() -> void:
	pause_panel = _panel(NAVY, 20)
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.visible = false
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pause_panel.add_child(v)
	v.add_child(_label("PAUSED", 46, YELLOW, 8))
	var lines: Array[String] = [
		"WASD / STICK  roll and steer (camera-relative)",
		"SPACE / A  ollie          SHIFT / LT  brake",
		"J / X  flip (steer for variations)",
		"K / B  hold to grab (steer for variations)",
		"L / Y  grind: press near a rail, ledge or coping",
		"M / RT  manual on flat ground",
		"AIR: left / right spins   Q / E  turn camera",
		"R  reset to start        T  toggle tank steering",
		"",
		"ESC  resume      ENTER  restart session",
	]
	for line in lines:
		v.add_child(_label(line, 20, WHITE, 4))
	root.add_child(pause_panel)


func _build_results() -> void:
	results_panel = _panel(NAVY, 22)
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.visible = false
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	results_panel.add_child(v)
	v.add_child(_label("SESSION OVER", 50, YELLOW, 8))
	results_body = _label("", 26, WHITE, 5)
	v.add_child(results_body)
	v.add_child(_label("ENTER  skate again", 22, GREEN, 5))
	root.add_child(results_panel)


# ------------------------------------------------------------------ updates

func _process(delta: float) -> void:
	_shown_score = lerpf(_shown_score, float(_target_score), 1.0 - exp(-9.0 * delta))
	if absf(_shown_score - _target_score) < 1.0:
		_shown_score = float(_target_score)
	score_value.text = _commas(int(round(_shown_score)))
	_chip_bump = maxf(0.0, _chip_bump - delta * 5.0)
	var s: float = 1.0 + _chip_bump * 0.35
	chip.pivot_offset = chip.size * 0.5
	chip.scale = Vector2(s, s)
	if _center_t > 0.0:
		_center_t -= delta
		center_label.modulate.a = clampf(_center_t / 0.5, 0.0, 1.0)
		if _center_t <= 0.0:
			center_label.text = ""


func set_score(v: int) -> void:
	_target_score = v


func set_combo(mult: int, names_text: String, pending: int, live: bool) -> void:
	var was_visible: bool = chip.modulate.a > 0.5
	var t: float = 1.0 if live else 0.0
	chip.modulate.a = lerpf(chip.modulate.a, t, 0.35)
	trick_panel.modulate.a = lerpf(trick_panel.modulate.a, t, 0.35)
	if live:
		var new_text: String = "X%d" % mult
		if chip_label.text != new_text:
			_chip_bump = 1.0
		chip_label.text = new_text
		trick_label.text = names_text.to_upper()
		pending_label.text = "%s x %d" % [_commas(pending), mult]
	elif was_visible and chip.modulate.a < 0.5:
		trick_label.text = ""


func set_timer(seconds: float, running: bool) -> void:
	var s: int = maxi(0, int(ceil(seconds)))
	timer_label.text = "%d:%02d" % [s / 60, s % 60]
	timer_label.add_theme_color_override("font_color", RED if (running and seconds < 10.0) else WHITE)


func set_speed(v: float) -> void:
	speed_bar.value = v


func set_best(v: int) -> void:
	best_label.text = "BEST %s" % _commas(v)


func set_letters(have: Array) -> void:
	for i in letters.size():
		letters[i].add_theme_color_override("font_color", YELLOW if have[i] else Color(0.5, 0.55, 0.7))


func announce(text: String, color: Color = YELLOW, seconds: float = 1.6) -> void:
	center_label.text = text
	center_label.add_theme_color_override("font_color", color)
	center_label.modulate.a = 1.0
	_center_t = seconds + 0.5


func toast(text: String, color: Color, from: Vector2) -> void:
	var l: Label = _label(text, 38, color, 8)
	l.position = from
	toast_layer.add_child(l)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", from.y - 90.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


func show_pause(v: bool) -> void:
	pause_panel.visible = v


func show_results(text: String) -> void:
	results_body.text = text
	results_panel.visible = true


func hide_hint() -> void:
	var bp: Control = hint_label.get_meta("panel")
	var tw: Tween = create_tween()
	tw.tween_property(bp, "modulate:a", 0.0, 1.0)


static func _commas(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	var c: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
