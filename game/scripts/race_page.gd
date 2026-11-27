class_name RacePage
extends CasinoGame
## Races: six made-up cars with odds that change every race. Pick one, bet,
## and watch. The finishing order is drawn at the start (RaceMath) and a win
## is paid at once; the race then plays out to match. Leaving early changes
## nothing (the result was already settled).
## Cars are tonal and numbered; only your pick is red.

var _rm := RaceMath.new()
var _track: Track
var _list: GridContainer
var _rows: Array = []
var _result: Label
var _bet: BetBar
var _go: Button
var _pick := 0
var _racing := false
var _hidden_win := 0.0
var _stake := 0.0


func _init() -> void:
	super("Races", true)


func play_button() -> Button:
	return _go


func build_game() -> void:
	_track = Track.new()
	_track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track.finished.connect(_on_finished)
	area.add_child(_track)
	_result = UI.label("Pick a car", 15, UI.SUB, true)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area.add_child(_result)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	area.add_child(pc)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 0)
	_list.add_theme_constant_override("v_separation", 0)
	pc.add_child(_list)
	for i in RaceMath.RUNNERS.size():
		var b := RunnerRow.new(i)
		b.pressed.connect(func():
			if _racing:
				Motion.shake(b)
				return
			Kit.haptic("selection")
			_pick = b.index
			_paint_rows())
		_list.add_child(b)
		_rows.append(b)
	_bet = BetBar.new()
	dock.add_child(_bet)
	_go = primary("Race", _on_go)
	dock.add_child(_go)
	_paint_rows()


func info_content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(note("Six cars race. Back one: if it wins you get your bet times its odds (the odds include your bet). The odds change every race with each car's form.", UI.TEXT))
	box.add_child(note("The order is drawn when you bet. Every car pays back 95% over time, whichever you pick."))
	return box


func _paint_rows() -> void:
	for r in _rows:
		var rr := r as RunnerRow
		rr.odds = float(_rm.odds[rr.index])
		rr.picked = rr.index == _pick
		rr.queue_redraw()
	_track.pick = _pick
	_track.queue_redraw()


func refresh() -> void:
	if _go == null:
		return
	_bet.locked = _racing
	_bet.refresh()
	status.set_chips(Game.chips() - _hidden_win)
	var name: String = RaceMath.RUNNERS[_pick][0]
	_go.text = "Racing" if _racing else "Back %s · %s" % [name, Game.money_short(_bet.value)]
	set_go(_go, not _racing)


func _on_go() -> void:
	if _racing:
		return
	_bet.refresh()
	var bet := _bet.value
	if bet > Game.chips() + 0.001:
		Kit.toast("Not enough chips")
		Motion.shake(_go)
		offer_chips()
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
	_stake = bet
	status.clear_win()
	_result.text = "And they're off"
	_result.add_theme_color_override("font_color", UI.SUB)
	_track.run(order, Motion.reduced())
	_track.set_meta("res", [won, paid, order])
	refresh()


func _on_finished() -> void:
	var res: Array = _track.get_meta("res", [false, 0.0, []])
	_racing = false
	_hidden_win = 0.0
	var winner: String = RaceMath.RUNNERS[int(res[2][0])][0]
	if bool(res[0]):
		_result.text = "%s wins, you win" % winner
		_result.add_theme_color_override("font_color", UI.GOLD)
	else:
		_result.text = "%s wins" % winner
		_result.add_theme_color_override("font_color", UI.TEXT)
	win_fx(float(res[1]), _stake, 5.0)
	_rm.new_form()   # new odds for the next race
	_paint_rows()
	Game.flush_changes()
	refresh()


static func car_color(i: int, picked := false) -> Color:
	## Tonal cars, told apart by their numbers; your pick is the red one.
	if picked:
		return UI.RED
	var cols := [UI.TEXT, UI.GOLD, UI.SUB, UI.FELT_LINE, UI.UP, UI.DIM]
	return cols[i % cols.size()]


