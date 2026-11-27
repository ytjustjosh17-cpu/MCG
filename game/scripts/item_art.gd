class_name ItemArt
extends Control
## A small drawing of one personal item: each watch, painting, car, jet,
## yacht, island and relic has its own look (index 0-5 changes the details).
## `col` is the collection id; `idx` is the item number (-1 = the set's emblem).
## Owned items are drawn in full (TEXT with one GOLD accent, the "luxury"
## colour). Items you don't own yet are a quiet SUB silhouette, so the two
## read apart at a glance even at list size.

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
	var k := clampi(idx if idx >= 0 else 5, 0, 5)
	var ink := UI.TEXT if owned else Color(UI.SUB, 0.55)
	var acc := UI.GOLD if owned else Color(UI.SUB, 0.3)
	# A soft shadow on the ground under things that stand or drive.
	if owned and col in ["cars", "relics", "watches"]:
		_shadow(o + Vector2(s * 0.5, s * (0.82 if col == "cars" else 0.9)), s * 0.42, s * 0.05)
	match col:
		"watches": _watch(o, s, k, ink, acc)
		"art": _painting(o, s, k, ink, acc)
		"cars": _car(o, s, k, ink, acc)
		"jets": _jet(o, s, k, ink, acc)
		"yachts": _yacht(o, s, k, ink, acc)
		"islands": _island(o, s, k, ink, acc)
		"relics": _relic(o, s, k, ink, acc)


func _p(o: Vector2, s: float, x: float, y: float) -> Vector2:
	return o + Vector2(x, y) * s


func _poly(o: Vector2, s: float, pts: Array, c: Color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(_p(o, s, q[0], q[1]))
	draw_colored_polygon(p, c)


func _rrect(o: Vector2, s: float, x: float, y: float, w: float, h: float, r: float, c: Color) -> void:
	draw_colored_polygon(UI.rounded_rect_poly(Rect2(_p(o, s, x, y), Vector2(w, h) * s), r * s), c)


func _shadow(c: Vector2, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, Color(UI.INK, 0.45))


func _shine() -> Color:
	## A soft highlight where the light catches a surface.
	return Color(UI.FLASH, 0.55) if owned else Color(UI.SUB, 0.12)


func _hole() -> Color:
	## The dark "inside" colour (dial, windows, wheels).
	return UI.INK if owned else UI.PANEL


func _watch(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Strap above and below, then the case: round, cushion or square.
	var strap := UI.RAISED if owned else Color(UI.SUB, 0.25)
	_rrect(o, s, 0.36, 0.0, 0.28, 0.3, 0.06, strap)
	_rrect(o, s, 0.36, 0.7, 0.28, 0.3, 0.06, strap)
	var c := _p(o, s, 0.5, 0.5)
	var r := s * 0.32
	if k == 2 or k == 4:
		draw_colored_polygon(UI.rounded_rect_poly(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), r * 0.4), ink)
	else:
		draw_circle(c, r, ink)
	draw_circle(c, r * 0.8, _hole())
	# Bezel: gold on the diver and the last watch, a crown on the right.
	if k == 2 or k == 5:
		draw_arc(c, r * 0.9, 0.0, TAU, 40, acc, r * 0.16, true)
	draw_rect(Rect2(c + Vector2(r * 0.98, -r * 0.12), Vector2(r * 0.18, r * 0.24)), ink)
	# Four hour marks.
	for m in 4:
		var a := TAU * float(m) / 4.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.56, c + d * r * 0.72, ink, maxf(1.0, s * 0.03))
	if k == 3:   # moonphase window
		draw_circle(c + Vector2(0, r * 0.38), r * 0.18, acc)
	if k == 4:   # tourbillon cage
		draw_arc(c + Vector2(0, r * 0.36), r * 0.18, 0.0, TAU, 16, acc, maxf(1.0, s * 0.03), true)
	# Light across the glass, and a stitched strap.
	draw_arc(c, r * 0.66, PI * 1.08, PI * 1.42, 12, Color(UI.TEXT, 0.4) if owned else Color(UI.SUB, 0.12), maxf(1.0, s * 0.03), true)
	for yy in [0.06, 0.16, 0.8, 0.9]:
		draw_rect(Rect2(_p(o, s, 0.4, yy), Vector2(0.02, 0.04) * s), Color(UI.SUB, 0.6) if owned else Color(UI.SUB, 0.2))
		draw_rect(Rect2(_p(o, s, 0.58, yy), Vector2(0.02, 0.04) * s), Color(UI.SUB, 0.6) if owned else Color(UI.SUB, 0.2))
	var ah := TAU * float(k * 2 + 1) / 12.0 - PI / 2.0
	var am := TAU * float(k * 7 + 2) / 12.0 - PI / 2.0
	draw_line(c, c + Vector2(cos(ah), sin(ah)) * r * 0.42, ink, maxf(1.5, s * 0.05), true)
	draw_line(c, c + Vector2(cos(am), sin(am)) * r * 0.62, ink, maxf(1.0, s * 0.035), true)
	draw_circle(c, maxf(1.5, s * 0.03), acc)


