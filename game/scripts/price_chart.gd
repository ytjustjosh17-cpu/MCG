class_name PriceChart
extends Control
## Pale line of a price history with one lit point at the end.

var sym := ""


func _init(s := "") -> void:
	sym = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var h: Array = Game.price_hist.get(sym, [])
	if h.size() < 2 or size.x < 20.0:
		return
	var lo: float = h.min()
	var hi: float = h.max()
	if hi - lo <= hi * 1e-6:
		hi = lo * 1.001 + 1e-9
	var pts := PackedVector2Array()
	var w := size.x - 12.0
	for i in range(h.size()):
		var y := size.y - 8.0 - (float(h[i]) - lo) / (hi - lo) * (size.y - 16.0)
		pts.append(Vector2(w * i / float(h.size() - 1), y))
	draw_dashed_line(Vector2(0, pts[0].y), Vector2(size.x, pts[0].y), UI.TRACK, 1.0, 4.0)
	var area := PackedVector2Array(pts)
	area.append(Vector2(pts[pts.size() - 1].x, size.y))
	area.append(Vector2(0, size.y))
	var cols := PackedColorArray()
	for p in area:
		cols.append(Color(UI.TEXT, 0.12 * (1.0 - clampf(p.y / size.y, 0.0, 1.0))))
	draw_polygon(area, cols)
	draw_polyline(pts, UI.TEXT, 2.0, true)
	draw_rect(Rect2(pts[pts.size() - 1] - Vector2(5, 5), Vector2(10, 10)), UI.RED, true)


static func change_pct(s: String, back := 60) -> float:
	var h: Array = Game.price_hist.get(s, [])
	if h.size() < 2:
		return 0.0
	var a: float = h[maxi(0, h.size() - 1 - back)]
	return (float(h[h.size() - 1]) - a) / a * 100.0
