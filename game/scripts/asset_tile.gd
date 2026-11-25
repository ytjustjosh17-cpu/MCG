class_name AssetTile
extends Control
## A bare mark for a company or coin: a small geometric shape in its own colour,
## no box behind it. Shares use a shape per sector; coins use a notched disc.

var sym := ""
var col := UI.TEXT
var shape := "coin"
var seed_i := 0
var cut := UI.PANEL   # colour behind the mark, used for cut-outs


func _init(s := "", side := 40.0) -> void:
	sym = s
	col = UI.asset_color(s)
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in s.to_utf8_buffer():
		seed_i += c
	for st in Data.STOCKS:
		if st[0] == s:
			shape = st[4]


func _draw() -> void:
	var w := size.x
	var c := size * 0.5
	var r := w * 0.36
	match shape:
		"Energy":
			# Sun on a horizon: a disc cut by a band.
			draw_colored_polygon(UI.circle_poly(c, r, 40), col)
			draw_rect(Rect2(c.x - r - 1.0, c.y + r * 0.25, r * 2.0 + 2.0, r * 0.22), cut)
		"Finance":
			# Three columns, middle one tallest.
			var bw := r * 0.5
			for i in 3:
				var hh := r * (1.3 if i == 1 else 0.95 + 0.1 * float(seed_i % 3))
				draw_rect(Rect2(c.x - r + i * (bw + r * 0.25), c.y + r - hh, bw, hh), col)
		"Tech":
			# Two offset squares.
			draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 1.25, r * 1.25)), col)
			draw_rect(Rect2(c - Vector2(r * 0.25, r * 0.25), Vector2(r * 1.25, r * 1.25)), col.darkened(0.35))
		"Transport":
			# A forward chevron.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(-r * 0.2, -r), c + Vector2(r, 0),
				c + Vector2(-r * 0.2, r), c + Vector2(-r, r), c + Vector2(r * 0.15, 0)]), col)
		"Retail":
			# A thick ring.
			draw_arc(c, r * 0.78, 0.0, TAU, 40, col, r * 0.45, true)
		"Food":
			# A half disc, like a bowl.
			var pts := PackedVector2Array()
			for i in 21:
				var a := PI * float(i) / 20.0
				pts.append(c + Vector2(cos(a) * r, sin(a) * r - r * 0.25))
			draw_colored_polygon(pts, col)
		"Industry":
			# Stepped blocks.
			var st := r * 2.0 / 3.0
			for i in 3:
				draw_rect(Rect2(c.x - r + i * st, c.y + r - st * (i + 1), st, st * (i + 1)), col)
		_:
			# Coin: a disc with a notch, rotated per coin.
			draw_colored_polygon(UI.circle_poly(c, r, 40), col)
			var ang := float(seed_i % 8) * TAU / 8.0
			draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.55, r * 0.3, cut)
