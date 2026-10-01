class_name UiKit
extends RefCounted
## The game's UI look in one place: Barlow Condensed, warm white text with a soft shadow, one orange accent,
## translucent dark panels with small radii. Grounded, like a sports broadcast, not a cartoon.

const INK: Color = Color(0.05, 0.06, 0.08)          # panel base (used translucent)
const PAPER: Color = Color(0.97, 0.96, 0.93)        # text
const MUTED: Color = Color(0.74, 0.76, 0.8)         # secondary text
const ACCENT: Color = Color(1.0, 0.6, 0.16)         # the one highlight colour
const GOOD: Color = Color(0.46, 0.9, 0.56)
const BAD: Color = Color(1.0, 0.4, 0.34)
const INFO: Color = Color(0.5, 0.78, 1.0)

const FONT_BODY: FontFile = preload("res://assets/fonts/BarlowCondensed-Medium.ttf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
const FONT_DISPLAY: FontFile = preload("res://assets/fonts/BarlowCondensed-ExtraBold.ttf")

## weight: "body", "bold" or "display"
static func font(weight: String = "bold") -> Font:
	match weight:
		"body":
			return FONT_BODY
		"display":
			return FONT_DISPLAY
	return FONT_BOLD


static func style(alpha: float = 0.55, radius: int = 6, accent: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(INK, alpha)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	if accent.a > 0.0:                      # a stripe down the left edge
		sb.border_color = accent
		sb.border_width_left = 4
	return sb


static func panel(alpha: float = 0.55, radius: int = 6, accent: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(alpha, radius, accent))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String, size: int, color: Color = PAPER, weight: String = "bold") -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(1, size / 18))
	l.add_theme_constant_override("shadow_outline_size", maxi(2, size / 10))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A small caps label that sits above a value ("SCORE", "BEST").
static func caption(text: String, size: int = 17, color: Color = MUTED) -> Label:
	var l: Label = label(text.to_upper(), size, color, "bold")
	return l


## A thin bar (meters: pop, balance, speed).
static func bar(width: float, height: float, fill: Color) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.custom_minimum_size = Vector2(width, height)
	b.show_percentage = false
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(INK, 0.55)
	bg.set_corner_radius_all(int(height * 0.5))
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(int(height * 0.5))
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## A row of key hints: "SPACE jump   J flip". Keys are bold paper, actions muted. Each entry is
## [key, action] (keyboard only: left out while a gamepad is in use) or [key, action, pad button].
static func hints(entries: Array) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad: bool = Controls.using_pad
	var pairs: Array = []
	for e in entries:
		if not pad:
			pairs.append([e[0], e[1]])
		elif (e as Array).size() > 2:
			pairs.append([e[2], e[1]])
	for i in pairs.size():
		var p: Array = pairs[i]
		h.add_child(label(String(p[0]), 18, PAPER, "bold"))
		var a: Label = label(String(p[1]) + ("      " if i < pairs.size() - 1 else ""), 18, Color(PAPER, 0.78), "body")
		h.add_child(a)
	return h


static func commas(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	var c: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


## Rows for the controls card: [keys, gamepad, what they do].
const CONTROLS: Array = [
	["W / S", "STICK UP / DOWN", "push / brake"],
	["A / D", "STICK LEFT / RIGHT", "turn; in the air, spin"],
	["SPACE", "A", "hold to crouch, release to jump (longer = higher)"],
	["J", "X", "flip trick (hold a direction for variations)"],
	["K", "B", "hold to grab (hold a direction for variations)"],
	["L", "Y", "grind: press near or toward a rail, ledge or coping"],
	["L + stick", "Y + STICK", "at the top of a quarter / half pipe: lip trick (stall; left / right balance, jump to drop in)"],
	["W, S", "UP, DOWN", "quick taps: manual"],
	["S, W", "DOWN, UP", "quick taps: nose manual"],
	["W / S", "STICK", "in a manual: keep the balance meter centred"],
	["M", "RT", "at a ramp lip: transfer; after a ramp landing: revert"],
	["SPACE", "A", "as you hit a wall: wall plant"],
	["L", "Y", "in the air, into a wall at an angle: wallride (SPACE on it: wallie)"],
	["SPACE", "A", "down after a crash: hurry back to the board"],
	["SHIFT", "LT", "brake"],
	["R", "BACK", "reset to the start"],
	["ESC", "START", "pause"],
]


## The controls card: keys, gamepad and action columns.
static func controls_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 2)
	for head in ["KEYS", "GAMEPAD", ""]:
		grid.add_child(caption(head, 15))
	for row in CONTROLS:
		grid.add_child(label(String(row[0]), 21, ACCENT, "bold"))
		grid.add_child(label(String(row[1]), 21, INFO, "bold"))
		grid.add_child(label(String(row[2]), 21, PAPER, "body"))
	return grid
