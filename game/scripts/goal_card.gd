class_name GoalCard
extends Button
## Earn screen: the next big thing to save for, with a thin progress line.

var _icon: Icon
var _title: Label
var _sub: Label
var _chev: Icon
var _prog := 0.0
var goal := {}


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, UI.box(UI.PANEL if st != "pressed" else UI.RAISED, 16))
	_icon = Icon.new("goal", UI.SUB, 20.0)
	add_child(_icon)
	_title = UI.label("", 15, UI.TEXT, true)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_title)
	_sub = UI.label("", 13, UI.SUB)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_sub)
	_chev = Icon.new("chevron", UI.DIM, 14.0)
	add_child(_chev)
	resized.connect(_layout)
	Kit.press_fx(self)


func _layout() -> void:
	_icon.position = Vector2(14, (size.y - 20.0) * 0.5 - 2.0)
	_chev.position = Vector2(size.x - 12 - 14, (size.y - 14.0) * 0.5 - 2.0)
	_sub.size = Vector2(110, 20)
	_sub.position = Vector2(size.x - 32 - 110, (size.y - 20.0) * 0.5 - 2.0)
	_title.position = Vector2(44, (size.y - 22.0) * 0.5 - 2.0)
	_title.size = Vector2(maxf(0.0, size.x - 44 - 150), 22)


func set_goal(g: Dictionary) -> void:
	goal = g
	visible = not g.is_empty()
	if g.is_empty():
		return
	var cost := float(g["cost"])
	_prog = 1.0 if cost <= 0.0 else clampf(Game.cash / cost, 0.0, 1.0)
	var ready := _prog >= 1.0
	_icon.kind = g["icon"]
	_icon.set_style(UI.RED if ready else UI.SUB)
	_title.text = title_for(g)
	var wait := Game.eta(cost)
	_sub.text = "Buy now" if ready else (wait if wait != "" else Game.money_short(cost - Game.cash) + " more")
	_sub.add_theme_color_override("font_color", UI.TEXT if ready else UI.SUB)
	queue_redraw()


static func title_for(g: Dictionary) -> String:
	## A verb first, so the card says what to do: "Open X", "Buy X", "Move to X".
	var t := String(g["text"])
	match String(g["icon"]):
		"home":
			return "Move to " + t
		"business":
			return ("Buy " + t.substr(3)) if t.begins_with("+1 ") else ("Open " + t)
		"pie":
			return "Form " + t
		"invest":
			return t if t.contains(" for ") else ("Buy " + t)
	return t


func _draw() -> void:
	var w := size.x - 28.0
	var y := size.y - 8.0
	draw_line(Vector2(14, y), Vector2(14 + w, y), UI.TRACK, 3.0, true)
	if _prog > 0.0:
		draw_line(Vector2(14, y), Vector2(14 + w * _prog, y), UI.RED if _prog >= 1.0 else UI.TEXT, 3.0, true)
