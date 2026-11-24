class_name NetChart
extends Control
## Pale line chart of net worth over the past week, with one lit red point at the end.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _points() -> Array:
	var cutoff := Game.now() - Game.WEEK_S
	var pts: Array = []
	for p in Game.history:
		if p[0] >= cutoff:
			pts.append(p[1])
	pts.append(Game.net_worth())
	return pts


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
	draw_rect(Rect2(end - Vector2(5, 5), Vector2(10, 10)), UI.RED, true)
