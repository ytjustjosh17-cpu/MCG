class_name RacePage
extends Page
## Races: six made-up cars with odds that change every race. Pick one, bet,
## and watch. The finishing order is drawn at the start (RaceMath) and a win
## is paid at once; the race then plays out to match. Leaving early changes
## nothing (the result was already settled).

var _rm := RaceMath.new()
var _track: Track
var _list: GridContainer
var _rows: Array = []
var _status: Label
var _result: Label
var _bet: CasinoPage.BetBar
var _go: Button
var _pick := 0
var _racing := false
var _hidden_win := 0.0


func _init() -> void:
	super("Races", true)


func play_button() -> Button:
	return _go


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_track = Track.new()
	_track.custom_minimum_size = Vector2(0, 196)
	_track.finished.connect(_on_finished)
	body.add_child(_track)
	_result = UI.label("Pick a car", 15, UI.SUB)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_result)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	body.add_child(pc)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 0)
	_list.add_theme_constant_override("v_separation", 0)
	pc.add_child(_list)
	for i in RaceMath.RUNNERS.size():
		var b := RunnerRow.new(i)
		b.pressed.connect(func():
			if _racing:
				return
			Kit.haptic("selection")
			_pick = b.index
			_paint_rows())
		_list.add_child(b)
		_rows.append(b)
	_status = CasinoPage.status_row(body)
	_bet = CasinoPage.BetBar.new()
	body.add_child(_bet)
	_go = CasinoPage.game_button("Race", true, _on_go)
	body.add_child(_go)
	_paint_rows()


func _paint_rows() -> void:
	for r in _rows:
		var rr := r as RunnerRow
		rr.odds = float(_rm.odds[rr.index])
		rr.picked = rr.index == _pick
		rr.queue_redraw()


func refresh() -> void:
	if _status == null:
		return
	_bet.locked = _racing
	_bet.refresh()
	_status.text = "Chips %s · limit %s" % [Game.money(Game.chips() - _hidden_win), Game.money_short(Game.casino_max_bet())]
	var name: String = RaceMath.RUNNERS[_pick][0]
	_go.text = "Racing..." if _racing else "Back %s · %s" % [name, Game.money_short(_bet.value)]
	Page.set_enabled(_go, not _racing)


func _on_go() -> void:
	if _racing:
		return
	_bet.refresh()
	var bet := _bet.value
	if bet > Game.chips() + 0.001:
		Kit.toast("Not enough chips")
		Motion.shake(_go)
		return
	if not Game.casino_stake(bet):
		Kit.toast("Over the table limit")
		Motion.shake(_go)
		return
	var order := _rm.run()
	var odds := float(_rm.odds[_pick])
	var won: bool = int(order[0]) == _pick
	var paid := Game.casino_pay(bet * odds) if won else 0.0   # paid and saved before the race runs
	Kit.sound("tap")
	_racing = true
	_hidden_win = paid
	_result.text = "And they're off"
	_track.run(order, Motion.reduced())
	_track.set_meta("res", [won, paid, order])
	refresh()


func _on_finished() -> void:
	var res: Array = _track.get_meta("res", [false, 0.0, []])
	_racing = false
	_hidden_win = 0.0
	var winner: String = RaceMath.RUNNERS[int(res[2][0])][0]
	if bool(res[0]):
		_result.text = "%s wins · +%s" % [winner, Game.money_short(float(res[1]))]
		Kit.haptic("success")
		Kit.sound("fanfare")
	else:
		_result.text = "%s wins" % winner
		Kit.haptic("light")
	_rm.new_form()   # new odds for the next race
	_paint_rows()
	Game.flush_changes()
	refresh()


static func car_color(i: int) -> Color:
	var cols := [UI.RED, UI.GOLD, UI.SLOT_COL["wild"], UI.TEXT, UI.SLOT_COL["scatter"], UI.UP]
	return cols[i % cols.size()]


