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
	add_results_strip("plinko")
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
	_board.add_ball(d["path"], int(d["slot"]), paid, bet, Game.jackpot_pending() > 0.0)
	refresh()


func _on_landed(slot: int, paid: float, bet: float) -> void:
	_hidden_win = maxf(0.0, _hidden_win - paid)
	record_result(bet, paid)
	_win_feedback(slot, paid, bet)
	refresh()


func _win_feedback(slot: int, paid: float, bet: float) -> void:
	## Everything a landing shows and plays, in one place: the bucket pulses,
	## the win counts up, big multipliers burst. Never blocks taps.
	var m := paid / maxf(bet, 0.0001)
	_board.flash(slot, m >= 10.0)
	# Balls land quickly one after another: only a real win gets a buzz.
	status.set_win(paid, paid > bet * 1.001)
	# A jackpot is paid even on a losing bucket.
	if paid > bet * 1.01 or Game.jackpot_pending() > 0.0:
		win_fx(paid, bet, 10.0, _board.slot_center(slot))


class Board extends Control:
	## Pegs in a triangle, slots with their multipliers, balls falling.
	signal landed(slot: int, paid: float, bet: float)
	const STEP_S := 0.13
	var risk := "medium"
	var balls: Array = []     # {path, slot, paid, bet, t}
	var _flash := {}          # slot -> time left
	var _big := {}            # slot -> true when a big multiplier was hit (a wider burst)
	var _hits := {}           # "row:k" -> time left: a peg glows briefly when the ball strikes it

	func _init() -> void:
		set_process(false)

	func add_ball(path: Array, slot: int, paid: float, bet: float, gold := false) -> void:
		balls.append({"path": path, "slot": slot, "paid": paid, "bet": bet, "t": 0.0, "gold": gold})
		set_process(true)

	func flash(slot: int, big := false) -> void:
		_flash[slot] = 0.9 if big else 0.6
		if big:
			_big[slot] = true
		set_process(true)
		queue_redraw()

	func slot_center(slot: int) -> Vector2:
		var g := _geo()
		var slots := PlinkoMath.ROWS + 1
		var x := float(g["cx"]) + (float(slot) - float(slots - 1) * 0.5) * float(g["gap"])
		return global_position + Vector2(x, float(g["top"]) + float(PlinkoMath.ROWS) * float(g["gy"]) + 20.0)

	func _process(delta: float) -> void:
		var done: Array = []
		for b in balls:
			var before := int(float(b["t"]) / STEP_S)
			b["t"] = float(b["t"]) + delta
			var now_step := int(float(b["t"]) / STEP_S)
			if now_step != before and now_step <= PlinkoMath.ROWS:
				# The ball just struck the peg of row `before`: light it for a moment.
				var path: Array = b["path"]
				var rights := 0
				for i in mini(before, path.size()):
					rights += int(path[i])
				if before < PlinkoMath.ROWS:
					_hits["%d:%d" % [before, rights + 1]] = 0.25
			if float(b["t"]) >= STEP_S * float(PlinkoMath.ROWS + 1):
				done.append(b)
		for b in done:
			balls.erase(b)
			landed.emit(int(b["slot"]), float(b["paid"]), float(b["bet"]))
		for k in _flash.keys():
			_flash[k] = float(_flash[k]) - delta
			if float(_flash[k]) <= 0.0:
				_flash.erase(k)
				_big.erase(k)
		for k in _hits.keys():
			_hits[k] = float(_hits[k]) - delta
			if float(_hits[k]) <= 0.0:
				_hits.erase(k)
		if balls.is_empty() and _flash.is_empty() and _hits.is_empty():
			set_process(false)
		queue_redraw()

	func _geo() -> Dictionary:
		## gap: horizontal spacing, gy: vertical. In landscape the board is short,
		## so it may be wider than tall (up to 1.8x), which keeps every bucket
		## label at a readable 13 px.
		var slots := PlinkoMath.ROWS + 1
		# 18 px each side: the outer pegs and buckets clear the cabinet frame.
		var gy := minf((size.x - 36.0) / float(slots), (size.y - 70.0) / float(PlinkoMath.ROWS + 1))
		var gx := minf((size.x - 36.0) / float(slots), gy * 1.8)
		var top := 22.0 + maxf(0.0, (size.y - 70.0 - gy * float(PlinkoMath.ROWS + 1)) * 0.5)
		return {"gap": gx, "gy": gy, "top": top, "cx": size.x * 0.5}

	func _peg(row: int, k: int, g: Dictionary) -> Vector2:
		## Row `row` has row + 3 pegs, centred.
		var n := row + 3
		return Vector2(float(g["cx"]) + (float(k) - float(n - 1) * 0.5) * float(g["gap"]), float(g["top"]) + float(row) * float(g["gy"]))

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
		var y := float(g["top"]) - float(g["gy"]) * 0.6 + float(g["gy"]) * (float(step) + frac)
		y -= sin(frac * PI) * float(g["gy"]) * 0.35   # a small hop off each peg
		return Vector2(x, y)

	func _draw() -> void:
		# The cabinet: a bevelled frame around a deep back panel, lit from above.
		var face := CasinoGame.draw_frame(self, Rect2(Vector2.ZERO, size), 16.0, UI.SIDE.lerp(UI.PANEL, 0.6))
		for k in 6:   # soft light falling down the back panel
			var t := float(k) / 6.0
			var band := Rect2(face.position + Vector2(0, face.size.y * t * 0.5), Vector2(face.size.x, face.size.y * (1.0 - t * 0.5)))
			draw_colored_polygon(UI.rounded_rect_poly(band, 11.0), Color(UI.HAZE, 0.05))
		var g := _geo()
		var gap := float(g["gap"])
		var gy := float(g["gy"])
		var pr := clampf(minf(gap, gy) * 0.13, 2.5, 4.5)
		# A soft wash of light behind the peg triangle.
		var apex := _peg(0, 1, g) + Vector2(0, -gy * 0.8)
		var base_y := float(g["top"]) + float(PlinkoMath.ROWS - 1) * gy + gy * 0.6
		var half := minf((float(PlinkoMath.ROWS + 2) * 0.5 + 0.6) * gap, face.size.x * 0.5 - 6.0)   # stays inside the frame
		draw_colored_polygon(PackedVector2Array([apex + Vector2(-gap, 0), apex + Vector2(gap, 0),
			Vector2(float(g["cx"]) + half, base_y), Vector2(float(g["cx"]) - half, base_y)]), Color(UI.HAZE, 0.22))
		for row in PlinkoMath.ROWS:
			for k in row + 3:
				var p := _peg(row, k, g)
				var hit := float(_hits.get("%d:%d" % [row, k], 0.0))
				draw_circle(p + Vector2(pr * 0.35, pr * 0.6), pr * 1.1, Color(UI.INK, 0.55))   # shadow on the panel
				var body: Color = UI.SUB.lerp(UI.TEXT, 0.25)
				if hit > 0.0:
					var h := hit / 0.25
					draw_circle(p, pr * (2.2 + h), Color(UI.GOLD, 0.18 * h))   # a quick glow where the ball struck
					body = body.lerp(UI.GOLD, h)
				draw_circle(p, pr, body.darkened(0.2))
				draw_circle(p + Vector2(-pr * 0.12, -pr * 0.12), pr * 0.8, body)
				draw_circle(p + Vector2(-pr * 0.35, -pr * 0.35), pr * 0.3, Color(UI.TEXT, 0.9))
		# Buckets: raised boxes; the big multipliers at the edges are gold and lit.
		var slots := PlinkoMath.ROWS + 1
		var sy := float(g["top"]) + float(PlinkoMath.ROWS) * gy + 8.0
		var f: Font = UI.SEMI
		for k in slots:
			var x := float(g["cx"]) + (float(k) - float(slots - 1) * 0.5) * gap - gap * 0.5 + 1.0
			var m := PlinkoMath.mult(risk, k)
			var col: Color = UI.SIDE.lerp(UI.PANEL, 0.6)
			var fg: Color = UI.SUB
			if m >= 10.0:
				col = UI.GOLD
				fg = UI.INK
			elif m >= 2.0:
				col = UI.GOLD.lerp(UI.SIDE, 0.6)
				fg = UI.TEXT
			elif m >= 1.0:
				col = UI.RAISED
				fg = UI.TEXT
			var fl := float(_flash.get(k, 0.0))
			var pulse := clampf(fl / 0.6, 0.0, 1.0)
			var br := Rect2(Vector2(x, sy + pulse * 3.0), Vector2(gap - 2.0, 30))   # pressed down a touch when hit
			if m >= 10.0:
				draw_colored_polygon(UI.rounded_rect_poly(br.grow(3.0), 9.0), Color(UI.GOLD, 0.16 + 0.3 * pulse))   # a steady halo, brighter on a hit
			draw_colored_polygon(UI.rounded_rect_poly(Rect2(br.position + Vector2(0, 3), br.size), 6.0), Color(UI.INK, 0.5))
			draw_colored_polygon(UI.rounded_rect_poly(br, 6.0), col.lerp(UI.TEXT, pulse * 0.45))
			draw_line(br.position + Vector2(4, 1.5), Vector2(br.end.x - 4, br.position.y + 1.5), Color(UI.TEXT, 0.35 if m >= 2.0 else 0.15), 1.0, true)   # lit top lip
			var t := PlinkoPage._num(m)
			# The label keeps to its own slot; on a narrow board (landscape) it
			# steps down a size or two instead of being cut to "1.".
			var lfs := 13   # the board widens in landscape instead of shrinking this
			draw_string(f, Vector2(br.position.x - 1.0, br.position.y + 15.0 + lfs * 0.38), t, HORIZONTAL_ALIGNMENT_CENTER, gap, lfs, fg)
			if fl > 0.0:
				# A ring of light rising out of the bucket that was hit; wider for a big one.
				var life := 1.0 - fl / (0.9 if _big.has(k) else 0.6)
				var rc := br.get_center()
				var rad := (gap * 0.6) + life * gap * (2.2 if _big.has(k) else 1.2)
				draw_arc(rc, rad, 0.0, TAU, 32, Color(UI.GOLD if m >= 2.0 else UI.TEXT, 0.5 * (1.0 - life)), 2.0, true)
		# Balls with a fading trail and a little squash as they strike each peg.
		var br_r := minf(gap, gy) * 0.24
		for b in balls:
			for i in range(4, 0, -1):
				var tb: Dictionary = b.duplicate()
				tb["t"] = maxf(0.0, float(b["t"]) - float(i) * 0.03)
				draw_circle(_ball_pos(tb, g), br_r * (1.0 - float(i) * 0.15), Color(UI.TEXT, 0.12 * float(5 - i) / 4.0))
			var bp := _ball_pos(b, g)
			var frac := fmod(float(b["t"]) / STEP_S, 1.0)
			var sq := maxf(0.0, 0.18 - frac) * 1.2   # squashed right after a strike, round again in a blink
			draw_set_transform(bp, 0.0, Vector2(1.0 + sq, 1.0 - sq))
			if bool(b.get("gold", false)):   # the jackpot ball: gold with a halo
				draw_circle(Vector2.ZERO, br_r * 2.2, Color(UI.GOLD, 0.25))
				draw_circle(Vector2.ZERO, br_r, UI.GOLD)
				draw_circle(Vector2(-br_r * 0.3, -br_r * 0.3), br_r * 0.35, Color(UI.TEXT, 0.9))
			else:
				CasinoGame.draw_ball(self, Vector2.ZERO, br_r)
			draw_set_transform(Vector2.ZERO, 0.0)
