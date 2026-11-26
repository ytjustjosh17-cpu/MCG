class_name IconButton
extends Button
## Round icon button with an optional progress ring, red dot and small caption below.

var icon_kind := "bolt"
var icon_color := UI.TEXT
var ring := -1.0          # 0..1 shows a ring, -1 hides it
var dot := false
var caption := ""
var diameter := 64.0
var fill := Color(0.0, 0.08, 0.08, 0.72)
var _icon: Icon
var _cap: Label


func _init(kind := "bolt", d := 64.0) -> void:
	icon_kind = kind
	diameter = d
	focus_mode = Control.FOCUS_NONE
	flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	custom_minimum_size = Vector2(d, d + 20)
	size = custom_minimum_size
	_icon = Icon.new(kind, UI.TEXT, d * 0.42)
	add_child(_icon)
	_cap = UI.label("", 13, UI.TEXT, true)
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_cap)
	resized.connect(_layout)
	Kit.press_fx(self)


func _layout() -> void:
	_icon.position = Vector2((size.x - _icon.size.x) / 2.0, (diameter - _icon.size.y) / 2.0)
	_cap.position = Vector2(0, diameter + 2)
	_cap.size = Vector2(size.x, 18)
	pivot_offset = Vector2(size.x / 2.0, diameter / 2.0)


func set_state(c: Color, r := -1.0, d := false, cap := "") -> void:
	icon_color = c
	ring = r
	dot = d
	caption = cap
	_icon.set_style(c, true)
	_cap.text = cap
	_cap.add_theme_color_override("font_color", c)
	queue_redraw()


func _draw() -> void:
	var cx := size.x / 2.0
	var center := Vector2(cx, diameter / 2.0)
	var r := diameter / 2.0
	draw_circle(center, r, fill)
	draw_arc(center, r - 0.5, 0, TAU, 64, Color(UI.TEXT, 0.14), 1.0, true)
	if ring >= 0.0:
		draw_arc(center, r - 3.0, -PI / 2.0, -PI / 2.0 + TAU, 64, Color(UI.TEXT, 0.12), 3.0, true)
		if ring > 0.0:
			draw_arc(center, r - 3.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(ring, 0.0, 1.0), 64, UI.RED, 3.0, true)
	if dot:
		draw_circle(center + Vector2(r * 0.72, -r * 0.72), 5.0, UI.RED)
