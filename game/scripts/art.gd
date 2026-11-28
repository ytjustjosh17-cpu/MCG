class_name Art
extends RefCounted
## Flat silhouettes for businesses and properties, drawn on a 120 x 70 box
## (ground at y = 70). Lit windows use the brand red.

static func _poly(ci: CanvasItem, o: Vector2, s: float, pts: Array, c: Color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(o + Vector2(q[0], q[1]) * s)
	ci.draw_colored_polygon(p, c)


# Detail for windows (frames, sills, glow) once a picture is big enough to
# show it. draw() sets these; small list thumbnails stay clean silhouettes.
static var _detail := false
static var _lit_col := Color(0, 0, 0, 0)


static func _rect(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	var r := Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s)
	if not _detail or r.size.x < 5.0 or r.size.y < 3.5:
		ci.draw_rect(r, c, true)
		return
	if c == _lit_col:
		# A lit window: a soft glow round it, the pane, a brighter top pane.
		ci.draw_rect(r.grow(maxf(1.5, s * 1.2)), Color(c, 0.18), true)
		ci.draw_rect(r, c, true)
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.38)), c.lerp(UI.FLASH, 0.28), true)
	elif c == UI.INK and r.size.x >= 28.0 and r.size.y >= 22.0:
		# A big wall: faint floor lines and a darker band down the far side,
		# so it reads as a building with depth, not a flat slab.
		ci.draw_rect(r, c, true)
		var fy := r.position.y + maxf(6.0, s * 7.0)
		while fy < r.end.y - 2.0:
			ci.draw_rect(Rect2(r.position.x + 1.0, fy, r.size.x - 2.0, 1.0), Color(UI.HAZE, 0.32), true)
			fy += maxf(6.0, s * 7.0)
		ci.draw_rect(Rect2(r.end.x - r.size.x * 0.1, r.position.y, r.size.x * 0.1, r.size.y), Color(UI.SIDE, 0.55), true)
		return
	elif c == UI.WINDOW:
		ci.draw_rect(r, c, true)
		# A faint reflection of the sky across the top corner.
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.45, maxf(1.0, r.size.y * 0.22))), Color(UI.HAZE, 0.55), true)
	else:
		ci.draw_rect(r, c, true)
		return
	# Frame: a thin dark mullion on wider windows, and a lighter sill below.
	if r.size.x >= 9.0:
		ci.draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 0.5, r.position.y, 1.0, r.size.y), Color(UI.INK, 0.55), true)
	ci.draw_rect(Rect2(r.position.x - 1.0, r.end.y, r.size.x + 2.0, maxf(1.0, s * 0.8)), Color(UI.HAZE, 0.7), true)


static func _circle(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, r: float, c: Color) -> void:
	ci.draw_circle(o + Vector2(x, y) * s, r * s, c)


static func _car(ci: CanvasItem, o: Vector2, s: float, x: float, ink: Color, glass: Color, taxi := false) -> void:
	_poly(ci, o, s, [[x + 2, 60], [x + 6, 50], [x + 12, 44], [x + 40, 44], [x + 50, 52], [x + 62, 54], [x + 64, 62], [x + 2, 62]], ink)
	_rect(ci, o, s, x + 14, 47, 11, 6, glass)
	_rect(ci, o, s, x + 28, 47, 12, 6, glass)
	_circle(ci, o, s, x + 14, 63, 6, ink)
	_circle(ci, o, s, x + 50, 63, 6, ink)
	_circle(ci, o, s, x + 14, 63, 2.4, glass)
	_circle(ci, o, s, x + 50, 63, 2.4, glass)
	if taxi:
		_rect(ci, o, s, x + 22, 39, 10, 5, ink)


static func draw(ci: CanvasItem, kind: String, o: Vector2, s: float, lit := 2, red := UI.RED, flat := Color(0, 0, 0, 0)) -> void:
	## `flat`: draw the whole silhouette in one colour (used for the sun's rim light).
	var ink := UI.INK
	var win := UI.WINDOW
	var keep_detail := _detail
	if flat.a > 0.0:
		ink = flat
		win = flat
		red = flat
		_detail = false
	else:
		_detail = s >= 0.9
		_lit_col = red
	_draw_kind(ci, kind, o, s, lit, red, ink, win)
	_detail = keep_detail


