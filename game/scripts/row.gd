class_name Row
extends Button
## Tappable list row: optional icon or art, title and subtitle on the left,
## value and note on the right, then a chevron.

var title_l: Label
var sub_l: Label
var value_l: Label
var note_l: Label
var mark: ColorRect
var lead: Control
var lock_i: Icon       # small lock before the value (set_locked)
var _h: HBoxContainer
var _m: MarginContainer
var _left: VBoxContainer
var _right: VBoxContainer


func _init(icon := "", art := "", chevron := true) -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.05), 0))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	custom_minimum_size = Vector2(0, 60)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	_m = m
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	_h = h
	if icon != "":
		lead = Icon.new(icon, UI.TEXT, 22.0)
		lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(lead)
	elif art != "":
		lead = Art.Scene.new(art, 8.0)
		lead.custom_minimum_size = Vector2(52, 40)
		lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(lead)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(left)
	_left = left
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(th)
	title_l = UI.label("", 17)
	# A long name ends in "..." instead of pushing the value off the card.
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A long one-line name trims with "..." (set in set_texts, so titles a
	# page makes wrap, like headlines, are left alone).
	th.add_child(title_l)
	mark = ColorRect.new()
	mark.color = UI.TEXT  # "owned"; red stays for the sun and lit windows
	mark.custom_minimum_size = Vector2(8, 8)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.visible = false
	th.add_child(mark)
	sub_l = UI.label("", 13, UI.SUB)
	sub_l.clip_text = true
	sub_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left.add_child(sub_l)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 2)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	_right = right
	var vh := HBoxContainer.new()
	vh.alignment = BoxContainer.ALIGNMENT_END
	vh.add_theme_constant_override("separation", 6)
	vh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(vh)
	lock_i = Icon.new("lock", UI.SUB, 15.0)
	lock_i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock_i.visible = false
	vh.add_child(lock_i)
	value_l = UI.label("", 17)
	value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vh.add_child(value_l)
	note_l = UI.label("", 13, UI.SUB)
	note_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(note_l)
	if chevron:
		var c := Icon.new("chevron", UI.DIM, 16.0)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(c)


func set_texts(t: String, s := "", v := "", n := "") -> void:
	title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if title_l.autowrap_mode == TextServer.AUTOWRAP_OFF else TextServer.OVERRUN_NO_TRIMMING
	title_l.text = t
	# One row height everywhere: 56 px, 60 with a second line (a page can pin
	# its own with set_meta("fixed_h", true)).
	if not has_meta("fixed_h"):
		custom_minimum_size.y = UI.ROW_H_SUB if s != "" else UI.ROW_H
	sub_l.text = s
	sub_l.visible = s != ""
	value_l.text = v
	note_l.text = n
	note_l.visible = n != ""


func set_change(pct: float) -> void:
	## Shows a price change with an arrow and sign; down moves use the dim colour.
	var up := pct >= 0.0
	note_l.text = ("▲ +" if up else "▼ −") + "%.2f%%" % absf(pct)
	note_l.visible = true
	note_l.add_theme_color_override("font_color", UI.change_color(pct))


func set_lead(c: Control) -> void:
	## Puts a custom badge (e.g. an AssetTile) at the start of the row.
	if lead:
		lead.queue_free()
	lead = c
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_h.add_child(c)
	_h.move_child(c, 0)


func set_bold(on := true) -> void:
	## Semibold title and value (list rows that name a thing: shares, coins, homes).
	title_l.add_theme_font_override("font", UI.SEMI if on else UI.REG)
	value_l.add_theme_font_override("font", UI.SEMI if on else UI.REG)


func set_locked(on: bool) -> void:
	## A small lock before the value: you can't buy this one yet.
	lock_i.visible = on


func align_top(pad := 12) -> void:
	## For wrapped titles (headlines): both columns start at the first line,
	## so the value lines up with it instead of floating in the middle.
	_left.alignment = BoxContainer.ALIGNMENT_BEGIN
	_right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_m.add_theme_constant_override("margin_top", pad)
	_m.add_theme_constant_override("margin_bottom", pad)
	grow_to_fit()


func grow_to_fit() -> void:
	## The row gets as tall as its wrapped text (a Button doesn't size to its
	## children by itself). Pins the height, so set_texts leaves it alone.
	set_meta("fixed_h", true)
	if not _m.minimum_size_changed.is_connected(_grow):
		_m.minimum_size_changed.connect(_grow)
	_grow.call_deferred()


func _grow() -> void:
	custom_minimum_size.y = maxf(UI.ROW_H, _m.get_combined_minimum_size().y)


func caption_on_top() -> void:
	## The second line moves above the title, as a small caption ("News · DPW").
	_left.move_child(sub_l, 0)
