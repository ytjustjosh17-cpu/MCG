class_name CrashPage
extends Page
## Crash: the multiplier climbs until it crashes; cash out before it does.
## The crash point is fixed before the round starts (CrashMath) and kept in
## Game.ui["crash_round"] with the stake, so closing the app can't re-roll
## it. With an auto cash-out target the result is known at the start and is
## paid at once. A manual cash-out pays the moment you tap; leaving the page
## mid-climb cashes out there. A round left open by closing the app is
## settled as lost when you come back (unless the auto target already paid it).

const TARGETS := [0.0, 1.2, 1.5, 2.0, 3.0, 5.0, 10.0, 25.0, 100.0]   # 0 = off

var _cm := CrashMath.new()
var _graph: Graph
var _status: Label
var _bet: CasinoPage.BetBar
var _go: Button
var _auto_l: Label
var _target_i := 0
var _round := {}          # the live round: crash, stake, target, paid
var _t := 0.0
var _running := false
var _hidden_win := 0.0
var _history: Array = []


func _init() -> void:
	super("Crash", true)


func play_button() -> Button:
	return _go


func finish_for_test() -> void:
	if _running:
		_on_go()   # cash out at once
	await get_tree().create_timer(0.2).timeout


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settle_left_over()
	_graph = Graph.new()
	_graph.custom_minimum_size = Vector2(0, 330)
	body.add_child(_graph)
	_status = CasinoPage.status_row(body)
	# Auto cash-out target: tap to step through the choices.
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 6)
	body.add_child(ar)
	var al := UI.label("Auto cash out", 15, UI.SUB)
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ar.add_child(al)
	var down := UI.pill("-", UI.RAISED, UI.TEXT, 20, 0)
	down.custom_minimum_size = Vector2(52, 52)
	down.pressed.connect(func(): _step_target(-1))
	ar.add_child(down)
	_auto_l = UI.label("", 17, UI.TEXT, true)
	_auto_l.custom_minimum_size = Vector2(72, 0)
	_auto_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_auto_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ar.add_child(_auto_l)
	var up := UI.pill("+", UI.RAISED, UI.TEXT, 20, 0)
	up.custom_minimum_size = Vector2(52, 52)
	up.pressed.connect(func(): _step_target(1))
	ar.add_child(up)
	_bet = CasinoPage.BetBar.new()
	body.add_child(_bet)
	_go = CasinoPage.game_button("Bet", true, _on_go)
	body.add_child(_go)
	_target_i = clampi(int(Game.ui.get("crash_target_i", 0)), 0, TARGETS.size() - 1)
	tree_exiting.connect(_on_leave)


func _on_leave() -> void:
	## Leaving mid-climb cashes out at the current multiplier (if it hasn't crashed).
	if _running:
		_cash_out()
		Game.ui.erase("crash_round")
		Game.save_game()


func _settle_left_over() -> void:
	## A round still open from before the app closed: lost (if not already paid).
	if Game.ui.has("crash_round"):
		var r: Dictionary = Game.ui["crash_round"]
		GameLog.info("casino", "Crash round left open settled (%s)" % ("paid" if bool(r.get("paid", false)) else "lost"))
		Game.ui.erase("crash_round")
		Game.save_game()


func _step_target(d: int) -> void:
	if _running:
		return
	Kit.haptic("selection")
	_target_i = clampi(_target_i + d, 0, TARGETS.size() - 1)
	Game.ui["crash_target_i"] = _target_i
	refresh()


func refresh() -> void:
	if _status == null:
		return
	_bet.locked = _running
	_bet.refresh()
	var tg: float = TARGETS[_target_i]
	_auto_l.text = "Off" if tg <= 0.0 else "%sx" % _fmt(tg)
	_status.text = "Chips %s · limit %s" % [Game.money(Game.chips() - _hidden_win), Game.money_short(Game.casino_max_bet())]
	if _running and not bool(_round.get("paid", false)):
		_go.text = "Cash out · " + Game.money_short(float(_round["stake"]) * CrashMath.at(_t))
	elif _running:
		_go.text = "Cashed out"
	else:
		_go.text = "Bet · " + Game.money_short(_bet.value)
	Page.set_enabled(_go, not (_running and bool(_round.get("paid", false))))


static func _fmt(x: float) -> String:
	return ("%.2f" % x) if x < 10.0 else ("%.1f" % x if x < 100.0 else "%d" % int(x))


func _on_go() -> void:
	if _running:
		_cash_out()
		return
	_bet.refresh()
	var bet := _bet.value
	if bet > Game.chips() + 0.001:
		Kit.toast("Not enough chips")
		Motion.shake(_go)
		return
	var crash := _cm.roll()
	var target: float = TARGETS[_target_i]
	_round = {"crash": crash, "stake": bet, "target": target, "paid": false}
	Game.ui["crash_round"] = _round   # saved with the stake, so it can't re-roll
	if not Game.casino_stake(bet):
		Game.ui.erase("crash_round")
		Kit.toast("Over the table limit")
		Motion.shake(_go)
		return
	Kit.sound("tap")
	if target > 0.0 and crash >= target:
		# Known now: pay at once, then show the climb.
		_hidden_win = Game.casino_pay(bet * target)
		_round["paid"] = true
		_round["paid_at"] = target
		Game.save_game()
	_t = 0.0
	_running = true
	_graph.start(crash)
	refresh()


