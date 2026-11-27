class_name SeasonBar
extends Control
## The weekly season bar on Goals: points fill a track, and each milestone sits
## on it at its points with its icon above (cash, Rush or Frenzy) and the points
## under it. Reached milestones are lit; claimed ones show a tick. Rewards are
## claimed from the "To claim" list like any other.

const H := 76.0
const PAD := 16.0
var _icons: Array = []   # Icon per milestone
var _sig := ""


func _init() -> void:
	custom_minimum_size = Vector2(0, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_place)


func refresh() -> void:
	var ms: Array = Game.season_milestones()
	var sig := str(int(Game.season_pts()))
	for m in ms:
		sig += "|%s%s" % [m["reached"], m["claimed"]]
	if sig == _sig and _icons.size() == ms.size():
		return
	_sig = sig
	if _icons.size() != ms.size():
		for ic in _icons:
			(ic as Node).queue_free()
		_icons.clear()
		for m in ms:
			var ic := Icon.new(_kind_icon(String(m["kind"])), UI.SUB, 18.0)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(ic)
			_icons.append(ic)
	for i in range(ms.size()):
		var m: Dictionary = ms[i]
		var ic: Icon = _icons[i]
		if m["claimed"]:
			ic.kind = "check"
			ic.set_style(UI.TEXT, true)
		elif m["reached"]:
			ic.kind = _kind_icon(String(m["kind"]))
			ic.set_style(UI.TEXT, true)
		else:
			ic.kind = _kind_icon(String(m["kind"]))
			ic.set_style(UI.SUB, false)
	_place()
	queue_redraw()


static func _kind_icon(k: String) -> String:
	return {"cash": "coins", "rush": "bolt", "frenzy": "fire"}.get(k, "star")


func _top() -> float:
	var ms: Array = Data.SEASON
	return float(ms[ms.size() - 1][0]) if not ms.is_empty() else 1.0


func _x(pts: float) -> float:
	return PAD + (size.x - PAD * 2.0) * clampf(pts / _top(), 0.0, 1.0)


func _place() -> void:
	var ms: Array = Data.SEASON
	for i in range(mini(_icons.size(), ms.size())):
		var ic: Icon = _icons[i]
		ic.position = Vector2(_x(float(ms[i][0])) - 9.0, 2.0)
	queue_redraw()


func _draw() -> void:
	var ms: Array = Game.season_milestones()
	var y := 36.0
	var x0 := PAD
	var x1 := size.x - PAD
	draw_line(Vector2(x0, y), Vector2(x1, y), UI.TRACK, 6.0, true)
	var px := _x(Game.season_pts())
	if px > x0:
		draw_line(Vector2(x0, y), Vector2(px, y), UI.TEXT, 6.0, true)
	var f: Font = UI.REG
	for m in ms:
		var x := _x(float(m["pts"]))
		var lit: bool = m["reached"]
		draw_circle(Vector2(x, y), 7.0, UI.TEXT if lit else UI.PANEL)
		if not lit:
			draw_arc(Vector2(x, y), 7.0, 0.0, TAU, 24, UI.TRACK, 2.0, true)
		var t := str(int(m["pts"]))
		var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tx := clampf(x - tw * 0.5, 0.0, size.x - tw)
		draw_string(f, Vector2(tx, y + 30.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.TEXT if lit else UI.SUB)
