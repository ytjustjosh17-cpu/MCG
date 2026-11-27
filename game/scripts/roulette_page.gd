class_name RoulettePage
extends CasinoGame
## European roulette. A phone-sized vertical betting mat (zero on top, 12
## rows of three, dozens and even-money bets down the left, columns at the
## bottom) that scrolls in its own area; chips, Undo, Clear, Rebet or Double,
## and Spin in thumb reach. When you spin, the wheel (real pocket order, a
## ball that orbits, drops and settles) rises over the mat, then steps aside.
## The mat keeps its own scroll: 14 rows at a 48 px tap size can't fit.
##
## Money: the whole table is staked with one Game.casino_stake() and the
## result paid with Game.casino_pay() BEFORE the wheel spins, so both are
## saved at once and closing the app mid-spin can't undo a loss. The chips
## shown on screen lag behind until the ball settles.

const MAT_W := 358.0
const ROW_H := 48.0
const GAP := 3.0
const STRIP_W := 48.0
const HISTORY := 12
const WHEEL_SIDE := 260.0

var _math := RouletteMath.new()
var _wheel: WheelView
var _over: Control        # the wheel over the mat while it spins
var _num_panel: PanelContainer
var _num_l: Label
var _win_l: Label
var _hist_box: HBoxContainer
var _status: Label        # the chips shown (status row)
var _mat_scroll: ScrollContainer
var _mat: Control
var _chip_row: HBoxContainer
var _undo_b: Button
var _clear_b: Button
var _again_b: Button
var _spin_b: Button

var _cells := {}          # bet key -> Button
var _marks := {}          # bet key -> ChipMark
var _bets := {}           # bet key -> {type, arg, amount}
var _undo: Array = []     # snapshots of _bets before each change
var _last_bets := {}      # for Rebet
var _chip := 0.0          # chosen chip value
var _denoms: Array = []
var _spinning := false
var _shown_chips := -1.0  # what the screen shows while the ball is moving
var _winners: Array = []  # keys that won last spin (gold edge until the next bet)
var _history: Array = []
var _hide_t: Tween


func _init() -> void:
	super("Roulette", true)


func build_game() -> void:
	_status = status.chips_l
	# Top strip: the last number, what it paid, and the numbers before it.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	area.add_child(top)
	_num_panel = PanelContainer.new()
	_num_panel.custom_minimum_size = Vector2(48, 48)
	_num_panel.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 24))
	top.add_child(_num_panel)
	_num_l = UI.display("-", 24)
	_num_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_num_panel.add_child(_num_l)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tv)
	_win_l = UI.label("Place your bets", 15, UI.TEXT, true)
	tv.add_child(_win_l)
	_hist_box = HBoxContainer.new()
	_hist_box.add_theme_constant_override("separation", 4)
	tv.add_child(_hist_box)
	# The mat, in its own scroll area (a wobbly tap still places a chip),
	# with the wheel drawn over it during a spin (never takes a tap).
	var board := Control.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_PASS
	area.add_child(board)
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UI.box(UI.FELT, 16, 0, 0))
	mp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(mp)
	_mat_scroll = ScrollContainer.new()
	_mat_scroll.scroll_deadzone = 10
	_mat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	mp.add_child(_mat_scroll)
	_mat = Control.new()
	_mat.custom_minimum_size = Vector2(MAT_W, 14.0 * ROW_H + 15.0 * GAP)
	_mat.mouse_filter = Control.MOUSE_FILTER_PASS
	_mat_scroll.add_child(_mat)
	_build_mat()
	# A slim bar shows there's more mat below (columns and the rest).
	var vb := _mat_scroll.get_v_scroll_bar()
	vb.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	vb.add_theme_stylebox_override("grabber", UI.box(Color(UI.TEXT, 0.35), 3))
	vb.add_theme_stylebox_override("grabber_highlight", UI.box(Color(UI.TEXT, 0.5), 3))
	vb.add_theme_stylebox_override("grabber_pressed", UI.box(Color(UI.TEXT, 0.5), 3))
	vb.custom_minimum_size.x = 5
	_over = Control.new()
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.visible = false
	_over.draw.connect(func(): _over.draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2.ZERO, _over.size), 16.0), Color(UI.INK, 0.72)))
	board.add_child(_over)
	_wheel = WheelView.new()
	_wheel.custom_minimum_size = Vector2(WHEEL_SIDE, WHEEL_SIDE)
	_wheel.size = Vector2(WHEEL_SIDE, WHEEL_SIDE)
	_over.add_child(_wheel)
	_over.resized.connect(func(): _wheel.position = (_over.size - _wheel.size) * 0.5)
	# Dock: chips to bet with, Undo / Clear / Rebet, then Spin.
	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 8)
	_chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_chip_row.custom_minimum_size = Vector2(0, 52)
	dock.add_child(_chip_row)
	_undo_b = quiet("Undo", _on_undo)
	_clear_b = quiet("Clear", _on_clear)
	_again_b = quiet("Rebet", _on_again)
	dock_row([_undo_b, _clear_b, _again_b])
	_spin_b = primary("Spin", _on_spin)
	dock.add_child(_spin_b)


