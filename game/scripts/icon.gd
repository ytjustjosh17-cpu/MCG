class_name Icon
extends Control
## Small line icons drawn on a 24 x 24 grid, in the style of the designs.

@export var kind := "earn"
@export var color := UI.TEXT
@export var filled := false


func _init(k := "earn", c := UI.TEXT, side := 22.0) -> void:
	kind = k
	color = c
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_style(c: Color, f := false) -> void:
	color = c
	filled = f
	queue_redraw()


func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * (size.x / 24.0)


func _line(points: Array, w := 1.8) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(_p(p[0], p[1]))
	draw_polyline(pts, color, w * size.x / 24.0, true)


func _rect(x: float, y: float, w: float, h: float) -> void:
	var r := Rect2(_p(x, y), _p(w, h))
	if filled:
		draw_rect(r, color, true)
	else:
		draw_rect(r, color, false, 1.8 * size.x / 24.0)


func _fill(points: Array) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(_p(p[0], p[1]))
	draw_colored_polygon(pts, color)


func _draw() -> void:
	var s := size.x / 24.0
	match kind:
		"earn":
			_rect(7, 3, 10, 19)
			_rect(3, 12, 4, 10)
			_rect(17, 9, 4, 13)
		"business":
			if filled:
				draw_rect(Rect2(_p(3, 7), _p(18, 13)), color, true)
			else:
				draw_rect(Rect2(_p(3, 7), _p(18, 13)), color, false, 1.8 * s)
				_line([[3, 12], [21, 12]])
			_line([[9, 7], [9, 4], [15, 4], [15, 7]])
		"invest":
			var w := 2.6 if filled else 1.8
			_line([[3, 17], [9, 11], [13, 15], [21, 7]], w)
			_line([[15, 7], [21, 7], [21, 13]], w)
		"items":
			_rect(3.5, 3.5, 7, 7)
			_rect(13.5, 3.5, 7, 7)
			_rect(3.5, 13.5, 7, 7)
			_rect(13.5, 13.5, 7, 7)
		"profile":
			if filled:
				draw_circle(_p(12, 8), 4.5 * s, color)
				var body := PackedVector2Array()
				for i in range(17):
					var a := PI + PI * float(i) / 16.0
					body.append(_p(12, 21.5) + Vector2(cos(a), sin(a)) * 8.5 * s)
				draw_colored_polygon(body, color)
			else:
				draw_arc(_p(12, 8), 4 * s, 0, TAU, 32, color, 1.8 * s, true)
				draw_arc(_p(12, 21.5), 8 * s, PI, TAU, 24, color, 1.8 * s, true)
		"bolt":
			_fill([[13, 2], [5, 13], [11, 13], [10, 22], [19, 10], [13, 10]])
		"back":
			_line([[15, 5], [8, 12], [15, 19]], 2.4)
		"plus":
			_line([[12, 5], [12, 19]], 2.2)
			_line([[5, 12], [19, 12]], 2.2)
		"check":
			_line([[5, 12.5], [10, 17], [19, 7]], 2.4)
		"lock":
			draw_rect(Rect2(_p(5, 11), _p(14, 10)), color, false, 1.8 * s)
			draw_arc(_p(12, 11), 4 * s, PI, TAU, 16, color, 1.8 * s, true)
		"trophy":
			_line([[7, 4], [17, 4], [17, 9], [14, 13], [10, 13], [7, 9], [7, 4]])
			_line([[12, 13], [12, 18]])
			_line([[8, 20], [16, 20]])
		"list":
			_line([[4, 6], [20, 6]])
			_line([[4, 12], [20, 12]])
			_line([[4, 18], [14, 18]])
		"chevron":
			_line([[9, 5], [15, 12], [9, 19]], 2.2)
		"up":
			_fill([[12, 4], [21, 18], [3, 18]])
		"down":
			_fill([[12, 20], [21, 6], [3, 6]])
		"level":
			_line([[6, 13], [12, 7], [18, 13]], 2.0)
			_line([[6, 19], [12, 13], [18, 19]], 2.0)
		"dots":
			for x in [6.0, 12.0, 18.0]:
				draw_circle(_p(x, 12), 1.8 * s, color)
		_:
			draw_arc(_p(12, 12), 8 * s, 0, TAU, 32, color, 1.8 * s, true)
