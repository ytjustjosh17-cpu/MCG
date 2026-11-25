class_name NavBar
extends Control
## Floating tab bar: Earn, Business, Invest, Items, Profile.

signal tab_selected(index: int)

const TABS := [["earn", "Earn"], ["business", "Business"], ["invest", "Invest"], ["items", "Items"], ["profile", "Profile"]]

var _buttons: Array = []
var _icons: Array = []
var _labels: Array = []
var _active := 0
var _badges: Array = []
var _want: Array = []  # badge wanted per tab; never shown on the active tab


func _ready() -> void:
	var glass := GlassPanel.new(32.0, Color(0.035, 0.133, 0.145, 0.7), 12.0)
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(glass)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	for i in range(TABS.size()):
		var b := UI.flat_button()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 52)
		b.pressed.connect(func(): tab_selected.emit(i))
		Kit.press_fx(b)
		row.add_child(b)
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var ic := Icon.new(TABS[i][0], UI.SUB, 26.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
		var l := UI.label(TABS[i][1], 11, UI.TEXT, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visible = false
		col.add_child(l)
		b.tooltip_text = TABS[i][1]
		_buttons.append(b)
		var dot := ColorRect.new()
		dot.color = UI.RED
		dot.size = Vector2(7, 7)
		dot.visible = false
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
		b.resized.connect(func(): dot.position = Vector2(b.size.x / 2.0 + 12.0, 8.0))
		_badges.append(dot)
		_want.append(false)
		_icons.append(ic)
		_labels.append(l)
	set_active(0)


func set_badge(i: int, on: bool) -> void:
	if i < _badges.size():
		_want[i] = on
		_badges[i].visible = on and i != _active


func set_active(i: int) -> void:
	_active = i
	for k in range(_buttons.size()):
		var on := k == i
		_badges[k].visible = _want[k] and not on
		(_labels[k] as Label).visible = on
		var b: Button = _buttons[k]
		var bg: StyleBox = UI.box(Color(UI.TEXT, 0.1), 26) if on else StyleBoxEmpty.new()
		b.add_theme_stylebox_override("normal", bg)
		b.add_theme_stylebox_override("hover", bg)
		(_icons[k] as Icon).set_style(UI.RED if on else UI.SUB, on)
		var ic: Icon = _icons[k]
		if on:
			ic.pivot_offset = ic.size / 2.0
			ic.scale = Vector2(0.86, 0.86)
			ic.create_tween().tween_property(ic, "scale", Vector2.ONE, Motion.d(0.28)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