func info_content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(note("Pick a chip, tap the mat to bet, then spin. A single zero wheel. Pays include your bet back.\n", UI.TEXT))
	for p in [["A number", "36×"], ["Dozen or column", "3×"], ["Red, black, odd, even", "2×"], ["1-18 or 19-36", "2×"]]:
		box.add_child(pay_line(p[0], p[1]))
	box.add_child(note("\nRebet puts your last bets back; with chips down it doubles them. Pays back 97.3% over time."))
	return box


# ---- the mat ----------------------------------------------------------------

func _build_mat() -> void:
	var nx := STRIP_W * 2.0 + GAP * 3.0
	var cw := (MAT_W - nx - GAP * 2.0 - GAP) / 3.0
	var rowy := func(r: int) -> float: return GAP + float(r) * (ROW_H + GAP)
	# Zero across the top.
	_cell("straight:0", Rect2(nx, rowy.call(0), cw * 3.0 + GAP * 2.0, ROW_H), "0", UI.ROUL_GREEN, 20, "straight", 0)
	# Numbers: row r holds 3r-2, 3r-1, 3r.
	for r in range(1, 13):
		for c in range(3):
			var n := 3 * r - 2 + c
			var col: Color = UI.ROUL_RED if RouletteMath.color(n) == "red" else UI.ROUL_BLACK
			_cell("straight:%d" % n, Rect2(nx + float(c) * (cw + GAP), rowy.call(r), cw, ROW_H), str(n), col, 20, "straight", n)
	# Columns (2 to 1) along the bottom.
	for c in range(3):
		_cell("column:%d" % (c + 1), Rect2(nx + float(c) * (cw + GAP), rowy.call(13), cw, ROW_H), "2 to 1", UI.FELT, 13, "column", c + 1)
	# Dozens down the far left, four rows each.
	var tall := 4.0 * ROW_H + 3.0 * GAP
	for d in range(3):
		_cell("dozen:%d" % (d + 1), Rect2(GAP, rowy.call(1 + d * 4), STRIP_W, tall), ["1-12", "13-24", "25-36"][d], UI.FELT, 13, "dozen", d + 1)
	# Even-money bets, two rows each.
	var two := 2.0 * ROW_H + GAP
	var evens := [["low", "1-18", UI.FELT], ["even", "Even", UI.FELT], ["red", "Red", UI.ROUL_RED],
		["black", "Black", UI.ROUL_BLACK], ["odd", "Odd", UI.FELT], ["high", "19-36", UI.FELT]]
	for i in range(evens.size()):
		var e: Array = evens[i]
		_cell(String(e[0]), Rect2(STRIP_W + GAP * 2.0, rowy.call(1 + i * 2), STRIP_W, two), String(e[1]), e[2], 13, String(e[0]), null)


