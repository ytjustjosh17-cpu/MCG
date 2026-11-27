class_name NetChart
extends Control
## Pale line chart of net worth over the past week, with a dot at "now".
## Profile hides it until week_points() >= 2 (a flat stub says nothing).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


static func week_points() -> int:
	## Saved history points inside the past week (the live point not counted).
	var cutoff := Game.now() - Game.WEEK_S
	var n := 0
	for i in range(Game.history.size() - 1, -1, -1):
		if Game.history[i][0] < cutoff:
			break
		n += 1
		if n >= 2:
			break
	return n


var _hist_n := -1
var _cache: Array = []
var _last_ms := 0


func refresh() -> void:
	## Redraw when a history point is added, or once a second for the live
	## end point (not on every game change: a week is up to 2,000 points).
	var t := Time.get_ticks_msec()
	if Game.history.size() != _hist_n or t - _last_ms >= 1000:
		_last_ms = t
		queue_redraw()


func _points() -> Array:
	if Game.history.size() != _hist_n:
		_hist_n = Game.history.size()
		var cutoff := Game.now() - Game.WEEK_S
		var pts: Array = []
		for p in Game.history:
			if p[0] >= cutoff:
				pts.append(p[1])
		# Thin to about 200 points: plenty for a phone-wide line.
		if pts.size() > 200:
			var step := float(pts.size()) / 200.0
			var thin: Array = []
			var i := 0.0
			while int(i) < pts.size():
				thin.append(pts[int(i)])
				i += step
			pts = thin
		_cache = pts
	var out := _cache.duplicate()
	out.append(Game.net_worth())
	return out


func _draw() -> void:
	if size.x < 20.0 or size.y < 20.0:
		return
	var vals := _points()
	var w := size.x - 12.0
	var h := size.y
	if vals.size() < 2:
		draw_dashed_line(Vector2(0, h * 0.7), Vector2(size.x, h * 0.7), UI.TRACK, 1.0, 4.0)
		return
	var lo: float = vals.min()
	var hi: float = vals.max()
	if hi - lo < 0.01:
		hi = lo + 1.0
	var line := PackedVector2Array()
	for i in range(vals.size()):
		var x := w * float(i) / float(vals.size() - 1)
		var y := h - 8.0 - (float(vals[i]) - lo) / (hi - lo) * (h - 16.0)
		line.append(Vector2(x, y))
	var base_y := line[0].y
	draw_dashed_line(Vector2(0, base_y), Vector2(size.x, base_y), UI.TRACK, 1.0, 4.0)
	var area := PackedVector2Array(line)
	area.append(Vector2(line[line.size() - 1].x, h))
	area.append(Vector2(0, h))
	var cols := PackedColorArray()
	for p in area:
		cols.append(Color(UI.TEXT, 0.14 * (1.0 - clampf(p.y / h, 0.0, 1.0))))
	draw_polygon(area, cols)
	draw_polyline(line, UI.TEXT, 2.0, true)
	var end := line[line.size() - 1]
	draw_circle(end, 4.0, UI.TEXT)
