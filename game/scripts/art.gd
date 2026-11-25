class_name Art
extends RefCounted
## Flat silhouettes for businesses and properties, drawn on a 120 x 70 box
## (ground at y = 70). Lit windows use the brand red.

static func _poly(ci: CanvasItem, o: Vector2, s: float, pts: Array, c: Color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(o + Vector2(q[0], q[1]) * s)
	ci.draw_colored_polygon(p, c)


static func _rect(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), c, true)


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


static func draw(ci: CanvasItem, kind: String, o: Vector2, s: float, lit := 2) -> void:
	var ink := UI.INK
	var win := UI.WINDOW
	var red := UI.RED
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
			_car(ci, o, s * 0.55, 38 / 0.55 - 6, ink, red if lit > 0 else win)
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
		_:
			_rect(ci, o, s, 30, 20, 60, 50, ink)


static func draw_scene(ci: CanvasItem, rect: Rect2, kind: String, radius := 16.0, sun_r := 0.0, lit := 2) -> void:
	## Sky panel, cropped flat sun, power line and the silhouette, clipped to a rounded rect.
	var clip := UI.rounded_rect_poly(rect, radius)
	ci.draw_colored_polygon(clip, UI.SKY)
	var r := sun_r if sun_r > 0.0 else rect.size.y * 0.62
	var sun := UI.circle_poly(rect.position + Vector2(rect.size.x - r * 0.5, r * 0.28), r)
	for piece in Geometry2D.intersect_polygons(sun, clip):
		if piece.size() >= 3:
			ci.draw_colored_polygon(piece, UI.RED)
	var a := rect.position + Vector2(rect.size.x * 0.35, -4)
	var b := rect.position + Vector2(rect.size.x + 4, rect.size.y * 0.72)
	for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), clip):
		ci.draw_polyline(piece, UI.INK, 1.0, true)
	var s := minf(rect.size.x / 150.0, (rect.size.y - 10.0) / 78.0)
	var o := rect.position + Vector2(rect.size.x - 124.0 * s - 6.0, rect.size.y - 74.0 * s)
	draw(ci, kind, o, s, lit)
	var ground := Rect2(rect.position + Vector2(0, rect.size.y - 4.0 * s), Vector2(rect.size.x, 4.0 * s + 1.0))
	for piece in Geometry2D.intersect_polygons(UI.rect_poly(ground), clip):
		if piece.size() >= 3:
			ci.draw_colored_polygon(piece, UI.INK)


class Scene extends Control:
	## A Control that draws Art.draw_scene; use for headers and cards.
	var kind := "shop"
	var radius := 16.0
	var lit := 2

	func _init(k := "shop", r := 16.0) -> void:
		kind = k
		radius = r
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 20.0 or size.y < 20.0:
			return
		Art.draw_scene(self, Rect2(Vector2.ZERO, size), kind, radius, 0.0, lit)
