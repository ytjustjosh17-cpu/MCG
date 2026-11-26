class_name RoulettePage
extends Page
## European roulette. A wheel drawn in real pocket order with a ball that
## orbits, drops and settles; a phone-sized vertical betting mat (zero on
## top, 12 rows of three, dozens and even-money bets down the left, columns
## at the bottom) that scrolls in its own area; chips, Undo, Clear, Rebet
## or Double, and Spin in thumb reach.
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

var _math := RouletteMath.new()
var _wheel: WheelView
var _num_panel: PanelContainer
var _num_l: Label
var _win_l: Label
var _hist_box: GridContainer
var _status: Label
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


func _init() -> void:
	super("Roulette", true)


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # the mat scrolls, not the page
	# Top: the wheel, the last number, the win and the history strip.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	body.add_child(top)
	_wheel = WheelView.new()
	top.add_child(_wheel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 10)
	side.add_child(hr)
	_num_panel = PanelContainer.new()
	_num_panel.custom_minimum_size = Vector2(64, 64)
	_num_panel.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 14))
	hr.add_child(_num_panel)
	_num_l = UI.display("-", 34)
	_num_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_num_panel.add_child(_num_l)
	var wv := VBoxContainer.new()
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	hr.add_child(wv)
	wv.add_child(UI.label("Last spin", 13, UI.SUB))
	_win_l = UI.label("Place your bets", 15, UI.TEXT, true)
	_win_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wv.add_child(_win_l)
	_hist_box = GridContainer.new()
	_hist_box.columns = 6
	_hist_box.add_theme_constant_override("h_separation", 4)
	_hist_box.add_theme_constant_override("v_separation", 4)
	side.add_child(_hist_box)
	# Status: table total, limit and chips, with a quick way to buy chips.
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	body.add_child(sr)
	_status = UI.label("", 13, UI.SUB)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sr.add_child(_status)
	var buy := UI.pill("+ Chips", UI.RAISED, UI.TEXT, 15, 16)
	buy.custom_minimum_size = Vector2(88, 48)
	buy.pressed.connect(func():
		Kit.tick()
		if Game.cash < 0.01:
			Kit.toast("No cash to spend")
			return
		TradeSheet.open("chips", "", "chips_in"))
	Kit.press_fx(buy)
	sr.add_child(buy)
	# The mat, in its own scroll area (a wobbly tap still places a chip).
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UI.box(UI.FELT, 16, 0, 0))
	body.add_child(mp)
	_mat_scroll = ScrollContainer.new()
	_mat_scroll.scroll_deadzone = 10
	_mat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_mat_scroll.custom_minimum_size = Vector2(0, 260)
	mp.add_child(_mat_scroll)
	_mat = Control.new()
	_mat.custom_minimum_size = Vector2(MAT_W, 14.0 * ROW_H + 15.0 * GAP)
	_mat.mouse_filter = Control.MOUSE_FILTER_PASS
	_mat_scroll.add_child(_mat)
	_build_mat()
	# Chips to bet with.
	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 8)
	_chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_chip_row)
	# Actions, Spin biggest and nearest the thumb.
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 6)
	body.add_child(ar)
	_undo_b = _small("Undo", _on_undo)
	ar.add_child(_undo_b)
	_clear_b = _small("Clear", _on_clear)
	ar.add_child(_clear_b)
	_again_b = _small("Rebet", _on_again)
	ar.add_child(_again_b)
	_spin_b = UI.pill("Spin", UI.TEXT, UI.INK, 17, 24)
	_spin_b.custom_minimum_size = Vector2(0, 52)
	_spin_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_b.pressed.connect(_on_spin)
	Kit.press_fx(_spin_b)
	ar.add_child(_spin_b)


