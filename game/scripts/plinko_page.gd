class_name PlinkoPage
extends CasinoGame
## Plinko: drop a ball through 12 rows of pegs into a slot. Each drop is bet,
## worked out (PlinkoMath) and paid at once; the ball then falls along that
## path. Several balls can be in the air; the chips shown catch up as they land.

const RISKS := ["low", "medium", "high"]
const MAX_BALLS := 8

var _pm := PlinkoMath.new()
var _board: Board
var _bet: BetBar
var _go: Button
var _seg: Segmented
var _hidden_win := 0.0


func _init() -> void:
	super("Plinko", true)


func play_button() -> Button:
	return _go


func build_game() -> void:
	_board = Board.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.landed.connect(_on_landed)
	area.add_child(_board)
	_bet = BetBar.new()
	dock.add_child(_bet)
	_seg = Segmented.new(["Low risk", "Medium", "High risk"])
	_seg.index = clampi(int(Game.ui.get("plinko_risk", 1)), 0, 2)
	_seg.select(_seg.index)
	_seg.changed.connect(func(i: int):
		Game.ui["plinko_risk"] = i
		_board.risk = RISKS[i]
		_board.queue_redraw())
	dock.add_child(_seg)
	_board.risk = RISKS[_seg.index]
	_go = primary("Drop", _on_drop)
	dock.add_child(_go)


func info_content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(note("Each drop bets once. The ball bounces left or right off 12 rows of pegs and pays the multiplier of the slot it lands in. Drop again while balls are still falling.", UI.TEXT))
	for i in RISKS.size():
		var t: Array = PlinkoMath.TABLES[RISKS[i]]
		box.add_child(pay_line(["Low risk", "Medium", "High risk"][i], "edges ×%s · middle ×%s" % [_num(float(t[0])), _num(float(t[6]))], i == _seg.index))
	box.add_child(note("Pays back about 97 to 98% over time."))
	return box


static func _num(m: float) -> String:
	return ("%d" % int(m)) if m >= 10.0 or is_equal_approx(m, roundf(m)) else str(m)


func refresh() -> void:
	if _go == null:
		return
	_bet.refresh()
	status.set_chips(Game.chips() - _hidden_win)
	_go.text = "Drop · " + Game.money_short(_bet.value)


func _on_drop() -> void:
	if _board.balls.size() >= MAX_BALLS:
		Motion.shake(_go)
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
	# Balls land quickly one after another: only a real win gets a buzz.
	status.set_win(paid)
	if paid > bet * 1.01:
		win_fx(paid, bet, 10.0, _board.slot_center(slot))
	refresh()


class Board extends Control:
	## Pegs in a triangle, slots with their multipliers, balls falling.
	signal landed(slot: int, paid: float, bet: float)
	const STEP_S := 0.13
	var risk := "medium"
	var balls: Array = []     # {path, slot, paid, bet, t}
	var _flash := {}          # slot -> time left

	func _init() -> void:
		set_process(false)

	func add_ball(path: Array, slot: int, paid: float, bet: float) -> void:
		balls.append({"path": path, "slot": slot, "paid": paid, "bet": bet, "t": 0.0})
		set_process(true)

	func flash(slot: int) -> void:
		_flash[slot] = 0.6
		set_process(true)
		queue_redraw()

	func slot_center(slot: int) -> Vector2:
		var g := _geo()
		var slots := PlinkoMath.ROWS + 1
		var x := float(g["cx"]) + (float(slot) - float(slots - 1) * 0.5) * float(g["gap"])
		return global_position + Vector2(x, float(g["top"]) + float(PlinkoMath.ROWS) * float(g["gap"]) + 20.0)

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
		var top := 22.0 + maxf(0.0, (size.y - 70.0 - gap * float(PlinkoMath.ROWS + 1)) * 0.5)
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
		draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2.ZERO, size), 16.0), UI.PANEL)
		var g := _geo()
		for row in PlinkoMath.ROWS:
			for k in row + 3:
				draw_circle(_peg(row, k, g), 3.0, UI.SUB)
		# Slots along the bottom: tonal, brighter as they pay more; gold for 10x and up.
		var slots := PlinkoMath.ROWS + 1
		var gap := float(g["gap"])
		var sy := float(g["top"]) + float(PlinkoMath.ROWS) * gap + 8.0
		var f: Font = UI.SEMI
		for k in slots:
			var x := float(g["cx"]) + (float(k) - float(slots - 1) * 0.5) * gap - gap * 0.5 + 1.0
			var m := PlinkoMath.mult(risk, k)
			var col: Color = UI.INK
			var fg: Color = UI.SUB
			if m >= 10.0:
				col = UI.GOLD
				fg = UI.INK
			elif m >= 2.0:
				col = Color(UI.GOLD, 0.35)
				fg = UI.TEXT
			elif m >= 1.0:
				col = UI.RAISED
				fg = UI.TEXT
			if _flash.has(k):
				col = col.lerp(UI.TEXT, clampf(float(_flash[k]) / 0.6, 0.0, 1.0) * 0.6)
			draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2(x, sy), Vector2(gap - 2.0, 30)), 6.0), col)
			var t := PlinkoPage._num(m)
			draw_string(f, Vector2(x, sy + 20), t, HORIZONTAL_ALIGNMENT_CENTER, gap - 2.0, 13, fg)
		for b in balls:
			draw_circle(_ball_pos(b, g), gap * 0.24, UI.TEXT)
