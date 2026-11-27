class_name HomePage
extends Page
## Inside your home (1.2): a room drawn for each home on the ladder, from a
## rented room to the island palace, with the window showing the real time of
## day. Items you own are on show: paintings on the wall, a watch on the side
## table, a car in the garage, models and relics on the shelf.

var _room: Room
var _sub: Label
var _shown: Label
var _shown_head: Control
var _shown_card: Control
var _grid: GridContainer
var _shown_key := "-"


func _init() -> void:
	super(String(Data.HOMES[Game.home][0]), true)


func build() -> void:
	_sub = UI.label("", 13, UI.SUB)
	body.add_child(_sub)
	var c := card()
	_room = Room.new()
	_room.custom_minimum_size = Vector2(0, 400)
	c.add_child(_room)
	# What's on show: a tidy two-column list, one set per cell.
	section("On show")
	_shown_head = body.get_child(body.get_child_count() - 1)
	var sc := card()
	_shown_card = sc.get_parent()
	var pad := padded(sc, 16, 0)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 4)
	pad.add_child(_grid)
	_shown = UI.label("Items you buy appear here.", 15, UI.SUB)
	_shown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_shown)


func refresh() -> void:
	if _room == null:
		return
	var h: Array = Data.HOMES[Game.home]
	_sub.text = "%s · home %d of %d" % [h[1], Game.home + 1, Data.HOMES.size()]
	var parts: Array = []
	for col in Game.collections():
		var n := Game.collection_count(String(col["id"]))
		if n > 0:
			parts.append([String(col["id"]), String(col["name"]), n])
	_shown.visible = parts.is_empty()
	_shown_head.visible = not parts.is_empty()
	_shown_card.visible = not parts.is_empty()
	var key := str(parts)
	if key != _shown_key:
		_shown_key = key
		for ch in _grid.get_children():
			ch.queue_free()
		for pt in parts:
			var cell := HBoxContainer.new()
			cell.custom_minimum_size = Vector2(0, 40)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_theme_constant_override("separation", 8)
			var art := ItemArt.new(pt[0], maxi(0, HomePage.best_item(pt[0])), 28.0)
			art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(art)
			var nm := UI.label(pt[1], 15)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			nm.clip_text = true
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.add_child(nm)
			var cnt := UI.label(str(pt[2]), 15, UI.SUB)
			cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cell.add_child(cnt)
			_grid.add_child(cell)
	_room.set_home(Game.home)


static func best_item(col: String) -> int:
	## The most valuable item you own in a collection, or -1.
	var c := Game.collection(col)
	if c.is_empty():
		return -1
	for i in range(c["items"].size() - 1, -1, -1):
		if Game.item_owned(col, i):
			return i
	return -1


