class_name TowerCard
extends Control
## The tap card: headquarters tower against the flat red sun.
## Tap anywhere on the card (outside its buttons) to earn.

const DESIGN_W := 358.0
const COLS := [210.0, 230.0, 250.0, 270.0]
const ROWS := 9
const RADIUS := 22.0

var _order: Array = []
var _flash_index := -1
var _flash_time := 0.0
var _float_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	_order = range(COLS.size() * ROWS)
	for i in range(_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = _order[i]
		_order[i] = _order[j]
		_order[j] = t
	Game.changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func lit_count() -> int:
	return clampi((Game.level - 1) * 4 + 2 + int(Game.level_progress() * 4.0), 1, COLS.size() * ROWS)


func _window_rect(i: int, dx: float) -> Rect2:
	var col := i % COLS.size()
	var row := i / COLS.size()
	return Rect2(COLS[col] + dx, 54.0 + row * 18.0, 12.0, 9.0)


func _card_poly() -> PackedVector2Array:
	return UI.rounded_rect_poly(Rect2(Vector2.ZERO, size), RADIUS)


func _fill_clipped(poly: PackedVector2Array, clip: PackedVector2Array, c: Color) -> void:
	for piece in Geometry2D.intersect_polygons(poly, clip):
		if piece.size() >= 3:
			draw_colored_polygon(piece, c)


func _line_clipped(a: Vector2, b: Vector2, clip: PackedVector2Array, c: Color, w: float) -> void:
	for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), clip):
		draw_polyline(piece, c, w, true)


func _draw() -> void:
	if size.x < 100.0 or size.y < 100.0:
		return
	var clip := _card_poly()
	var dx := size.x - DESIGN_W
	draw_colored_polygon(clip, UI.SKY)
	# The sun: flat, no glow.
	var sun_col := UI.RED
	if Game.boost_active():
		sun_col = UI.RED.lightened(0.12)
	_fill_clipped(UI.circle_poly(Vector2(268.0 + dx, 72.0), 92.0), clip, sun_col)
	# Power lines.
	_line_clipped(Vector2(140 + dx, -6), Vector2(366 + dx, 118), clip, UI.INK, 1.2)
	_line_clipped(Vector2(150 + dx, size.y + 4), Vector2(366 + dx, 30), clip, UI.INK, 1.0)
	# Tower.
	_fill_clipped(UI.rect_poly(Rect2(214 + dx, 26, 30, 14)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(200 + dx, 38, 96, size.y)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(296 + dx, 46, 10, size.y)), clip, UI.SIDE)
	# Windows.
	var lit := lit_count()
	var lit_set := {}
	for k in range(lit):
		lit_set[_order[k]] = true
	for i in range(COLS.size() * ROWS):
		var r := _window_rect(i, dx)
		if r.end.y > size.y - 4.0:
			continue
		var c := UI.WINDOW
		if lit_set.has(i):
			c = UI.RED
		if i == _flash_index and _flash_time > 0.0:
			c = UI.FLASH
		draw_rect(r, c, true)
	# Neighbour block.
	_fill_clipped(UI.rect_poly(Rect2(314 + dx, size.y - 66, 60, 80)), clip, UI.WINDOW)
	_fill_clipped(UI.rect_poly(Rect2(324 + dx, size.y - 52, 8, 7)), clip, UI.RED)


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_tap(event.position)
		accept_event()


func _do_tap(pos: Vector2) -> void:
	var v := Game.tap()
	_flash_index = randi() % (COLS.size() * ROWS)
	_flash_time = 0.12
	queue_redraw()
	if Game.vibrate:
		Input.vibrate_handheld(18)
	if _float_count < 12:
		_spawn_float(pos, v)


func _spawn_float(pos: Vector2, v: float) -> void:
	var l := UI.label("+" + Game.money(v), 17, UI.TEXT, true)
	add_child(l)
	l.position = pos + Vector2(-28, -34)
	_float_count += 1
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 56.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		_float_count -= 1
		l.queue_free())
