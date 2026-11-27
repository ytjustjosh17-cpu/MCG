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
				draw_colored_polygon(UI.rounded_rect_poly(c, 10.0), col)
				if live and row == step:
					draw_polyline(UI.rounded_rect_poly(c, 10.0), Color(UI.TEXT, 0.5), 1.5, true)
				var mid := c.get_center()
				var r := minf(c.size.x, c.size.y) * 0.18
				if mark == "safe":
					draw_circle(mid, r, UI.GOLD)
				elif mark == "bad":
					draw_line(mid - Vector2(r, r), mid + Vector2(r, r), UI.TEXT, 3.0, true)
					draw_line(mid + Vector2(-r, r), mid + Vector2(r, -r), UI.TEXT, 3.0, true)
				elif reveal and bad_here:
					draw_line(mid - Vector2(r, r), mid + Vector2(r, r), Color(UI.TEXT, 0.5), 2.0, true)
					draw_line(mid + Vector2(-r, r), mid + Vector2(r, -r), Color(UI.TEXT, 0.5), 2.0, true)
		# The ladder: each row's cash-out, your step in gold, the next one bright.
		var lx := size.x - LADDER_W
		var rh := size.y / float(_rows())
		for row in _rows():
			var k := row + 1
			var y := size.y - rh * float(row + 1)
			var r2 := Rect2(Vector2(lx, y + 3.0), Vector2(LADDER_W, rh - 6.0))
			var reached := not rnd.is_empty() and k <= step
			var next := live and k == step + 1
			if reached and k == step:
				draw_colored_polygon(UI.rounded_rect_poly(r2, 10.0), UI.RAISED)
			var m := TowerMath.mult(mode, k)
			var t := "×" + TowerPage._num(m)
			var tc: Color = UI.GOLD if reached else (UI.TEXT if next else UI.SUB)
			var fs := 15 if rh >= 40.0 else 13
			draw_string(f, Vector2(lx, r2.get_center().y + fs * 0.35), t, HORIZONTAL_ALIGNMENT_CENTER, LADDER_W, fs, tc)
		if rnd.is_empty():
			draw_string(f, Vector2(0, size.y * 0.5), "Bet, then pick a box", HORIZONTAL_ALIGNMENT_CENTER, _grid().size.x, 15, UI.SUB)
