class_name Switch
extends Button
## An on/off switch (51 x 31 track, 48 px tall tap area) for settings that
## are simply on or off. Emits `toggled_on(on)`.

signal toggled_on(on: bool)
var on := false
var _t := 0.0   # knob position 0..1, animated


func _init(start := false) -> void:
	on = start
	_t = 1.0 if on else 0.0
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(64, 48)
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(k, StyleBoxEmpty.new())
	pressed.connect(func():
		set_on(not on)
		Kit.haptic("selection")
		toggled_on.emit(on))


func set_on(v: bool) -> void:
	on = v
	var tw := create_tween()
	tw.tween_method(func(x: float):
		_t = x
		queue_redraw(), _t, 1.0 if on else 0.0, Motion.d(0.18))


func _draw() -> void:
	var tr := Rect2(Vector2(size.x - 51.0, (size.y - 31.0) * 0.5), Vector2(51, 31))
	draw_colored_polygon(UI.rounded_rect_poly(tr, 15.5), UI.TRACK.lerp(UI.TEXT, _t))
	var r := 13.0
	var cx := lerpf(tr.position.x + 15.5, tr.end.x - 15.5, _t)
	draw_circle(Vector2(cx, tr.get_center().y), r, UI.INK if _t > 0.5 else UI.SUB)
