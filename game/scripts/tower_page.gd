class_name TowerPage
extends CasinoGame
## Tower: bet once, then climb. Each row has a bad box (or two on Hard); pick
## a safe one to go up a row, cash out between rows, or lose the stake on a
## bad one. The whole tower is laid out when you bet (TowerMath) and kept in
## Game.ui["tower_round"] with the stake and your picks, so leaving the page
## or closing the app never re-rolls it: the round waits for you to come back.
## Money: stake when you start, pay when you cash out (or reach the top).

var _tm := TowerMath.new()
var _board: Board
var _bet: BetBar
var _go: Button
var _seg: Segmented
var _mode := "easy"


func _init() -> void:
	super("Tower", true)


func play_button() -> Button:
	return _go


func build_game() -> void:
	add_results_strip("tower")
	_board = Board.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.picked.connect(_on_pick)
	area.add_child(_board)
	_bet = BetBar.new()
	dock.add_child(_bet)
	_seg = Segmented.new(["Easy", "Medium", "Hard"])
	_seg.index = clampi(int(Game.ui.get("tower_mode", 0)), 0, 2)
	_seg.select(_seg.index)
	_seg.changed.connect(func(i: int):
		if _live():
			_seg.select(TowerMath.ORDER.find(_mode))
			Kit.toast("Finish this climb first")
			return
		Game.ui["tower_mode"] = i
		_mode = TowerMath.ORDER[i]
		_board.show_empty(_mode)
		refresh())
	dock.add_child(_seg)
	_mode = TowerMath.ORDER[_seg.index]
	_go = primary("Start", _on_go)
	dock.add_child(_go)
	# A climb left open (page closed or app restarted) carries on where it was.
	if _live():
		var r: Dictionary = Game.ui["tower_round"]
		_mode = String(r["mode"])
		_seg.select(TowerMath.ORDER.find(_mode))
		_board.show_round(r, false)
	else:
		_board.show_empty(_mode)


func info_content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(note("Bet once, then climb. Each row hides a bad box: pick a safe one to go up a row and the prize grows. Cash out between rows, or lose the bet on a bad box. Reach the top and it cashes out for you.", UI.TEXT))
	for m in TowerMath.ORDER:
		var d := TowerMath.mode(m)
		box.add_child(pay_line(String(d["name"]), "%d rows · %d of %d boxes safe · top ×%s" % [int(d["rows"]), int(d["boxes"]) - int(d["bad"]), int(d["boxes"]), _num(TowerMath.mult(m, int(d["rows"])))], m == _mode))
	box.add_child(note("The tower is set when you bet, and a climb you leave waits for you. Pays back about 97% over time."))
	return box


static func _num(x: float) -> String:
	return ("%.2f" % x) if x < 10.0 else ("%.1f" % x if x < 100.0 else "%d" % int(x))


func _live() -> bool:
	return Game.ui.has("tower_round") and typeof(Game.ui["tower_round"]) == TYPE_DICTIONARY and not bool(Game.ui["tower_round"].get("over", false))


func _round() -> Dictionary:
	return Game.ui["tower_round"] if _live() else {}


func refresh() -> void:
	if _go == null:
		return
	var live := _live()
	_bet.locked = live
	_bet.refresh()
	_seg.modulate.a = 0.4 if live else 1.0
	status.set_chips(Game.chips())
	var stake := float(_round().get("stake", _bet.value)) if live else _bet.value
	_board.stake = stake
	_board.queue_redraw()
	if not live:
		_go.text = "Start · " + Game.money_short(_bet.value)
		set_go(_go, true)
		return
	var step := int(_round()["step"])
	if step <= 0:
		_go.text = "Pick a box"
		set_go(_go, false)
	else:
		_go.text = "Cash out · " + Game.money_short(stake * TowerMath.mult(_mode, step))
		set_go(_go, true, true)


func _on_go() -> void:
	if _live():
		if int(_round()["step"]) <= 0:
			Kit.toast("Pick a box in the bottom row")
			Motion.shake(_go)
			return
		_cash_out()
		return
	_bet.refresh()
	var bet := _bet.value
	if bet > Game.chips() + 0.001:
		Kit.toast("Not enough chips")
		Motion.shake(_go)
		offer_chips()
		return
	var layout := _tm.roll_layout(_mode)
	var r := {"mode": _mode, "stake": bet, "layout": layout, "step": 0, "picks": [], "over": false}
	Game.ui["tower_round"] = r   # saved with the stake, so it can't re-roll
	if not Game.casino_stake(bet):
		Game.ui.erase("tower_round")
		Kit.toast("Over the table limit")
		Motion.shake(_go)
		return
	Kit.sound("tap")
	status.clear_win()
	_board.show_round(r, false)
	refresh()


