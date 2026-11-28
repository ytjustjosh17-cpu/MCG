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
var tier := 0          # wealth tier 0-5, from net worth (see _tier_now)
var _tier_t := 0.0
const TIERS := [1.0e6, 1.0e8, 1.0e10, 1.0e12, 1.0e14]


var _sky: Control
var _sky_boost := false
var _sky_t := 0.0
var _sky_key := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sky = TowerSky.new()
	_sky.show_behind_parent = true
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sky)
	add_child(SkyTime.Layer.new())   # rain or fog on top, when the weather turns
	var street := StreetLife.new()
	street.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(street)   # a car now and then; its own layer, so the tower isn't redrawn
	tier = _tier_now()
	Game.changed.connect(_on_game_changed)
	resized.connect(_reshape)


var _lit_key := ""


func _on_game_changed() -> void:
	## Income ticks change the game ten times a second; the tower only needs
	## a redraw when the number of lit windows or the tier actually changes.
	var k := "%d|%d" % [lit_count(), tier]
	if k != _lit_key:
		_lit_key = k
		queue_redraw()


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
	var top := h * (0.27 - 0.025 * float(tier))   # the tower gets taller with each wealth tier
	var win_w := tw * 0.125
	return {"tw": tw, "tx": tx, "top": top, "win_w": win_w, "win_h": win_w * 0.72,
		"pitch_x": tw * 0.21, "pitch_y": win_w * 1.5, "pad": tw * 0.1}


