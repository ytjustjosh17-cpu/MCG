class_name PriceChart
extends Control
## Pale line of a price history with one lit point at the end.
## `range_name` is "1H", "1D" or "1W". Press and drag to read a price.

signal scrub(price: float, index: int, count: int)

var sym := ""
var range_name := "1H"
var interactive := false
var line_col := UI.TEXT
var avg_price := 0.0   # your average buy price; 0 = none owned, no line
var show_range := false   # faint high and low prices at the right
var _touch := -1.0
var _start := Vector2(-1, -1)
var _pts := PackedVector2Array()
var _vals: Array = []


func _init(s := "", r := "1H", touch := false) -> void:
	sym = s
	range_name = r
	interactive = touch
	mouse_filter = Control.MOUSE_FILTER_PASS if touch else Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_range(r: String) -> void:
	range_name = r
	_touch = -1.0
	_start = Vector2(-1, -1)
	queue_redraw()


func values() -> Array:
	var h: Array = Game.series(sym, range_name).filter(func(v): return float(v) > 0.0)   # a missing (0) sample would draw a spike from the floor
	if range_name == "1H" and h.size() > 61:
		h = h.slice(h.size() - 61)
	if Game.price(sym) > 0.0:
		h.append(Game.price(sym))
	return h


func _gui_input(e: InputEvent) -> void:
	## Press and drag sideways to read old prices. A mostly-up/down drag is
	## left to the page so it still scrolls (10 px before deciding).
	if not interactive:
		return
	if e is InputEventScreenTouch or e is InputEventMouseButton:
		if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			_start = e.position
			_touch = -1.0
		else:
			_start = Vector2(-1, -1)
			if _touch >= 0.0:
				_touch = -1.0
				scrub.emit(-1.0, -1, 0)
				queue_redraw()
	elif (e is InputEventScreenDrag or e is InputEventMouseMotion) and _start.x >= 0.0:
		if _touch < 0.0:
			var d: Vector2 = e.position - _start
			if d.length() < 10.0:
				return
			if absf(d.x) < absf(d.y):
				_start = Vector2(-1, -1)  # vertical: let the page scroll
				return
			Kit.haptic("selection")
		_touch = clampf(e.position.x, 0.0, size.x)
		accept_event()
		_emit_scrub()
		queue_redraw()


func _emit_scrub() -> void:
	var h := values()
	if h.size() < 2 or size.x < 20.0:
		return
	var i := clampi(int(round(_touch / (size.x - 12.0) * float(h.size() - 1))), 0, h.size() - 1)
	scrub.emit(float(h[i]), i, h.size())


func _draw() -> void:
	_vals = values()
	var h := _vals
	if h.size() < 2 or size.x < 20.0 or size.y < 20.0:
		return
	var lo: float = h.min()
	var hi: float = h.max()
	if hi - lo <= hi * 1e-6:
		hi = lo * 1.001 + 1e-9
	_pts = PackedVector2Array()
	var w := size.x - 12.0
	var pad := 20.0 if show_range else 8.0   # room for the high and low text
	for i in range(h.size()):
		var y := size.y - pad - (float(h[i]) - lo) / (hi - lo) * (size.y - pad * 2.0)
		_pts.append(Vector2(w * i / float(h.size() - 1), y))
	var pts := _pts
	draw_dashed_line(Vector2(0, pts[0].y), Vector2(size.x, pts[0].y), UI.TRACK, 1.0, 4.0)
	var area := PackedVector2Array(pts)
	area.append(Vector2(pts[pts.size() - 1].x, size.y))
	area.append(Vector2(0, size.y))
	var cols := PackedColorArray()
	for p in area:
		cols.append(Color(line_col, 0.18 * (1.0 - clampf(p.y / size.y, 0.0, 1.0))))
	draw_polygon(area, cols)
	draw_polyline(pts, line_col, 2.0, true)
	var font: Font = UI.REG
	var fs := 13   # the smallest text size anywhere in the game
	if avg_price > 0.0 and avg_price >= lo and avg_price <= hi:
		var ay := size.y - pad - (avg_price - lo) / (hi - lo) * (size.y - pad * 2.0)
		draw_dashed_line(Vector2(0, ay), Vector2(size.x, ay), Color(UI.SUB, 0.7), 1.0, 2.0)
		var aw := font.get_string_size("avg", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_rect(Rect2(0, ay - 9.0, aw + 8.0, 18.0), UI.BG)
		draw_string(font, Vector2(4.0, ay + 5.0), "avg", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.SUB)
	if show_range:
		var faint := UI.SUB
		var tw := 120.0
		var x0 := size.x - 24.0 - tw
		draw_string(font, Vector2(x0, float(fs) + 1.0), AssetDetail.price_text(hi), HORIZONTAL_ALIGNMENT_RIGHT, tw, fs, faint)
		draw_string(font, Vector2(x0, size.y - 2.0), AssetDetail.price_text(lo), HORIZONTAL_ALIGNMENT_RIGHT, tw, fs, faint)
	if _touch >= 0.0:
		var i := clampi(int(round(_touch / w * float(h.size() - 1))), 0, h.size() - 1)
		var p := pts[i]
		draw_line(Vector2(p.x, 0), Vector2(p.x, size.y), UI.SUB, 1.0)
		draw_circle(p, 5.0, line_col)
	else:
		# The latest price: a dot in the line's own colour with a dark ring (red stays rare).
		draw_circle(pts[pts.size() - 1], 6.0, UI.BG)
		draw_circle(pts[pts.size() - 1], 4.0, line_col)


static func change_pct(s: String, back := 60) -> float:
	return Game.change_pct(s, back)
