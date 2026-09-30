class_name Hud
extends CanvasLayer
## In-game HUD, sports-broadcast style: score top left with the event's goal checklist under it, the clock top
## right, the trick string bottom centre (tricks + points x multiplier, which banks green or bails red), meters
## for pop and manual balance, title cards for announcements, and the pause and results screens. An event with
## letters to collect (P-A-R-T-Y) shows them as balloon badges top centre.

const ACCENT: Color = UiKit.ACCENT
const GOOD: Color = UiKit.GOOD
const BAD: Color = UiKit.BAD
const INFO: Color = UiKit.INFO
const PAPER: Color = UiKit.PAPER
const MUTED: Color = UiKit.MUTED
const BALANCE_W: float = 280.0
const BACKDROP: Shader = preload("res://shaders/menu_backdrop.gdshader")
const LETTER_SIZE: float = 54.0
const LETTER_GAP: int = 10

signal resume_requested
signal restart_requested
signal quit_requested

var root: Control
var score_value: Label
var score_caption: Label
var money: float = 0.0                   # a fundraiser: the score is dollars raised, this many a point
var title_label: Label
var goals_panel: PanelContainer
var goals_box: VBoxContainer
var clock_box: VBoxContainer
var timer_label: Label
var best_label: Label
var trick_box: VBoxContainer
var trick_names: Label
var trick_points: Label
var charge_bar: ProgressBar
var balance_box: VBoxContainer
var balance_marker: ColorRect
var _blink: ColorRect = null
var letters_box: HBoxContainer
var _letter_tiles: Dictionary = {}       # letter -> {"tile": Control, "label": Label, "color": Color, "got": bool}
var _letters_word: String = ""
var _blink_tw: Tween = null
var speed_box: HBoxContainer
var speed_bar: ProgressBar
var card: VBoxContainer
var card_label: Label
var card_rule: ColorRect
var card_sub: Label
var hint_box: Control
var pause_layer: Control
var pause_items: Array[Label] = []
var pause_sel: int = 0
var controls_card: PanelContainer
var pause_menu: VBoxContainer
var results_layer: Control
var results_box: VBoxContainer
var _results_at: int = 0             # when the results came up (msec)
var _shown_score: float = 0.0
var _target_score: int = 0
var _card_t: float = 0.0
var _card_queue: Array = []                 # cards waiting their turn: [text, color, seconds, sub]
const CARD_HALF: float = 330.0              # half the centre card's width (the goal panel ends at about x 420)
const GOAL_TEXT_W: float = 330.0            # goal lines wrap at this width
var _trick_state: String = ""           # "", "live", "banked", "lost"
var _trick_t: float = 0.0
var _last_names: int = 0
var _hint_entries: Array = []
var _saved_vis: Dictionary = {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_score()
	_build_clock()
	_build_tricks()
	_build_meters()
	_build_letters()
	_build_card()
	_build_hints()
	_build_pause()
	_build_results()
	Controls.device_changed.connect(func(_pad: bool) -> void:
		if not _hint_entries.is_empty():
			var a: float = hint_box.modulate.a
			set_hints(_hint_entries)
			hint_box.modulate.a = a)


# ------------------------------------------------------------------ builders

func _build_score() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.position = Vector2(36, 26)
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	score_caption = UiKit.caption("Score")
	col.add_child(score_caption)
	score_value = UiKit.label("0", 58, PAPER, "display")
	col.add_child(score_value)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap)
	goals_panel = UiKit.panel(0.5, 6, ACCENT)
	goals_panel.custom_minimum_size = Vector2(GOAL_TEXT_W + 24, 0)
	var gv: VBoxContainer = VBoxContainer.new()
	gv.add_theme_constant_override("separation", 3)
	goals_panel.add_child(gv)
	title_label = UiKit.label("", 21, ACCENT, "bold")
	gv.add_child(title_label)
	goals_box = VBoxContainer.new()
	goals_box.add_theme_constant_override("separation", 2)
	gv.add_child(goals_box)
	goals_panel.visible = false
	col.add_child(goals_panel)