func lit_count() -> int:
	var total := COLS * _rows
	# More windows lit after dark.
	return clampi((Game.level - 1) * 3 + Game.companies() * 2 + 2 + int(Game.level_progress() * 3.0) + int(SkyTime.night() * COLS * 3), 1, total)


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
	# The sky, sun, skyline and pylon live on _sky (drawn behind, only when needed).
	var tx: float = g["tx"]
	var tw: float = g["tw"]
	var top: float = g["top"]
	# Wealth tiers: the skyline around the tower grows as net worth does.
	if tier >= 1:
		# A second, older block behind on the left.
		var bx := tx - tw * 0.62
		var bt := top + h * 0.12
		_fill_clipped(UI.rect_poly(Rect2(bx, bt, tw * 0.55, h)), clip, UI.SIDE)
		var wy := bt + 12.0
		while wy < h - 20.0:
			for c in 3:
				var on := (int(wy) / 7 + c) % 5 == 0
				draw_rect(Rect2(bx + 8.0 + c * tw * 0.15, wy, tw * 0.07, 4.0), Color(UI.RED, 0.55) if on else UI.WINDOW, true)
			wy += 14.0
		if tier >= 4:
			# A sky bridge joins it to the tower.
			_fill_clipped(UI.rect_poly(Rect2(bx + tw * 0.55, bt + h * 0.12, tw * 0.07 + 4.0, 10.0)), clip, UI.INK)
			draw_rect(Rect2(bx + tw * 0.55, bt + h * 0.12 + 4.0, tw * 0.07 + 4.0, 2.0), Color(UI.RED, 0.8), true)
	if tier >= 3 or SkyTime.night() > 0.5:
		# Searchlights sweeping up from the roof (faint; always on at night).
		for k in 2:
			var o := Vector2(tx + tw * (0.2 + k * 0.6), top)
			var ang := -PI / 2.0 + (0.28 if k == 1 else -0.28)
			var d := Vector2(cos(ang), sin(ang)) * h
			var side := Vector2(-d.y, d.x).normalized() * h * 0.09
			_fill_clipped(PackedVector2Array([o, o + d + side, o + d - side]), clip, Color(UI.TEXT, 0.09 + 0.05 * SkyTime.night()))
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
	if tier >= 2:
		# Red aircraft lights on the roof corners.
		draw_rect(Rect2(tx - 2.0, top - 4.0, 4.0, 4.0), UI.RED, true)
		draw_rect(Rect2(tx + tw - 2.0, top - 4.0, 4.0, 4.0), UI.RED, true)
	if tier >= 5:
		# A crown: the top floors lit red all round, and a slim spire.
		draw_rect(Rect2(tx, top + 6.0, tw, 3.0), UI.RED, true)
		_fill_clipped(PackedVector2Array([Vector2(tx + tw * 0.62, top - tw * 0.16), Vector2(tx + tw * 0.71, top - tw * 0.85), Vector2(tx + tw * 0.8, top - tw * 0.16)]), clip, UI.INK)
	# Body with a ledge at the top and the shaded side.
	_fill_clipped(UI.rect_poly(Rect2(tx - 4.0, top, tw + 8.0, 6.0)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(tx, top, tw, h)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(Rect2(tx + tw, top + 8.0, tw * 0.1, h)), clip, UI.SIDE)
	# Concrete panel seams on the face, and slim pillars between the window
	# columns that catch a little light.
	var seam := Color(UI.HAZE, 0.35)
	for k in [0.5]:
		draw_rect(Rect2(tx + tw * k - 0.5, top + 8.0, 1.0, h - 10.0 - top - 8.0), seam, true)
	for c2 in range(1, COLS):
		var px: float = tx + g["pad"] + c2 * g["pitch_x"] - (g["pitch_x"] - g["win_w"]) * 0.5
		draw_rect(Rect2(px - 1.0, top + 10.0, 2.0, h - 10.0 - top - 10.0), Color(UI.HAZE, 0.22), true)
	# The sun catches the roof ledge and the corner facing it.
	draw_rect(Rect2(tx - 4.0, top, tw + 8.0, 1.5), Color(UI.RED, 0.55), true)
	draw_rect(Rect2(tx + tw + tw * 0.1 - 1.5, top + 8.0, 1.5, h - 10.0 - top - 8.0), Color(UI.RED, 0.35), true)
	# Ground floor: a lit glass lobby under a canopy.
	var lob := Rect2(tx + tw * 0.18, h - 10.0 - 26.0, tw * 0.64, 26.0)
	_fill_clipped(UI.rect_poly(lob), clip, Color(UI.FLASH, 0.22))
	for d in 4:
		draw_rect(Rect2(lob.position.x + lob.size.x * float(d) / 4.0, lob.position.y, 1.5, lob.size.y), UI.INK, true)
	_fill_clipped(UI.rect_poly(Rect2(lob.position.x - 6.0, lob.position.y - 4.0, lob.size.x + 12.0, 4.0)), clip, UI.INK)
	draw_rect(Rect2(lob.position.x - 6.0, lob.position.y - 4.0, lob.size.x + 12.0, 1.0), Color(UI.RED, 0.45), true)
	if tier >= 2:
		# A setback crown band of lit glass near the top.
		draw_rect(Rect2(tx + 3.0, top + 9.0, tw - 6.0, 4.0), Color(UI.FLASH, 0.18), true)
	if tier >= 3:
		# A helipad ring on the roof.
		draw_arc(Vector2(tx + tw * 0.5, top - 2.0), tw * 0.16, PI, TAU, 24, Color(UI.TEXT, 0.35), 1.5, true)
	var py: float = g["pitch_y"]
	var fy: float = top + 18.0 - py * 0.25
	while fy < h - 10.0:
		draw_rect(Rect2(tx + 2.0, fy, tw - 4.0, 1.0), seam, true)
		fy += py
	# Air-con boxes hanging off a few floors on the shaded side.
	for row in [3, 7, 12]:
		var ay: float = top + 18.0 + row * py
		if ay < h - 30.0:
			_fill_clipped(UI.rect_poly(Rect2(tx + tw + tw * 0.1, ay, tw * 0.09, g["win_h"])), clip, UI.INK)
	# Cables from the roof edge out across the sun, sagging.
	for k in 3:
		var a := Vector2(tx + tw, top + 4.0 + k * 10.0)
		var b := Vector2(w + 8.0, h * (0.06 + k * 0.09))
		Art._wire(self, a, b, h * (0.015 + k * 0.01), clip, UI.INK, 1.3)
	# Street: ground strip and a lamp on the right (one at the far left read
	# as a stray dash against the pylon, so it went).
	_fill_clipped(UI.rect_poly(Rect2(0, h - 10.0, w, 10.0)), clip, UI.SIDE)   # lighter than the page, so the card's rounded foot shows
	for lx in [w * 0.95]:
		_fill_clipped(UI.rect_poly(Rect2(lx, h - 46.0, 2.0, 36.0)), clip, UI.INK)
		_fill_clipped(UI.rect_poly(Rect2(lx - 6.0, h - 48.0, 10.0, 3.0)), clip, UI.INK)
		draw_rect(Rect2(lx - 5.0, h - 45.0, 8.0, 2.0), Color(UI.FLASH, 0.5), true)
	var lit := {}
	for k in range(mini(lit_count(), _order.size())):
		lit[_order[k]] = true
	for i in range(COLS * _rows):
		var r := _window_rect(i, g)
		if r.end.y > h - 42.0:
			continue   # the ground floor is the lobby
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
		_window(r, c)
	var nb := Rect2(w * 0.86, h * 0.46, w * 0.2, h * 0.54 - 10.0)   # stands on the street
	_fill_clipped(UI.rect_poly(nb), clip, UI.WINDOW)
	_fill_clipped(UI.rect_poly(Rect2(nb.position + Vector2(10, 14), Vector2(8, 7))), clip, UI.RED)
	# A tall red sign on the neighbour block, made-up marks.
	var sign := Rect2(nb.position.x - w * 0.02, nb.position.y + h * 0.08, w * 0.05, h * 0.13)
	_fill_clipped(UI.rect_poly(sign.grow(2.0)), clip, UI.INK)
	_fill_clipped(UI.rect_poly(sign), clip, Color(UI.RED, 0.85))
	for m in 4:
		var my := sign.position.y + 5.0 + m * sign.size.y * 0.23
		_fill_clipped(UI.rect_poly(Rect2(sign.position.x + 3.0, my, sign.size.x - 6.0 - (m % 2) * 4.0, 2.0)), clip, UI.INK)


func _window(r: Rect2, c: Color) -> void:
	## One window: a soft glow when lit, a brighter top pane, a mullion, a sill;
	## dark windows show a faint reflection of the sky.
	if c == UI.RED or c == UI.FLASH:
		draw_rect(r.grow(2.0), Color(c, 0.16), true)
		draw_rect(r, c, true)
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.38)), c.lerp(UI.FLASH, 0.3), true)
	else:
		draw_rect(r, c, true)
		draw_rect(Rect2(r.position, Vector2(r.size.x * 0.4, 1.5)), Color(UI.HAZE, 0.6), true)
	draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 0.5, r.position.y, 1.0, r.size.y), Color(UI.INK, 0.5), true)
	draw_rect(Rect2(r.position.x - 1.0, r.end.y, r.size.x + 2.0, 1.0), Color(UI.HAZE, 0.75), true)


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
	if Game.boost_active() != _sky_boost:
		_sky_boost = Game.boost_active()
		_sky.queue_redraw()
	_sky_t -= delta
	if _sky_t <= 0.0:
		# Time of day, weather and the skyline of owned companies: check twice a minute.
		_sky_t = 30.0
		var k := "%s|%d" % [SkyTime.key(), Game.companies()]
		if k != _sky_key:
			_sky_key = k
			_sky.queue_redraw()
			queue_redraw()
	_tier_t -= delta
	if _tier_t <= 0.0:
		_tier_t = 2.0
		var tn := _tier_now()
		if tn != tier:
			tier = tn
			_reshape()
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


