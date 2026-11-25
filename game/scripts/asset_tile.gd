class_name AssetTile
extends Control
## A bold square badge with the ticker, in the company's or coin's colour.

var sym := ""
var col := UI.TEXT


func _init(s := "", side := 40.0) -> void:
	sym = s
	col = UI.asset_color(s)
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(UI.rounded_rect_poly(r, size.x * 0.16), col)
	# A cut corner gives each badge a slightly brutalist edge.
	var c := size.x * 0.28
	draw_colored_polygon(PackedVector2Array([Vector2(size.x - c, size.y), Vector2(size.x, size.y - c), Vector2(size.x, size.y)]), UI.PANEL)
	var f: Font = UI.SEMI
	var fs := int(size.x * 0.3)
	var w := f.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2((size.x - w) * 0.5, size.y * 0.5 + fs * 0.36), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK)
