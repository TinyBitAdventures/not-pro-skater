class_name StatsScreen
extends ColorRect
## The rider's stats and style, over the title (opened from its STATS row). Up / down pick a stat, right (or Enter)
## spends a point on it, left takes a spent point back, Esc / B closes. Points come from event goals
## (Game.stat_points_free): every goal done anywhere gives each rider one.

signal closed

const SEG: Vector2 = Vector2(22, 16)

var rider: String = "dev"
var selected: int = 0
var _name: Label
var _points: Label
var _rows: Array[Label] = []
var _values: Array[Label] = []
var _bars: Array[HBoxContainer] = []
var _about: Label
var _style: Array[Label] = []           # stance, push, terrain, signature: each a value label


func _init() -> void:
	color = Color(UiKit.INK, 0.72)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var p: PanelContainer = UiKit.panel(0.88, 8, UiKit.ACCENT)
	cc.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	_name = UiKit.label("", 52, UiKit.PAPER, "display")
	v.add_child(_name)
	_points = UiKit.label("", 23, UiKit.ACCENT, "bold")
	v.add_child(_points)
	v.add_child(UiKit.label("One point for every event goal done, for every rider", 19, UiKit.MUTED, "body"))
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	v.add_child(grid)
	for stat in RiderProfiles.STATS:
		var l: Label = UiKit.label("", 24, UiKit.PAPER, "bold")
		l.custom_minimum_size = Vector2(210, 0)
		grid.add_child(l)
		_rows.append(l)
		var bar: HBoxContainer = HBoxContainer.new()
		bar.add_theme_constant_override("separation", 3)
		bar.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in RiderProfiles.MAX:
			var seg: ColorRect = ColorRect.new()
			seg.custom_minimum_size = SEG
			seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.add_child(seg)
		grid.add_child(bar)
		_bars.append(bar)
		var val: Label = UiKit.label("", 24, UiKit.PAPER, "bold")
		val.custom_minimum_size = Vector2(36, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		_values.append(val)
	_about = UiKit.label("", 21, UiKit.MUTED, "body")
	v.add_child(_about)

	var gap2: Control = Control.new()
	gap2.custom_minimum_size = Vector2(0, 12)
	v.add_child(gap2)
	v.add_child(UiKit.caption("Style", 19, UiKit.ACCENT))
	var sg: GridContainer = GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 18)
	sg.add_theme_constant_override("v_separation", 0)
	v.add_child(sg)
	for title in ["Stance", "Push", "Terrain", "Signature"]:
		sg.add_child(UiKit.label(title, 22, UiKit.MUTED, "bold"))
		var val2: Label = UiKit.label("", 22, UiKit.PAPER, "body")
		sg.add_child(val2)
		_style.append(val2)

	var gap3: Control = Control.new()
	gap3.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap3)
	v.add_child(UiKit.hints([["RIGHT / ENTER", "raise", "D-PAD RIGHT / A"], ["LEFT", "take back", "D-PAD LEFT"],
		["ESC", "back", "B"]]))


func open(key: String) -> void:
	rider = key
	selected = 0
	visible = true
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	var stats: Dictionary = Game.rider_stats(rider)
	var base: Dictionary = RiderProfiles.base(rider)
	var free: int = Game.stat_points_free(rider)
	_name.text = Game.rider_name(rider).to_upper()
	_points.text = ("%d POINT%s TO SPEND" % [free, "" if free == 1 else "S"]) if free > 0 else "NO POINTS TO SPEND"
	for i in RiderProfiles.STATS.size():
		var stat: String = RiderProfiles.STATS[i]
		var on: bool = i == selected
		_rows[i].text = ("›  " if on else "") + RiderProfiles.stat_name(stat).to_upper()
		_rows[i].add_theme_color_override("font_color", UiKit.ACCENT if on else UiKit.PAPER)
		var now: int = int(stats[stat])
		var own: int = int(base[stat])
		_values[i].text = str(now)
		_values[i].add_theme_color_override("font_color", UiKit.ACCENT if now > own else UiKit.PAPER)
		var segs: Array[Node] = _bars[i].get_children()
		for k in segs.size():
			var c: Color = Color(UiKit.PAPER, 0.14)
			if k < own:
				c = Color(UiKit.PAPER, 0.85)
			elif k < now:
				c = UiKit.ACCENT
			(segs[k] as ColorRect).color = c
	var sel: String = RiderProfiles.STATS[selected]
	_about.text = String(RiderProfiles.STAT_INFO[sel][1])
	var p: Dictionary = RiderProfiles.profile(rider)
	var goofy: bool = Game.rider_goofy(rider)
	_style[0].text = ("Goofy, right foot forward" if goofy else "Regular, left foot forward") + \
		("" if Game.stance == "own" else "  (the stance setting)")
	_style[1].text = "Mongo, the front foot pushes" if String(p["push"]) == "mongo" else "Regular, the back foot pushes"
	var terrain: String = String(p["terrain"])
	_style[2].text = String(RiderProfiles.TERRAIN_NAMES[terrain]) + ("  (+8% on every trick)" if terrain == "all" \
		else "  (+20%% on %s tricks)" % terrain)
	_style[3].text = "  ·  ".join(PackedStringArray(p["signature"])) + "  (+50%)"


## The title forwards its input here while this is open. Returns whether it was used.
func handle(event: InputEvent) -> bool:
	if not visible:
		return false
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_down") or Controls.nav_pressed(event, "ui_down"):
		selected = (selected + 1) % RiderProfiles.STATS.size()
		refresh()
		Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_up") or Controls.nav_pressed(event, "ui_up"):
		selected = (selected - 1 + RiderProfiles.STATS.size()) % RiderProfiles.STATS.size()
		refresh()
		Sound.play("ui_ok", -6.0, 0.9)
	elif Controls.nav_pressed(event, "move_right") or Controls.nav_pressed(event, "ui_right") \
			or (event.is_action_pressed("ui_accept") and not _is_space(event)):
		_spend(1)
	elif Controls.nav_pressed(event, "move_left") or Controls.nav_pressed(event, "ui_left"):
		_spend(-1)
	else:
		return event is InputEventKey or event is InputEventJoypadButton    # (nothing else reaches the title)
	return true


func _spend(step: int) -> void:
	if Game.spend_stat(rider, RiderProfiles.STATS[selected], step):
		Sound.play("ui_ok", -4.0, 1.2 if step > 0 else 0.95)
		refresh()
	else:
		Sound.play("ui_ok", -10.0, 0.7)


## Space is the jump key: it never spends a point (Enter or right does).
static func _is_space(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE
