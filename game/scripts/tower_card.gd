class_name TowerCard
extends Control
## The tap card: headquarters tower against the flat red sun. Scales to any size.
## Tap anywhere on the card (outside its buttons) to earn.

const COLS := 4
const RADIUS := 24.0

var _order: Array = []
var _rows := 0
var _flash_index := -1
var _flash_time := 0.0
var _float_count := 0
var _flicker_index := -1
var _flicker_time := 0.0
var _flicker_wait := 3.0
var _wave := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.changed.connect(queue_redraw)
	resized.connect(_reshape)


func _reshape() -> void:
	var g := _geo()
	_rows = maxi(1, int((size.y - g["top"] - 24.0) / g["pitch_y"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	_order = range(COLS * _rows)
	for i in range(_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = _order[i]
		_order[i] = _order[j]
		_order[j] = t
	queue_redraw()


func _geo() -> Dictionary:
	var w := size.x
	var h := size.y
	var tw := clampf(w * 0.34, 96.0, 170.0)
	var tx := w * 0.6 - tw / 2.0
	var top := h * 0.2
	var win_w := tw * 0.125
	return {"tw": tw, "tx": tx, "top": top, "win_w": win_w, "win_h": win_w * 0.72,
		"pitch_x": tw * 0.21, "pitch_y": win_w * 1.5, "pad": tw * 0.1}


func lit_count() -> int:
	var total := COLS * _rows
	return clampi((Game.level - 1) * 3 + Game.companies() * 2 + 2 + int(Game.level_progress() * 3.0), 1, total)


func _window_rect(i: int, g: Dictionary) -> Rect2:
	var col := i % COLS
	var row := i / COLS
	return Rect2(g["tx"] + g["pad"] + col * g["pitch_x"], g["top"] + 18.0 + row * g["pitch_y"], g["win_w"], g["win_h"])


func _fill_clipped(poly: PackedVector2Array, clip: PackedVector2Array, c: Color) -> void:
	for piece in Geometry2D.intersect_polygons(poly, clip):
		if piece.size() >= 3:
			draw_colored_polygon(piece, c)


func _line_clipped(a: Vector2, b: Vector2, clip: PackedVector2Array, c: Color, w: float) -> void:
	for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), clip):
		draw_polyline(piece, c, w, true)


func _draw() -> void:
	if size.x < 100.0 or size.y < 100.0 or _rows == 0:
		return
	var w := size.x
	var h := size.y
	var g := _geo()
	var clip := UI.rounded_rect_poly(Rect2(Vector2.ZERO, size), RADIUS)
	draw_colored_polygon(clip, UI.SKY)
	var sun_r := minf(w * 0.42, h * 0.34)
	var sun_col := UI.RED.lightened(0.12) if Game.boost_active() else UI.RED
	_fill_clipped(UI.circle_poly(Vector2(w * 0.78, h * 0.24), sun_r, 96), clip, sun_col)
	_line_clipped(Vector2(w * 0.25, -6), Vector2(w + 6, h * 0.5), clip, UI.INK, 1.4)
	_line_clipped(Vector2(w * 0.3, h + 6), Vector2(w + 6, h * 0.12), clip, UI.INK, 1.1)
	var tx: float = g["tx"]
	var tw: float = g["tw"]
	var top: float = g["top"]
	_fill_clipped(UI.rect_poly(Rect2(tx + tw * 0.15, top - tw * 0.12, tw * 0.3, tw * 0.12)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(tx, top, tw, h)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(tx + tw, top + 8.0, tw * 0.1, h)), clip, UI.SIDE)
	var lit := {}
	for k in range(mini(lit_count(), _order.size())):
		lit[_order[k]] = true
	for i in range(COLS * _rows):
		var r := _window_rect(i, g)
		if r.end.y > h - 14.0:
			continue
		var c := UI.WINDOW
		if lit.has(i):
			c = UI.RED
		if i == _flash_index and _flash_time > 0.0:
			c = UI.FLASH
		elif i == _flicker_index and _flicker_time > 0.0:
			c = UI.WINDOW if lit.has(i) else Color(UI.RED, 0.6)
		if _wave >= 0.0:
			var row_pos := float(i / COLS) / float(maxi(1, _rows))
			if absf((1.0 - row_pos) - _wave) < 0.12:
				c = UI.FLASH
		draw_rect(r, c, true)
	var nb := Rect2(w * 0.86, h * 0.68, w * 0.2, h * 0.4)
	_fill_clipped(UI.rect_poly(nb), clip, UI.WINDOW)
	_fill_clipped(UI.rect_poly(Rect2(nb.position + Vector2(10, 14), Vector2(8, 7))), clip, UI.RED)


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			queue_redraw()
	# Ambient life: now and then one window flickers. Off with Reduce Motion.
	if not Game.reduce_motion and is_visible_in_tree():
		_flicker_wait -= delta
		if _flicker_wait <= 0.0 and _rows > 0:
			_flicker_wait = randf_range(2.5, 6.0)
			_flicker_index = randi() % (COLS * _rows)
			_flicker_time = 0.35
			queue_redraw()
		if _flicker_time > 0.0:
			_flicker_time -= delta
			if _flicker_time <= 0.0:
				queue_redraw()
	if _wave >= 0.0:
		_wave += delta * 1.6
		if _wave > 1.2:
			_wave = -1.0
		queue_redraw()


func celebrate() -> void:
	## A wave of light runs up the tower (level up).
	if not Game.reduce_motion:
		_wave = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_tap(event.position)
		accept_event()


func _do_tap(pos: Vector2) -> void:
	var v := Game.tap()
	if _rows > 0:
		_flash_index = randi() % (COLS * _rows)
	_flash_time = 0.12
	queue_redraw()
	if Game.vibrate:
		Input.vibrate_handheld(18)
	if _float_count < 12:
		_spawn_float(pos, v)


func _spawn_float(pos: Vector2, v: float) -> void:
	if Motion.reduced():
		return  # no rising numbers with Reduce motion on
	var l := UI.label("+" + Game.money_short(v), 22, UI.TEXT, true)
	add_child(l)
	l.position = pos + Vector2(-30, -40)
	_float_count += 1
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)  # reduced-checked
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		_float_count -= 1
		l.queue_free())
