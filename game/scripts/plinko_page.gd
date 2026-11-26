class_name PlinkoPage
extends Page
## Plinko: drop a ball through 12 rows of pegs into a slot. Each drop is bet,
## worked out (PlinkoMath) and paid at once; the ball then falls along that
## path. Several balls can be in the air; the chips shown catch up as they land.

const RISKS := ["low", "medium", "high"]
const MAX_BALLS := 8

var _pm := PlinkoMath.new()
var _board: Board
var _status: Label
var _bet: CasinoPage.BetBar
var _go: Button
var _seg: Segmented
var _hidden_win := 0.0


func _init() -> void:
	super("Plinko", true)


func play_button() -> Button:
	return _go


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_seg = Segmented.new(["Low", "Medium", "High"])
	_seg.index = clampi(int(Game.ui.get("plinko_risk", 1)), 0, 2)
	_seg.changed.connect(func(i: int):
		Game.ui["plinko_risk"] = i
		_board.risk = RISKS[i]
		_board.queue_redraw())
	body.add_child(_seg)
	_board = Board.new()
	_board.custom_minimum_size = Vector2(0, 380)
	_board.risk = RISKS[_seg.index]
	_board.landed.connect(_on_landed)
	body.add_child(_board)
	_status = CasinoPage.status_row(body)
	_bet = CasinoPage.BetBar.new()
	body.add_child(_bet)
	_go = CasinoPage.game_button("Drop", true, _on_drop)
	body.add_child(_go)


func refresh() -> void:
	if _status == null:
		return
	_bet.refresh()
	_status.text = "Chips %s · limit %s" % [Game.money(Game.chips() - _hidden_win), Game.money_short(Game.casino_max_bet())]
	_go.text = "Drop · " + Game.money_short(_bet.value)


func _on_drop() -> void:
	if _board.balls.size() >= MAX_BALLS:
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
	var risk: String = RISKS[_seg.index]
	var d := _pm.drop()
	var m := PlinkoMath.mult(risk, int(d["slot"]))
	var paid := Game.casino_pay(bet * m) if m > 0.0 else 0.0   # paid and saved before it falls
	Kit.sound("tap")
	if Motion.reduced():
		_on_landed(int(d["slot"]), paid, bet)
		return
	_hidden_win += paid
	_board.add_ball(d["path"], int(d["slot"]), paid, bet)
	refresh()


func _on_landed(slot: int, paid: float, bet: float) -> void:
	_hidden_win = maxf(0.0, _hidden_win - paid)
	_board.flash(slot)
	if paid > bet * 1.01:
		Kit.haptic("success" if paid >= bet * 5.0 else "light")
		if paid >= bet * 10.0:
			Kit.sound("fanfare")
			Kit.toast("Plinko x%s · +%s" % [str(PlinkoMath.mult(RISKS[_seg.index], slot)), Game.money_short(paid)], true)
	refresh()


class Board extends Control:
	## Pegs in a triangle, slots with their multipliers, balls falling.
	signal landed(slot: int, paid: float, bet: float)
	const STEP_S := 0.13
	var risk := "medium"
	var balls: Array = []     # {path, slot, paid, bet, t}
	var _flash := {}          # slot -> time left

	func add_ball(path: Array, slot: int, paid: float, bet: float) -> void:
		balls.append({"path": path, "slot": slot, "paid": paid, "bet": bet, "t": 0.0})
		set_process(true)

	func flash(slot: int) -> void:
		_flash[slot] = 0.6
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		var done: Array = []
		for b in balls:
			b["t"] = float(b["t"]) + delta
			if float(b["t"]) >= STEP_S * float(PlinkoMath.ROWS + 1):
				done.append(b)
		for b in done:
			balls.erase(b)
			landed.emit(int(b["slot"]), float(b["paid"]), float(b["bet"]))
		for k in _flash.keys():
			_flash[k] = float(_flash[k]) - delta
			if float(_flash[k]) <= 0.0:
				_flash.erase(k)
		if balls.is_empty() and _flash.is_empty():
			set_process(false)
		queue_redraw()

	func _geo() -> Dictionary:
		var slots := PlinkoMath.ROWS + 1
		var gap := minf((size.x - 16.0) / float(slots), (size.y - 70.0) / float(PlinkoMath.ROWS + 1))
		var top := 22.0
		return {"gap": gap, "top": top, "cx": size.x * 0.5}

	func _peg(row: int, k: int, g: Dictionary) -> Vector2:
		## Row `row` has row + 3 pegs, centred.
		var n := row + 3
		return Vector2(float(g["cx"]) + (float(k) - float(n - 1) * 0.5) * float(g["gap"]), float(g["top"]) + float(row) * float(g["gap"]))

	func _ball_pos(b: Dictionary, g: Dictionary) -> Vector2:
		var t := float(b["t"]) / STEP_S
		var step := int(t)
		var frac := t - float(step)
		var path: Array = b["path"]
		# Horizontal position after `step` bounces: count of rights so far.
		var rights := 0
		for i in mini(step, path.size()):
			rights += int(path[i])
		var x0 := float(g["cx"]) + (float(rights) - float(mini(step, path.size())) * 0.5) * float(g["gap"])
		var dir := 0.0
		if step < path.size():
			dir = 0.5 if int(path[step]) == 1 else -0.5
		var x := x0 + dir * float(g["gap"]) * frac
		var y := float(g["top"]) - float(g["gap"]) * 0.6 + float(g["gap"]) * (float(step) + frac)
		y -= sin(frac * PI) * float(g["gap"]) * 0.35   # a small hop off each peg
		return Vector2(x, y)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UI.INK)
		var g := _geo()
		for row in PlinkoMath.ROWS:
			for k in row + 3:
				draw_circle(_peg(row, k, g), 3.0, UI.SUB)
		# Slots along the bottom.
		var slots := PlinkoMath.ROWS + 1
		var gap := float(g["gap"])
		var sy := float(g["top"]) + float(PlinkoMath.ROWS) * gap + 8.0
		var f: Font = UI.SEMI
		for k in slots:
			var x := float(g["cx"]) + (float(k) - float(slots - 1) * 0.5) * gap - gap * 0.5 + 1.0
			var m := PlinkoMath.mult(risk, k)
			var col: Color = UI.RAISED
			if m >= 10.0:
				col = UI.RED
			elif m >= 2.0:
				col = UI.GOLD
			elif m >= 1.0:
				col = UI.FELT
			if _flash.has(k):
				col = col.lerp(UI.TEXT, clampf(float(_flash[k]) / 0.6, 0.0, 1.0) * 0.6)
			draw_rect(Rect2(Vector2(x, sy), Vector2(gap - 2.0, 30)), col)
			var t := ("%d" % int(m)) if m >= 10.0 else str(m)
			draw_string(f, Vector2(x, sy + 20), t, HORIZONTAL_ALIGNMENT_CENTER, gap - 2.0, 10 if t.length() > 3 else 11, UI.INK if m >= 1.0 else UI.SUB)
		for b in balls:
			draw_circle(_ball_pos(b, g), gap * 0.24, UI.RED)