static func draw_car(ci: CanvasItem, p: Vector2, s: float, col: Color, n := 0) -> void:
	## A low racing car seen from the side, nose to the right; p = middle of its
	## base. Shadow, two-tone body with a lit top line, a spoiler, the driver's
	## helmet in the cockpit, a number roundel and wheels with rims.
	var w := 46.0 * s
	var h := 12.0 * s
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.52, h * 0.25), p + Vector2(w * 0.55, h * 0.25),
		p + Vector2(w * 0.45, h * 0.45), p + Vector2(-w * 0.45, h * 0.45)]), Color(UI.INK, 0.45))   # shadow on the track
	# Spoiler at the back.
	ci.draw_rect(Rect2(p + Vector2(-w * 0.52, -h * 1.25), Vector2(w * 0.13, h * 0.22)), col.darkened(0.3))
	ci.draw_line(p + Vector2(-w * 0.46, -h * 1.05), p + Vector2(-w * 0.44, -h * 0.7), col.darkened(0.3), maxf(1.0, s * 2.0))
	var body := PackedVector2Array([
		p + Vector2(-w * 0.5, 0), p + Vector2(-w * 0.5, -h * 0.7), p + Vector2(-w * 0.15, -h * 0.8),
		p + Vector2(0, -h * 1.5), p + Vector2(w * 0.22, -h * 1.5), p + Vector2(w * 0.32, -h * 0.8),
		p + Vector2(w * 0.5, -h * 0.5), p + Vector2(w * 0.5, 0)])
	ci.draw_colored_polygon(body, col)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.5, 0), p + Vector2(-w * 0.5, -h * 0.3),
		p + Vector2(w * 0.5, -h * 0.25), p + Vector2(w * 0.5, 0)]), col.darkened(0.3))   # darker sill
	ci.draw_polyline(PackedVector2Array([p + Vector2(-w * 0.48, -h * 0.7), p + Vector2(-w * 0.15, -h * 0.8),
		p + Vector2(w * 0.32, -h * 0.8), p + Vector2(w * 0.5, -h * 0.5)]), Color(UI.TEXT, 0.45), maxf(1.0, s * 1.2), true)   # lit top line
	# Cockpit glass and the driver's helmet.
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(w * 0.02, -h * 1.42), p + Vector2(w * 0.2, -h * 1.42),
		p + Vector2(w * 0.27, -h * 0.9), p + Vector2(w * 0.02, -h * 0.9)]), UI.INK)
	ci.draw_circle(p + Vector2(w * 0.1, -h * 1.12), h * 0.24, UI.TEXT.lerp(col, 0.3))
	# Number roundel on the side (only when the car is big enough to read it).
	if n > 0 and h >= 10.0:
		ci.draw_circle(p + Vector2(-w * 0.2, -h * 0.5), h * 0.36, UI.TEXT)
		ci.draw_string(UI.SEMI, p + Vector2(-w * 0.2 - 8.0, -h * 0.5 + h * 0.18), str(n), HORIZONTAL_ALIGNMENT_CENTER, 16, int(clampf(h * 0.6, 7.0, 11.0)), UI.INK)
	for wx in [-0.3, 0.3]:
		var wc := p + Vector2(w * float(wx), 0)
		ci.draw_circle(wc, h * 0.44, UI.INK)
		ci.draw_circle(wc, h * 0.28, UI.SIDE.lerp(UI.SUB, 0.6))
		ci.draw_circle(wc, h * 0.12, UI.INK)
		ci.draw_arc(wc, h * 0.4, PI * 1.1, PI * 1.6, 6, Color(UI.TEXT, 0.35), 1.0, true)


static func draw_num(ci: CanvasItem, c: Vector2, n: int, lit: bool) -> void:
	## The car's number in a small disc with a rim (lane and list match).
	ci.draw_circle(c + Vector2(0, 1.5), 11.5, Color(UI.INK, 0.4))
	ci.draw_circle(c, 11.0, UI.RED if lit else UI.RAISED)
	ci.draw_arc(c, 10.0, PI * 1.1, PI * 1.7, 8, Color(UI.TEXT, 0.3), 1.0, true)
	ci.draw_string(UI.SEMI, c + Vector2(-11, 5), str(n), HORIZONTAL_ALIGNMENT_CENTER, 22, 13, UI.TEXT)