static func _draw_kind(ci: CanvasItem, kind: String, o: Vector2, s: float, lit: int, red: Color, ink: Color, win: Color) -> void:
	match kind:
		"shop":
			_rect(ci, o, s, 20, 26, 80, 44, ink)
			_poly(ci, o, s, [[16, 26], [104, 26], [98, 18], [22, 18]], ink)
			_rect(ci, o, s, 28, 36, 26, 18, red if lit > 0 else win)
			_rect(ci, o, s, 66, 36, 22, 34, win)
		"taxi":
			_car(ci, o, s, 26, ink, win, true)
		"ship":
			_rect(ci, o, s, 14, 30, 64, 32, ink)
			_poly(ci, o, s, [[78, 62], [78, 38], [94, 38], [104, 50], [104, 62]], ink)
			_rect(ci, o, s, 84, 41, 9, 8, win)
			for wx in [26, 44, 70, 96]:
				_circle(ci, o, s, wx, 63, 6, ink)
				_circle(ci, o, s, wx, 63, 2.4, win)
			_rect(ci, o, s, 20, 36, 10, 6, red if lit > 0 else win)
		"factory":
			_poly(ci, o, s, [[10, 70], [10, 40], [30, 28], [30, 40], [50, 28], [50, 40], [70, 28], [70, 40], [96, 40], [96, 70]], ink)
			_rect(ci, o, s, 80, 10, 9, 30, ink)
			_rect(ci, o, s, 18, 50, 10, 8, red if lit > 0 else win)
			_rect(ci, o, s, 38, 50, 10, 8, win)
			_rect(ci, o, s, 58, 50, 10, 8, red if lit > 1 else win)
		"crane":
			_rect(ci, o, s, 30, 8, 6, 62, ink)
			_rect(ci, o, s, 10, 8, 96, 5, ink)
			_rect(ci, o, s, 86, 13, 1.5, 22, ink)
			_rect(ci, o, s, 82, 35, 9, 6, ink)
			_rect(ci, o, s, 50, 40, 48, 30, ink)
			_rect(ci, o, s, 58, 48, 9, 7, red if lit > 0 else win)
			_rect(ci, o, s, 76, 48, 9, 7, win)
		"dealer":
			_rect(ci, o, s, 8, 30, 104, 40, ink)
			_rect(ci, o, s, 14, 36, 92, 22, win)
			_car(ci, o + Vector2(0, 19.0) * s, s * 0.55, 38 / 0.55 - 6, ink, red if lit > 0 else win)   # in the showroom, not on its roof
		"screen":
			_rect(ci, o, s, 22, 14, 34, 56, ink)
			_rect(ci, o, s, 64, 24, 34, 46, ink)
			for yy in [22, 32, 42, 52]:
				_rect(ci, o, s, 28, yy, 22, 3, win)
			for yy in [32, 42, 52]:
				_rect(ci, o, s, 70, yy, 22, 3, win)
			_rect(ci, o, s, 28, 22, 6, 3, red if lit > 0 else win)
		"bank":
			_poly(ci, o, s, [[10, 30], [60, 10], [110, 30]], ink)
			_rect(ci, o, s, 12, 64, 96, 6, ink)
			for cx in [18, 38, 58, 78, 96]:
				_rect(ci, o, s, cx, 34, 8, 30, ink)
			_rect(ci, o, s, 54, 22, 12, 5, red if lit > 0 else win)
		"stadium":
			_poly(ci, o, s, [[6, 70], [12, 40], [108, 40], [114, 70]], ink)
			_rect(ci, o, s, 20, 46, 80, 6, win)
			for lx in [16, 100]:
				_rect(ci, o, s, lx, 8, 3, 32, ink)
				_rect(ci, o, s, lx - 5, 6, 13, 6, red if lit > 0 else win)
		"rig":
			_rect(ci, o, s, 10, 44, 100, 8, ink)
			for lx in [20, 50, 80, 98]:
				_rect(ci, o, s, lx, 52, 5, 18, ink)
			_poly(ci, o, s, [[38, 44], [52, 6], [56, 6], [70, 44]], ink)
			_rect(ci, o, s, 76, 30, 26, 14, ink)
			_rect(ci, o, s, 80, 34, 6, 5, red if lit > 0 else win)
		"plane":
			_poly(ci, o, s, [[8, 42], [18, 36], [96, 36], [112, 40], [96, 46], [18, 46]], ink)
			_poly(ci, o, s, [[48, 44], [70, 44], [54, 66], [44, 66]], ink)
			_poly(ci, o, s, [[18, 36], [26, 36], [16, 18], [10, 18]], ink)
			for wx in range(30, 92, 8):
				_rect(ci, o, s, wx, 39, 4, 3, win)
			_rect(ci, o, s, 96, 39, 6, 3, red if lit > 0 else win)
		"house":
			_poly(ci, o, s, [[24, 34], [60, 10], [96, 34]], ink)
			_rect(ci, o, s, 30, 34, 60, 36, ink)
			_rect(ci, o, s, 38, 42, 12, 10, red if lit > 0 else win)
			_rect(ci, o, s, 70, 42, 12, 10, win)
			_rect(ci, o, s, 54, 52, 12, 18, win)
		"flats":
			_rect(ci, o, s, 30, 8, 60, 62, ink)
			for yy in range(14, 64, 10):
				for xx in [36, 50, 64, 78]:
					_rect(ci, o, s, xx, yy, 7, 5, win)
			_rect(ci, o, s, 50, 24, 7, 5, red if lit > 0 else win)
			_rect(ci, o, s, 78, 44, 7, 5, red if lit > 1 else win)
		"tower":
			_rect(ci, o, s, 44, 0, 34, 70, ink)
			_rect(ci, o, s, 56, -8, 10, 8, ink)
			_rect(ci, o, s, 82, 30, 22, 40, ink)
			for yy in range(6, 66, 8):
				_rect(ci, o, s, 50, yy, 6, 4, win)
				_rect(ci, o, s, 66, yy, 6, 4, win)
			_rect(ci, o, s, 66, 22, 6, 4, red if lit > 0 else win)
			_rect(ci, o, s, 50, 46, 6, 4, red if lit > 1 else win)
		"resort":
			_rect(ci, o, s, 8, 40, 104, 30, ink)
			_rect(ci, o, s, 30, 26, 60, 14, ink)
			_rect(ci, o, s, 90, 14, 3, 30, ink)
			_poly(ci, o, s, [[78, 16], [92, 10], [106, 16], [92, 14]], ink)
			for xx in range(14, 108, 12):
				_rect(ci, o, s, xx, 48, 6, 5, win)
			_rect(ci, o, s, 38, 30, 8, 5, red if lit > 0 else win)
		"van":
			_rect(ci, o, s, 14, 30, 70, 32, ink)
			_poly(ci, o, s, [[84, 62], [84, 38], [98, 38], [108, 50], [108, 62]], ink)
			_rect(ci, o, s, 24, 36, 40, 12, red if lit > 0 else win)
			_poly(ci, o, s, [[20, 36], [68, 36], [72, 30], [16, 30]], ink)
			_rect(ci, o, s, 22, 26, 50, 3, ink)
			_rect(ci, o, s, 88, 41, 9, 7, win)
			for wx in [30, 94]:
				_circle(ci, o, s, wx, 63, 6, ink)
				_circle(ci, o, s, wx, 63, 2.4, win)
		"gym":
			_rect(ci, o, s, 12, 30, 96, 40, ink)
			_rect(ci, o, s, 12, 24, 96, 6, ink)
			for wx in [18, 40, 62, 84]:
				_rect(ci, o, s, wx, 36, 18, 22, win)
			_rect(ci, o, s, 40, 36, 18, 22, red if lit > 0 else win)
			# A big dumbbell sign on the roof.
			_rect(ci, o, s, 44, 12, 32, 3, ink)
			_rect(ci, o, s, 40, 7, 6, 13, ink)
			_rect(ci, o, s, 74, 7, 6, 13, ink)
		"hotel":
			_rect(ci, o, s, 34, 2, 52, 68, ink)
			_rect(ci, o, s, 22, 50, 76, 20, ink)
			_rect(ci, o, s, 52, -6, 16, 8, ink)
			for yy in range(8, 46, 7):
				for xx in [40, 50, 60, 70]:
					_rect(ci, o, s, xx, yy, 6, 3, win)
			_rect(ci, o, s, 60, 15, 6, 3, red if lit > 0 else win)
			_rect(ci, o, s, 40, 36, 6, 3, red if lit > 1 else win)
			_rect(ci, o, s, 50, 58, 20, 12, red if lit > 0 else win)
		"mast":
			_poly(ci, o, s, [[54, 70], [60, 2], [66, 70]], ink)
			_rect(ci, o, s, 59, -8, 2, 12, ink)
			for yy in [18, 34, 50]:
				_rect(ci, o, s, 50, yy, 20, 2, ink)
			_circle(ci, o, s, 60, -8, 2.5, red if lit > 0 else win)
			_rect(ci, o, s, 74, 42, 34, 28, ink)
			_rect(ci, o, s, 80, 48, 22, 10, win)
			_rect(ci, o, s, 80, 48, 8, 10, red if lit > 1 else win)
			_circle(ci, o, s, 92, 36, 6, ink)
		"mine":
			_poly(ci, o, s, [[40, 70], [50, 10], [56, 10], [66, 70]], ink)
			_rect(ci, o, s, 44, 6, 18, 6, ink)
			_circle(ci, o, s, 53, 9, 7, ink)
			_circle(ci, o, s, 53, 9, 3, win)
			_rect(ci, o, s, 70, 40, 38, 30, ink)
			_poly(ci, o, s, [[8, 70], [22, 52], [36, 70]], ink)
			_rect(ci, o, s, 76, 48, 8, 6, red if lit > 0 else win)
			_rect(ci, o, s, 92, 48, 8, 6, win)
			_rect(ci, o, s, 64, 30, 30, 3, ink)
		"rocket":
			_rect(ci, o, s, 52, 14, 14, 56, ink)
			_poly(ci, o, s, [[52, 14], [59, 0], [66, 14]], ink)
			_poly(ci, o, s, [[52, 56], [44, 70], [52, 70]], ink)
			_poly(ci, o, s, [[66, 56], [74, 70], [66, 70]], ink)
			_circle(ci, o, s, 59, 26, 3, red if lit > 0 else win)
			# Launch tower beside it.
			_rect(ci, o, s, 80, 6, 6, 64, ink)
			for yy in range(10, 66, 10):
				_rect(ci, o, s, 66, yy, 14, 2, ink)
			_rect(ci, o, s, 86, 6, 10, 3, ink)
			_circle(ci, o, s, 83, 4, 2, red if lit > 1 else win)
		"fusion":
			# A domed reactor between two cooling towers.
			for tx in [10, 82]:
				_poly(ci, o, s, [[tx, 70], [tx + 4, 40], [tx + 2, 22], [tx + 22, 22], [tx + 20, 40], [tx + 24, 70]], ink)
			_rect(ci, o, s, 34, 46, 48, 24, ink)
			_circle(ci, o, s, 58, 46, 22, ink)
			_rect(ci, o, s, 52, 54, 12, 8, red if lit > 0 else win)
			_circle(ci, o, s, 58, 30, 3, red if lit > 1 else win)
		"orbital":
			# A ring dock high up, tethered to a base station.
			_rect(ci, o, s, 56, 18, 3, 40, ink)
			_rect(ci, o, s, 30, 58, 56, 12, ink)
			_rect(ci, o, s, 40, 4, 36, 6, ink)
			_rect(ci, o, s, 34, 10, 6, 10, ink)
			_rect(ci, o, s, 76, 10, 6, 10, ink)
			_rect(ci, o, s, 52, 6, 12, 2, red if lit > 0 else win)
			_rect(ci, o, s, 44, 62, 10, 5, win)
			_rect(ci, o, s, 62, 62, 10, 5, red if lit > 1 else win)
		"lighthouse":
			# A tall light on a rock, with a keeper's house.
			_poly(ci, o, s, [[30, 70], [38, 60], [86, 60], [96, 70]], ink)
			_poly(ci, o, s, [[46, 60], [50, 14], [62, 14], [66, 60]], ink)
			_rect(ci, o, s, 48, 6, 16, 8, red if lit > 0 else win)
			_poly(ci, o, s, [[46, 6], [56, 0], [66, 6]], ink)
			_rect(ci, o, s, 70, 46, 18, 14, ink)
			_rect(ci, o, s, 76, 50, 5, 5, win)
		"observatory":
			# A dome with its slit open, on a stepped base.
			_rect(ci, o, s, 22, 52, 76, 18, ink)
			_rect(ci, o, s, 32, 40, 56, 12, ink)
			_circle(ci, o, s, 60, 40, 24, ink)
			_poly(ci, o, s, [[56, 16], [64, 16], [64, 36], [56, 36]], red if lit > 0 else win)
			_rect(ci, o, s, 30, 58, 8, 6, win)
			_rect(ci, o, s, 82, 58, 8, 6, win)
		"skyport":
			# A tower with a landing pad on top and a craft arriving.
			_rect(ci, o, s, 46, 22, 26, 48, ink)
			_rect(ci, o, s, 34, 18, 50, 5, ink)
			for yy in [30, 42, 54]:
				_rect(ci, o, s, 52, yy, 6, 6, win)
				_rect(ci, o, s, 62, yy, 6, 6, red if lit > 1 and yy == 42 else win)
			_poly(ci, o, s, [[86, 8], [104, 8], [108, 12], [82, 12]], ink)
			_circle(ci, o, s, 59, 16, 2, red if lit > 0 else win)
		"terrace":
			_poly(ci, o, s, [[8, 30], [112, 30], [104, 20], [16, 20]], ink)
			_rect(ci, o, s, 8, 30, 104, 40, ink)
			for i in 4:
				var xx := 14 + i * 26
				_rect(ci, o, s, xx, 38, 9, 9, win)
				_rect(ci, o, s, xx + 12, 50, 7, 20, win)
				_rect(ci, o, s, xx + 18, 12, 4, 8, ink)
			_rect(ci, o, s, 40, 38, 9, 9, red if lit > 0 else win)
		"cottage":
			_poly(ci, o, s, [[22, 38], [52, 14], [82, 38]], ink)
			_rect(ci, o, s, 26, 38, 52, 32, ink)
			_rect(ci, o, s, 64, 10, 6, 16, ink)
			_rect(ci, o, s, 34, 46, 10, 10, red if lit > 0 else win)
			_rect(ci, o, s, 52, 50, 10, 20, win)
			# Tree beside it.
			_rect(ci, o, s, 96, 46, 3, 24, ink)
			_circle(ci, o, s, 97, 40, 11, ink)
		"loft":
			_rect(ci, o, s, 10, 22, 100, 48, ink)
			_poly(ci, o, s, [[10, 22], [30, 12], [50, 22], [70, 12], [90, 22], [110, 12], [110, 22]], ink)
			for xx in range(16, 106, 16):
				_rect(ci, o, s, xx, 30, 10, 14, win)
				_rect(ci, o, s, xx, 50, 10, 14, win)
			_rect(ci, o, s, 48, 30, 10, 14, red if lit > 0 else win)
			_rect(ci, o, s, 80, 50, 10, 14, red if lit > 1 else win)
		"granary":
			_rect(ci, o, s, 20, 30, 42, 40, ink)
			_poly(ci, o, s, [[16, 30], [41, 10], [66, 30]], ink)
			for i in 3:
				_rect(ci, o, s, 72 + i * 13, 16, 11, 54, ink)
				_circle(ci, o, s, 77.5 + i * 13, 16, 5.5, ink)
			_rect(ci, o, s, 34, 40, 14, 12, red if lit > 0 else win)
		"villa":
			_rect(ci, o, s, 14, 40, 92, 30, ink)
			_rect(ci, o, s, 40, 22, 56, 18, ink)
			_rect(ci, o, s, 36, 20, 64, 3, ink)
			_rect(ci, o, s, 46, 27, 44, 9, win)
			_rect(ci, o, s, 20, 48, 30, 12, red if lit > 0 else win)
			_rect(ci, o, s, 60, 48, 40, 12, win)
			_rect(ci, o, s, 2, 64, 30, 6, win)
		"offices":
			_rect(ci, o, s, 22, 10, 40, 60, ink)
			_rect(ci, o, s, 66, 26, 40, 44, ink)
			for yy in range(16, 66, 6):
				_rect(ci, o, s, 26, yy, 32, 2, win)
			for yy in range(32, 66, 6):
				_rect(ci, o, s, 70, yy, 32, 2, win)
			_rect(ci, o, s, 26, 28, 14, 2, red if lit > 0 else win)
			_rect(ci, o, s, 82, 44, 14, 2, red if lit > 1 else win)
		"spire":
			_poly(ci, o, s, [[40, 70], [50, 6], [60, -14], [70, 6], [80, 70]], ink)
			_rect(ci, o, s, 59, -24, 2, 12, ink)
			for yy in range(14, 66, 8):
				_rect(ci, o, s, 54, yy, 12, 2, win)
			_rect(ci, o, s, 54, 30, 12, 2, red if lit > 0 else win)
			_circle(ci, o, s, 60, -24, 2, red)
		"arena":
			_poly(ci, o, s, [[6, 70], [10, 44], [30, 32], [90, 32], [110, 44], [114, 70]], ink)
			for xx in range(16, 108, 8):
				_rect(ci, o, s, xx, 48, 3, 18, win)
			_rect(ci, o, s, 30, 28, 60, 3, red if lit > 0 else win)
		"sphere":
			_rect(ci, o, s, 56, 40, 8, 30, ink)
			_circle(ci, o, s, 60, 28, 24, ink)
			for yy in [18, 26, 34]:
				_rect(ci, o, s, 42, yy, 36, 2, win)
			_rect(ci, o, s, 54, 26, 12, 2, red if lit > 0 else win)
			_rect(ci, o, s, 30, 64, 60, 6, ink)
		"island":
			_poly(ci, o, s, [[4, 70], [24, 54], [96, 54], [116, 70]], ink)
			_rect(ci, o, s, 40, 38, 40, 16, ink)
			_rect(ci, o, s, 46, 42, 10, 6, red if lit > 0 else win)
			_rect(ci, o, s, 62, 42, 12, 6, win)
			for px in [20, 96]:
				_poly(ci, o, s, [[px, 54], [px + 2, 30], [px + 4, 54]], ink)
				_poly(ci, o, s, [[px - 10, 32], [px + 2, 26], [px + 14, 32], [px + 2, 30]], ink)
		_:
			_rect(ci, o, s, 30, 20, 60, 50, ink)


