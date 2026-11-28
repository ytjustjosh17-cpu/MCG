class_name AssetTile
extends Control
## A mark for a company or coin. Coins show their real logo (assets/coins, CC0);
## shares show their company's own made-up logo (assets/logos); anything
## without one falls back to a sector shape with its initial cut in.

var sym := ""
var col := UI.TEXT
var shape := "coin"
var cut := UI.PANEL   # colour behind the mark, used for cut-outs


func _init(s := "", side := 40.0) -> void:
	sym = s
	col = UI.asset_color(s)
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for st in Data.STOCKS:
		if st[0] == s:
			shape = st[4]


static var _logos := {}


static func logo(sym: String) -> Texture2D:
	## The coin's real logo (CC0 set in assets/coins), the company's own made-up
	## logo (assets/logos), or null if there isn't one.
	if not _logos.has(sym):
		_logos[sym] = null
		for path in ["res://assets/coins/%s.svg" % sym, "res://assets/logos/%s.svg" % sym]:
			if ResourceLoader.exists(path):
				_logos[sym] = load(path)
				break
	return _logos[sym]


func _draw() -> void:
	var w := size.x
	var c := size * 0.5
	var r := w * 0.36
	var tex := logo(sym)
	if tex != null:
		var d := r * 2.3
		draw_texture_rect(tex, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false)
		return
	match sym:
		"SHIB":
			# Orange disc with a simple dog face: two ears and a light muzzle.
			draw_colored_polygon(UI.circle_poly(c, r * 1.15, 40), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.2), c + Vector2(-r * 0.55, -r * 0.95), c + Vector2(-r * 0.15, -r * 0.45)]), UI.INK)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.75, -r * 0.2), c + Vector2(r * 0.55, -r * 0.95), c + Vector2(r * 0.15, -r * 0.45)]), UI.INK)
			draw_circle(c + Vector2(0, r * 0.3), r * 0.42, UI.SHIB_FACE)
			draw_circle(c + Vector2(0, r * 0.18), r * 0.12, UI.INK)
			return
		"PEPE":
			# Green disc with two big frog eyes.
			draw_colored_polygon(UI.circle_poly(c, r * 1.15, 40), col)
			for sx in [-1.0, 1.0]:
				draw_circle(c + Vector2(sx * r * 0.42, -r * 0.2), r * 0.34, UI.TEXT)
				draw_circle(c + Vector2(sx * r * 0.42 + r * 0.08, -r * 0.18), r * 0.15, UI.INK)
			draw_arc(c + Vector2(0, r * 0.25), r * 0.45, 0.2, PI - 0.2, 16, UI.INK, r * 0.12, true)
			return
	# Shares: a sector shape with the company's initial cut into it, like a logo.
	var poly := PackedVector2Array()
	match shape:
		"Energy":
			poly = UI.circle_poly(c, r * 1.1, 40)
		"Finance":
			poly = PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r * 0.25), c + Vector2(0, r * 1.15), c + Vector2(-r, r * 0.25)])
		"Tech":
			poly = UI.rounded_rect_poly(Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), r * 0.45)
		"Transport":
			poly = PackedVector2Array([c + Vector2(-r * 1.1, -r * 0.8), c + Vector2(r * 0.5, -r * 0.8), c + Vector2(r * 1.15, 0), c + Vector2(r * 0.5, r * 0.8), c + Vector2(-r * 1.1, r * 0.8)])
		"Retail":
			poly = UI.rounded_rect_poly(Rect2(c - Vector2(r, r * 0.9), Vector2(r * 2.0, r * 1.8)), r * 0.2)
		"Food":
			for k in 21:
				var a := PI + PI * float(k) / 20.0
				poly.append(c + Vector2(cos(a) * r * 1.1, -sin(a) * r * 1.1 * 0.95))
		"Industry":
			for k in 6:
				var a := TAU * float(k) / 6.0 + PI / 6.0
				poly.append(c + Vector2(cos(a), sin(a)) * r * 1.12)
		_:
			poly = UI.circle_poly(c, r, 40)
	# A soft drop shadow, the badge, then a sheen across its top half.
	var shadow := PackedVector2Array()
	for q in poly:
		shadow.append(q + Vector2(0, maxf(1.0, w * 0.035)))
	draw_colored_polygon(shadow, Color(UI.INK, 0.45))
	draw_colored_polygon(poly, col)
	for piece in Geometry2D.intersect_polygons(poly, UI.rect_poly(Rect2(Vector2.ZERO, Vector2(w, c.y - r * 0.15)))):
		if piece.size() >= 3:
			draw_colored_polygon(piece, Color(UI.TEXT, 0.12))
	var initial := sym.substr(0, 1)
	for st in Data.STOCKS:
		if st[0] == sym:
			initial = String(st[1]).substr(0, 1)
	var font: Font = UI.DISPLAY
	var fs := int(r * 1.35)
	var ly := c.y
	if shape == "Food":
		# The bowl shape is the lower half: the letter sits inside it.
		fs = int(r * 1.0)
		ly = c.y + r * 0.42
	var tw := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(c.x - tw.x * 0.5, ly + fs * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cut)
