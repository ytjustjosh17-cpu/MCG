class_name Segmented
extends PanelContainer
## iOS-style segmented control.

signal changed(index: int)

var _buttons: Array = []
var index := 0


func _init(labels: Array) -> void:
	add_theme_stylebox_override("panel", UI.box(UI.PANEL, 10, 2, 2))
	custom_minimum_size = Vector2(0, 52)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	add_child(h)
	for i in range(labels.size()):
		var b := Button.new()
		b.text = labels[i]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(func(): select(i, true))
		h.add_child(b)
		_buttons.append(b)
	select(0)


func select(i: int, emit := false) -> void:
	index = i
	for k in range(_buttons.size()):
		var b: Button = _buttons[k]
		var on := k == i
		var bg: StyleBox = UI.box(UI.RAISED, 8) if on else StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, bg)
		b.add_theme_font_override("font", UI.SEMI if on else UI.REG)
		for k2 in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k2, UI.TEXT if on else UI.SUB)
	if emit:
		Kit.tick(5)
		changed.emit(i)