func _build_clock() -> void:
	clock_box = VBoxContainer.new()
	clock_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock_box.position = Vector2(-236, 26)
	clock_box.custom_minimum_size = Vector2(200, 0)
	clock_box.add_theme_constant_override("separation", 0)
	clock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clock_box)
	var cap: Label = UiKit.caption("Time")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_box.add_child(cap)
	timer_label = UiKit.label("2:00", 58, PAPER, "display")
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_box.add_child(timer_label)
	best_label = UiKit.label("", 19, MUTED, "bold")
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_box.add_child(best_label)
	clock_box.visible = false


func _build_tricks() -> void:
	trick_box = VBoxContainer.new()
	trick_box.anchor_left = 0.5
	trick_box.anchor_right = 0.5
	trick_box.anchor_top = 1.0
	trick_box.anchor_bottom = 1.0
	trick_box.offset_left = -480.0
	trick_box.offset_right = 480.0
	trick_box.offset_top = -196.0
	trick_box.offset_bottom = -96.0
	trick_box.alignment = BoxContainer.ALIGNMENT_END
	trick_box.add_theme_constant_override("separation", -4)
	trick_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(trick_box)
	trick_names = UiKit.label("", 30, PAPER, "bold")
	trick_names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trick_names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trick_box.add_child(trick_names)
	trick_points = UiKit.label("", 44, ACCENT, "display")
	trick_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trick_box.add_child(trick_points)
	trick_box.modulate.a = 0.0


func _build_meters() -> void:
	charge_bar = UiKit.bar(180.0, 6.0, ACCENT)
	charge_bar.max_value = 1.0
	charge_bar.anchor_left = 0.5
	charge_bar.anchor_right = 0.5
	charge_bar.anchor_top = 1.0
	charge_bar.anchor_bottom = 1.0
	charge_bar.offset_left = -90.0
	charge_bar.offset_right = 90.0
	charge_bar.offset_top = -70.0
	charge_bar.offset_bottom = -64.0
	charge_bar.visible = false
	root.add_child(charge_bar)

	# manual balance: the marker drifts toward an end; up / down bring it back
	balance_box = VBoxContainer.new()
	balance_box.anchor_left = 0.5
	balance_box.anchor_right = 0.5
	balance_box.anchor_top = 1.0
	balance_box.anchor_bottom = 1.0
	balance_box.offset_left = -BALANCE_W * 0.5
	balance_box.offset_right = BALANCE_W * 0.5
	balance_box.offset_top = -250.0
	balance_box.offset_bottom = -210.0
	balance_box.add_theme_constant_override("separation", 4)
	balance_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap: Label = UiKit.caption("Balance", 15)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_box.add_child(cap)
	var track: Control = Control.new()
	track.custom_minimum_size = Vector2(BALANCE_W, 10)
	var bg: Panel = Panel.new()
	var sb: StyleBoxFlat = UiKit.style(0.6, 5)
	bg.add_theme_stylebox_override("panel", sb)
	bg.size = Vector2(BALANCE_W, 10)
	track.add_child(bg)
	var sweet: ColorRect = ColorRect.new()
	sweet.color = Color(GOOD, 0.35)
	sweet.size = Vector2(BALANCE_W * 0.3, 10)
	sweet.position = Vector2(BALANCE_W * 0.35, 0)
	track.add_child(sweet)
	balance_marker = ColorRect.new()
	balance_marker.size = Vector2(6, 18)
	balance_marker.position.y = -4
	balance_marker.color = PAPER
	track.add_child(balance_marker)
	balance_box.add_child(track)
	balance_box.visible = false
	root.add_child(balance_box)

	speed_box = HBoxContainer.new()
	speed_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_box.position = Vector2(-240, -52)
	speed_box.add_theme_constant_override("separation", 10)
	speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_box.add_child(UiKit.caption("Speed", 15))
	speed_bar = UiKit.bar(140.0, 6.0, INFO)
	speed_bar.max_value = 16.0
	speed_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_box.add_child(speed_bar)
	speed_box.visible = false
	root.add_child(speed_box)