func _on_pick(box: int) -> void:
	if not _live() or box < 0:
		if _go != null:
			Motion.shake(_go)
			Kit.toast("Bet first, then pick a box")
		return
	var r: Dictionary = Game.ui["tower_round"]
	var row := int(r["step"])
	var picks: Array = r["picks"]
	picks.append(box)
	r["picks"] = picks
	if TowerMath.is_safe(r["layout"], row, box):
		r["step"] = row + 1
		Kit.haptic("selection")
		Kit.sound("tap")
		if int(r["step"]) >= int(TowerMath.mode(_mode)["rows"]):
			_cash_out()   # the top: cash out for you
			return
		Game.save_game()
		_board.show_round(r, false)
	else:
		r["over"] = true
		Game.save_game()
		_board.show_round(r, true)
		win_fx(0.0, float(r["stake"]))
		record_result(float(r["stake"]), 0.0)
		Game.ui.erase("tower_round")
		Game.save_game()
		Game.flush_changes()
	refresh()


func _cash_out() -> void:
	var r: Dictionary = Game.ui["tower_round"]
	var stake := float(r["stake"])
	var got := Game.casino_pay(stake * TowerMath.mult(String(r["mode"]), int(r["step"])))
	r["over"] = true
	Game.ui.erase("tower_round")
	Game.save_game()
	_board.show_round(r, true)
	win_fx(got, stake)
	record_result(stake, got)
	Game.flush_changes()
	refresh()


func finish_for_test() -> void:
	## Tests: one safe pick (from the known layout) and cash out.
	if _live():
		var r: Dictionary = Game.ui["tower_round"]
		var bad: Array = r["layout"][int(r["step"])]
		for b in int(TowerMath.mode(String(r["mode"]))["boxes"]):
			if not bad.has(b):
				_on_pick(b)
				break
		if _live():
			_on_go()
	await get_tree().create_timer(0.2).timeout


func layout_changed_game(_landscape: bool) -> void:
	if _board != null:
		_board.queue_redraw()