func _ready() -> void:
	super()
	# The mat takes whatever height is left above the bottom bar.
	await get_tree().process_frame
	if not is_instance_valid(_mat_scroll):
		return
	var used := body.get_combined_minimum_size().y - _mat_scroll.custom_minimum_size.y
	_mat_scroll.custom_minimum_size.y = maxf(200.0, get_viewport_rect().size.y - 4.0 - 104.0 - used)


func _small(t: String, call: Callable) -> Button:
	var b := UI.pill(t, UI.RAISED, UI.TEXT, 15, 18)
	b.custom_minimum_size = Vector2(64, 52)
	b.pressed.connect(call)
	Kit.press_fx(b)
	return b


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
		_cell("dozen:%d" % (d + 1), Rect2(GAP, rowy.call(1 + d * 4), STRIP_W, tall), ["1-12", "13-24", "25-36"][d], UI.FELT, 12, "dozen", d + 1)
	# Even-money bets, two rows each.
	var two := 2.0 * ROW_H + GAP
	var evens := [["low", "1-18", UI.FELT], ["even", "Even", UI.FELT], ["red", "Red", UI.ROUL_RED],
		["black", "Black", UI.ROUL_BLACK], ["odd", "Odd", UI.FELT], ["high", "19-36", UI.FELT]]
	for i in range(evens.size()):
		var e: Array = evens[i]
		_cell(String(e[0]), Rect2(STRIP_W + GAP * 2.0, rowy.call(1 + i * 2), STRIP_W, two), String(e[1]), e[2], 12, String(e[0]), null)


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
		Kit.toast("Not enough chips · tap + Chips")
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
		m.set_amount(amt, Game.casino_max_bet())


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
		Kit.toast("Not enough chips · tap + Chips")
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
		Kit.toast("Not enough chips · tap + Chips")
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
	_win_l.text = "No more bets"
	_win_l.add_theme_color_override("font_color", UI.SUB)
	refresh()
	_wheel.spin_to(n, func(): _finish(n, paid, total))