func _cell(key: String, r: Rect2, text: String, bg: Color, fsize: int, type: String, arg) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.clip_text = false
	b.add_theme_font_override("font", UI.SEMI)
	b.add_theme_font_size_override("font_size", fsize)
	b.position = r.position
	b.size = r.size
	b.custom_minimum_size = r.size
	b.mouse_filter = Control.MOUSE_FILTER_PASS   # lets the mat scroll; a still tap still presses
	b.set_meta("bg", bg)
	_paint_cell(b, bg, false)
	b.pressed.connect(func(): _place(key, type, arg))
	_mat.add_child(b)
	_cells[key] = b
	var m := ChipMark.new()
	m.position = Vector2(r.size.x - 30.0, r.size.y * 0.5 - 13.0) if r.size.x > 60.0 else Vector2(r.size.x * 0.5 - 13.0, r.size.y - 30.0)
	m.visible = false
	b.add_child(m)
	_marks[key] = m


func _paint_cell(b: Button, bg: Color, win: bool) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := UI.box(bg.lerp(UI.INK, 0.2) if st == "pressed" else bg, 8)
		sb.border_color = UI.GOLD if win else UI.FELT_LINE
		sb.set_border_width_all(3 if win else 1)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, UI.TEXT)


func _table_total() -> float:
	var t := 0.0
	for k in _bets.keys():
		t += float(_bets[k]["amount"])
	return t


func _bets_list() -> Array:
	var out: Array = []
	for k in _bets.keys():
		out.append(_bets[k])
	return out


func _place(key: String, type: String, arg) -> void:
	if _spinning:
		return
	var b: Button = _cells[key]
	var total := _table_total()
	var mx := Game.casino_max_bet()
	if total + _chip > mx + 0.001:
		Kit.toast("Table limit %s" % Game.money_short(mx))
		Motion.shake(b)
		return
	if total + _chip > Game.chips() + 0.001:
		Kit.toast("Not enough chips · tap +")
		Motion.shake(b)
		return
	_clear_winners()
	_undo.append(_bets.duplicate(true))
	if not _bets.has(key):
		_bets[key] = {"type": type, "arg": arg, "amount": 0.0}
	_bets[key]["amount"] = float(_bets[key]["amount"]) + _chip
	Kit.haptic("selection")
	Kit.sound("tap")
	_update_marks()
	refresh()


func _update_marks() -> void:
	for k in _marks.keys():
		var m: ChipMark = _marks[k]
		var amt := float(_bets[k]["amount"]) if _bets.has(k) else 0.0
		m.visible = amt > 0.0
		m.set_amount(amt)


func _clear_winners() -> void:
	for k in _winners:
		if _cells.has(k):
			var b: Button = _cells[k]
			_paint_cell(b, b.get_meta("bg"), false)
	_winners = []


func _on_undo() -> void:
	if _spinning or _undo.is_empty():
		Motion.shake(_undo_b)
		return
	Kit.tick()
	_bets = _undo.pop_back()
	_update_marks()
	refresh()


func _on_clear() -> void:
	if _spinning or _bets.is_empty():
		Motion.shake(_clear_b)
		return
	Kit.tick()
	_undo.append(_bets.duplicate(true))
	_bets = {}
	_update_marks()
	refresh()


func _on_again() -> void:
	## Rebet the last spin's bets on an empty table, or double what's there.
	if _spinning:
		return
	var next := {}
	if _bets.is_empty():
		if _last_bets.is_empty():
			Motion.shake(_again_b)
			return
		next = _last_bets.duplicate(true)
	else:
		next = _bets.duplicate(true)
		for k in next.keys():
			next[k]["amount"] = float(next[k]["amount"]) * 2.0
	var t := 0.0
	for k in next.keys():
		t += float(next[k]["amount"])
	if t > Game.casino_max_bet() + 0.001:
		Kit.toast("Table limit %s" % Game.money_short(Game.casino_max_bet()))
		Motion.shake(_again_b)
		return
	if t > Game.chips() + 0.001:
		Kit.toast("Not enough chips · tap +")
		Motion.shake(_again_b)
		return
	Kit.tick()
	_clear_winners()
	_undo.append(_bets.duplicate(true))
	_bets = next
	_update_marks()
	refresh()


