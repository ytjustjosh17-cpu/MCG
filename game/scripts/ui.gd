class_name UI
extends RefCounted
## Shared colours, fonts and widget helpers for the red-sun look.

const BG := Color("#001414")
const PANEL := Color("#092225")
const RAISED := Color("#1C3A3B")
const SKY := Color("#012B2A")
const TEXT := Color("#D8E6E3")
const SUB := Color("#8FAAA6")
const DIM := Color("#4F6E6C")
const TRACK := Color("#2A4A4B")
const RED := Color("#FF1A0F")
const INK := Color("#001414")
const WINDOW := Color("#0A2526")
const SIDE := Color("#041717")
const FAR := Color("#03201F")    # distant skyline, a step darker than the sky
const HAZE := Color("#08403D")   # nearer haze layer and far windows
const FLASH := Color("#FFC2B8")
# Accents: used sparingly for markets so each company and coin has its own look.
const UP := Color("#7FCFA6")
const DOWN := Color("#EE7A6B")
# Tonal, slightly muted accents so they sit with the teal instead of shouting.
const SECTOR_COL := {
	"Energy": Color("#D9A75E"), "Finance": Color("#D6CCB2"), "Tech": Color("#9DC3DF"),
	"Transport": Color("#82BDB2"), "Retail": Color("#E09C93"), "Food": Color("#A3C995"),
	"Industry": Color("#AEB7B8"),
}
const COIN_COL := [Color("#D9A75E"), Color("#82BDB2"), Color("#B8A58E"), Color("#D6CCB2"), Color("#9DC3DF"),
	Color("#E39573"), Color("#C9B6D9"), Color("#A9D3C6"), Color("#E3CB84"), Color("#A8D8E6")]

# Type: Switzer for text, Tanker for big numbers and titles (both from
# Fontshare, ITF Free Font License). They can't be stored in this public repo,
# so the build downloads them into assets/fonts/ext. Inter (OFL) is the backup.
static var REG: Font = _font("Switzer-Regular", "res://assets/fonts/Inter-Regular.ttf")
static var SEMI: Font = _font("Switzer-Semibold", "res://assets/fonts/Inter-SemiBold.ttf")
static var DISPLAY: Font = _font("Tanker-Regular", "res://assets/fonts/Inter-SemiBold.ttf")


static func _font(name: String, backup: String) -> Font:
	var path := "res://assets/fonts/ext/%s.ttf" % name
	if not ResourceLoader.exists(path):
		return load(backup)
	var f: Font = load(path)
	if f is FontFile:
		# Any glyph the font lacks comes from Inter.
		(f as FontFile).fallbacks = [load(backup)]
	return f


static func display(text: String, size: int, color: Color = TEXT) -> Label:
	## Big numbers and page titles.
	var l := label(text, size, color)
	l.add_theme_font_override("font", DISPLAY)
	return l


static func label(text: String, size: int, color: Color = TEXT, semibold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", SEMI if semibold else REG)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(color: Color, radius: int, pad_x := 0, pad_y := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func panel(color: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", box(color, radius))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


static func place(c: Control, x: float, y: float, w := -1.0, h := -1.0) -> Control:
	c.position = Vector2(x, y)
	if w >= 0.0 and h >= 0.0:
		c.size = Vector2(w, h)
	return c


static func pill(text: String, bg: Color, fg: Color, size := 17, radius := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", SEMI)
	b.add_theme_font_size_override("font_size", size)
	paint(b, bg, fg, radius)
	return b


static func paint(b: Button, bg: Color, fg: Color, radius := 22) -> void:
	b.add_theme_stylebox_override("normal", box(bg, radius, 16))
	b.add_theme_stylebox_override("hover", box(bg, radius, 16))
	b.add_theme_stylebox_override("pressed", box(bg.lerp(Color.BLACK, 0.15), radius, 16))
	b.add_theme_stylebox_override("disabled", box(bg, radius, 16))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, fg)


static func flat_button() -> Button:
	## Invisible button used as a tappable row; children draw the content.
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var press := box(Color(1, 1, 1, 0.05), 0)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func rounded_rect_poly(r: Rect2, radius: float, seg := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(r.size.x - radius, radius), -PI / 2.0],
		[r.position + Vector2(r.size.x - radius, r.size.y - radius), 0.0],
		[r.position + Vector2(radius, r.size.y - radius), PI / 2.0],
		[r.position + Vector2(radius, radius), PI],
	]
	for c in corners:
		for i in range(seg + 1):
			var a: float = c[1] + (PI / 2.0) * float(i) / float(seg)
			pts.append(c[0] + Vector2(cos(a), sin(a)) * radius)
	return pts


static func circle_poly(center: Vector2, radius: float, seg := 64) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg):
		var a := TAU * float(i) / float(seg)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


static func rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func asset_color(sym: String) -> Color:
	for st in Data.STOCKS:
		if st[0] == sym:
			return SECTOR_COL.get(st[4], TEXT)
	for i in range(Data.COINS.size()):
		if Data.COINS[i][0] == sym:
			return COIN_COL[i % COIN_COL.size()]
	return SECTOR_COL.get(sym, TEXT)


static func change_color(pct: float) -> Color:
	return UP if pct >= 0.0 else DOWN
