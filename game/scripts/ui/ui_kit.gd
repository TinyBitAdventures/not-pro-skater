class_name UiKit
extends RefCounted
## The game's UI look in one place: chunky rounded navy panels, bold outlined labels.

const NAVY: Color = Color(0.17, 0.22, 0.4)
const NAVY_DK: Color = Color(0.09, 0.11, 0.2)
const YELLOW: Color = Color(1.0, 0.82, 0.25)
const BLUE: Color = Color(0.24, 0.6, 1.0)
const GREEN: Color = Color(0.3, 0.85, 0.5)
const RED: Color = Color(1.0, 0.35, 0.35)
const WHITE: Color = Color(0.96, 0.98, 1.0)

static var _font: FontVariation


static func font() -> FontVariation:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.9
	return _font


static func style(fill: Color, radius: int = 14, border: Color = NAVY_DK, bw: int = 4) -> StyleBoxFlat:
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


static func panel(fill: Color = NAVY, radius: int = 14) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(fill, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String, size: int, color: Color = WHITE, outline: int = 5) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", NAVY_DK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


const CONTROL_LINES: Array[String] = [
	"W push    S brake    A / D turn        (T: screen-relative steering instead)",
	"SPACE  hold to crouch, release to jump (longer = higher); at a ramp lip for big air",
	"J  flip     K  hold to grab     L  grind (press near or toward a rail, ledge or coping)",
	"IN THE AIR  A / D spin, then J or K for tricks",
	"W then S (quick taps)  manual     S then W  nose manual     keep the BALANCE meter centred",
	"M  manual too; at a ramp lip: transfer; just after a ramp landing: revert",
	"SPACE as you hit a wall  wall plant",
	"R  reset     ESC  back to the title     F3  tuning",
]