func _tier_now() -> int:
	var nw := Game.net_worth()
	var t := 0
	for v in TIERS:
		if nw >= v:
			t += 1
	return t


func celebrate() -> void:
	## A wave of light runs up the tower (level up).
	if not Game.reduce_motion:
		_wave = 0.0
	if not Motion.reduced():
		add_child(Confetti.new(Vector2(size.x * 0.5, size.y * 0.3), 60, true))

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


var _fx_ms := 0


func _do_tap(pos: Vector2) -> void:
	# The combo counts this tap first, so its bonus applies to it.
	_combo_tick(pos)
	var v := Game.tap(Game.combo_mult(_combo))
	# Very fast tapping (or a tapping app): sound and buzz at most ~14 a second.
	var ms := Time.get_ticks_msec()
	var fx_ok := ms - _fx_ms >= 70
	if fx_ok:
		_fx_ms = ms
		Kit.sound("tap")
	if _rows > 0:
		_flash_index = randi() % (COLS * _rows)
	_flash_time = 0.12
	queue_redraw()
	if Game.vibrate and fx_ok:
		Input.vibrate_handheld(18)
	if v <= 0.0:
		return   # an unpaid extra tap: no "+£0"
	if Game.last_tap_crit:
		_spawn_crit(pos, v)
	elif _float_count < 12:
		_spawn_float(pos, v)


# ---- tap combo: taps in a row pay more, up to x2.5 (Game.combo_mult) ------------

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
	_combo_l.size = Vector2(300, 40)
	_combo_l.position = Vector2(size.x - 316, 10)
	_combo_l.visible = _combo >= 10
	_combo_l.modulate.a = 1.0
	var cm := Game.combo_mult(_combo)
	_combo_l.text = ("%d combo  x%.1f" % [_combo, cm]) if cm > 1.0 else "%d combo" % _combo
	if _combo in COMBO_MARKS:
		# Stays TEXT: red would vanish against the sun behind it.
		Kit.haptic("medium")
		Motion.pop(_combo_l, 1.25)
		if not Motion.reduced():
			add_child(Confetti.new(pos, 40, true))


func _combo_fade() -> void:
	if _combo_l and _combo_l.visible and Time.get_ticks_msec() - _combo_ms > COMBO_GAP_MS:
		_combo = 0
		var t := create_tween()
		t.tween_property(_combo_l, "modulate:a", 0.0, Motion.d(0.4))
		t.tween_callback(func(): _combo_l.visible = false)


