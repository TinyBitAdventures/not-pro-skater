class_name TuningPanel
extends CanvasLayer
## F3: live sliders for every SkateTuning value. Changes apply to all skaters at once.
## Save writes res://tuning/default.tres when running from source (user://tuning.tres in an exported build).
## Sliders never take keyboard focus, so WASD / Space keep driving the skater while the panel is open.

const WIDTH: float = 430.0

var tune: SkateTuning = SkateTuning.shared()
var _root: PanelContainer
var _rows: Dictionary = {}          # name -> {"slider": HSlider, "value": Label}
var _status: Label
var _dirty: bool = false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func _input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_F3:
		_root.visible = not _root.visible
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	_root.add_theme_stylebox_override("panel", sb)
	_root.anchor_left = 1.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_left = -WIDTH - 12.0
	_root.offset_right = -12.0
	_root.offset_top = 12.0
	_root.offset_bottom = -12.0
	add_child(_root)

	var col: VBoxContainer = VBoxContainer.new()
	_root.add_child(col)
	var head: HBoxContainer = HBoxContainer.new()
	col.add_child(head)
	var title: Label = _label("SKATE TUNING  (F3)", 17, Color(1, 0.85, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Save", _on_save))
	head.add_child(_button("Reset", _on_reset))
	_status = _label("", 13, Color(0.6, 0.85, 1.0))
	col.add_child(_status)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var group: String = ""
	for t in tune.tunables():
		if t["group"] != group:
			group = t["group"]
			var g: Label = _label(group.to_upper(), 14, Color(0.55, 0.62, 0.75))
			list.add_child(g)
		list.add_child(_row(t))


func _row(t: Dictionary) -> Control:
	var name_s: String = t["name"]
	var row: HBoxContainer = HBoxContainer.new()
	var nl: Label = _label(name_s.replace("_", " "), 13, Color(0.9, 0.92, 0.96))
	nl.custom_minimum_size.x = 150.0
	row.add_child(nl)
	var s: HSlider = HSlider.new()
	s.min_value = t["min"]
	s.max_value = t["max"]
	s.step = t["step"]
	s.value = float(tune.get(name_s))
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var vl: Label = _label(_fmt(s.value, s.step), 13, Color(1, 1, 1))
	vl.custom_minimum_size.x = 56.0
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(vl)
	s.value_changed.connect(func(v: float) -> void:
		tune.set(name_s, v)
		vl.text = _fmt(v, s.step)
		_dirty = true
		_status.text = "unsaved changes")
	_rows[name_s] = {"slider": s, "value": vl}
	return row


func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(v))
	if step >= 0.1:
		return "%.1f" % v
	return "%.2f" % v


func _label(text: String, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _on_save() -> void:
	var path: String = tune.save_tune()
	_dirty = false
	_status.text = ("saved to " + path) if path != "" else "save FAILED"


func _on_reset() -> void:
	tune.reset_to_defaults()
	for name_s in _rows:
		var r: Dictionary = _rows[name_s]
		(r["slider"] as HSlider).set_value_no_signal(float(tune.get(name_s)))
		(r["value"] as Label).text = _fmt(float(tune.get(name_s)), (r["slider"] as HSlider).step)
	_status.text = "reset to built-in defaults (not saved)"