func _build_letters() -> void:
	letters_box = HBoxContainer.new()
	letters_box.anchor_left = 0.5
	letters_box.anchor_right = 0.5
	letters_box.offset_top = 30.0
	letters_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	letters_box.alignment = BoxContainer.ALIGNMENT_CENTER
	letters_box.add_theme_constant_override("separation", LETTER_GAP)
	letters_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letters_box.visible = false
	root.add_child(letters_box)


func _build_card() -> void:
	card = VBoxContainer.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.26             # under the letters, and below where a gate's banner sits as you ride through
	card.anchor_bottom = 0.26
	card.offset_left = -CARD_HALF      # clear of the goal panel on the left and the clock on the right
	card.offset_right = CARD_HALF
	card.add_theme_constant_override("separation", 6)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	card_label = UiKit.label("", 64, PAPER, "display")
	_outline(card_label, 12)                 # cards land on banners, walls and sky: an outline keeps them readable
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(card_label)
	var rule_row: CenterContainer = CenterContainer.new()
	rule_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_rule = ColorRect.new()
	card_rule.custom_minimum_size = Vector2(120, 4)
	card_rule.color = ACCENT
	rule_row.add_child(card_rule)
	card.add_child(rule_row)
	card_sub = UiKit.label("", 30, PAPER, "body")
	_outline(card_sub, 8)
	card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(card_sub)
	card.modulate.a = 0.0


static func _outline(l: Label, px: int) -> void:
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.75))


func _build_hints() -> void:
	hint_box = UiKit.panel(0.5, 6)
	hint_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_box.position = Vector2(30, -60)
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_box)


func _build_pause() -> void:
	pause_layer = _dim_layer()
	var c: CenterContainer = CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(c)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size = Vector2(420, 0)
	c.add_child(v)
	pause_menu = v
	var ttl: Label = UiKit.label("PAUSED", 72, PAPER, "display")
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ttl)
	var rule: ColorRect = ColorRect.new()
	rule.custom_minimum_size = Vector2(90, 4)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.color = ACCENT
	v.add_child(rule)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	v.add_child(gap)
	for i in 4:
		var l: Label = UiKit.label(["RESUME", "RESTART", "CONTROLS", "QUIT TO TITLE"][i], 36, PAPER, "bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(func() -> void: _pause_select(i))
		l.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_pause_select(i)
				_pause_activate())
		v.add_child(l)
		pause_items.append(l)
	controls_card = _controls_card()
	controls_card.visible = false
	c.add_child(controls_card)
	pause_layer.visible = false


func _controls_card() -> PanelContainer:
	var p: PanelContainer = UiKit.panel(0.85, 8, ACCENT)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(UiKit.label("CONTROLS", 44, PAPER, "display"))
	v.add_child(UiKit.controls_grid())
	var back: Label = UiKit.label("ESC / B  back", 19, MUTED, "bold")
	v.add_child(back)
	return p


func _build_results() -> void:
	results_layer = _dim_layer()
	var c: CenterContainer = CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_layer.add_child(c)
	results_box = VBoxContainer.new()
	results_box.add_theme_constant_override("separation", 4)
	results_box.custom_minimum_size = Vector2(560, 0)
	c.add_child(results_box)
	results_layer.visible = false