static func _fill(ci: CanvasItem, poly: PackedVector2Array, clip: PackedVector2Array, c: Color) -> void:
	for piece in Geometry2D.intersect_polygons(poly, clip):
		if piece.size() >= 3:
			ci.draw_colored_polygon(piece, c)


static func _wire(ci: CanvasItem, a: Vector2, b: Vector2, sag: float, clip: PackedVector2Array, c: Color, w: float) -> void:
	## A cable hanging between two points (a shallow curve, lowest in the middle).
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		pts.append(a.lerp(b, t) + Vector2(0, sag * 4.0 * t * (1.0 - t)))
	for piece in Geometry2D.intersect_polyline_with_polygon(pts, clip):
		ci.draw_polyline(piece, c, w, true)


static func pylon(ci: CanvasItem, base: Vector2, h: float, clip: PackedVector2Array) -> Array:
	## A lattice electricity pylon standing on `base`. Returns the three cable points.
	var c := UI.INK
	var bw := h * 0.32
	var tw := h * 0.07
	var top := base - Vector2(0, h)
	var l0 := base - Vector2(bw / 2.0, 0)
	var r0 := base + Vector2(bw / 2.0, 0)
	var l1 := top - Vector2(tw / 2.0, 0)
	var r1 := top + Vector2(tw / 2.0, 0)
	var lw := maxf(1.0, h * 0.012)
	var segs: Array = [[l0, l1], [r0, r1]]
	# Cross bracing up the body.
	var n := 6
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var a0 := l0.lerp(l1, t0)
		var b0 := r0.lerp(r1, t0)
		var a1 := l0.lerp(l1, t1)
		var b1 := r0.lerp(r1, t1)
		segs.append([a0, b1])
		segs.append([b0, a1])
		segs.append([a1, b1])
	# Two cross arms, joined to the frame by braces, with hanging insulators.
	var tips: Array = []
	for k in 2:
		var t := 0.1 + k * 0.17
		var y := top.y + h * t
		var lb := l1.lerp(l0, t)
		var rb := r1.lerp(r0, t)
		var half := h * (0.17 - k * 0.03)
		var la := Vector2(top.x - half, y)
		var ra := Vector2(top.x + half, y)
		segs.append([la, ra])
		segs.append([la, Vector2(lb.x, y - h * 0.05)])
		segs.append([ra, Vector2(rb.x, y - h * 0.05)])
		for e in [la, ra]:
			segs.append([e, e + Vector2(0, h * 0.04)])
			tips.append(e + Vector2(0, h * 0.04))
	segs.append([top, top - Vector2(0, h * 0.06)])
	for sgm in segs:
		for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([sgm[0], sgm[1]]), clip):
			ci.draw_polyline(piece, c, lw, true)
	return tips