func _painting(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# A gilt frame (gold once owned), then a tiny scene per painting.
	var fr := Rect2(_p(o, s, 0.04, 0.12), Vector2(0.92, 0.76) * s)
	draw_rect(fr, acc if owned else ink)
	# A bevelled frame: lighter top and left, darker bottom and right.
	draw_rect(Rect2(fr.position, Vector2(fr.size.x, maxf(1.0, s * 0.02))), _shine())
	draw_rect(Rect2(fr.position, Vector2(maxf(1.0, s * 0.02), fr.size.y)), _shine())
	draw_rect(Rect2(fr.position.x, fr.end.y - maxf(1.0, s * 0.02), fr.size.x, maxf(1.0, s * 0.02)), Color(UI.INK, 0.5))
	var cv := fr.grow(-s * 0.07)
	draw_rect(cv.grow(maxf(1.0, s * 0.015)), Color(UI.INK, 0.6))   # the inner shadow of the frame
	draw_rect(cv, UI.SKY if owned else UI.PANEL)
	var b := cv.position
	var w := cv.size
	match k:
		0:  # Harbour at Dusk: sun low, water lines
			draw_circle(b + Vector2(w.x * 0.68, w.y * 0.5), w.y * 0.24, ink)
			for i in 3:
				draw_rect(Rect2(b + Vector2(0, w.y * (0.68 + i * 0.12)), Vector2(w.x, maxf(1.0, s * 0.03))), ink)
		1:  # Two Cranes
			for cx in [0.3, 0.66]:
				draw_rect(Rect2(b + Vector2(w.x * cx, w.y * 0.2), Vector2(maxf(2.0, s * 0.04), w.y * 0.8)), ink)
				draw_rect(Rect2(b + Vector2(w.x * (cx - 0.16), w.y * 0.2), Vector2(w.x * 0.36, maxf(2.0, s * 0.04))), ink)
		2:  # Ironmere Smoke: chimneys and a cloud
			for cx in [0.2, 0.42, 0.64]:
				draw_rect(Rect2(b + Vector2(w.x * cx, w.y * 0.45), Vector2(w.x * 0.1, w.y * 0.55)), ink)
			draw_circle(b + Vector2(w.x * 0.5, w.y * 0.24), w.y * 0.17, ink)
			draw_circle(b + Vector2(w.x * 0.68, w.y * 0.22), w.y * 0.13, ink)
		3:  # The Long Quay: a pier into the distance
			draw_colored_polygon(PackedVector2Array([b + Vector2(0, w.y), b + Vector2(w.x * 0.44, w.y * 0.42), b + Vector2(w.x * 0.56, w.y * 0.42), b + Vector2(w.x, w.y)]), ink)
		4:  # Red Sun Rising: the one red in the set
			draw_circle(b + Vector2(w.x * 0.5, w.y * 0.7), w.y * 0.3, UI.RED if owned else ink)
			draw_rect(Rect2(b + Vector2(0, w.y * 0.7), Vector2(w.x, w.y * 0.3)), _hole())
		_:  # Portrait in Teal: head and shoulders
			draw_circle(b + Vector2(w.x * 0.5, w.y * 0.38), w.y * 0.2, ink)
			draw_colored_polygon(PackedVector2Array([b + Vector2(w.x * 0.18, w.y), b + Vector2(w.x * 0.34, w.y * 0.64), b + Vector2(w.x * 0.66, w.y * 0.64), b + Vector2(w.x * 0.82, w.y)]), ink)


func _car(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Side view: low body, glasshouse, two big wheels. Each car has its own
	# shape: open roadster, fastback GT, notchback sport, roofless spyder,
	# long-bonnet coupe and a long limousine.
	var roof: float = [0.46, 0.36, 0.38, 0.5, 0.36, 0.34][k]
	var rs: float = [0.4, 0.2, 0.32, 0.4, 0.42, 0.24][k]     # where the roof starts (rear)
	var re: float = [0.56, 0.56, 0.58, 0.56, 0.62, 0.66][k]  # where the windscreen tops out
	var tail: float = [0.08, 0.05, 0.06, 0.06, 0.05, 0.02][k]
	var nose: float = [0.94, 0.95, 0.94, 0.94, 0.97, 0.98][k]
	var belt := 0.54
	if k == 0 or k == 3:   # open cars: a low body, a windscreen and a headrest
		_poly(o, s, [[tail, 0.7], [tail, belt], [rs - 0.04, belt - 0.02], [re + 0.1, belt - 0.02], [nose, belt + 0.04], [nose, 0.7]], ink)
		draw_line(_p(o, s, re + 0.04, belt - 0.02), _p(o, s, re - 0.02, belt - 0.14), ink, maxf(1.5, s * 0.04))
		_rrect(o, s, rs - 0.02, belt - 0.1, 0.06, 0.09, 0.02, ink)
	else:
		_poly(o, s, [[tail, 0.7], [tail, belt + 0.04], [rs - 0.06, belt], [rs, roof], [re, roof], [re + 0.1, belt], [nose, belt + 0.04], [nose, 0.7]], ink)
		_poly(o, s, [[rs + 0.03, roof + 0.04], [re - 0.01, roof + 0.04], [re + 0.07, belt - 0.01], [rs - 0.02, belt - 0.01]], _hole())
	# Gold pin stripe along the side, a shine along the shoulder, lights.
	draw_rect(Rect2(_p(o, s, tail + 0.04, 0.59), Vector2(nose - tail - 0.08, 0.03) * s), acc)
	draw_rect(Rect2(_p(o, s, tail + 0.06, belt + 0.035), Vector2((nose - tail) * 0.55, 0.015) * s), _shine())
	draw_rect(Rect2(_p(o, s, nose - 0.03, belt + 0.06), Vector2(0.03, 0.035) * s), UI.FLASH if owned else _hole())
	draw_rect(Rect2(_p(o, s, tail, belt + 0.06), Vector2(0.025, 0.035) * s), UI.RED if owned else _hole())
	for wx in [0.25, 0.75]:
		draw_arc(_p(o, s, wx, 0.7), s * 0.125, PI, TAU, 12, Color(UI.INK, 0.8), maxf(1.0, s * 0.02), true)   # wheel arch
		draw_circle(_p(o, s, wx, 0.7), s * 0.11, _hole())
		draw_circle(_p(o, s, wx, 0.7), s * 0.075, ink)
		for sp in 5:
			var a := TAU * float(sp) / 5.0
			draw_line(_p(o, s, wx, 0.7), _p(o, s, wx, 0.7) + Vector2(cos(a), sin(a)) * s * 0.07, _hole(), maxf(1.0, s * 0.012))
		draw_circle(_p(o, s, wx, 0.7), s * 0.03, acc)


func _jet(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Seen from above; longer body and more sweep as the price rises.
	var len := 0.66 + 0.05 * float(k)
	var sweep := 0.1 + 0.035 * float(k)
	var x0 := 0.5 - len * 0.5
	var x1 := 0.5 + len * 0.5
	_poly(o, s, [[0.44, 0.46], [0.44 + sweep, 0.1], [0.56 + sweep, 0.1], [0.6, 0.46]], ink)
	_poly(o, s, [[0.44, 0.54], [0.44 + sweep, 0.9], [0.56 + sweep, 0.9], [0.6, 0.54]], ink)
	_poly(o, s, [[x0 + 0.02, 0.47], [x0 - 0.02, 0.3], [x0 + 0.07, 0.3], [x0 + 0.12, 0.47]], ink)
	_poly(o, s, [[x0 + 0.02, 0.53], [x0 - 0.02, 0.7], [x0 + 0.07, 0.7], [x0 + 0.12, 0.53]], ink)
	_poly(o, s, [[x0, 0.5], [x0 + 0.08, 0.44], [x1 - 0.08, 0.44], [x1, 0.5], [x1 - 0.08, 0.56], [x0 + 0.08, 0.56]], ink)
	# Gold cheat line down the body, cabin windows, dark cockpit at the nose.
	draw_rect(Rect2(_p(o, s, x0 + 0.1, 0.485), Vector2(len - 0.22, 0.03) * s), acc)
	var wn := 4 + k
	for i in wn:
		draw_rect(Rect2(_p(o, s, x0 + 0.16 + float(i) * (len - 0.34) / float(wn), 0.455), Vector2(0.018, 0.018) * s), _hole())
	draw_rect(Rect2(_p(o, s, x0 + 0.08, 0.445), Vector2(len - 0.2, 0.01) * s), _shine())
	_poly(o, s, [[x1 - 0.1, 0.47], [x1 - 0.04, 0.5], [x1 - 0.1, 0.53]], _hole())


func _yacht(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Hull with a gold trim, decks stacked higher on bigger boats, a sail on
	# the first two.
	_poly(o, s, [[0.02, 0.6], [0.98, 0.6], [0.86, 0.78], [0.12, 0.78]], ink)
	draw_rect(Rect2(_p(o, s, 0.06, 0.64), Vector2(0.86, 0.035) * s), acc)
	var decks: int = [0, 1, 1, 2, 2, 3][k]
	for d in decks:
		var w := 0.62 - 0.14 * float(d)
		var y := 0.6 - 0.09 * float(d)
		_poly(o, s, [[0.46 - w * 0.5, y], [0.46 + w * 0.5 + 0.06, y], [0.46 + w * 0.5, y - 0.08], [0.46 - w * 0.5 + 0.05, y - 0.08]], ink)
		for wx in range(int(w * 10.0)):
			draw_rect(Rect2(_p(o, s, 0.46 - w * 0.4 + float(wx) * 0.09, y - 0.06), Vector2(0.05, 0.035) * s), _hole())
	if k <= 1:
		draw_rect(Rect2(_p(o, s, 0.48, 0.1), Vector2(0.03, 0.5) * s), ink)
		_poly(o, s, [[0.52, 0.12], [0.52, 0.56], [0.84, 0.56]], ink)
	# Light along the gunwale, a wake behind and the hull's reflection.
	draw_rect(Rect2(_p(o, s, 0.06, 0.6), Vector2(0.88, 0.012) * s), _shine())
	for i in 3:
		draw_rect(Rect2(_p(o, s, 0.08 + i * 0.3, 0.88), Vector2(0.2, 0.02) * s), Color(UI.SUB, 0.5) if owned else Color(UI.SUB, 0.2))
	_poly(o, s, [[0.12, 0.8], [0.86, 0.8], [0.8, 0.84], [0.18, 0.84]], Color(ink, 0.18))
	draw_line(_p(o, s, 0.02, 0.76), _p(o, s, -0.04, 0.8), Color(UI.SUB, 0.5) if owned else Color(UI.SUB, 0.15), maxf(1.0, s * 0.015))


func _island(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Sea, a mound of a different shape, palms and (later ones) a villa.
	draw_rect(Rect2(_p(o, s, 0.0, 0.7), Vector2(1.0, 0.3) * s), UI.SKY if owned else UI.PANEL)
	var wid := 0.5 + 0.08 * float(k % 4)
	var hgt := 0.14 + 0.03 * float(k % 3)
	_poly(o, s, [[0.5 - wid * 0.5, 0.72], [0.5 - wid * 0.25, 0.72 - hgt], [0.5 + wid * 0.25, 0.72 - hgt * 1.1], [0.5 + wid * 0.5, 0.72]], ink)
	# Glints on the sea.
	for g2 in 4:
		draw_rect(Rect2(_p(o, s, 0.1 + g2 * 0.22, 0.8 + (g2 % 2) * 0.08), Vector2(0.08, 0.012) * s), Color(UI.TEXT, 0.35) if owned else Color(UI.SUB, 0.15))
	# Gold sand line where the island meets the sea.
	draw_rect(Rect2(_p(o, s, 0.5 - wid * 0.5, 0.7), Vector2(wid, 0.03) * s), acc)
	var palms: int = [1, 1, 2, 2, 3, 3][k]
	for p in palms:
		var px := 0.5 - wid * 0.3 + float(p) * 0.16
		var top := _p(o, s, px + 0.04, 0.3)
		draw_line(_p(o, s, px, 0.72 - hgt), top, ink, maxf(1.5, s * 0.04), true)
		for a in [-2.6, -1.9, -1.2, -0.5]:
			draw_line(top, top + Vector2(cos(a), sin(a) + 0.9) * s * 0.12, ink, maxf(1.5, s * 0.04), true)
	if k >= 3:
		_rrect(o, s, 0.58, 0.72 - hgt - 0.11, 0.18, 0.11, 0.02, _hole())
		draw_rect(Rect2(_p(o, s, 0.56, 0.72 - hgt - 0.13), Vector2(0.22, 0.03) * s), acc)


func _relic(o: Vector2, s: float, k: int, ink: Color, acc: Color) -> void:
	# Six finds from the old coast, each its own shape.
	var c := _p(o, s, 0.5, 0.5)
	match k:
		0:  # Iron Compass: a ring with a needle
			draw_circle(c, s * 0.38, ink)
			draw_circle(c, s * 0.3, _hole())
			_poly(o, s, [[0.5, 0.2], [0.56, 0.5], [0.5, 0.8], [0.44, 0.5]], acc)
			draw_circle(c, s * 0.04, ink)
		1:  # Salt Crown: five points on a band
			_poly(o, s, [[0.14, 0.72], [0.14, 0.36], [0.3, 0.55], [0.4, 0.26], [0.5, 0.5], [0.6, 0.26], [0.7, 0.55], [0.86, 0.36], [0.86, 0.72]], ink)
			for x in [0.3, 0.5, 0.7]:
				draw_circle(_p(o, s, x, 0.63), s * 0.05, acc)
		2:  # Tern Idol: a standing bird figure
			_poly(o, s, [[0.4, 0.88], [0.4, 0.45], [0.34, 0.3], [0.5, 0.12], [0.66, 0.3], [0.6, 0.45], [0.6, 0.88]], ink)
			_poly(o, s, [[0.6, 0.44], [0.9, 0.36], [0.62, 0.56]], acc)
			draw_circle(_p(o, s, 0.5, 0.26), s * 0.035, _hole())
		3:  # Sun Lens: a glass disc catching the sun
			draw_circle(c - Vector2(s * 0.06, s * 0.06), s * 0.32, ink)
			draw_circle(c - Vector2(s * 0.06, s * 0.06), s * 0.25, UI.SKY if owned else UI.PANEL)
			draw_circle(c - Vector2(s * 0.02, s * 0.02), s * 0.1, acc)
			draw_line(_p(o, s, 0.66, 0.66), _p(o, s, 0.9, 0.9), ink, s * 0.08)
		4:  # Drowned Bell: a bell with weed on its rim
			_poly(o, s, [[0.28, 0.72], [0.32, 0.4], [0.42, 0.22], [0.58, 0.22], [0.68, 0.4], [0.72, 0.72]], ink)
			draw_rect(Rect2(_p(o, s, 0.22, 0.72), Vector2(0.56, 0.07) * s), ink)
			draw_circle(_p(o, s, 0.5, 0.85), s * 0.05, ink)
			for x in [0.3, 0.46, 0.62]:
				draw_line(_p(o, s, x, 0.72), _p(o, s, x + 0.04, 0.92), acc, maxf(1.5, s * 0.035), true)
		_:  # First Ingot: a stepped bar with a stamp
			_poly(o, s, [[0.1, 0.72], [0.22, 0.42], [0.78, 0.42], [0.9, 0.72]], acc)
			_poly(o, s, [[0.22, 0.42], [0.28, 0.34], [0.84, 0.34], [0.78, 0.42]], ink)
			draw_circle(_p(o, s, 0.5, 0.58), s * 0.07, _hole())
	# A glint where the light catches the metal.
	if owned:
		draw_circle(_p(o, s, 0.36, 0.34), maxf(1.0, s * 0.025), Color(UI.FLASH, 0.8))
		draw_line(_p(o, s, 0.36, 0.28), _p(o, s, 0.36, 0.4), Color(UI.FLASH, 0.5), 1.0)
		draw_line(_p(o, s, 0.3, 0.34), _p(o, s, 0.42, 0.34), Color(UI.FLASH, 0.5), 1.0)