func _spawn_crit(pos: Vector2, v: float) -> void:
	## Critical tap: a bigger red number, a burst and a crisp sound.
	Kit.sound("crit")
	if Game.vibrate:
		Input.vibrate_handheld(28)
	if Motion.reduced():
		return
	var l := UI.label("BIG TAP +" + Game.money_short(v), 28, UI.TEXT, true)
	l.add_theme_font_override("font", UI.DISPLAY)
	# Dark outline so it reads on the red sun as well as the dark sky.
	l.add_theme_color_override("font_outline_color", UI.INK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	l.position = pos + Vector2(-50, -52)
	l.pivot_offset = Vector2(50, 16)
	l.scale = Vector2(0.6, 0.6)
	_float_count += 1
	add_child(Confetti.new(pos, 18, true))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)  # reduced-checked
	tw.tween_property(l, "position:y", l.position.y - 90.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)  # reduced-checked
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		_float_count -= 1
		l.queue_free())


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


class TowerSky extends Control:
	## Static backdrop for the tower; redraws on resize or when the boost starts or ends.
	func _init() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 100.0 or h < 100.0:
			return
		var clip := UI.rounded_rect_poly(Rect2(Vector2.ZERO, size), TowerCard.RADIUS)
		var sun_col := SkyTime.sun_colour()
		if Game.boost_active():
			sun_col = sun_col.lightened(0.12)
		var sun_c := SkyTime.sun_center(w, h, Vector2(w * 0.78, h * 0.24))
		Art.backdrop(self, Rect2(Vector2.ZERO, size), clip, sun_c, minf(w * 0.42, h * 0.34), sun_col, 4401, {"clouds": false})   # bars behind the tower read as stray lines
		_skyline(w, h)
		SkyTime.shade(self, Rect2(Vector2.ZERO, size), clip)

	func _skyline(w: float, h: float) -> void:
		## The companies you own stand on the far side of town, left of the
		## tower and just above the buttons: a back row and a front row, more as
		## you open more, softened by haze so the tower stays the hero.
		var kinds: Array = []
		for b in Game.businesses():
			if Game.owns(String(b["id"])):
				kinds.append(String(b["kind"]))
		if kinds.is_empty():
			return
		var lit := 2 if SkyTime.night() > 0.5 else 1
		var base := h - 10.0   # on the street, not floating mid-air
		var area := w * 0.36
		var front: Array = kinds.slice(0, 5)
		var back: Array = kinds.slice(5, 11)
		var sb := 0.27
		for i in range(back.size()):
			var x := 10.0 + area * (float(i) + 0.5) / 6.0
			Art.draw(self, String(back[i]), Vector2(x, base - 14.0 - 70.0 * sb), sb, lit)
		var sf := 0.36
		for i in range(front.size()):
			var x := 8.0 + area * float(i) / 5.0
			Art.draw(self, String(front[i]), Vector2(x, base - 70.0 * sf), sf, lit)
		draw_rect(Rect2(0, base - 70.0 * sf - 18.0, w * 0.45, 70.0 * sf + 22.0), Color(UI.HAZE, 0.08), true)


class StreetLife extends Control:
	## A car drives along the street every so often, headlights on. Drawn at
	## 10 frames a second on its own layer and only while it is passing; still
	## with Less motion on. Never takes a tap.
	var _t := 0.0
	var _acc := 0.0
	const CYCLE := 14.0
	const DRIVE := 5.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or Game.reduce_motion:
			return
		_t += delta
		if fmod(_t, CYCLE) > DRIVE + 0.2:
			return   # nothing on the street: no redraws
		_acc += delta
		if _acc >= 0.1:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		if Game.reduce_motion:
			return
		var p := fmod(_t, CYCLE) / DRIVE
		if p > 1.0:
			return
		var w := size.x
		var h := size.y
		var x := lerpf(w + 30.0, -60.0, p)   # right to left, towards the tower's foot
		var y := h - 10.0
		var a := clampf(minf(x - 20.0, w - 20.0 - x) / 24.0, 0.0, 1.0)
		if a <= 0.0:
			return
		var cw := 34.0
		var ch := 11.0
		draw_rect(Rect2(x - 24.0, y - 4.0, 24.0, 2.0), Color(UI.FLASH, 0.22 * a), true)   # light on the road ahead
		draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x, y - ch * 0.55), Vector2(x + cw * 0.22, y - ch), Vector2(x + cw * 0.7, y - ch), Vector2(x + cw, y - ch * 0.5), Vector2(x + cw, y)]), Color(UI.INK, a))
		draw_rect(Rect2(x + cw * 0.28, y - ch * 0.85, cw * 0.36, ch * 0.3), Color(UI.WINDOW, a), true)
		draw_rect(Rect2(x, y - ch * 0.45, 2.5, 2.0), Color(UI.FLASH, a), true)
		draw_rect(Rect2(x + cw - 2.0, y - ch * 0.45, 2.0, 2.0), Color(UI.RED, a), true)
		for wx in [x + cw * 0.22, x + cw * 0.78]:
			draw_circle(Vector2(wx, y), 3.5, Color(UI.INK, a))