# Each kind gets its own setting so no two pictures look alike.
# sun: [x, y, size] as shares of the picture; sky: "city", "dense", "cranes",
# "hills", "flat" (open land) or "none"; ground: "street", "water", "runway", "field".
const SCENES := {
	"shop": {"sun": [0.88, 0.2, 0.62], "sky": "city", "ground": "street", "pylon": true},
	"van": {"sun": [0.2, 0.35, 0.5], "sky": "city", "ground": "street", "pylon": false},
	"taxi": {"sun": [0.75, 0.45, 0.55], "sky": "dense", "ground": "street", "pylon": true},
	"ship": {"sun": [0.5, 0.55, 0.45], "sky": "cranes", "ground": "water", "pylon": false},
	"factory": {"sun": [0.3, 0.3, 0.55], "sky": "city", "ground": "field", "pylon": true},
	"crane": {"sun": [0.15, 0.25, 0.5], "sky": "cranes", "ground": "field", "pylon": false},
	"dealer": {"sun": [0.85, 0.35, 0.5], "sky": "city", "ground": "street", "pylon": false},
	"gym": {"sun": [0.25, 0.2, 0.42], "sky": "dense", "ground": "street", "pylon": false},
	"screen": {"sun": [0.55, 0.12, 0.3], "sky": "dense", "ground": "street", "pylon": false},
	"hotel": {"sun": [0.62, 0.42, 0.8], "sky": "none", "ground": "water", "pylon": false},
	"mast": {"sun": [0.45, 0.62, 0.7], "sky": "hills", "ground": "field", "pylon": false},
	"bank": {"sun": [0.5, 0.3, 0.6], "sky": "dense", "ground": "street", "pylon": false},
	"stadium": {"sun": [0.12, 0.5, 0.55], "sky": "city", "ground": "field", "pylon": false},
	"mine": {"sun": [0.8, 0.4, 0.75], "sky": "hills", "ground": "field", "pylon": true},
	"rig": {"sun": [0.4, 0.6, 0.6], "sky": "none", "ground": "water", "pylon": false},
	"plane": {"sun": [0.2, 0.22, 0.35], "sky": "flat", "ground": "runway", "pylon": false},
	"rocket": {"sun": [0.3, 0.55, 0.9], "sky": "hills", "ground": "field", "pylon": false},
	"house": {"sun": [0.82, 0.3, 0.55], "sky": "city", "ground": "street", "pylon": true},
	"terrace": {"sun": [0.2, 0.25, 0.45], "sky": "city", "ground": "street", "pylon": true},
	"cottage": {"sun": [0.75, 0.55, 0.6], "sky": "hills", "ground": "field", "pylon": false},
	"flats": {"sun": [0.85, 0.25, 0.6], "sky": "dense", "ground": "street", "pylon": false},
	"loft": {"sun": [0.5, 0.2, 0.4], "sky": "cranes", "ground": "street", "pylon": false},
	"granary": {"sun": [0.82, 0.5, 0.55], "sky": "hills", "ground": "field", "pylon": true},
	"villa": {"sun": [0.75, 0.5, 0.65], "sky": "none", "ground": "water", "pylon": false},
	"offices": {"sun": [0.2, 0.3, 0.5], "sky": "dense", "ground": "street", "pylon": false},
	"tower": {"sun": [0.85, 0.22, 0.6], "sky": "dense", "ground": "street", "pylon": false},
	"spire": {"sun": [0.5, 0.35, 0.75], "sky": "dense", "ground": "street", "pylon": false},
	"arena": {"sun": [0.15, 0.4, 0.5], "sky": "city", "ground": "field", "pylon": false},
	"sphere": {"sun": [0.7, 0.3, 0.7], "sky": "dense", "ground": "water", "pylon": false},
	"resort": {"sun": [0.25, 0.55, 0.6], "sky": "none", "ground": "water", "pylon": false},
	"island": {"sun": [0.5, 0.58, 0.7], "sky": "none", "ground": "water", "pylon": false},
	"fusion": {"sun": [0.72, 0.32, 0.7], "sky": "hills", "ground": "field", "pylon": true},
	"orbital": {"sun": [0.25, 0.5, 0.95], "sky": "flat", "ground": "field", "pylon": false},
	"lighthouse": {"sun": [0.78, 0.5, 0.6], "sky": "none", "ground": "water", "pylon": false},
	"observatory": {"sun": [0.3, 0.35, 0.6], "sky": "hills", "ground": "field", "pylon": false},
	"skyport": {"sun": [0.65, 0.25, 0.5], "sky": "dense", "ground": "street", "pylon": false},
}