static func draw_car(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	## A low racing car seen from the side, nose to the right; p = middle of its base.
	var w := 46.0 * s
	var h := 12.0 * s
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(-w * 0.5, 0), p + Vector2(-w * 0.5, -h * 0.7), p + Vector2(-w * 0.15, -h * 0.8),
		p + Vector2(0, -h * 1.5), p + Vector2(w * 0.22, -h * 1.5), p + Vector2(w * 0.32, -h * 0.8),
		p + Vector2(w * 0.5, -h * 0.5), p + Vector2(w * 0.5, 0)]), col)
	ci.draw_rect(Rect2(p + Vector2(w * 0.02, -h * 1.35), Vector2(w * 0.17, h * 0.45)), UI.INK)
	for wx in [-0.3, 0.3]:
		ci.draw_circle(p + Vector2(w * wx, 0), h * 0.42, UI.INK)
		ci.draw_circle(p + Vector2(w * wx, 0), h * 0.16, UI.SUB)


class RunnerRow extends Button:
	var index := 0
	var odds := 1.0
	var picked := false

	func _init(i := 0) -> void:
		index = i
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(0, 52)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		if picked:
			draw_rect(Rect2(Vector2(4, 3), size - Vector2(8, 6)), UI.RAISED)
			draw_rect(Rect2(Vector2(4, 3), Vector2(3, size.y - 6)), UI.GOLD)
		RacePage.draw_car(self, Vector2(28, size.y * 0.62), 0.55, RacePage.car_color(index))
		var f: Font = UI.SEMI
		draw_string(f, Vector2(56, size.y * 0.44), String(RaceMath.RUNNERS[index][0]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 14, UI.TEXT)
		draw_string(f, Vector2(56, size.y * 0.82), "pays x%.2f" % odds, HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 12, UI.GOLD if picked else UI.SUB)


class Track extends Control:
	## Six lanes; each car's finishing time follows the drawn order.
	signal finished
	const BASE_S := 5.0
	var _order: Array = []
	var _finish_t: Array = []
	var _t := 0.0
	var _running := false
	var _phase: Array = []

	func run(order: Array, instant: bool) -> void:
		_order = order
		_finish_t = []
		_phase = []
		for i in 6:
			_finish_t.append(0.0)
			_phase.append(randf() * TAU)
		for place in order.size():
			_finish_t[int(order[place])] = BASE_S + float(place) * 0.28 + randf() * 0.1
		_t = 0.0
		_running = true
		set_process(true)
		if instant:
			_t = BASE_S + 2.0
			_running = false
			queue_redraw()
			finished.emit.call_deferred()

	func _process(delta: float) -> void:
		if not _running:
			set_process(false)
			return
		_t += delta
		var last := 0.0
		for v in _finish_t:
			last = maxf(last, float(v))
		if _t >= last + 0.4:
			_running = false
			finished.emit()
		queue_redraw()

	func _progress(i: int) -> float:
		if _finish_t.is_empty():
			return 0.0
		var T := float(_finish_t[i])
		var x := clampf(_t / T, 0.0, 1.0)
		# Uneven pace (surges and fades) that still ends at the finish on time.
		return clampf(x + sin(x * PI) * 0.06 * sin(_t * 1.7 + float(_phase[i])), 0.0, 1.0)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UI.INK)
		var lane_h := (size.y - 16.0) / 6.0
		var x0 := 34.0
		var x1 := size.x - 30.0
		# Finish line: a chequer of light and dark.
		for k in int(size.y / 8.0):
			draw_rect(Rect2(Vector2(x1 + 4.0 + float(k % 2) * 4.0, 8.0 + float(k) * 8.0 - 8.0), Vector2(4, 8)), UI.TEXT if k % 2 == 0 else UI.SIDE)
		for i in 6:
			var y := 8.0 + lane_h * float(i)
			draw_line(Vector2(0, y + lane_h), Vector2(size.x, y + lane_h), UI.TRACK, 1.0)
			var px := lerpf(x0, x1 - 20.0, _progress(i))
			RacePage.draw_car(self, Vector2(px, y + lane_h * 0.78), 0.7, RacePage.car_color(i))
		if not _running and not _order.is_empty():
			var f: Font = UI.SEMI
			for place in mini(3, _order.size()):
				var i := int(_order[place])
				var y := 8.0 + lane_h * float(i)
				draw_string(f, Vector2(6, y + lane_h * 0.7), str(place + 1), HORIZONTAL_ALIGNMENT_LEFT, 20, 14, UI.GOLD if place == 0 else UI.SUB)
