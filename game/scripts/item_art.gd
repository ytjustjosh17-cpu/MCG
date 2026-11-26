class_name ItemArt
extends Control
## A small drawing of one personal item: each watch, painting, car, jet,
## yacht and island has its own look (index 0-5 changes the details).
## `col` is the collection id; `idx` is the item number (-1 = the set's emblem).

var col := "watches"
var idx := 0
var owned := true


func _init(c := "watches", i := 0, side := 48.0) -> void:
	col = c
	idx = i
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_owned(o: bool) -> void:
	if o != owned:
		owned = o
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var k := maxi(idx, 0)
	var ink := UI.TEXT if owned else UI.DIM
	var acc: Color = UI.COIN_COL[(k * 5 + col.length()) % UI.COIN_COL.size()] if owned else UI.TRACK
	match col:
		"watches": _watch(o, s, k, ink, acc)
		"art": _painting(o, s, k, ink, acc)
		"cars": _car(o, s, k, ink, acc)
		"jets": _jet(o, s, k, ink, acc)
		"yachts": _yacht(o, s, k, ink, acc)
		"islands": _island(o, s, k, ink, acc)


func _p(o: Vector2, s: float, x: float, y: float) -> Vector2:
	return o + Vector2(x, y) * s


func _poly(o: Vector2, s: float, pts: Array, c: Color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(_p(o, s, q[0], q[1]))
	draw_colored_polygon(p, c)


func _watch(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Strap, then a round (or cushion) case, hands at a different time each.
	draw_rect(Rect2(_p(o, s, 0.38, 0.02), Vector2(0.24, 0.96) * s), UI.RAISED if owned else UI.TRACK)
	var c := _p(o, s, 0.5, 0.5)
	var r := s * (0.3 + 0.02 * float(k % 3))
	if k == 2 or k == 4:
		draw_colored_polygon(UI.rounded_rect_poly(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), r * 0.35), ink)
	else:
		draw_circle(c, r, ink)
	draw_circle(c, r * 0.82, UI.INK)
	if k == 2:   # diver: coloured bezel ring
		draw_arc(c, r * 0.9, 0.0, TAU, 32, acc, r * 0.14, true)
	if k == 3:   # moonphase: small moon window
		draw_circle(c + Vector2(0, r * 0.42), r * 0.2, acc)
	if k == 4:   # tourbillon: a little gear
		for g in 8:
			var a := TAU * float(g) / 8.0
			draw_line(c + Vector2(0, r * 0.4), c + Vector2(0, r * 0.4) + Vector2(cos(a), sin(a)) * r * 0.22, acc, 1.5)
	var ah := TAU * float(k * 2 + 1) / 12.0 - PI / 2.0
	var am := TAU * float(k * 7 + 2) / 12.0 - PI / 2.0
	draw_line(c, c + Vector2(cos(ah), sin(ah)) * r * 0.45, ink, 2.0, true)
	draw_line(c, c + Vector2(cos(am), sin(am)) * r * 0.68, ink, 1.5, true)
	if k == 5:   # Red Sun No. 1: a red dot at twelve
		draw_circle(c + Vector2(0, -r * 0.6), r * 0.13, UI.RED if owned else UI.DIM)


func _painting(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Frame, then a tiny scene per painting.
	var fr := Rect2(_p(o, s, 0.06, 0.14), Vector2(0.88, 0.72) * s)
	draw_rect(fr, ink)
	var cv := fr.grow(-s * 0.06)
	draw_rect(cv, UI.SKY if owned else UI.PANEL)
	var b := cv.position
	var w := cv.size
	match k:
		0:  # Harbour at Dusk: sun low, water lines
			draw_circle(b + Vector2(w.x * 0.7, w.y * 0.55), w.y * 0.25, acc)
			for i in 3:
				draw_rect(Rect2(b + Vector2(0, w.y * (0.7 + i * 0.1)), Vector2(w.x, 1.5)), ink)
		1:  # Two Cranes
			for cx in [0.3, 0.65]:
				draw_rect(Rect2(b + Vector2(w.x * cx, w.y * 0.2), Vector2(2, w.y * 0.8)), ink)
				draw_rect(Rect2(b + Vector2(w.x * (cx - 0.15), w.y * 0.2), Vector2(w.x * 0.35, 2)), ink)
		2:  # Ironmere Smoke: chimneys and a smudge
			for cx in [0.25, 0.45, 0.65]:
				draw_rect(Rect2(b + Vector2(w.x * cx, w.y * 0.45), Vector2(w.x * 0.08, w.y * 0.55)), ink)
			draw_circle(b + Vector2(w.x * 0.5, w.y * 0.25), w.y * 0.18, acc)
		3:  # The Long Quay: a long pier into the distance
			draw_colored_polygon(PackedVector2Array([b + Vector2(0, w.y), b + Vector2(w.x * 0.45, w.y * 0.45), b + Vector2(w.x * 0.55, w.y * 0.45), b + Vector2(w.x, w.y)]), ink)
		4:  # Red Sun Rising
			draw_circle(b + Vector2(w.x * 0.5, w.y * 0.8), w.y * 0.45, UI.RED if owned else UI.DIM)
			draw_rect(Rect2(b + Vector2(0, w.y * 0.8), Vector2(w.x, w.y * 0.2)), UI.INK)
		_:  # Portrait in Teal: head and shoulders
			draw_circle(b + Vector2(w.x * 0.5, w.y * 0.4), w.y * 0.2, acc)
			draw_colored_polygon(PackedVector2Array([b + Vector2(w.x * 0.2, w.y), b + Vector2(w.x * 0.35, w.y * 0.65), b + Vector2(w.x * 0.65, w.y * 0.65), b + Vector2(w.x * 0.8, w.y)]), acc)


func _car(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# A side view; roof height, length and fins change per car.
	var roof: float = [0.42, 0.36, 0.40, 0.48, 0.34, 0.30][k]
	var nose: float = [0.9, 0.95, 0.92, 0.9, 0.96, 0.98][k]
	_poly(o, s, [[0.06, 0.68], [0.08, 0.56], [0.25, 0.52], [0.35, roof], [0.62, roof], [0.74, 0.52], [nose, 0.56], [nose, 0.68]], acc)
	if k != 3:   # the Spyder has no roof window
		_poly(o, s, [[0.38, roof + 0.03], [0.6, roof + 0.03], [0.68, 0.51], [0.32, 0.51]], UI.INK)
	for wx in [0.24, 0.74]:
		draw_circle(_p(o, s, wx, 0.68), s * 0.09, ink)
		draw_circle(_p(o, s, wx, 0.68), s * 0.04, UI.INK)
	if k == 5:   # The Lamplight: a long chrome line
		draw_rect(Rect2(_p(o, s, 0.1, 0.6), Vector2(0.8, 0.02) * s), ink)


func _jet(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Seen from above; wings sweep more and the body grows with the price.
	var len := 0.6 + 0.06 * float(k)
	var sweep := 0.1 + 0.04 * float(k)
	var x0 := 0.5 - len * 0.5
	var x1 := 0.5 + len * 0.5
	_poly(o, s, [[x0, 0.5], [x0 + 0.08, 0.45], [x1 - 0.05, 0.46], [x1, 0.5], [x1 - 0.05, 0.54], [x0 + 0.08, 0.55]], ink)
	_poly(o, s, [[0.45, 0.47], [0.45 + sweep, 0.12], [0.55 + sweep, 0.12], [0.6, 0.47]], acc)
	_poly(o, s, [[0.45, 0.53], [0.45 + sweep, 0.88], [0.55 + sweep, 0.88], [0.6, 0.53]], acc)
	_poly(o, s, [[x0 + 0.02, 0.48], [x0 - 0.02, 0.34], [x0 + 0.06, 0.34], [x0 + 0.1, 0.48]], ink)
	if k == 4:   # Red Sun One: a red stripe
		draw_rect(Rect2(_p(o, s, x0 + 0.1, 0.49), Vector2(len - 0.15, 0.02) * s), UI.RED if owned else UI.DIM)


func _yacht(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Hull, decks stacked higher on bigger boats, a sail on the first two.
	_poly(o, s, [[0.04, 0.62], [0.96, 0.62], [0.86, 0.78], [0.14, 0.78]], ink)
	var decks: int = [0, 1, 1, 2, 2, 3][k]
	for d in decks:
		var w := 0.6 - 0.14 * float(d)
		_poly(o, s, [[0.5 - w * 0.5, 0.62 - 0.08 * d], [0.5 + w * 0.5 + 0.05, 0.62 - 0.08 * d], [0.5 + w * 0.5, 0.54 - 0.08 * d], [0.5 - w * 0.5 + 0.05, 0.54 - 0.08 * d]], acc if d % 2 == 0 else ink)
	if k <= 1:
		draw_rect(Rect2(_p(o, s, 0.49, 0.14), Vector2(0.02, 0.48) * s), ink)
		_poly(o, s, [[0.51, 0.16], [0.51, 0.58], [0.82, 0.58]], acc)
	for i in 2:
		draw_rect(Rect2(_p(o, s, 0.1 + i * 0.3, 0.86), Vector2(0.22, 0.015) * s), UI.SUB if owned else UI.TRACK)


func _island(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Sea, a mound of a different shape, palms and (later ones) a house.
	draw_rect(Rect2(_p(o, s, 0.0, 0.7), Vector2(1.0, 0.3) * s), UI.SKY if owned else UI.PANEL)
	var wid := 0.4 + 0.08 * float(k)
	var hgt := 0.12 + 0.03 * float(k % 3)
	_poly(o, s, [[0.5 - wid * 0.5, 0.72], [0.5 - wid * 0.25, 0.72 - hgt], [0.5 + wid * 0.25, 0.72 - hgt * 1.1], [0.5 + wid * 0.5, 0.72]], acc)
	var palms: int = [1, 1, 2, 2, 3, 3][k]
	for p in palms:
		var px := 0.5 - wid * 0.3 + float(p) * 0.16
		draw_line(_p(o, s, px, 0.72 - hgt), _p(o, s, px + 0.03, 0.34), ink, 2.0, true)
		for a in [-0.6, 0.0, 0.6]:
			draw_line(_p(o, s, px + 0.03, 0.34), _p(o, s, px + 0.03, 0.34) + Vector2(cos(a - PI / 2.0 + PI / 2.0 * signf(a)), sin(a - 0.9)) * s * 0.1, ink, 2.0, true)
	if k >= 3:
		var hx := 0.56
		draw_rect(Rect2(_p(o, s, hx, 0.72 - hgt - 0.1), Vector2(0.16, 0.1) * s), ink)
		if k == 5:   # Crown Isle: a red roof light
			draw_circle(_p(o, s, hx + 0.08, 0.72 - hgt - 0.13), s * 0.025, UI.RED if owned else UI.DIM)