func _cash_out() -> void:
	if bool(_round.get("paid", false)):
		return
	var m := CrashMath.at(_t)
	if m >= float(_round["crash"]):
		return   # too late: it already crashed
	var got := Game.casino_pay(float(_round["stake"]) * m)
	_round["paid"] = true
	_round["paid_at"] = m
	Game.save_game()
	Kit.haptic("success")
	Kit.sound("buy")
	_graph.cashed = m
	Kit.toast("Cashed out at %sx · +%s" % [_fmt(m), Game.money_short(got)])
	refresh()


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	var m := CrashMath.at(_t)
	var crash := float(_round["crash"])
	var paid_at := float(_round.get("paid_at", 0.0))
	if paid_at > 0.0 and _graph.cashed <= 0.0 and m >= paid_at:
		_graph.cashed = paid_at   # the auto cash-out point goes past
		_hidden_win = 0.0
		Kit.haptic("success")
		Kit.sound("buy")
	if m >= crash:
		_finish()
		return
	_graph.now = m
	_graph.queue_redraw()
	refresh()


func _finish() -> void:
	var crash := float(_round["crash"])
	_running = false
	_hidden_win = 0.0
	_graph.now = crash
	_graph.crashed = true
	_graph.queue_redraw()
	if not bool(_round.get("paid", false)):
		Kit.haptic("error")
	_history.push_front(crash)
	if _history.size() > 8:
		_history.pop_back()
	_graph.history = _history
	Game.ui.erase("crash_round")
	Game.save_game()
	Game.flush_changes()
	refresh()


class Graph extends Control:
	## The climbing curve, the big multiplier, and the last few crash points.
	var now := 1.0
	var crash := 0.0
	var crashed := false
	var cashed := 0.0
	var history: Array = []

	func start(c: float) -> void:
		crash = c
		now = 1.0
		crashed = false
		cashed = 0.0
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UI.INK)
		var top := maxf(2.0, now * 1.15)
		var pad := Vector2(16, 40)
		var w := size.x - pad.x * 2.0
		var h := size.y - pad.y - 56.0
		# Grid lines at round multipliers.
		var f: Font = UI.SEMI
		for gm in [1.0, 2.0, 5.0, 10.0, 25.0, 100.0, 250.0, 1000.0]:
			if gm > top:
				break
			var gy: float = pad.y + h - h * (float(gm) - 1.0) / (top - 1.0)
			draw_line(Vector2(pad.x, gy), Vector2(pad.x + w, gy), Color(UI.TEXT, 0.06), 1.0)
			draw_string(f, Vector2(pad.x + w - 40, gy - 4), "%sx" % CrashPage._fmt(gm), HORIZONTAL_ALIGNMENT_RIGHT, 40, 11, UI.DIM)
		# The curve so far.
		var tt := CrashMath.time_to(now)
		var pts := PackedVector2Array()
		var steps := 40
		for i in steps + 1:
			var s := tt * float(i) / float(steps)
			var m := CrashMath.at(s)
			pts.append(Vector2(pad.x + w * (float(i) / float(steps)), pad.y + h - h * (m - 1.0) / (top - 1.0)))
		var col: Color = UI.RED if crashed else UI.GOLD
		if pts.size() > 1:
			draw_polyline(pts, col, 3.0, true)
			draw_circle(pts[pts.size() - 1], 5.0, col)
		# The big number.
		var big := "%sx" % CrashPage._fmt(now)
		draw_string(UI.DISPLAY, Vector2(0, pad.y + h * 0.45), big, HORIZONTAL_ALIGNMENT_CENTER, size.x, 56, UI.RED if crashed else UI.TEXT)
		var sub := ""
		if crashed:
			sub = "Crashed" + (" · you cashed out at %sx" % CrashPage._fmt(cashed) if cashed > 0.0 else "")
		elif cashed > 0.0:
			sub = "Cashed out at %sx" % CrashPage._fmt(cashed)
		elif crash > 0.0:
			sub = "Climbing..."
		draw_string(f, Vector2(0, pad.y + h * 0.45 + 30), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, UI.GOLD if cashed > 0.0 else UI.SUB)
		# Last crash points along the bottom.
		var x := 12.0
		for v in history:
			var t := "%sx" % CrashPage._fmt(float(v))
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
			if x + tw > size.x - 8.0:
				break
			draw_rect(Rect2(Vector2(x, size.y - 40), Vector2(tw, 28)), UI.RAISED if float(v) >= 2.0 else UI.PANEL)
			draw_string(f, Vector2(x, size.y - 21), t, HORIZONTAL_ALIGNMENT_CENTER, tw, 13, UI.GOLD if float(v) >= 2.0 else UI.SUB)
			x += tw + 6.0