static func backdrop(ci: CanvasItem, rect: Rect2, clip: PackedVector2Array, sun_c: Vector2, sun_r: float, sun_col: Color, seed_v := 7, opt := {}, red := UI.RED) -> void:
	## Dusk sky: the sun with a soft glow, a far skyline (or hills, or nothing),
	## low mist, the ground, and on some pictures a pylon with hanging cables.
	ci.draw_colored_polygon(clip, UI.SKY)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w := rect.size.x
	var h := rect.size.y
	var o := rect.position
	var sky: String = opt.get("sky", "city")
	var ground: String = opt.get("ground", "street")
	var gh := h * 0.14 if ground == "water" else 0.0
	# Mist low down, behind the sun so it stays clean.
	for i in 5:
		var y := h * (0.62 + i * 0.08)
		_fill(ci, UI.rect_poly(Rect2(o + Vector2(0, y), Vector2(w, h - y))), clip, Color(UI.HAZE, 0.10))
	# Soft glow round the sun, then the sun itself (finer steps on big
	# pictures, so the glow is smooth rather than banded).
	var steps := 10 if rect.size.x >= 220.0 else 4
	for i in steps:
		var k2 := float(steps - i) / float(steps)
		_fill(ci, UI.circle_poly(sun_c, sun_r * (1.0 + 0.3 * k2), 96), clip, Color(sun_col, 0.2 / float(steps)))
	_fill(ci, UI.circle_poly(sun_c, sun_r, 96), clip, sun_col)
	var base_y := h - gh
	var hero := w >= 220.0   # small thumbnails stay simple; big pictures get the detail
	if hero:
		# Thin cloud bands drifting across the sun, low in the sky.
		for k in (2 if opt.get("clouds", false) else 0):   # off by default: thin bands read as stray bars
			var cy := sun_c.y + sun_r * (0.25 + 0.32 * k)
			# Short, soft wisps well inside the sun's face: long full-width
			# bands read as stray bars running to the edge of the picture.
			var cw := sun_r * (1.0 - k * 0.35)
			var cx := sun_c.x - cw * (0.62 - 0.2 * k)
			var ch := maxf(2.0, h * 0.012)
			var band := UI.rounded_rect_poly(Rect2(cx, cy, cw, ch), ch * 0.5)
			for piece in Geometry2D.intersect_polygons(band, UI.circle_poly(sun_c, sun_r * 0.92, 96)):
				_fill(ci, piece, clip, Color(UI.SKY, 0.6))
		# A few birds far off.
		for k in 3:
			var bp := o + Vector2(w * rng.randf_range(0.1, 0.6), h * rng.randf_range(0.1, 0.32))
			var bs := h * rng.randf_range(0.012, 0.02)
			var bird := PackedVector2Array([bp + Vector2(-bs * 1.6, -bs * 0.6), bp, bp + Vector2(bs * 1.6, -bs * 0.6)])
			for piece in Geometry2D.intersect_polyline_with_polygon(bird, clip):
				ci.draw_polyline(piece, Color(UI.INK, 0.7), 1.2, true)
	match sky:
		"hills":
			for layer in 2:
				var pts := PackedVector2Array()
				pts.append(o + Vector2(-4, base_y))
				var n := 7
				for i in n + 1:
					var x := w * i / float(n)
					var y := base_y - h * rng.randf_range(0.08, 0.22 if layer == 0 else 0.14)
					pts.append(o + Vector2(x, y))
				pts.append(o + Vector2(w + 4, base_y))
				_fill(ci, pts, clip, UI.HAZE if layer == 0 else UI.FAR)
		"city", "dense", "cranes":
			var tall := 0.38 if sky == "dense" else 0.26
			for layer in 2:
				var col := UI.HAZE if layer == 0 else UI.FAR
				var x := -rng.randf() * 20.0
				while x < w:
					var bw := rng.randf_range(0.05, 0.12 if sky == "dense" else 0.14) * w
					var bh := rng.randf_range(0.10, tall if layer == 0 else tall * 0.7) * h
					var r := Rect2(o + Vector2(x, base_y - bh), Vector2(bw, bh))
					_fill(ci, UI.rect_poly(r), clip, col)
					if rng.randf() < 0.3:
						_fill(ci, UI.rect_poly(Rect2(r.position + Vector2(bw * 0.45, -bh * 0.18), Vector2(1.5, bh * 0.18))), clip, col)
					if hero:
						# Roof units: a plant box, sometimes a water tank on legs.
						var ux := r.position.x + bw * rng.randf_range(0.1, 0.55)
						_fill(ci, UI.rect_poly(Rect2(ux, r.position.y - h * 0.015, bw * 0.28, h * 0.015)), clip, col)
						if rng.randf() < 0.35:
							var tx2 := r.position.x + bw * 0.68
							_fill(ci, UI.rect_poly(Rect2(tx2, r.position.y - h * 0.035, bw * 0.2, h * 0.02)), clip, col)
							_fill(ci, UI.rect_poly(Rect2(tx2 + 1.0, r.position.y - h * 0.015, 1.0, h * 0.015)), clip, col)
						if layer == 1 and bw > 10.0:
							# A faint grid of floors on the nearer row.
							var fy2 := r.position.y + h * 0.03
							while fy2 < base_y - 3.0:
								var fx := r.position.x + 2.0
								while fx < r.end.x - 3.0:
									var lit2 := rng.randf() < 0.12
									_fill(ci, UI.rect_poly(Rect2(fx, fy2, 2.0, 1.5)), clip, Color(red, 0.5) if lit2 else Color(UI.HAZE, 0.8))
									fx += 5.0
								fy2 += h * 0.03
					if layer == 1:
						for k in rng.randi_range(0, 3):
							var wp := r.position + Vector2(rng.randf_range(3.0, maxf(4.0, bw - 6.0)), rng.randf_range(6.0, maxf(7.0, bh - 6.0)))
							var lit := rng.randf() < 0.25
							_fill(ci, UI.rect_poly(Rect2(wp, Vector2(3, 2))), clip, Color(red, 0.55) if lit else UI.HAZE)
					x += bw + rng.randf_range(0.0, 0.03) * w
			if sky == "cranes":
				for k in 2:
					var cx := w * (0.15 + k * 0.45 + rng.randf() * 0.1)
					var ch := h * rng.randf_range(0.45, 0.6)
					var top := o + Vector2(cx, base_y - ch)
					_fill(ci, UI.rect_poly(Rect2(top, Vector2(maxf(2.0, w * 0.012), ch))), clip, UI.FAR)
					_fill(ci, UI.rect_poly(Rect2(top + Vector2(-w * 0.12, 0), Vector2(w * 0.26, maxf(2.0, h * 0.015)))), clip, UI.FAR)
					_fill(ci, UI.rect_poly(Rect2(top + Vector2(w * 0.11, 0), Vector2(1.0, ch * 0.3))), clip, UI.FAR)
		"flat":
			_fill(ci, UI.rect_poly(Rect2(o + Vector2(0, base_y - h * 0.05), Vector2(w, h * 0.05))), clip, UI.FAR)
	match ground:
		"water":
			var wr := Rect2(o + Vector2(0, base_y), Vector2(w, gh + 1.0))
			_fill(ci, UI.rect_poly(wr), clip, UI.FAR)
			# The sun's reflection: broken red lines on the water.
			var ry := base_y + 3.0
			var k := 0
			while ry < h - 2.0:
				var half := sun_r * (0.55 - k * 0.08) * rng.randf_range(0.7, 1.0)
				if half > 2.0:
					_fill(ci, UI.rect_poly(Rect2(Vector2(sun_c.x - half, o.y + ry), Vector2(half * 2.0, 1.5))), clip, Color(red, 0.45))
				ry += maxf(3.0, gh * 0.18)
				k += 1
			if hero:
				# Ripples: short light dashes scattered across the water.
				for q in 18:
					var rp := o + Vector2(rng.randf() * w, base_y + 2.0 + rng.randf() * (gh - 3.0))
					_fill(ci, UI.rect_poly(Rect2(rp, Vector2(rng.randf_range(4.0, 10.0), 1.0))), clip, Color(UI.HAZE, 0.9))
				# The shoreline: a darker band where the land meets the water.
				_fill(ci, UI.rect_poly(Rect2(o + Vector2(0, base_y), Vector2(w, 2.0))), clip, Color(UI.INK, 0.5))
		"runway":
			var rr := Rect2(o + Vector2(0, h - h * 0.08), Vector2(w, h * 0.08))
			_fill(ci, UI.rect_poly(rr), clip, UI.INK)
			var lx := 6.0
			while lx < w:
				ci.draw_rect(Rect2(o + Vector2(lx, h - h * 0.05), Vector2(3, 1.5)), Color(UI.FLASH, 0.55), true)
				lx += w * 0.06
	if not bool(opt.get("pylon", true)) or w < 220.0:
		return
	# Power pylon with cables running off both sides.
	var ph := h * 0.5
	var px: float = opt.get("pylon_x", 0.13)
	var base := o + Vector2(w * px, h - h * 0.02)
	var tips := pylon(ci, base, ph, clip)
	for t in tips:
		_wire(ci, t, t + Vector2(w * 1.1, -h * 0.02), h * 0.08, clip, UI.INK, maxf(1.0, h * 0.006))
		_wire(ci, t + Vector2(-w * 0.5, -h * 0.01), t, h * 0.05, clip, UI.INK, maxf(1.0, h * 0.006))