class Board extends Control:
	## The tower: rows from the bottom up, the row you're on lit, picked boxes
	## shown, and the prize ladder down the right side with your step in gold.
	signal picked(box: int)
	const LADDER_W := 96.0
	const GAP := 8.0
	var mode := "easy"
	var rnd := {}          # the round being shown (layout, picks, step)
	var reveal := false    # show every bad box (the round is over)
	var stake := 0.0
	var _down := Vector2.INF

	func show_empty(m: String) -> void:
		mode = m
		rnd = {}
		reveal = false
		queue_redraw()

	func show_round(r: Dictionary, show_all: bool) -> void:
		mode = String(r["mode"])
		rnd = r
		reveal = show_all
		queue_redraw()

	func _rows() -> int:
		return int(TowerMath.mode(mode)["rows"])

	func _boxes() -> int:
		return int(TowerMath.mode(mode)["boxes"])

	func _grid() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(maxf(60.0, size.x - LADDER_W - GAP), size.y))

	func _cell(row: int, box: int) -> Rect2:
		## Row 0 is at the bottom.
		var g := _grid()
		var rh := g.size.y / float(_rows())
		var bw := g.size.x / float(_boxes())
		var y := g.end.y - rh * float(row + 1)
		return Rect2(Vector2(g.position.x + bw * float(box) + 3.0, y + 3.0), Vector2(bw - 6.0, rh - 6.0))

	func _gui_input(e: InputEvent) -> void:
		if not (e is InputEventMouseButton) or e.button_index != MOUSE_BUTTON_LEFT:
			return
		if e.pressed:
			_down = e.position
			return
		if _down == Vector2.INF or e.position.distance_to(_down) > 14.0:
			_down = Vector2.INF
			return   # a drag, not a tap
		_down = Vector2.INF
		if rnd.is_empty() or reveal:
			picked.emit(-1)   # no climb going: the page says "bet first"
			return
		var row := int(rnd["step"])
		var g := _grid()
		var rh := g.size.y / float(_rows())
		var bw := g.size.x / float(_boxes())
		for b in _boxes():
			# The whole slot takes the tap, gaps included (rows can be ~40 px).
			if Rect2(Vector2(g.position.x + bw * float(b), g.end.y - rh * float(row + 1)), Vector2(bw, rh)).has_point(e.position):
				accept_event()
				picked.emit(b)
				return

	func _draw() -> void:
		var f: Font = UI.SEMI
		var step := int(rnd.get("step", 0))
		var picks: Array = rnd.get("picks", [])
		var layout: Array = rnd.get("layout", [])
		var live := not rnd.is_empty() and not reveal
		for row in _rows():
			for b in _boxes():
				var c := _cell(row, b)
				var col: Color = UI.PANEL
				var mark := ""
				var picked_here := row < picks.size() and int(picks[row]) == b
				var bad_here := row < layout.size() and (layout[row] as Array).has(b)
				if picked_here and not bad_here:
					col = UI.TRACK
					mark = "safe"
				elif picked_here and bad_here:
					col = Color(UI.RED, 0.85)
					mark = "bad"
				elif reveal and bad_here:
					col = Color(UI.RED, 0.25)
				elif live and row == step:
					col = UI.RAISED
				_tile(c, col, live and row == step)
				var mid := c.get_center()
				var r := minf(c.size.x, c.size.y) * 0.18
				if mark == "safe":
					_gem(mid, r * 1.3)
				elif mark == "bad":
					# A cracked tile: a jagged split and a red X.
					draw_polyline(PackedVector2Array([c.position + Vector2(c.size.x * 0.3, 2), mid + Vector2(-r * 0.3, -r * 0.4),
						mid + Vector2(r * 0.2, r * 0.1), Vector2(c.position.x + c.size.x * 0.62, c.end.y - 2)]), Color(UI.INK, 0.6), 2.0, true)
					draw_line(mid - Vector2(r, r), mid + Vector2(r, r), UI.TEXT, 3.0, true)
					draw_line(mid + Vector2(-r, r), mid + Vector2(r, -r), UI.TEXT, 3.0, true)
				elif reveal and bad_here:
					draw_line(mid - Vector2(r, r), mid + Vector2(r, r), Color(UI.TEXT, 0.5), 2.0, true)
					draw_line(mid + Vector2(-r, r), mid + Vector2(r, -r), Color(UI.TEXT, 0.5), 2.0, true)
		# The ladder: each row's cash-out, your step in gold, the next one bright,
		# on its own recessed panel with rungs between the steps.
		var lx := size.x - LADDER_W
		var rh := size.y / float(_rows())
		var lp := Rect2(Vector2(lx - 2.0, 0), Vector2(LADDER_W + 2.0, size.y))
		draw_colored_polygon(UI.rounded_rect_poly(lp, 12.0), UI.SIDE)
		draw_polyline(UI.rounded_rect_poly(lp.grow(-0.5), 11.5), Color(UI.TEXT, 0.06), 1.0, true)
		for row in range(1, _rows()):
			var ry := size.y - rh * float(row)
			draw_line(Vector2(lx + 10.0, ry), Vector2(lx + LADDER_W - 10.0, ry), Color(UI.TEXT, 0.06), 1.0)
		for row in _rows():
			var k := row + 1
			var y := size.y - rh * float(row + 1)
			var r2 := Rect2(Vector2(lx, y + 3.0), Vector2(LADDER_W, rh - 6.0))
			var reached := not rnd.is_empty() and k <= step
			var next := live and k == step + 1
			if reached and k == step:
				draw_colored_polygon(UI.rounded_rect_poly(r2.grow(-2.0), 9.0), Color(UI.GOLD, 0.18))
				draw_polyline(UI.rounded_rect_poly(r2.grow(-2.0), 9.0), Color(UI.GOLD, 0.6), 1.2, true)
			var m := TowerMath.mult(mode, k)
			var t := "×" + TowerPage._num(m)
			var tc: Color = UI.GOLD if reached else (UI.TEXT if next else UI.SUB)
			var fs := 15 if rh >= 40.0 else 13
			draw_string(f, Vector2(lx, r2.get_center().y + fs * 0.35), t, HORIZONTAL_ALIGNMENT_CENTER, LADDER_W, fs, tc)
		if rnd.is_empty():
			draw_string(f, Vector2(0, size.y * 0.5), "Bet, then pick a box", HORIZONTAL_ALIGNMENT_CENTER, _grid().size.x, 15, UI.SUB)

	func _tile(c: Rect2, col: Color, lit: bool) -> void:
		## A glassy box: shadow, a darker base, the face, and a lit top lip.
		draw_colored_polygon(UI.rounded_rect_poly(Rect2(c.position + Vector2(0, 3), c.size), 10.0), Color(UI.INK, 0.45))
		draw_colored_polygon(UI.rounded_rect_poly(c, 10.0), col.darkened(0.25))
		draw_colored_polygon(UI.rounded_rect_poly(Rect2(c.position, c.size - Vector2(0, 3)), 10.0), col)
		draw_line(c.position + Vector2(8, 2), Vector2(c.end.x - 8, c.position.y + 2), Color(UI.TEXT, 0.16 if not lit else 0.4), 1.2, true)
		if lit:
			draw_polyline(UI.rounded_rect_poly(c, 10.0), Color(UI.TEXT, 0.55), 1.5, true)

	func _gem(p: Vector2, r: float) -> void:
		## A small cut gem: crown and pavilion facets with one bright face.
		var top := p + Vector2(0, -r * 0.55)
		var l := p + Vector2(-r, -r * 0.1)
		var rr := p + Vector2(r, -r * 0.1)
		var bot := p + Vector2(0, r * 0.95)
		draw_circle(p + Vector2(0, r * 0.2), r * 1.4, Color(UI.GOLD, 0.15))
		draw_colored_polygon(PackedVector2Array([l, p + Vector2(-r * 0.55, -r * 0.55), p + Vector2(r * 0.55, -r * 0.55), rr]), UI.GOLD.lightened(0.15))
		draw_colored_polygon(PackedVector2Array([l, rr, bot]), UI.GOLD.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([l, p + Vector2(0, -r * 0.1), bot]), UI.GOLD)
		draw_line(top + Vector2(-r * 0.3, 0), top + Vector2(r * 0.1, 0), Color(UI.TEXT, 0.8), 1.2, true)