class Room extends Control:
	## The drawn room; owned items sit on top as small ItemArt pictures.
	var tier := -1
	var _sig := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		resized.connect(_place_items)

	func set_home(t: int) -> void:
		var sig := "%d|%s" % [t, SkyTime.key()]
		for col in ["art", "watches", "cars", "jets", "yachts", "islands", "relics"]:
			sig += "|%d" % HomePage.best_item(col)
		if sig == _sig:
			return
		_sig = sig
		tier = t
		_place_items()
		queue_redraw()

	const SHELF_X := 0.35   # the display shelf: left edge and width, as shares of the room
	const SHELF_W := 0.36
	const SHELF_Y := 0.47

	func _floor_y() -> float:
		return size.y * 0.8

	func _place_items() -> void:
		for ch in get_children():
			ch.queue_free()
		if size.x < 50.0 or tier < 0:
			return
		var w := size.x
		var fy := _floor_y()
		# A painting on the wall, left of the window.
		var art := HomePage.best_item("art")
		if art >= 0:
			_add(ItemArt.new("art", art, 64.0), Vector2(w * 0.06, size.y * 0.16))
		# A watch on the side table (on the mantel once there is a fireplace).
		var watch := HomePage.best_item("watches")
		if watch >= 0:
			var wp := Vector2(w * 0.09, fy - 48.0)
			if tier >= 6:
				wp = Vector2(w * 0.05 + w * 0.11 - 15.0, size.y * 0.46 - 30.0)
			_add(ItemArt.new("watches", watch, 30.0), wp)
		# A car in the garage bay on the right (from the town house up).
		var car := HomePage.best_item("cars")
		if car >= 0:
			_add(ItemArt.new("cars", car, 78.0), Vector2(w * 0.76, fy - 42.0))
		# Models and relics on the display shelf.
		var x := w * SHELF_X + 6.0
		for col in ["jets", "yachts", "islands", "relics"]:
			var i := HomePage.best_item(col)
			if i >= 0:
				_add(ItemArt.new(col, i, 26.0), Vector2(x, size.y * SHELF_Y - 29.0))
				x += 30.0

	func _add(c: Control, pos: Vector2) -> void:
		c.position = pos
		add_child(c)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 50.0 or tier < 0:
			return
		var fy := _floor_y()
		var rich := float(tier) / float(Data.HOMES.size() - 1)   # 0 rented room .. 1 palace
		# Wall and floor.
		draw_rect(Rect2(Vector2.ZERO, size), UI.WINDOW if tier < 4 else UI.PANEL, true)
		draw_rect(Rect2(0, fy, w, h - fy), UI.SIDE, true)
		draw_rect(Rect2(0, fy, w, 3.0), UI.INK, true)
		# The window: a small sash at first, a glass wall in the penthouse,
		# arches in the villa and the palace.
		var win := Rect2(w * 0.38, h * 0.1, w * (0.2 + 0.3 * rich), fy - h * 0.18)
		if tier <= 1:
			win = Rect2(w * 0.5, h * 0.12, w * 0.22, h * 0.26)
		_view(win)
		if tier in [5, 8]:
			# Arches over each bay.
			var bays := 3
			var bw := win.size.x / float(bays)
			for b in bays:
				var c := Vector2(win.position.x + bw * (b + 0.5), win.position.y + bw * 0.5)
				draw_rect(Rect2(win.position.x + bw * b, win.position.y, bw, bw * 0.5), UI.PANEL, true)
				draw_circle(c, bw * 0.46, UI.SKY)
				draw_rect(Rect2(win.position.x + bw * b - 2.0, win.position.y, 4.0, win.size.y), UI.INK, true)
		else:
			var panes := 1 if tier <= 1 else (2 if tier <= 3 else 4)
			for p in range(1, panes):
				var px := win.position.x + win.size.x * float(p) / float(panes)
				draw_rect(Rect2(px - 1.5, win.position.y, 3.0, win.size.y), UI.INK, true)
			draw_rect(Rect2(win.position.x, win.position.y + win.size.y * 0.55, win.size.x, 2.0), UI.INK, true)
		draw_rect(win, UI.INK, false, 4.0)
		# A display shelf for models and relics: a back panel and two posts,
		# so the pieces stand on furniture, not in the window.
		var shelf := Rect2(w * SHELF_X, h * SHELF_Y - 36.0, w * SHELF_W, 36.0)
		draw_rect(shelf, UI.SIDE, true)
		draw_rect(Rect2(shelf.position.x, h * SHELF_Y, shelf.size.x, 4.0), UI.INK, true)
		draw_rect(Rect2(shelf.position.x, shelf.position.y, 3.0, 40.0), UI.INK, true)
		draw_rect(Rect2(shelf.end.x - 3.0, shelf.position.y, 3.0, 40.0), UI.INK, true)
		draw_rect(Rect2(shelf.position.x, shelf.position.y, shelf.size.x, 3.0), UI.INK, true)
		# Furniture, richer as you move up.
		if tier == 0:
			draw_rect(Rect2(w * 0.08, fy - 16.0, w * 0.34, 16.0), UI.TRACK, true)   # a mattress on the floor
			draw_line(Vector2(w * 0.3, 0), Vector2(w * 0.3, h * 0.2), UI.INK, 1.5)
			draw_circle(Vector2(w * 0.3, h * 0.2 + 5.0), 6.0, UI.FLASH)   # a bare bulb
		else:
			# Side table with the watch, then a sofa (longer in bigger homes).
			draw_rect(Rect2(w * 0.07, fy - 18.0, w * 0.12, 18.0), UI.INK, true)
			var sw := w * (0.28 + 0.12 * rich)
			var sx := w * 0.24
			draw_rect(Rect2(sx, fy - 30.0, sw, 30.0), UI.RAISED, true)
			draw_rect(Rect2(sx, fy - 46.0, sw, 18.0), UI.TRACK, true)
			draw_rect(Rect2(sx - 6.0, fy - 36.0, 8.0, 36.0), UI.TRACK, true)
			draw_rect(Rect2(sx + sw - 2.0, fy - 36.0, 8.0, 36.0), UI.TRACK, true)
			# A rug in front.
			draw_rect(Rect2(sx + sw * 0.1, fy + 10.0, sw * 0.8, 10.0), UI.HAZE.lerp(UI.TRACK, rich), true)   # red stays for the sun
		if tier >= 2:
			# A lamp, and a plant.
			draw_rect(Rect2(w * 0.68, fy - 60.0, 2.0, 60.0), UI.INK, true)
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.68 - 10.0, fy - 60.0), Vector2(w * 0.68 + 12.0, fy - 60.0), Vector2(w * 0.68 + 6.0, fy - 74.0), Vector2(w * 0.68 - 4.0, fy - 74.0)]), UI.FLASH if SkyTime.night() > 0.5 else UI.SUB)
			draw_rect(Rect2(w * 0.02, fy - 12.0, 14.0, 12.0), UI.INK, true)
			for k in 3:
				draw_circle(Vector2(w * 0.02 + 7.0 + (k - 1) * 6.0, fy - 20.0 - k * 4.0), 7.0, UI.HAZE)
		if tier >= 3:
			# The garage bay on the right, door open, for the car.
			draw_rect(Rect2(w * 0.73, h * 0.3, w * 0.27, fy - h * 0.3), UI.INK, true)
			for k in 4:
				draw_rect(Rect2(w * 0.73, h * 0.3 + k * 6.0, w * 0.27, 2.0), UI.SIDE, true)
		if tier >= 4:
			# A chandelier.
			var cx := w * 0.55
			draw_line(Vector2(cx, 0), Vector2(cx, h * 0.06), UI.INK, 1.5)
			for k in 5:
				draw_circle(Vector2(cx + (k - 2) * 9.0, h * 0.07 + absf(k - 2) * 2.0), 3.0, UI.FLASH)
		if tier >= 6:
			# A fireplace with a low fire.
			var fx := w * 0.05
			draw_rect(Rect2(fx, h * 0.46, w * 0.22, fy - h * 0.46), UI.TRACK, true)
			draw_rect(Rect2(fx + w * 0.04, h * 0.56, w * 0.14, fy - h * 0.56), UI.INK, true)
			draw_colored_polygon(PackedVector2Array([Vector2(fx + w * 0.07, fy), Vector2(fx + w * 0.11, fy - 22.0), Vector2(fx + w * 0.15, fy)]), UI.RED)
		if tier >= 7:
			# Gold trim along the ceiling.
			draw_rect(Rect2(0, 0, w, 4.0), UI.GOLD, true)

	func _view(r: Rect2) -> void:
		## What you see through the window: sky, the sun at its real height,
		## the city or the sea, and night drawn over it.
		draw_rect(r, UI.SKY, true)
		var sun := SkyTime.sun_center(r.size.x, r.size.y, Vector2(r.size.x * 0.7, r.size.y * 0.28))
		var sr := minf(r.size.x, r.size.y) * 0.22
		if sun.y + sr > 0.0:
			draw_circle(r.position + sun, sr, SkyTime.sun_colour())
		var sea := tier in [5, 8]
		var base := r.position.y + r.size.y
		if sea:
			draw_rect(Rect2(r.position.x, base - r.size.y * 0.3, r.size.x, r.size.y * 0.3), UI.FAR, true)
		elif tier == 7:
			# Above the clouds.
			for k in 3:
				draw_rect(Rect2(r.position.x, base - r.size.y * (0.12 + 0.06 * k), r.size.x, r.size.y * 0.06), Color(UI.TEXT, 0.12), true)
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = 90 + tier
			var x := r.position.x
			while x < r.end.x:
				var bw := r.size.x * rng.randf_range(0.08, 0.18)
				var bh := r.size.y * rng.randf_range(0.15, 0.45 if tier >= 4 else 0.6)
				draw_rect(Rect2(x, base - bh, minf(bw, r.end.x - x), bh), UI.FAR, true)
				x += bw + 2.0
		var n := SkyTime.night()
		if n > 0.0:
			draw_rect(r, Color(UI.INK, 0.4 * n), true)
		if SkyTime.weather() == "rain":
			for k in 9:
				var lx := r.position.x + r.size.x * (0.08 + 0.1 * k)
				draw_line(Vector2(lx, r.position.y + 6.0 + (k % 3) * 9.0), Vector2(lx - 2.0, r.position.y + 16.0 + (k % 3) * 9.0), Color(UI.SUB, 0.4), 1.0)