static func draw_scene(ci: CanvasItem, rect: Rect2, kind: String, radius := 16.0, sun_r := 0.0, lit := 2, seed_key := "", muted := false) -> void:
	## The kind's own backdrop and its silhouette, clipped to a rounded rect.
	## Muted: a quieter sun and windows for small list pictures, so a list of
	## ten rows is not ten red suns (the full red stays on big hero art).
	var red := MUTED_RED if muted else UI.RED
	var clip := UI.rounded_rect_poly(rect, radius)
	var opt: Dictionary = SCENES.get(kind, SCENES["shop"])
	var sun: Array = opt["sun"]
	var sd := hash(seed_key if seed_key != "" else kind)
	var nudge := RandomNumberGenerator.new()
	nudge.seed = sd
	# The seed moves the sun a little, so two flats or two towers still differ.
	var sx := clampf(float(sun[0]) + (nudge.randf() - 0.5) * 0.16, 0.08, 0.92) if seed_key != "" else float(sun[0])
	var sy := clampf(float(sun[1]) + (nudge.randf() - 0.5) * 0.12, 0.08, 0.7) if seed_key != "" else float(sun[1])
	var sz := float(sun[2]) * (nudge.randf_range(0.88, 1.12) if seed_key != "" else 1.0)
	var r := sun_r if sun_r > 0.0 else rect.size.y * sz
	var sc := rect.position + Vector2(rect.size.x * sx, rect.size.y * sy)
	# Pylon on the left, clear of the building.
	var o2 := opt.duplicate()
	o2["pylon_x"] = 0.13   # left: the building always stands on the right
	backdrop(ci, rect, clip, sc, r, red, sd, o2, red)
	var s := minf(rect.size.x / 150.0, (rect.size.y - 10.0) / 78.0)
	if kind == "taxi":
		s *= 0.72   # a car is small next to buildings: full size it filled the sky and hit the cables
	var o := rect.position + Vector2(rect.size.x - 124.0 * s - 6.0, rect.size.y - 74.0 * s)
	if String(opt.get("ground", "")) == "water":
		o.y -= rect.size.y * 0.06
	if s >= 0.6:
		# Rim light: the silhouette once more, nudged towards the sun in a warm
		# tint, so the edges facing the sun catch its light.
		var bc := o + Vector2(60.0, 40.0) * s
		var toward := (sc - bc).normalized() * clampf(s * 0.5, 1.0, 2.0)   # a thin edge, never a second outline
		draw(ci, kind, o + toward, s, lit, red, Color(red.lerp(UI.FLASH, 0.2), 0.62))
	draw(ci, kind, o, s, lit, red)
	if String(opt.get("ground", "")) != "water":
		var ground := Rect2(rect.position + Vector2(0, rect.size.y - 4.0 * s), Vector2(rect.size.x, 4.0 * s + 1.0))
		_fill(ci, UI.rect_poly(ground), clip, UI.INK)
		if s >= 0.9:
			# A kerb catching the light along the top of the ground.
			_fill(ci, UI.rect_poly(Rect2(ground.position, Vector2(ground.size.x, 1.0))), clip, Color(UI.HAZE, 0.9))


