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
var _beacon_on := true


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


func _draw() -> void:
	if size.x < 100.0 or size.y < 100.0 or _rows == 0:
		return
	var w := size.x
	var h := size.y
	var g := _geo()
	var clip := UI.rounded_rect_poly(Rect2(Vector2.ZERO, size), RADIUS)
	var sun_r := minf(w * 0.42, h * 0.34)
	var sun_col := UI.RED.lightened(0.12) if Game.boost_active() else UI.RED
	Art.backdrop(self, Rect2(Vector2.ZERO, size), clip, Vector2(w * 0.78, h * 0.24), sun_r, sun_col, 4401)
	var tx: float = g["tx"]
	var tw: float = g["tw"]
	var top: float = g["top"]
	# Roof: plant room, water tank on legs, antenna with a red light.
	_fill_clipped(UI.rect_poly(Rect2(tx + tw * 0.15, top - tw * 0.12, tw * 0.3, tw * 0.12)), clip, UI.INK)
	var tank := Rect2(tx + tw * 0.62, top - tw * 0.16, tw * 0.18, tw * 0.1)
	_fill_clipped(UI.rect_poly(tank), clip, UI.INK)
	for lx in [tank.position.x + 2.0, tank.end.x - 4.0]:
		_fill_clipped(UI.rect_poly(Rect2(lx, tank.end.y, 2.0, tw * 0.06)), clip, UI.INK)
	var mast_x := tx + tw * 0.3
	var mast_top := top - tw * 0.55
	_fill_clipped(UI.rect_poly(Rect2(mast_x - 1.0, mast_top, 2.5, tw * 0.45)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(mast_x - 5.0, mast_top + tw * 0.12, 11.0, 2.0)), clip, UI.INK)
	var beacon_on := Game.reduce_motion or fmod(Time.get_ticks_msec() / 1000.0, 2.0) < 1.2
	if beacon_on:
		draw_circle(Vector2(mast_x + 0.25, mast_top), 3.0, UI.RED)
	# Body with a ledge at the top and the shaded side.
	_fill_clipped(UI.rect_poly(Rect2(tx - 4.0, top, tw + 8.0, 6.0)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(tx, top, tw, h)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(tx + tw, top + 8.0, tw * 0.1, h)), clip, UI.SIDE)
	# Street: ground strip and two lamps.
	_fill_clipped(UI.rect_poly(Rect2(0, h - 10.0, w, 10.0)), clip, UI.INK)
	for lx in [w * 0.04, w * 0.95]:
		_fill_clipped(UI.rect_poly(Rect2(lx, h - 46.0, 2.0, 36.0)), clip, UI.INK)
		_fill_clipped(UI.rect_poly(Rect2(lx - 6.0, h - 48.0, 10.0, 3.0)), clip, UI.INK)
		draw_rect(Rect2(lx - 5.0, h - 45.0, 8.0, 2.0), Color(UI.FLASH, 0.5), true)
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
	# Roof light blinks: redraw only when it switches.
	var on := fmod(Time.get_ticks_msec() / 1000.0, 2.0) < 1.2
	if on != _beacon_on and not Game.reduce_motion and is_visible_in_tree():
		_beacon_on = on
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
	if not Motion.reduced():
		add_child(Confetti.new(Vector2(size.x * 0.5, size.y * 0.3), 60))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _on_button(event.position):
			return  # Level up, Boost and the like: only the tower itself taps
		_do_tap(event.position)
		accept_event()


func spawn_sun() -> void:
	## Float a golden sun across the card (see golden_sun.gd).
	var s := GoldenSun.new()
	add_child(s)
	s.start(size)


func _on_button(pos: Vector2) -> bool:
	## True when the press lands on one of the card's own buttons.
	var gp := get_global_transform() * pos
	for ch in get_children():
		if ch is BaseButton and ch.is_visible_in_tree() and (ch as Control).get_global_rect().has_point(gp):
			return true
	return false


func _do_tap(pos: Vector2) -> void:
	var v := Game.tap()
	_combo_tick(pos)
	if _rows > 0:
		_flash_index = randi() % (COLS * _rows)
	_flash_time = 0.12
	queue_redraw()
	if Game.vibrate:
		Input.vibrate_handheld(18)
	if _float_count < 12:
		_spawn_float(pos, v)


# ---- tap combo (just for fun, no extra money) ----------------------------------

const COMBO_GAP_MS := 900
const COMBO_MARKS := [50, 100, 250, 500, 1000]
var _combo := 0
var _combo_ms := 0
var _combo_l: Label


func _combo_tick(pos: Vector2) -> void:
	var t := Time.get_ticks_msec()
	_combo = _combo + 1 if t - _combo_ms < COMBO_GAP_MS else 1
	_combo_ms = t
	if _combo_l == null:
		_combo_l = UI.display("", 30, UI.TEXT)
		_combo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(_combo_l)
		var timer := Timer.new()
		timer.wait_time = 0.25
		timer.autostart = true
		timer.timeout.connect(_combo_fade)
		add_child(timer)
	_combo_l.size = Vector2(220, 40)
	_combo_l.position = Vector2(size.x - 236, 10)
	_combo_l.visible = _combo >= 10
	_combo_l.modulate.a = 1.0
	_combo_l.text = "%d combo" % _combo
	if _combo in COMBO_MARKS:
		# Stays TEXT: red would vanish against the sun behind it.
		Kit.haptic("medium")
		Motion.pop(_combo_l, 1.25)
		if not Motion.reduced():
			add_child(Confetti.new(pos, 40))


func _combo_fade() -> void:
	if _combo_l and _combo_l.visible and Time.get_ticks_msec() - _combo_ms > COMBO_GAP_MS:
		_combo = 0
		var t := create_tween()
		t.tween_property(_combo_l, "modulate:a", 0.0, Motion.d(0.4))
		t.tween_callback(func(): _combo_l.visible = false)


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
