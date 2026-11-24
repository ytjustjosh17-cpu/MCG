class_name NavBar
extends Panel
## Floating tab bar: Earn, Business, Invest, Items, Profile.

signal tab_selected(index: int)

const TABS := [["earn", "Earn"], ["business", "Business"], ["invest", "Invest"], ["items", "Items"], ["profile", "Profile"]]

var _buttons: Array = []
var _icons: Array = []
var _labels: Array = []
var _active := 0


func _ready() -> void:
	var sb := UI.box(Color(0.035, 0.133, 0.145, 0.96), 32)
	sb.border_width_top = 1
	sb.border_color = Color(UI.TEXT, 0.12)
	add_theme_stylebox_override("panel", sb)
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
		row.add_child(b)
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var ic := Icon.new(TABS[i][0], UI.SUB, 22.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
		var l := UI.label(TABS[i][1], 13, UI.SUB)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		_buttons.append(b)
		_icons.append(ic)
		_labels.append(l)
	set_active(0)


func set_active(i: int) -> void:
	_active = i
	for k in range(_buttons.size()):
		var on := k == i
		var b: Button = _buttons[k]
		var bg: StyleBox = UI.box(Color(UI.TEXT, 0.1), 26) if on else StyleBoxEmpty.new()
		b.add_theme_stylebox_override("normal", bg)
		b.add_theme_stylebox_override("hover", bg)
		(_icons[k] as Icon).set_style(UI.RED if on else UI.SUB, on)
		var l: Label = _labels[k]
		l.add_theme_color_override("font_color", UI.TEXT if on else UI.SUB)
		l.add_theme_font_override("font", UI.SEMI if on else UI.REG)