# The sun in small list pictures: red sunk into the teal sky.
static var MUTED_RED: Color = UI.RED.lerp(UI.SKY, 0.5)


class Scene extends Control:
	## A Control that draws Art.draw_scene; use for headers and cards.
	var kind := "shop"
	var radius := 16.0
	# Redraw only when something really changes (pages refresh often).
	var lit := 2:
		set(v):
			if v != lit:
				lit = v
				queue_redraw()
	var seed_id := "":   # e.g. the company or property name, so look-alikes differ
		set(v):
			if v != seed_id:
				seed_id = v
				queue_redraw()
	var muted := false:   # list thumbnails: a quieter sun (see draw_scene)
		set(v):
			if v != muted:
				muted = v
				queue_redraw()

	var _life: Control

	func _init(k := "shop", r := 16.0) -> void:
		kind = k
		radius = r
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		resized.connect(_sync_life)

	func _sync_life() -> void:
		## Big hero pictures get a little life on top (birds, a car, a boat).
		if size.x >= 240.0 and size.y >= 100.0 and _life == null:
			_life = Art.Life.new(self)
			add_child(_life)

	func _draw() -> void:
		if size.x < 20.0 or size.y < 20.0:
			return
		Art.draw_scene(self, Rect2(Vector2.ZERO, size), kind, radius, 0.0, lit, seed_id, muted)