class RunnerRow extends Button:
	var index := 0
	var odds := 1.0
	var picked := false

	func _init(i := 0) -> void:
		index = i
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(0, 56)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		if picked:
			draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2(4, 4), size - Vector2(8, 8)), 12.0), UI.RAISED)
		RacePage.draw_num(self, Vector2(22, size.y * 0.5), index + 1, picked)
		var f: Font = UI.SEMI
		draw_string(f, Vector2(42, size.y * 0.45), String(RaceMath.RUNNERS[index][0]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 46, 15, UI.TEXT)
		draw_string(UI.REG, Vector2(42, size.y * 0.8), "pays ×%.2f" % odds, HORIZONTAL_ALIGNMENT_LEFT, size.x - 46, 13, UI.GOLD if picked else UI.SUB)


class Track extends Control:
	## Six lanes; each car's finishing time follows the drawn order.
	signal finished
	const BASE_S := 5.0
	var pick := 0
	var _order: Array = []
	var _finish_t: Array = []
	var _t := 0.0
	var _running := false
	var _phase: Array = []

	func _init() -> void:
		set_process(false)

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
		var face := CasinoGame.draw_frame(self, Rect2(Vector2.ZERO, size), 16.0, UI.SIDE)
		var top := face.position.y + 6.0
		var lane_h := (face.size.y - 12.0) / 6.0
		var x0 := 64.0
		var x1 := size.x - 30.0
		# Tarmac lanes in two close tones, with dashed white dividers.
		for i in 6:
			var y := top + lane_h * float(i)
			draw_rect(Rect2(Vector2(face.position.x + 2, y), Vector2(face.size.x - 4, lane_h)), UI.SIDE.lerp(UI.PANEL, 0.75 if i % 2 == 0 else 0.35))
		for i in 5:
			var y := top + lane_h * float(i)
			if true:
				var dx := 40.0
				while dx < size.x - 34.0:
					draw_line(Vector2(dx, y + lane_h), Vector2(dx + 8.0, y + lane_h), Color(UI.TEXT, 0.2), 1.0)
					dx += 16.0
		# Rails top and bottom: a white bar with posts.
		for ry in [top - 3.0, top + lane_h * 6.0 + 1.0]:
			draw_rect(Rect2(Vector2(face.position.x + 4, float(ry)), Vector2(face.size.x - 8, 2.0)), Color(UI.TEXT, 0.55))
			var px := face.position.x + 10.0
			while px < face.end.x - 6.0:
				draw_rect(Rect2(Vector2(px, float(ry) - 1.0), Vector2(2, 4)), Color(UI.TEXT, 0.35))
				px += 22.0
		# Start line and the finish: a chequer two squares wide.
		draw_line(Vector2(x0 - 6.0, top), Vector2(x0 - 6.0, top + lane_h * 6.0), Color(UI.TEXT, 0.25), 2.0)
		var sq := 6.0
		var rows := int(lane_h * 6.0 / sq)
		for k in rows:
			for c2 in 2:
				var dark := (k + c2) % 2 == 1
				draw_rect(Rect2(Vector2(x1 + 2.0 + float(c2) * sq, top + float(k) * sq), Vector2(sq, sq)), UI.SIDE if dark else UI.TEXT)
		var done := not _running and not _order.is_empty()
		var f: Font = UI.SEMI
		for i in 6:
			var y := top + lane_h * float(i)
			if done and int(_order[0]) == i:
				draw_rect(Rect2(Vector2(face.position.x + 2, y + 1), Vector2(face.size.x - 4, lane_h - 2)), Color(UI.GOLD, 0.14))
			RacePage.draw_num(self, Vector2(22, y + lane_h * 0.5), i + 1, i == pick)
			var px := lerpf(x0, x1 - 20.0, _progress(i))
			var cp := Vector2(px, y + lane_h * 0.78)
			if _running and px > x0 + 4.0:   # speed streaks behind a moving car
				for k in 3:
					var sy := cp.y - lane_h * (0.15 + 0.15 * float(k))
					draw_line(Vector2(px - 26.0 - float(k) * 6.0, sy), Vector2(px - 18.0 - float(k) * 3.0, sy), Color(UI.TEXT, 0.18), 1.0)
			RacePage.draw_car(self, cp, 0.7, RacePage.car_color(i, i == pick), i + 1)
		if done:
			for place in mini(3, _order.size()):
				var i := int(_order[place])
				var y := top + lane_h * float(i)
				draw_string(f, Vector2(40, y + lane_h * 0.62), ["1st", "2nd", "3rd"][place], HORIZONTAL_ALIGNMENT_LEFT, 40, 13, UI.GOLD if place == 0 else UI.SUB)
