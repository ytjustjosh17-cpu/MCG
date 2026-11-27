class_name IconButton
extends Button
## Round icon button with an optional progress ring and red dot. Given a
## title it becomes a wide tile: the round icon on the left, the title
## (13 px) and a value (15 px semibold) to its right. The whole tile taps.

var ring := -1.0          # 0..1 shows a ring, -1 hides it
var ring_color := UI.TEXT # RED only for the one action worth taking now
var dot := false
var diameter := 64.0
var fill := UI.RAISED
var _icon: Icon
var _title: Label
var _value: Label


func _init(kind := "bolt", d := 64.0, title := "") -> void:
	diameter = d
	focus_mode = Control.FOCUS_NONE
	flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	custom_minimum_size = Vector2(d, d)
	size = custom_minimum_size
	_icon = Icon.new(kind, UI.TEXT, d * 0.42)
	add_child(_icon)
	if title != "":
		_title = UI.label(title, 13, UI.SUB)
		_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title)
		_value = UI.label("", 15, UI.TEXT, true)
		_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_value)
	resized.connect(_layout)
	_layout()
	Kit.press_fx(self)


func _layout() -> void:
	var cy := size.y / 2.0
	var cx := diameter / 2.0 if _title else size.x / 2.0
	_icon.position = Vector2(cx, cy) - _icon.size / 2.0
	if _title:
		var x := diameter + 10.0
		_title.position = Vector2(x, cy - 20.0)
		_title.size = Vector2(size.x - x, 18)
		_value.position = Vector2(x, cy - 2.0)
		_value.size = Vector2(size.x - x, 20)
	pivot_offset = Vector2(cx, cy)


func set_state(c: Color, r := -1.0, d := false, value := "", rc: Color = UI.TEXT) -> void:
	ring = r
	ring_color = rc
	dot = d
	_icon.set_style(c, true)
	if _value:
		_value.text = value
		_value.add_theme_color_override("font_color", UI.TEXT if c != UI.SUB else UI.SUB)
	queue_redraw()


func _draw() -> void:
	var r := diameter / 2.0
	var center := Vector2(r if _title else size.x / 2.0, size.y / 2.0)
	draw_circle(center, r, fill)
	if ring >= 0.0:
		draw_arc(center, r - 2.0, -PI / 2.0, -PI / 2.0 + TAU, 48, UI.TRACK, 3.0, true)
		if ring > 0.0:
			draw_arc(center, r - 2.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(ring, 0.0, 1.0), 48, ring_color, 3.0, true)
	if dot:
		draw_circle(center + Vector2(r * 0.72, -r * 0.72), 4.0, UI.RED)