func _on_spin() -> void:
	if _spinning:
		return
	var total := _table_total()
	if total <= 0.0:
		Kit.toast("Place a bet first")
		Motion.shake(_spin_b)
		return
	if total > Game.chips() + 0.001:
		Kit.toast("Not enough chips · tap +")
		Motion.shake(_spin_b)
		return
	var before := Game.chips()
	# Take the bet and pay the result now (both saved), then show it.
	if not Game.casino_stake(total):
		Kit.toast("Table limit %s" % Game.money_short(Game.casino_max_bet()))
		Motion.shake(_spin_b)
		return
	var n := _math.spin()
	var paid := Game.casino_pay(RouletteMath.settle(_bets_list(), n))
	GameLog.info("casino", "Roulette %d: bet %s, back %s" % [n, Game.money(total), Game.money(paid)])
	_last_bets = _bets.duplicate(true)
	_shown_chips = before - total
	_spinning = true
	Kit.haptic("medium")
	status.clear_win()
	_win_l.text = "No more bets"
	_win_l.add_theme_color_override("font_color", UI.SUB)
	_show_wheel(true)
	refresh()
	_wheel.spin_to(n, func(): _finish(n, paid, total))


func _show_wheel(on: bool) -> void:
	## The wheel rises over the mat for the spin and fades after the result.
	if _hide_t and _hide_t.is_valid():
		_hide_t.kill()
	if Motion.reduced():
		_over.visible = false
		return
	if on:
		_over.visible = true
		_over.modulate.a = 0.0
		_over.queue_redraw()
		_hide_t = create_tween()
		_hide_t.tween_property(_over, "modulate:a", 1.0, 0.2)
		return
	_hide_t = create_tween()
	_hide_t.tween_interval(1.1)
	_hide_t.tween_property(_over, "modulate:a", 0.0, 0.3)
	_hide_t.tween_callback(func(): _over.visible = false)