func _dim_layer() -> Control:
	var d: ColorRect = ColorRect.new()
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = BACKDROP
	d.material = m
	root.add_child(d)
	return d


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	_shown_score = lerpf(_shown_score, float(_target_score), 1.0 - exp(-9.0 * delta))
	if absf(_shown_score - _target_score) < 1.0:
		_shown_score = float(_target_score)
	score_value.text = amount(int(round(_shown_score)))
	# title card: fade in fast, hold, fade out
	if _card_t <= 0.0 and not _card_queue.is_empty():
		var nxt: Array = _card_queue.pop_front()
		_show_card(nxt[0], nxt[1], nxt[2], nxt[3])
	if _card_t > 0.0:
		_card_t -= delta
		card.modulate.a = clampf(_card_t / 0.45, 0.0, 1.0) * minf(1.0, card.modulate.a + delta * 8.0)
		card_rule.custom_minimum_size.x = lerpf(card_rule.custom_minimum_size.x, 160.0, 1.0 - exp(-8.0 * delta))
	# trick string: a bank shows green, a bail red, then it fades
	match _trick_state:
		"live":
			trick_box.modulate.a = minf(1.0, trick_box.modulate.a + delta * 10.0)
			trick_points.scale = trick_points.scale.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
		"banked", "lost":
			_trick_t -= delta
			trick_box.modulate.a = clampf(_trick_t / 0.4, 0.0, 1.0)
			trick_points.scale = trick_points.scale.lerp(Vector2.ONE, 1.0 - exp(-10.0 * delta))
			if _trick_t <= 0.0:
				_trick_state = ""


# ------------------------------------------------------------------ updates

func set_title(text: String) -> void:
	title_label.text = text.to_upper()


## Fundraiser mode: the score reads as money raised.
func set_money(per_point: float) -> void:
	money = per_point
	score_caption.text = "RAISED" if money > 0.0 else "SCORE"


## Points as the HUD shows them: "12,340", or "$1,234" in a fundraiser.
func amount(points: int) -> String:
	if money > 0.0:
		return "$" + UiKit.commas(int(round(points * money)))
	return UiKit.commas(points)


func set_score(v: int) -> void:
	_target_score = v


## The live combo: the trick names so far, pending points and the multiplier.
func set_combo(mult: int, names: Array[String], pending: int, live: bool) -> void:
	if not live:
		return
	if _trick_state != "live":
		_trick_state = "live"
		trick_names.add_theme_color_override("font_color", PAPER)
		trick_points.add_theme_color_override("font_color", ACCENT)
	var shown: Array[String] = names.slice(maxi(0, names.size() - 5))
	trick_names.text = ("... + " if names.size() > 5 else "") + " + ".join(shown)
	trick_points.text = "%s  x %d" % [amount(pending), mult]
	trick_points.pivot_offset = trick_points.size * 0.5
	if names.size() != _last_names:
		trick_points.scale = Vector2(1.18, 1.18)     # a small pop for every new trick
		_last_names = names.size()


func combo_banked(points: int) -> void:
	_trick_state = "banked"
	_trick_t = 1.6
	_last_names = 0
	trick_points.text = "+" + amount(points)
	trick_points.add_theme_color_override("font_color", GOOD)
	trick_points.pivot_offset = trick_points.size * 0.5
	trick_points.scale = Vector2(1.3, 1.3)


func combo_lost() -> void:
	_trick_state = "lost"
	_trick_t = 1.3
	_last_names = 0
	trick_names.add_theme_color_override("font_color", Color(BAD, 0.9))
	trick_points.text = "BAIL"
	trick_points.add_theme_color_override("font_color", BAD)


func show_timer(v: bool) -> void:
	clock_box.visible = v


func set_timer(seconds: float, running: bool) -> void:
	var s: int = maxi(0, int(ceil(seconds)))
	timer_label.text = "%d:%02d" % [s / 60, s % 60]
	timer_label.add_theme_color_override("font_color", BAD if (running and seconds < 10.0) else PAPER)


func set_best(v: int) -> void:
	best_label.text = ("BEST  " + amount(v)) if v > 0 else ""


func show_speed(v: bool) -> void:
	speed_box.visible = v


func set_speed(v: float) -> void:
	speed_bar.value = v


func set_charge(v: float) -> void:
	charge_bar.visible = v > 0.02
	charge_bar.value = v


## Balance (manual, lip stall or grind), -1..1 (0 = perfect). Hidden when not balancing.
func set_balance(v: float, active: bool) -> void:
	balance_box.visible = active
	if not active:
		return
	var c: float = clampf(v, -1.0, 1.0)
	balance_marker.position.x = (c * 0.5 + 0.5) * (BALANCE_W - 6.0)
	balance_marker.color = PAPER.lerp(BAD, clampf((absf(c) - 0.4) / 0.5, 0.0, 1.0))