class Life extends Control:
	## Small moving things over a hero picture, drawn on their own layer at
	## 8 frames a second so the picture underneath is never redrawn. Nothing
	## moves with Less motion on, or while the picture is off screen.
	const FPS := 8.0
	var _scene
	var _t := 0.0
	var _acc := 0.0

	func _init(sc) -> void:
		_scene = sc
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		clip_contents = true
		_t = float(hash(String(sc.seed_id) + String(sc.kind)) % 1000)

	func _still() -> bool:
		## Less motion on? Looked up at run time: this file must not name the
		## Game autoload (tests load Art before autoloads exist).
		var g := get_tree().root.get_node_or_null("Game") if is_inside_tree() else null
		return g == null or bool(g.get("reduce_motion"))

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or _still():
			return
		_t += delta
		_acc += delta
		if _acc >= 1.0 / FPS:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		if _still():
			return
		var w := size.x
		var h := size.y
		var rad: float = _scene.radius
		var opt: Dictionary = Art.SCENES.get(String(_scene.kind), Art.SCENES["shop"])
		var s := minf(w / 150.0, (h - 10.0) / 78.0)
		# Two birds crossing the sky, wings beating.
		for i in 2:
			var span := w + 60.0
			var x := fmod(_t * (10.0 + 4.0 * i) + i * span * 0.5, span) - 30.0
			var y := h * (0.16 + 0.07 * i) + sin(_t * 0.8 + i) * 3.0
			var flap := 0.6 if int(_t * 4.0 + i) % 2 == 0 else -0.1
			var bs := 3.2 + i
			draw_polyline(PackedVector2Array([Vector2(x - bs * 1.6, y - bs * flap), Vector2(x, y), Vector2(x + bs * 1.6, y - bs * flap)]), Color(UI.INK, 0.75), 1.3, true)
		var ground := String(opt.get("ground", ""))
		if ground == "street" or ground == "runway":
			# Now and then a car passes along the street, headlights on.
			var cyc := 11.0
			var p := fmod(_t, cyc) / cyc
			if p < 0.55:
				var x := -40.0 + (w + 80.0) * (p / 0.55)
				var y := h - 4.0 * s
				var cw := 22.0 * maxf(0.8, s * 0.6)
				var ch := cw * 0.32
				var a := clampf(minf(x - rad, w - rad - x) / 20.0, 0.0, 1.0)
				if a > 0.0:
					draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x, y - ch * 0.6), Vector2(x + cw * 0.25, y - ch), Vector2(x + cw * 0.7, y - ch), Vector2(x + cw, y - ch * 0.5), Vector2(x + cw, y)]), Color(UI.INK, a))
					# A lit roof line and wheels, so it reads as a car and not a stray blob.
					draw_line(Vector2(x + cw * 0.25, y - ch), Vector2(x + cw * 0.7, y - ch), Color(UI.SUB, 0.55 * a), 1.0)
					for wx in [x + cw * 0.22, x + cw * 0.78]:
						draw_circle(Vector2(wx, y), ch * 0.22, Color(UI.INK, a))
						draw_circle(Vector2(wx, y), ch * 0.09, Color(UI.SUB, 0.6 * a))
					draw_rect(Rect2(x + cw - 2.0, y - ch * 0.45, 2.0, 2.0), Color(UI.FLASH, a), true)
					draw_rect(Rect2(x + cw, y - ch * 0.45, 10.0, 2.0), Color(UI.FLASH, 0.25 * a), true)
		elif ground == "water":
			# A small boat drifting slowly across.
			var span2 := w + 80.0
			var bx := fmod(_t * 6.0, span2) - 40.0
			var by := h - h * 0.07
			var a2 := clampf(minf(bx - rad, w - rad - bx) / 20.0, 0.0, 1.0)
			if a2 > 0.0:
				draw_colored_polygon(PackedVector2Array([Vector2(bx, by), Vector2(bx + 18.0, by), Vector2(bx + 14.0, by + 4.0), Vector2(bx + 3.0, by + 4.0)]), Color(UI.INK, a2))
				draw_rect(Rect2(bx + 6.0, by - 12.0, 1.2, 12.0), Color(UI.INK, a2), true)
				draw_colored_polygon(PackedVector2Array([Vector2(bx + 7.5, by - 12.0), Vector2(bx + 7.5, by - 2.0), Vector2(bx + 15.0, by - 2.0)]), Color(UI.INK, a2))
				draw_rect(Rect2(bx - 4.0, by + 5.0, 26.0, 1.0), Color(UI.HAZE, 0.8 * a2), true)