func _finish(n: int, paid: float, total: float) -> void:
	if not is_instance_valid(self):
		return
	_spinning = false
	_shown_chips = -1.0
	_history.push_front(n)
	if _history.size() > HISTORY:
		_history.resize(HISTORY)
	_num_l.text = str(n)
	_num_panel.add_theme_stylebox_override("panel", UI.box(_pocket_col(n), 14))
	Motion.pop(_num_panel, 1.1)
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
	if paid > 0.0:
		_win_l.add_theme_color_override("font_color", UI.GOLD)
		var tw := create_tween()
		tw.tween_method(func(v: float): _win_l.text = "Win " + Game.money(v), 0.0, paid, Motion.d(0.8)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		Kit.haptic("success")
		if paid >= total * 10.0:
			Kit.sound("fanfare")
			if not Motion.reduced():
				var c := Confetti.new(_wheel.global_position + _wheel.size * 0.5, 60)
				get_tree().root.get_node("Kit").add_child(c)
	else:
		_win_l.add_theme_color_override("font_color", UI.SUB)
		_win_l.text = "%d · no win" % n
	_draw_history()
	refresh()


func _pocket_col(n: int) -> Color:
	match RouletteMath.color(n):
		"red": return UI.ROUL_RED
		"black": return UI.ROUL_BLACK
	return UI.ROUL_GREEN


func _draw_history() -> void:
	for ch in _hist_box.get_children():
		ch.queue_free()
	for n in _history:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(26, 26)
		p.add_theme_stylebox_override("panel", UI.box(_pocket_col(int(n)), 13))
		var l := UI.label(str(n), 11, UI.TEXT, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		_hist_box.add_child(p)


# ---- chips --------------------------------------------------------------------

static func nice(x: float) -> float:
	## Rounds down to 1, 2 or 5 times a power of ten.
	if x < 1.0:
		return 1.0
	var p := pow(10.0, floor(log(x) / log(10.0)))
	var m := x / p
	return (1.0 if m < 2.0 else (2.0 if m < 5.0 else 5.0)) * p


static func denoms(max_bet: float) -> Array:
	## Five chip values that fit the table limit.
	var out: Array = []
	for f in [0.01, 0.05, 0.1, 0.25, 0.5]:
		var v := nice(max_bet * f)
		if not out.has(v):
			out.append(v)
	return out


static func chip_text(v: float) -> String:
	if v >= 1000.0:
		return Game.money_short(v).substr(1)
	return str(int(v))


func _rebuild_chips() -> void:
	var d := denoms(Game.casino_max_bet())
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
	if _status == null:
		return
	_rebuild_chips()
	var shown := _shown_chips if _shown_chips >= 0.0 else Game.chips()
	_status.text = "On table %s · limit %s\nChips %s" % [Game.money_short(_table_total()), Game.money_short(Game.casino_max_bet()), Game.money(shown)]
	_again_b.text = "Rebet" if _bets.is_empty() else "×2"
	Page.set_enabled(_spin_b, not _spinning and _table_total() > 0.0)


# ---- pieces ---------------------------------------------------------------------

class ChipButton extends Button:
	## A round casino chip you can tap; the chosen one sits up with a ring.
	var value := 1.0
	var tier := 0
	var selected := false

	func _init(v := 1.0, t := 0) -> void:
		value = v
		tier = t
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(52, 52)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5 - Vector2(0, 3.0 if selected else 0.0)
		var r := 22.0
		if selected:
			draw_circle(c + Vector2(0, 3), r + 4.0, UI.GOLD)
		RoulettePage.draw_chip(self, c, r, tier, RoulettePage.chip_text(value))


static func draw_chip(ci: CanvasItem, c: Vector2, r: float, tier: int, text: String) -> void:
	## A flat casino chip: coloured body, light edge marks, inner ring, value.
	var col: Color = UI.CHIP_COL[tier % UI.CHIP_COL.size()]
	var light := tier % UI.CHIP_COL.size() == 0
	ci.draw_circle(c, r, col)
	var mark: Color = UI.INK if light else UI.TEXT
	for i in 6:
		var a := TAU * float(i) / 6.0
		ci.draw_arc(c, r * 0.86, a - 0.16, a + 0.16, 6, mark, r * 0.22, true)
	ci.draw_circle(c, r * 0.64, col)
	ci.draw_arc(c, r * 0.64, 0.0, TAU, 32, Color(mark, 0.6), 1.5, true)
	var f: Font = UI.SEMI
	var fs := int(clampf(r * 0.62, 9.0, 15.0))
	if text.length() > 3:
		fs = int(fs * 0.8)
	ci.draw_string(f, c + Vector2(-r, fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, UI.INK if light else UI.TEXT)


class ChipMark extends Control:
	## The chip stack sitting on a bet, showing how much is on it.
	var amount := 0.0
	var tier := 0

	func _init() -> void:
		size = Vector2(26, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_amount(a: float, max_bet: float) -> void:
		amount = a
		var ds := RoulettePage.denoms(max_bet)
		tier = 0
		for i in range(ds.size()):
			if a >= float(ds[i]):
				tier = i
		queue_redraw()

	func _draw() -> void:
		if amount <= 0.0:
			return
		var c := size * 0.5
		draw_circle(c + Vector2(0, 3), 13.0, Color(UI.INK, 0.5))
		RoulettePage.draw_chip(self, c, 13.0, tier, RoulettePage.chip_text(amount))


class WheelView extends Control:
	## The wheel in real European order. spin_to() turns the wheel one way and
	## runs the ball the other, then drops it into the pocket.
	const SIDE := 168.0
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
		custom_minimum_size = Vector2(SIDE, SIDE)
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
			draw_string(f, Vector2(-8, 3), str(n), HORIZONTAL_ALIGNMENT_CENTER, 16, 8, UI.TEXT)
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
			draw_circle(bp + Vector2(1, 1.5), 5.0, Color(UI.INK, 0.5))
			draw_circle(bp, 5.0, UI.TEXT)
