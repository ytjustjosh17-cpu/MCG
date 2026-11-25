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


static func backdrop(ci: CanvasItem, rect: Rect2, clip: PackedVector2Array, sun_c: Vector2, sun_r: float, sun_col: Color, seed_v := 7) -> void:
	## Dusk sky: faint stars, the sun with sunset bands, a far skyline with a few
	## lit windows, and a power pylon with sagging cables.
	ci.draw_colored_polygon(clip, UI.SKY)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w := rect.size.x
	var h := rect.size.y
	var o := rect.position
	for i in int(w * h / 9000.0) + 6:
		var p := o + Vector2(rng.randf() * w, rng.randf() * h * 0.45)
		if p.distance_to(sun_c) > sun_r + 6.0:
			ci.draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(UI.TEXT, rng.randf_range(0.12, 0.35)), true)
	_fill(ci, UI.circle_poly(sun_c, sun_r, 96), clip, sun_col)
	# Sunset bands: gaps in the lower half of the sun that widen towards the ground.
	var band_y := sun_c.y + sun_r * 0.12
	var gap := maxf(1.5, sun_r * 0.025)
	while band_y < sun_c.y + sun_r:
		_fill(ci, UI.rect_poly(Rect2(sun_c.x - sun_r - 2.0, band_y, sun_r * 2.0 + 4.0, gap)), clip, UI.SKY)
		band_y += sun_r * 0.14
		gap *= 1.45
	# Far skyline, two layers.
	for layer in 2:
		var col := UI.HAZE if layer == 0 else UI.FAR
		var x := -rng.randf() * 20.0
		while x < w:
			var bw := rng.randf_range(0.06, 0.14) * w
			var bh := rng.randf_range(0.10, 0.26 if layer == 0 else 0.18) * h + layer * 0.0
			var r := Rect2(o + Vector2(x, h - bh), Vector2(bw, bh))
			_fill(ci, UI.rect_poly(r), clip, col)
			if rng.randf() < 0.3:
				_fill(ci, UI.rect_poly(Rect2(r.position + Vector2(bw * 0.45, -bh * 0.18), Vector2(1.5, bh * 0.18))), clip, col)
			if layer == 1:
				for k in rng.randi_range(0, 3):
					var wp := r.position + Vector2(rng.randf_range(3.0, maxf(4.0, bw - 6.0)), rng.randf_range(6.0, maxf(7.0, bh - 6.0)))
					var lit := rng.randf() < 0.25
					_fill(ci, UI.rect_poly(Rect2(wp, Vector2(3, 2))), clip, Color(UI.RED, 0.55) if lit else UI.HAZE)
			x += bw + rng.randf_range(0.0, 0.03) * w
	# Power pylon on the left with cables running off to the right (big pictures only).
	if w < 220.0:
		return
	var ph := h * 0.5
	var base := o + Vector2(w * 0.13, h - h * 0.02)
	var tips := pylon(ci, base, ph, clip)
	for t in tips:
		# Cables run off both edges, dipping between towers.
		_wire(ci, t, t + Vector2(w * 1.1, -h * 0.02), h * 0.08, clip, UI.INK, maxf(1.0, h * 0.006))
		_wire(ci, t + Vector2(-w * 0.5, -h * 0.01), t, h * 0.05, clip, UI.INK, maxf(1.0, h * 0.006))


static func draw_scene(ci: CanvasItem, rect: Rect2, kind: String, radius := 16.0, sun_r := 0.0, lit := 2) -> void:
	## Dusk backdrop and the silhouette, clipped to a rounded rect.
	var clip := UI.rounded_rect_poly(rect, radius)
	var r := sun_r if sun_r > 0.0 else rect.size.y * 0.62
	var sc := rect.position + Vector2(rect.size.x - r * 0.5, r * 0.28)
	backdrop(ci, rect, clip, sc, r, UI.RED, int(rect.size.x) + kind.length())
	var s := minf(rect.size.x / 150.0, (rect.size.y - 10.0) / 78.0)
	var o := rect.position + Vector2(rect.size.x - 124.0 * s - 6.0, rect.size.y - 74.0 * s)
	draw(ci, kind, o, s, lit)
	var ground := Rect2(rect.position + Vector2(0, rect.size.y - 4.0 * s), Vector2(rect.size.x, 4.0 * s + 1.0))
	_fill(ci, UI.rect_poly(ground), clip, UI.INK)


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