## The event's letters as a row of balloon badges: dim until grabbed, then filled with the balloon's colour.
## `colors` in word order; `got` = letters already collected. An empty word hides the row.
func set_letters(word: String, colors: Array, got: String = "") -> void:
	letters_box.visible = word != ""
	if word != _letters_word:
		_letters_word = word
		for c in letters_box.get_children():
			c.queue_free()
		_letter_tiles.clear()
		for i in word.length():
			var tile: Control = Control.new()
			tile.custom_minimum_size = Vector2(LETTER_SIZE, LETTER_SIZE)
			tile.pivot_offset = Vector2(LETTER_SIZE, LETTER_SIZE) * 0.5
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var disc: Panel = Panel.new()
			disc.set_anchors_preset(Control.PRESET_FULL_RECT)
			disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(disc)
			var l: Label = UiKit.label(word[i], 36, PAPER, "display")
			l.set_anchors_preset(Control.PRESET_FULL_RECT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.add_theme_constant_override("outline_size", 8)
			l.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.6))
			tile.add_child(l)
			letters_box.add_child(tile)
			_letter_tiles[word[i]] = {"tile": tile, "disc": disc, "label": l, "color": colors[i] if i < colors.size() else ACCENT, "got": false}
	for k in _letter_tiles:
		_letter_look(k, got.contains(k))


func _letter_look(letter: String, got: bool) -> void:
	var t: Dictionary = _letter_tiles[letter]
	t["got"] = got
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(int(LETTER_SIZE * 0.5))
	sb.set_border_width_all(3 if got else 2)
	sb.bg_color = t["color"] if got else Color(UiKit.INK, 0.5)
	sb.border_color = PAPER if got else Color(PAPER, 0.28)
	(t["disc"] as Panel).add_theme_stylebox_override("panel", sb)
	(t["label"] as Label).add_theme_color_override("font_color", PAPER if got else Color(PAPER, 0.32))


## A letter was grabbed: a copy of it flies from the balloon's spot on screen to its badge, which fills and pops.
## With the whole word in, the row does a little wave.
func grab_letter(letter: String, from: Vector2) -> void:
	if not _letter_tiles.has(letter):
		return
	var t: Dictionary = _letter_tiles[letter]
	var fly: Label = UiKit.label(letter, 72, t["color"], "display")
	fly.add_theme_constant_override("outline_size", 14)
	fly.add_theme_color_override("font_outline_color", PAPER)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fly)
	fly.reset_size()
	fly.pivot_offset = fly.size * 0.5
	fly.position = from - fly.size * 0.5
	var tile: Control = t["tile"]
	var to: Vector2 = tile.get_global_rect().get_center() - fly.size * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(fly, "scale", Vector2(1.35, 1.35), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fly, "position", to, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fly, "scale", Vector2(0.55, 0.55), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		fly.queue_free()
		_letter_look(letter, true)
		_bounce(tile, 0.0, 1.55)
		var all: bool = true
		for k in _letter_tiles:
			all = all and bool(_letter_tiles[k]["got"])
		if all:
			var i: int = 0
			for k in _letters_word:
				_bounce(_letter_tiles[k]["tile"], 0.35 + i * 0.07, 1.3)
				i += 1)


