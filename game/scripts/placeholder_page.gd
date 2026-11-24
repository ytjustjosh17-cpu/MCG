class_name PlaceholderPage
extends Control
## Simple "coming next" page for tabs that aren't built yet.

var _title := ""
var _lines: Array = []


func _init(title := "", lines: Array = []) -> void:
	_title = title
	_lines = lines


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.place(UI.label(_title, 34, UI.TEXT, true), 20, 52))
	var card := UI.panel(UI.PANEL, 16)
	card.position = Vector2(16, 108)
	add_child(card)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(UI.label("Coming in a later update", 17, UI.TEXT, true))
	for line in _lines:
		var l := UI.label("·  " + str(line), 17, UI.SUB)
		box.add_child(l)
	var fit := func(): card.size = Vector2(size.x - 32, 56 + 30 * _lines.size())
	resized.connect(fit)
	fit.call()
