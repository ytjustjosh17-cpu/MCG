class_name Page
extends Control
## Scrolling page with a large title, optional back button and a column of content.
## Pages ask the root to push or pop detail pages.

signal push_page(page: Control)
signal pop_page

var title := ""
var has_back := false
var scroll: ScrollContainer
var body: VBoxContainer
var _title_label: Label
var _needs_refresh := true


func _init(t := "", back := false) -> void:
	title = t
	has_back = back


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 104)
	scroll.add_child(margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	if has_back:
		var back := UI.pill("", UI.PANEL, UI.TEXT, 17, 22)
		back.custom_minimum_size = Vector2(44, 44)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var chev := Icon.new("back", UI.TEXT, 20.0)
		chev.position = Vector2(12, 12)
		back.add_child(chev)
		back.pressed.connect(func(): pop_page.emit())
		Kit.press_fx(back)
		body.add_child(back)
	else:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 44)
		body.add_child(gap)
	if title != "":
		_title_label = UI.label(title, 34, UI.TEXT, true)
		_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(_title_label)
	build()
	Game.changed.connect(_on_changed)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			refresh())
	refresh()


func set_title(t: String) -> void:
	title = t
	if _title_label:
		_title_label.text = t


func _on_changed() -> void:
	if is_visible_in_tree():
		refresh()


func build() -> void:
	pass


func refresh() -> void:
	pass


# ---- helpers for subclasses ------------------------------------------------

func card(parent: Control = null, radius := 16) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, radius))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	(parent if parent else body).add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	pc.add_child(v)
	return v


func padded(parent: Control, pad := 16, gap := 8) -> VBoxContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, pad)
	parent.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	m.add_child(v)
	return v


func section(text: String, right := "") -> Label:
	var h := HBoxContainer.new()
	body.add_child(h)
	var l := UI.label(text, 17, UI.TEXT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var r := UI.label(right, 13, UI.SUB)
	h.add_child(r)
	return r


func separator(parent: Control, indent := 16) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", indent)
	parent.add_child(m)
	var line := ColorRect.new()
	line.color = UI.RAISED
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(line)


func button(text: String, primary := true, call: Callable = Callable()) -> Button:
	var b := UI.pill(text, UI.TEXT if primary else UI.RAISED, UI.INK if primary else UI.TEXT, 17, 24)
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if call.is_valid():
		b.pressed.connect(func():
			Kit.tick()
			call.call())
	Kit.press_fx(b)
	return b


static func set_enabled(b: Button, on: bool, primary := true) -> void:
	b.disabled = not on
	if on:
		UI.paint(b, UI.TEXT if primary else UI.RAISED, UI.INK if primary else UI.TEXT, 24)
	else:
		UI.paint(b, UI.RAISED, UI.SUB, 24)