func _bounce(c: Control, delay: float, peak: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "scale", Vector2(peak, peak), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A quick cut to black that fades back in: covers the skater being warped back from the level's edge.
func blink(seconds: float = 0.45) -> void:
	if _blink == null:
		_blink = ColorRect.new()
		_blink.set_anchors_preset(Control.PRESET_FULL_RECT)
		_blink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blink.color = Color(0.02, 0.02, 0.03)
		root.add_child(_blink)
		root.move_child(_blink, 0)                 # under the HUD's panels
	_blink.modulate.a = 1.0
	_blink.visible = true
	if _blink_tw != null:
		_blink_tw.kill()
	_blink_tw = create_tween()
	_blink_tw.tween_interval(0.06)
	_blink_tw.tween_property(_blink, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_blink_tw.tween_callback(func() -> void: _blink.visible = false)


## The event's goal list: [{"text": String, "done": bool}, ...]. Empty hides it.
func set_goals(items: Array) -> void:
	goals_panel.visible = not items.is_empty()
	_fill_goals(goals_box, items)


static func _fill_goals(box_parent: VBoxContainer, items: Array, text_w: float = GOAL_TEXT_W) -> void:
	for c in box_parent.get_children():
		c.queue_free()
	for g in items:
		var done: bool = g.get("done", false)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box: Panel = Panel.new()
		box.custom_minimum_size = Vector2(14, 14)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(7)
		sb.bg_color = GOOD if done else Color(0, 0, 0, 0)
		sb.border_color = GOOD if done else Color(PAPER, 0.7)
		sb.set_border_width_all(2)
		box.add_theme_stylebox_override("panel", sb)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		var l: Label = UiKit.label(String(g["text"]), 20, Color(PAPER, 0.55) if done else PAPER, "body")
		l.custom_minimum_size = Vector2(text_w, 0)      # long goals wrap instead of widening the panel under the cards
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		box_parent.add_child(row)


## A title card in the upper middle of the screen, with an optional line of text under the rule. A card that
## arrives while another is up waits its turn (a bonus and the goal it finished come in the same frame), and
## cuts the one showing short so the queue keeps up.
func announce(text: String, color: Color = PAPER, seconds: float = 1.6, sub: String = "") -> void:
	if _card_t > 0.45:                       # a card is up (or fading in), not just fading out
		if card_label.text == text.to_upper() and card_sub.text == sub:
			return
		_card_queue.append([text, color, seconds, sub])
		if _card_queue.size() > 3:
			_card_queue.pop_front()
		_card_t = minf(_card_t, 1.25)        # the card showing stays up at least 0.8 s more, then fades
		return
	_show_card(text, color, seconds, sub)


func _show_card(text: String, color: Color, seconds: float, sub: String) -> void:
	card_sub.text = sub
	card_sub.visible = sub != ""
	card_label.text = text.to_upper()
	var w: float = get_viewport().get_visible_rect().size.x if is_inside_tree() else 1600.0
	# short titles big; long lines smaller and wrapped onto two lines within the card
	var fit: float = CARD_HALF * 2.0 * 1.9 * (2.0 if text.length() > 22 else 1.0) / maxf(text.length(), 1.0)
	card_label.add_theme_font_size_override("font_size", int(clampf(fit, 34.0, 64.0)))
	card_label.add_theme_color_override("font_color", color)
	card_rule.color = ACCENT if color == PAPER else color
	card_rule.custom_minimum_size.x = 40.0
	card.modulate.a = 0.0
	_card_t = seconds + 0.45


## Key hints along the bottom left: [["SPACE", "jump"], ...].
func set_hints(pairs: Array) -> void:
	_hint_entries = pairs
	for c in hint_box.get_children():
		c.free()
	hint_box.add_child(UiKit.hints(pairs))
	hint_box.reset_size()
	hint_box.modulate.a = 1.0


func hide_hints() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(hint_box, "modulate:a", 0.0, 1.0)


# ------------------------------------------------------------------ pause

func is_paused() -> bool:
	return pause_layer.visible


## Everything but the menus: hidden behind the pause and results screens (the blurred backdrop would smear it).
func _set_hud_visible(v: bool) -> void:
	for c in root.get_children():
		if c != pause_layer and c != results_layer:
			(c as CanvasItem).visible = v


func open_pause() -> void:
	_saved_vis.clear()
	for c in root.get_children():
		_saved_vis[c] = (c as CanvasItem).visible
	_set_hud_visible(false)
	pause_layer.visible = true
	_show_controls(false)
	_pause_select(0)
	get_tree().paused = true
	Sound.set_paused(true)


func close_pause() -> void:
	for c in _saved_vis:
		if is_instance_valid(c):
			(c as CanvasItem).visible = _saved_vis[c]
	pause_layer.visible = false
	get_tree().paused = false
	Sound.set_paused(false)


func _show_controls(v: bool) -> void:
	controls_card.visible = v
	pause_menu.visible = not v


func _pause_select(i: int) -> void:
	pause_sel = posmod(i, pause_items.size())
	for j in pause_items.size():
		var on: bool = j == pause_sel
		pause_items[j].add_theme_color_override("font_color", ACCENT if on else Color(PAPER, 0.8))
		pause_items[j].text = pause_items[j].text.trim_prefix("›  ").trim_suffix("  ‹").strip_edges()
		if on:
			pause_items[j].text = "›  " + pause_items[j].text + "  ‹"


func _pause_activate() -> void:
	match pause_sel:
		0:
			close_pause()
			resume_requested.emit()
		1:
			close_pause()
			restart_requested.emit()
		2:
			_show_controls(true)
		3:
			close_pause()
			quit_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if results_layer.visible:
		if Time.get_ticks_msec() < _results_at + 1000:
			return                 # a jump pressed just as the buzzer went mustn't skip the results
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("respawn"):
			get_viewport().set_input_as_handled()
			restart_requested.emit()
		elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			quit_requested.emit()
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if not pause_layer.visible:
			open_pause()
		elif controls_card.visible:
			_show_controls(false)
		else:
			close_pause()
			resume_requested.emit()
		return
	if not pause_layer.visible:
		return
	get_viewport().set_input_as_handled()
	if controls_card.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_show_controls(false)
		return
	if event.is_action_pressed("ui_cancel"):          # B (or ESC's twin) backs out of the pause menu
		close_pause()
		resume_requested.emit()
		return
	if Controls.nav_pressed(event, "move_down") or Controls.nav_pressed(event, "ui_down"):
		_pause_select(pause_sel + 1)
		Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_up") or Controls.nav_pressed(event, "ui_up"):
		_pause_select(pause_sel - 1)
		Sound.play("ui_ok", -6.0, 0.9)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ollie"):
		Sound.play("ui_ok")
		_pause_activate()


# ------------------------------------------------------------------ results

## results: {"title", "score", "best_combo", "new_best": bool, "goals": [{"text","done"}]}
func show_results(r: Dictionary) -> void:
	for c in results_box.get_children():
		c.queue_free()
	results_box.add_child(UiKit.caption(String(r.get("title", "")), 22, ACCENT))
	results_box.add_child(UiKit.label("SESSION OVER", 64, PAPER, "display"))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	for pair in [["Raised" if money > 0.0 else "Score", int(r.get("score", 0))], ["Best combo", int(r.get("best_combo", 0))]]:
		var v: VBoxContainer = VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		v.add_child(UiKit.caption(String(pair[0])))
		v.add_child(UiKit.label(amount(int(pair[1])), 52, PAPER, "display"))
		row.add_child(v)
	if r.get("new_best", false):
		var nb: Label = UiKit.label("NEW BEST", 30, ACCENT, "display")
		nb.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(nb)
	results_box.add_child(row)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	results_box.add_child(gap)
	var done: int = 0
	var goals: Array = r.get("goals", [])
	for g in goals:
		done += int(g.get("done", false))
	results_box.add_child(UiKit.caption("Goals  %d / %d" % [done, goals.size()]))
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	results_box.add_child(list)
	_fill_goals(list, goals, 560.0)
	var gap2: Control = Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	results_box.add_child(gap2)
	results_box.add_child(UiKit.hints([["ENTER", "skate again", "A"], ["ESC", "title", "B"]]))
	_set_hud_visible(false)
	results_layer.visible = true
	_results_at = Time.get_ticks_msec()
	results_layer.modulate.a = 0.0
	create_tween().tween_property(results_layer, "modulate:a", 1.0, 0.5)


static func _commas(n: int) -> String:
	return UiKit.commas(n)