func _finish(n: int, paid: float, total: float) -> void:
	if not is_instance_valid(self):
		return
	_spinning = false
	_shown_chips = -1.0
	_history.push_front(n)
	if _history.size() > HISTORY:
		_history.resize(HISTORY)
	_num_l.text = str(n)
	_num_panel.add_theme_stylebox_override("panel", UI.box(_pocket_col(n), 24))
	Motion.pop(_num_panel, 1.1)
	_show_wheel(false)
	# Winning bets get a gold edge until the next chip goes down.
	_winners = []
	for k in _bets.keys():
		var bt: Dictionary = _bets[k]
		if RouletteMath.payout(String(bt["type"]), bt["arg"], n) > 0.0:
			_winners.append(k)
	if not _winners.has("straight:%d" % n):
		_winners.append("straight:%d" % n)
	for k in _winners:
		if _cells.has(k):
			var b: Button = _cells[k]
			_paint_cell(b, b.get_meta("bg"), true)
	_bets = {}
	_undo = []
	_update_marks()
	# Bring the winning number into view on the mat.
	var wc: Button = _cells.get("straight:%d" % n)
	if wc:
		var to := int(clampf(wc.position.y - _mat_scroll.size.y * 0.4, 0.0, maxf(0.0, _mat.custom_minimum_size.y - _mat_scroll.size.y)))
		var st := create_tween()
		st.tween_property(_mat_scroll, "scroll_vertical", to, Motion.d(0.35)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var col := RouletteMath.color(n)
	var said := "%d %s" % [n, col] if n != 0 else "Zero"
	if paid > total + 0.001:
		_win_l.text = said + ", you win"
		_win_l.add_theme_color_override("font_color", UI.GOLD)
	elif paid > 0.0:
		_win_l.text = said + ", some back"
		_win_l.add_theme_color_override("font_color", UI.TEXT)
	else:
		_win_l.text = said + ", no win"
		_win_l.add_theme_color_override("font_color", UI.SUB)
	var at := _wheel.get_global_rect().get_center() if _wheel.is_visible_in_tree() else Vector2.INF
	win_fx(paid, total, 10.0, at)
	_draw_history()
	refresh()


func _pocket_col(n: int) -> Color:
	match RouletteMath.color(n):
		"red": return UI.ROUL_RED
		"black": return UI.ROUL_BLACK
	return UI.ROUL_GREEN


func _draw_history() -> void:
	## The numbers before the last one, newest first (as many as fit).
	for ch in _hist_box.get_children():
		ch.queue_free()
	for i in range(1, mini(_history.size(), 9)):
		var n: int = _history[i]
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(28, 24)
		p.add_theme_stylebox_override("panel", UI.box(_pocket_col(n), 12))
		var l := UI.label(str(n), 13, UI.TEXT, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		_hist_box.add_child(p)


# ---- chips --------------------------------------------------------------------

func _rebuild_chips() -> void:
	var d := CasinoGame.denoms(Game.casino_max_bet())
	if d == _denoms:
		return
	_denoms = d
	for ch in _chip_row.get_children():
		ch.queue_free()
	if not _denoms.has(_chip):
		_chip = _denoms[1] if _denoms.size() > 1 else _denoms[0]
	for i in range(_denoms.size()):
		var v: float = _denoms[i]
		var cb := ChipButton.new(v, i)
		cb.selected = is_equal_approx(v, _chip)
		cb.pressed.connect(func():
			Kit.haptic("selection")
			_chip = v
			for o in _chip_row.get_children():
				if o is ChipButton:
					(o as ChipButton).selected = is_equal_approx((o as ChipButton).value, v)
					o.queue_redraw())
		_chip_row.add_child(cb)


func refresh() -> void:
	if _spin_b == null:
		return
	_rebuild_chips()
	var shown := _shown_chips if _shown_chips >= 0.0 else Game.chips()
	status.set_chips(shown)
	_again_b.text = "Rebet" if _bets.is_empty() else "×2"
	var total := _table_total()
	_spin_b.text = "Spin · " + Game.money_short(total) if total > 0.0 else "Spin"
	set_go(_spin_b, not _spinning and total > 0.0)
	for b in [_undo_b, _clear_b, _again_b]:
		(b as Control).modulate.a = 0.4 if _spinning else 1.0


# ---- pieces ---------------------------------------------------------------------

class ChipMark extends Control:
	## The chip stack sitting on a bet, showing how much is on it.
	var amount := 0.0
	var tier := 0

	func _init() -> void:
		size = Vector2(26, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_amount(a: float) -> void:
		amount = a
		tier = CasinoGame.chip_tier(a)
		queue_redraw()

	func _draw() -> void:
		if amount <= 0.0:
			return
		var c := size * 0.5
		draw_circle(c + Vector2(0, 3), 13.0, Color(UI.INK, 0.5))
		CasinoGame.draw_chip(self, c, 13.0, tier, CasinoGame.chip_text(amount))


class WheelView extends Control:
	## The wheel in real European order. spin_to() turns the wheel one way and
	## runs the ball the other, then drops it into the pocket.
	var wheel_ang := 0.0
	var ball_ang := -PI / 2.0
	var ball_r := 0.0        # 0 = no ball shown, else fraction of the radius
	var _t := 0.0
	var _len := 0.0
	var _w0 := 0.0
	var _w_total := 0.0
	var _b0 := 0.0
	var _b_total := 0.0
	var _done: Callable
	var _running := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)

	static func pocket_ang(i: int) -> float:
		return TAU * float(i) / 37.0

	func spin_to(n: int, done: Callable) -> void:
		var idx := RouletteMath.pocket_index(n)
		_done = done
		_w0 = wheel_ang
		_w_total = TAU * 2.0 + randf() * PI
		var w_end := _w0 + _w_total
		var target := w_end + pocket_ang(idx)
		# The ball runs the other way, four to five turns, and ends in the pocket.
		_b0 = ball_ang
		_b_total = _b0 - target
		while _b_total < TAU * 4.0:
			_b_total += TAU
		if Motion.reduced():   # Less motion: show the result at once
			wheel_ang = w_end
			ball_ang = target
			ball_r = 0.74
			queue_redraw()
			_done.call()
			return
		_len = 4.6
		_t = 0.0
		ball_r = 0.95
		_running = true
		set_process(true)
		Kit.sound("tap")

	func _process(delta: float) -> void:
		if not _running:
			set_process(false)
			return
		_t = minf(_len, _t + delta)
		var p := _t / _len
		var e := 1.0 - pow(1.0 - p, 3.0)
		wheel_ang = _w0 + _w_total * e
		ball_ang = _b0 - _b_total * (1.0 - pow(1.0 - p, 2.4))
		# The ball rides the rim, then falls into the pockets with small bounces.
		if p < 0.62:
			ball_r = 0.95
		else:
			var q := (p - 0.62) / 0.38
			ball_r = lerpf(0.95, 0.74, minf(1.0, q * 1.6)) + absf(sin(q * 14.0)) * 0.06 * (1.0 - q)
		queue_redraw()
		if _t >= _len:
			_running = false
			ball_r = 0.74
			queue_redraw()
			if _done.is_valid():
				_done.call()

	func _draw() -> void:
		var c := size * 0.5
		var R := minf(size.x, size.y) * 0.5
		draw_circle(c, R, UI.SIDE)
		draw_arc(c, R - 1.0, 0.0, TAU, 72, UI.FELT_LINE, 2.0, true)
		var r_out := R * 0.9
		var r_in := R * 0.6
		var f: Font = UI.SEMI
		var fs := int(clampf(R * 0.09, 8.0, 12.0))   # pocket numbers: wheel art, the big number is in the strip
		for i in 37:
			var n: int = RouletteMath.WHEEL[i]
			var a0 := wheel_ang + pocket_ang(i) - PI / 37.0 - PI / 2.0
			var a1 := a0 + TAU / 37.0
			var col: Color = UI.ROUL_GREEN if n == 0 else (UI.ROUL_RED if RouletteMath.color(n) == "red" else UI.ROUL_BLACK)
			var pts := PackedVector2Array([
				c + Vector2(cos(a0), sin(a0)) * r_in, c + Vector2(cos(a0), sin(a0)) * r_out,
				c + Vector2(cos(a1), sin(a1)) * r_out, c + Vector2(cos(a1), sin(a1)) * r_in])
			draw_colored_polygon(pts, col)
			draw_line(c + Vector2(cos(a0), sin(a0)) * r_in, c + Vector2(cos(a0), sin(a0)) * r_out, UI.GOLD.lerp(UI.SIDE, 0.5), 1.0, true)
			# Number, upright along the radius.
			var am := (a0 + a1) * 0.5
			draw_set_transform(c + Vector2(cos(am), sin(am)) * R * 0.8, am + PI / 2.0)
			draw_string(f, Vector2(-10, fs * 0.4), str(n), HORIZONTAL_ALIGNMENT_CENTER, 20, fs, UI.TEXT)
			draw_set_transform(Vector2.ZERO, 0.0)
		draw_circle(c, r_in, UI.FELT)
		draw_arc(c, r_in, 0.0, TAU, 72, UI.GOLD.lerp(UI.SIDE, 0.4), 2.0, true)
		# The turret in the middle turns with the wheel.
		for k in 4:
			var a := wheel_ang + TAU * float(k) / 4.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * r_in * 0.55, UI.GOLD, 3.0, true)
		draw_circle(c, R * 0.12, UI.GOLD)
		draw_circle(c, R * 0.06, UI.SIDE)
		if ball_r > 0.0:
			var bp := c + Vector2(cos(ball_ang - PI / 2.0), sin(ball_ang - PI / 2.0)) * R * ball_r
			draw_circle(bp + Vector2(1, 1.5), 6.0, Color(UI.INK, 0.5))
			draw_circle(bp, 6.0, UI.TEXT)
