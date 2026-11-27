class_name ForgePage
extends CasinoGame
## Sun Forge: the flagship 6 x 5 slot. Symbols pay anywhere (8 or more),
## winners burst and the grid tumbles, sun orbs multiply the win, free spins
## keep a total multiplier, plus an ante bet and Buy free spins.
## Money first: every round (free spins included) is worked out by ForgeMath,
## staked and paid (saved) before any animation, then played back.

const BIG_X := 15.0
const MEGA_X := 30.0
const EPIC_X := 60.0
const AUTO_STOP_X := 15.0

var math: ForgeMath
var _grid: ForgeGrid
var _head: Label          # TUMBLE WIN / pays anywhere
var _fs_box: PanelContainer
var _fs_l: Label          # free spins left
var _tm_box: PanelContainer
var _tm_l: Label          # total multiplier
var _buy_b: Button
var _ante_b: Button
var _bet: BetBar
var _win_l: Label         # the status row's win (tests read it)
var _spin_b: Button
var _auto_b: Button
var _ladder: Array = []
var _bet_i := 0
var ante := false
var _busy := false
var _fast := false        # tap Spin while playing: hurry the rest
var _shown_chips := 0.0
var _last: Dictionary = {}   # last round, for tests: the ForgeMath result plus "paid"


func _init(_arg := "") -> void:
	super("Sun Forge", true)


func build_game() -> void:
	math = ForgeMath.new()
	_win_l = status.win_l
	# Header: free spins left, tumble win, total multiplier.
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 6)
	hh.custom_minimum_size = Vector2(0, 40)
	area.add_child(hh)
	_fs_box = _chip_box(hh)
	_fs_l = _fs_box.get_child(0) as Label
	_head = UI.label("", 15, UI.GOLD, true)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.clip_text = true
	hh.add_child(_head)
	_tm_box = _chip_box(hh)
	_tm_l = _tm_box.get_child(0) as Label
	_grid = ForgeGrid.new()
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.add_child(_grid)
	# Dock: the bet, then Buy free spins / Ante / Auto, then SPIN.
	_bet = BetBar.new()
	_bet.external = true
	_bet.stepped.connect(_step_bet)
	_bet.maxed.connect(func():
		if _busy:
			return
		_bet_i = _ladder.size() - 1
		_refresh_bet())
	dock.add_child(_bet)
	_buy_b = quiet("", _on_buy)
	_ante_b = quiet("", func(): set_ante(not ante))
	_auto_b = quiet("Auto", _on_auto)
	_auto_b.size_flags_horizontal = Control.SIZE_FILL
	_auto_b.custom_minimum_size.x = 72
	dock_row([_buy_b, _ante_b, _auto_b])
	_spin_b = primary("SPIN", _on_spin_pressed)
	_spin_b.add_theme_font_size_override("font_size", 20)
	dock.add_child(_spin_b)
	_shown_chips = Game.chips()
	_build_ladder()
	_bet_i = _default_bet()
	_grid.show_idle(math)


func show_info() -> void:
	_show_info()


func auto_spin() -> bool:
	return spin()


func is_busy() -> bool:
	return _busy


func _chip_box(parent: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 12, 10, 4))
	pc.custom_minimum_size = Vector2(92, 40)
	var l := UI.label("", 13, UI.TEXT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	parent.add_child(pc)
	return pc


# ---- bets ---------------------------------------------------------------------

func _build_ladder() -> void:
	## Bets in 1-2-5 steps; the stake (with the ante, if on) never passes the max.
	var cap := Game.casino_max_bet()
	_ladder = []
	for e in range(-2, 16):
		for m in [1.0, 2.0, 5.0]:
			var v: float = m * pow(10.0, e)
			if math.stake(v, ante) <= cap + 0.0001:
				_ladder.append(v)
	if _ladder.is_empty():
		_ladder = [0.01]
	_bet_i = clampi(_bet_i, 0, _ladder.size() - 1)


func _default_bet() -> int:
	## About 1% of your chips, within the limits.
	var want := maxf(Game.chips() * 0.01, 0.2)
	var best := 0
	for i in range(_ladder.size()):
		if float(_ladder[i]) <= want:
			best = i
	return best


func bet() -> float:
	return float(_ladder[_bet_i])


func stake() -> float:
	return math.stake(bet(), ante)


func _step_bet(d: int) -> void:
	if _busy:
		Motion.shake(_bet.plus if d > 0 else _bet.minus)
		return
	var ni := clampi(_bet_i + d, 0, _ladder.size() - 1)
	if ni == _bet_i:
		Motion.shake(_bet.plus if d > 0 else _bet.minus)
		if d > 0:
			Kit.toast("Table limit: %s a spin" % Game.money_short(Game.casino_max_bet()))
		return
	Kit.haptic("selection")
	_bet_i = ni
	_refresh_bet()


func set_ante(on: bool) -> void:
	if _busy or on == ante:
		return
	Kit.haptic("selection")
	var keep := bet()
	ante = on
	_build_ladder()
	var i := _ladder.find(keep)
	_bet_i = i if i >= 0 else _ladder.size() - 1
	_refresh_bet()


func _refresh_bet() -> void:
	_bet.show_text(Game.money_short(stake()), "with ante ×1.25" if ante else "")
	_buy_b.text = "Buy spins · " + Game.money_short(math.buy_cost(bet()))
	_ante_b.text = "Ante · on" if ante else "Ante · off"
	UI.paint(_ante_b, UI.RAISED, UI.GOLD if ante else UI.TEXT, 24)
	_update_buttons()


func refresh() -> void:
	if _spin_b == null:
		return
	var keep := bet() if not _ladder.is_empty() else 0.0
	_build_ladder()
	var idx := _ladder.find(keep)
	if idx >= 0:
		_bet_i = idx
	if not _busy:
		_shown_chips = Game.chips()
		status.set_chips(_shown_chips)
		if not _grid.in_feature():
			_head.text = "PAYS ANYWHERE · 8 OR MORE"
	_refresh_bet()


func _update_buttons() -> void:
	if _spin_b == null:
		return
	_spin_b.text = "SKIP" if _busy else ("STOP AUTO" if auto_on else "SPIN")
	set_go(_spin_b, _busy or auto_on or Game.chips() >= stake())
	_auto_b.text = ("%d left" % auto_left if auto_left > 0 else "Stop") if auto_on else "Auto"
	UI.paint(_auto_b, UI.RAISED, UI.GOLD if auto_on else UI.TEXT, 24)
	var idle := not _busy
	_bet.locked = not idle
	_ante_b.modulate.a = 1.0 if idle else 0.4
	_buy_b.modulate.a = 1.0 if (idle and not ante) else 0.4
	var inf := _grid.in_feature()
	_fs_box.visible = inf
	_tm_box.visible = inf


# ---- playing ------------------------------------------------------------------

func _on_spin_pressed() -> void:
	if _busy:
		_fast = true
		_grid.hurry()
		return
	if auto_on:
		stop_auto()
		return
	spin()


func spin() -> bool:
	## One paid spin. Worked out, staked and paid now; played back after.
	if _busy:
		return false
	var st := stake()
	if st > Game.casino_max_bet() + 0.001:
		_build_ladder()
		_refresh_bet()
		Kit.toast("Bet lowered to the table limit")
		return false
	if Game.chips() < st - 0.001:
		stop_auto()
		Motion.shake(_spin_b)
		Kit.toast("Not enough chips")
		offer_chips()
		return false
	var before := Game.chips()
	if not Game.casino_stake(st):
		Motion.shake(_spin_b)
		Kit.toast("That bet isn't allowed")
		return false
	var res := math.base_spin(bet(), ante, true)
	res["paid"] = Game.casino_pay(float(res["total"])) if float(res["total"]) > 0.0 else 0.0
	_shown_chips = before - st
	_play_round(res)
	return true


func buy_now() -> bool:
	## Buy free spins: 100x the bet, the whole feature settled at once.
	if _busy or ante:
		return false
	var cost := math.buy_cost(bet())
	var before := Game.chips()
	if not Game.casino_stake(cost, ForgeMath.BUY_X + 1.0):
		Kit.haptic("error")
		Kit.toast("Can't buy free spins now")
		return false
	var res := math.buy(bet(), true)
	res["paid"] = Game.casino_pay(float(res["total"])) if float(res["total"]) > 0.0 else 0.0
	_shown_chips = before - cost
	_play_round(res)
	return true


func _play_round(res: Dictionary) -> void:
	_last = res
	_busy = true
	_fast = Motion.reduced()
	status.clear_win()
	status.set_chips(_shown_chips)
	_update_buttons()
	_run_round(res)


func _run_round(res: Dictionary) -> void:
	var b := float(res["bet"])
	var shown_win := 0.0
	if not bool(res.get("bought", false)):
		var spin_money := await _play_spin(res["spin"], b, 0, false)
		shown_win += spin_money
		if not is_inside_tree():
			return
	var feat: Dictionary = res.get("feature", {})
	if not feat.is_empty():
		var sig_money := float(res["sigil_x"]) * b
		shown_win += sig_money
		_win_l.text = Game.money_short(shown_win)
		_win_l.add_theme_color_override("font_color", UI.GOLD)
		Kit.sound("sun")
		Kit.haptic("success")
		_grid.banner("%d FREE SPINS" % ForgeMath.FREE_SPINS, "Orbs build a total multiplier", 1.8)
		if auto_on:
			stop_auto()
			Kit.toast("Autoplay stopped for free spins")
		await _wait(1.6)
		if not is_inside_tree():
			return
		_grid.set_feature(true)
		var fw := 0.0
		var spins: Array = feat["spins"]
		var left := ForgeMath.FREE_SPINS
		var tm := 0
		_update_buttons()
		for fs in spins:
			left -= 1
			_fs_l.text = "%d SPINS" % maxi(left, 0)
			_tm_l.text = _tm_text(tm)
			var money := await _play_spin(fs["spin"], b, tm, true, int(fs["added"]))
			if not is_inside_tree():
				return
			tm = int(fs["total_mult"])
			left = int(fs["left"])
			_tm_l.text = _tm_text(tm)
			_fs_l.text = "%d SPINS" % left
			var sx := float(fs["x"]) * b
			if int(fs["extra"]) > 0:
				_grid.banner("+%d FREE SPINS" % int(fs["extra"]), "", 1.2)
				Kit.sound("sun")
				await _wait(1.0)
			fw += sx
			shown_win = minf(shown_win + sx, float(res["total"]))
			_win_l.text = Game.money_short(shown_win)
			_win_l.add_theme_color_override("font_color", UI.GOLD)
			_head.text = "FEATURE WIN %s" % Game.money_short(fw)
			if money <= 0.0:
				await _wait(0.15)
		_grid.set_feature(false)
		_grid.banner("FREE SPINS WON", Game.money_short(fw), 2.2)
		await _wait(1.6)
		if not is_inside_tree():
			return
	_finish(res)


func _play_spin(g: Dictionary, b: float, tm_before: int, free: bool, added := 0) -> float:
	## Plays one spin's tumbles. Returns the money that spin paid (after orbs).
	var steps: Array = g["steps"]
	var tumble := 0.0
	_head.text = "TUMBLE WIN " + Game.money_short(0.0) if not free else _head.text
	for si in range(steps.size()):
		var stp: Dictionary = steps[si]
		if si == 0:
			await _grid.drop_in(stp, _fast)
		else:
			await _grid.tumble_to(steps[si - 1], stp, _fast)
		if not is_inside_tree():
			return 0.0
		var wins: Array = stp["wins"]
		if wins.is_empty():
			break
		var sx := float(stp["x"]) * b
		tumble += sx
		Kit.sound("buy")
		Kit.haptic("selection")
		_head.text = "TUMBLE WIN " + Game.money_short(tumble)
		await _grid.show_wins(wins, b, _fast)
		if not is_inside_tree():
			return 0.0
	var x := float(g["x"])
	var orbs := int(g["orbs"])
	var money := tumble
	if x > 0.0 and orbs > 0:
		var mult := (tm_before + orbs) if free else orbs
		await _grid.fly_orbs(_fast)
		money = tumble * float(mult)
		_head.text = "%s × %d = %s" % [Game.money_short(tumble), mult, Game.money_short(money)]
		Kit.sound("crit")
		Kit.haptic("success")
		if free:
			_tm_l.text = _tm_text(mult)
		await _wait(0.7)
	elif tumble <= 0.0 and not free:
		_head.text = "PAYS ANYWHERE · 8 OR MORE"
	return money


func _tm_text(tm: int) -> String:
	return "TOTAL ×%d" % tm if tm > 0 else "TOTAL ×0"


func _finish(res: Dictionary) -> void:
	var paid := float(res.get("paid", 0.0))
	var b := float(res["bet"])
	var x := paid / maxf(b, 0.0001)
	var st := math.buy_cost(b) if bool(res.get("bought", false)) else float(res.get("stake", b))
	win_fx(paid, st, INF)   # the forge has its own big-win banner below
	if paid > 0.0:
		if x >= BIG_X:
			var tier := "EPIC WIN" if x >= EPIC_X else ("MEGA WIN" if x >= MEGA_X else "BIG WIN")
			_grid.big_win(tier, paid, _fast)
			Kit.sound("fanfare")
			if not Motion.reduced():
				var c := Confetti.new(Vector2(Kit.screen().x * 0.5, _grid.global_position.y + 140.0), 80)
				get_tree().root.get_node("Kit").add_child(c)
		if paid < float(res["total"]) - 0.01:
			Kit.toast("Round capped at the casino limit, %s" % Game.money_short(Game.casino_max_win()))
		if bool(res.get("capped", false)):
			Kit.toast("Max win reached: 5,000× the bet")
	var to := Game.chips()
	status.tween_chips(_shown_chips, to)
	_shown_chips = to
	if not bool(res.get("bought", false)) and (res.get("feature", {}) as Dictionary).is_empty() and paid <= 0.0:
		_head.text = "PAYS ANYWHERE · 8 OR MORE"
	await _wait(0.5 if paid > 0.0 else 0.05)
	if not is_inside_tree():
		return
	_busy = false
	_fast = false
	_update_buttons()
	_refresh_bet()
	if auto_on:
		if x >= AUTO_STOP_X:
			stop_auto()
			Kit.toast("Autoplay stopped on a big win")
			return
		if auto_left > 0:
			auto_left -= 1
		if auto_left <= 0:
			stop_auto()
		elif is_visible_in_tree():
			await _wait(0.35)
			if auto_on and not _busy and is_inside_tree():
				if not spin():
					stop_auto()
	_update_buttons()


func _wait(t: float) -> void:
	await get_tree().create_timer(0.01 if _fast else Motion.d(t)).timeout


# ---- autoplay, buy, info --------------------------------------------------------

func _on_auto() -> void:
	if auto_on:
		stop_auto()
		return
	if _busy:
		return
	Kit.tick()
	var acts: Array = []
	for n in [10, 25, 50, 100]:
		var nn: int = n
		acts.append({"text": "%d spins" % nn, "style": "secondary", "call": func(): _start_auto(nn)})
	acts.append({"text": "Close", "style": "plain"})
	Kit.sheet("Autoplay", "Spins at %s each. Stops on free spins, a win of %d× or more, when chips run out, or when you leave." % [Game.money_short(stake()), int(AUTO_STOP_X)], acts)


func _on_buy() -> void:
	if _busy:
		return
	Kit.tick()
	if ante:
		Kit.toast("Turn the ante bet off to buy free spins")
		Motion.shake(_buy_b)
		return
	var cost := math.buy_cost(bet())
	var body := "%d free spins with a total multiplier, starting now. Costs %s (100× your %s bet)." % [ForgeMath.FREE_SPINS, Game.money_short(cost), Game.money_short(bet())]
	var acts: Array = []
	if Game.chips() >= cost:
		acts.append({"text": "Buy · " + Game.money_short(cost), "style": "primary", "call": func(): buy_now()})
	else:
		body += "\n\nYou have %s in chips." % Game.money_short(Game.chips())
		acts.append({"text": "Buy chips", "style": "primary", "call": func(): TradeSheet.open("chips", "", "chips_in")})
	acts.append({"text": "Not now", "style": "plain"})
	Kit.sheet("Buy free spins", body, acts)


func _show_info() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var b := bet()
	var head := UI.label("Pays for 8-9 · 10-11 · 12+ anywhere", 13, UI.SUB)
	box.add_child(head)
	for s in [8, 7, 6, 5, 4, 3, 2, 1, 0]:
		var p: Array = ForgeMath.PAY[s]
		box.add_child(_pay_row(s, "%s  %s · %s · %s" % [ForgeMath.NAMES[s], Game.money_short(float(p[0]) * b), Game.money_short(float(p[1]) * b), Game.money_short(float(p[2]) * b)]))
	box.add_child(_pay_row(ForgeMath.SIGIL, "Forge sigil  4: %s · 5: %s · 6: %s, and free spins" % [Game.money_short(3.0 * b), Game.money_short(5.0 * b), Game.money_short(100.0 * b)]))
	box.add_child(_pay_row(ForgeMath.ORB, "Sun orb ×2 to ×100: added up, they multiply a winning spin"))
	box.add_child(note("Winners burst and new symbols tumble in until nothing more pays. 4 or more sigils give 15 free spins; there every orb in a win adds to a total multiplier for the whole feature, and 3 sigils give 5 more spins. Ante bet: 1.25× the bet, about twice the chance of free spins. Buy free spins: 100× the bet.\n\nPays back about 96.2%% over time (ante 96.1%%, buy 95.7%%). Max win 5,000× the bet, and the casino caps a round at %s." % Game.money_short(Game.casino_max_win())))
	Kit.sheet("Sun Forge", "", [{"text": "Close", "style": "plain"}], true, box)


func _pay_row(sym: int, text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ic := SymIcon.new(sym)
	ic.custom_minimum_size = Vector2(34, 34)
	h.add_child(ic)
	var l := UI.label(text, 13, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


# =================================================================================

class SymIcon extends Control:
	## One Sun Forge symbol in a box (paytable, lobby).
	var sym := 0
	var val := 0

	func _init(s := 0, v := 10) -> void:
		sym = s
		val = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		ForgeGrid.draw_symbol(self, sym, val, size * 0.5, minf(size.x, size.y), 1.0, 1.0)


class ForgeGrid extends Control:
	## The forge-framed 6 x 5 window. Plays drops, wins, tumbles and orbs.
	const CELL := 56.0                    # the largest cell; smaller screens get smaller
	const MIN_CELL := 42.0
	var cell := CELL
	const PAD := 11.0
	var syms := PackedInt32Array()
	var vals := PackedInt32Array()
	var off := PackedFloat32Array()       # y offset in px (negative = above)
	var start_off := PackedFloat32Array()
	var delay := PackedFloat32Array()
	var scl := PackedFloat32Array()       # 1 = normal, 0 = burst
	var hl := PackedByteArray()           # 1 = in a winning cluster
	var _t := 0.0
	var _phase := ""
	var _dur := 0.0
	var _phase_t := 0.0
	var _hurry := false
	var _labels: Array = []               # [pos, text, life]
	var _orb_fly: Array = []              # [from, value]
	var _orb_k := 0.0
	var _banner := ""
	var _banner_sub := ""
	var _banner_life := 0.0
	var _big := ""
	var _big_amt := 0.0
	var _big_shown := 0.0
	var _big_life := 0.0
	var _feature := false
	var _glow := 0.0
	var _was_active := true

	func _init() -> void:
		custom_minimum_size = Vector2(0, MIN_CELL * 5.0 + PAD * 2.0 + 4.0)
		resized.connect(func():
			# Cells shrink on a shorter screen so the buttons never sit under the nav.
			cell = clampf(minf((size.x - PAD * 2.0) / 6.0, (size.y - PAD * 2.0 - 4.0) / 5.0), MIN_CELL, CELL)
			queue_redraw())
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		syms.resize(30)
		vals.resize(30)
		off.resize(30)
		start_off.resize(30)
		delay.resize(30)
		scl.resize(30)
		hl.resize(30)
		for i in 30:
			scl[i] = 1.0

	func in_feature() -> bool:
		return _feature

	func set_feature(on: bool) -> void:
		_feature = on
		queue_redraw()

	func show_idle(m: ForgeMath) -> void:
		var g := m.grid_spin("base", true)
		var st: Dictionary = (g["steps"] as Array)[0]
		var gr: PackedInt32Array = st["grid"]
		var vv: PackedInt32Array = st["vals"]
		for i in 30:
			syms[i] = gr[i]
			vals[i] = vv[i]
			off[i] = 0.0
			scl[i] = 1.0
			hl[i] = 0
		queue_redraw()

	func hurry() -> void:
		_hurry = true

	func _origin() -> Vector2:
		# Centred in whatever height the page gives the grid.
		return Vector2((size.x - cell * 6.0) * 0.5, maxf(PAD + 2.0, (size.y - cell * 5.0) * 0.5))

	func cell_center(i: int) -> Vector2:
		var c := i / 5
		var r := i % 5
		return _origin() + Vector2(c * cell + cell * 0.5, r * cell + cell * 0.5)

	func _process(delta: float) -> void:
		_t += delta
		_glow = 0.5 + 0.5 * sin(_t * 3.0)
		if _phase != "":
			_phase_t += delta * (6.0 if _hurry else 1.0)
			var k := clampf(_phase_t / maxf(_dur, 0.001), 0.0, 1.0)
			match _phase:
				"drop":
					for i in 30:
						var local := clampf((_phase_t - delay[i]) / maxf(_dur - 0.18, 0.05), 0.0, 1.0)
						# Falls in with a small bounce at the end.
						var e := _ease_out_bounce(local)
						off[i] = lerpf(start_off[i], 0.0, e)
				"burst":
					for i in 30:
						if hl[i] == 1:
							scl[i] = 1.0 - k
				"fly":
					_orb_k = k
			if _phase_t >= _dur:
				_phase = ""
		if not _labels.is_empty():
			for lb in _labels:
				lb[2] = float(lb[2]) - delta
			_labels = _labels.filter(func(lb): return float(lb[2]) > 0.0)
		if _banner_life > 0.0:
			_banner_life -= delta
		if _big_life > 0.0:
			_big_life -= delta
			_big_shown = lerpf(_big_shown, _big_amt, minf(1.0, delta * 4.0))
		# Redraw only while something moves or glows; a grid at rest stays still (battery).
		var active := _phase != "" or not _labels.is_empty() or _banner_life > 0.0 or _big_life > 0.0 or _feature or hl.has(1)
		if active or _was_active:
			queue_redraw()
		_was_active = active

	static func _ease_out_bounce(x: float) -> float:
		if x < 0.85:
			var u := x / 0.85
			return 1.0 - pow(1.0 - u, 3.0)
		var v := (x - 0.85) / 0.15
		return 1.0 + sin(v * PI) * 0.04

	func _run(phase: String, dur: float, fast: bool) -> void:
		_hurry = fast
		_phase = phase
		_phase_t = 0.0
		_dur = dur if not fast else dur * 0.12
		if Motion.reduced():
			_dur = 0.001
		while _phase == phase and is_inside_tree():
			await get_tree().process_frame
		# Settle every value at its end state.
		for i in 30:
			if phase == "drop":
				off[i] = 0.0
			elif phase == "burst" and hl[i] == 1:
				scl[i] = 0.0

	func drop_in(st: Dictionary, fast: bool) -> void:
		## A new spin: every symbol falls in from above, column by column.
		var gr: PackedInt32Array = st["grid"]
		var vv: PackedInt32Array = st["vals"]
		for i in 30:
			syms[i] = gr[i]
			vals[i] = vv[i]
			hl[i] = 0
			scl[i] = 1.0
			var c := i / 5
			var r := i % 5
			start_off[i] = -cell * 6.0 - float(4 - r) * 6.0
			off[i] = start_off[i]
			delay[i] = c * 0.06 + float(4 - r) * 0.02
		await _run("drop", Motion.d(0.62), fast)

	func show_wins(wins: Array, bet: float, fast: bool) -> void:
		## Light up each winning cluster with its pay, then burst it.
		for i in 30:
			hl[i] = 0
		for w in wins:
			var cells: Array = w["cells"]
			var mid := Vector2.ZERO
			for c in cells:
				hl[int(c)] = 1
				mid += cell_center(int(c))
			mid /= float(maxi(1, cells.size()))
			_labels.append([mid, Game.money_short(float(w["x"]) * bet), 1.4])
		queue_redraw()
		await get_tree().create_timer(0.02 if (fast or Motion.reduced()) else Motion.d(0.75)).timeout
		await _run("burst", Motion.d(0.28), fast)

	func tumble_to(prev: Dictionary, st: Dictionary, fast: bool) -> void:
		## Survivors fall to their new rows; new symbols drop in from the top.
		var wins: Array = prev["wins"]
		var gone := {}
		for w in wins:
			gone[int(w["sym"])] = true
		var pg: PackedInt32Array = prev["grid"]
		var gr: PackedInt32Array = st["grid"]
		var vv: PackedInt32Array = st["vals"]
		for c in 6:
			var kept_rows: Array = []
			for r in 5:
				if not gone.has(pg[c * 5 + r]):
					kept_rows.append(r)
			var need := 5 - kept_rows.size()
			for r in 5:
				var i := c * 5 + r
				syms[i] = gr[i]
				vals[i] = vv[i]
				hl[i] = 0
				scl[i] = 1.0
				if r < need:
					start_off[i] = -cell * float(need) - 8.0
					delay[i] = c * 0.03 + float(need - r) * 0.03
				else:
					var old_r: int = kept_rows[r - need]
					start_off[i] = float(old_r - r) * cell
					delay[i] = c * 0.03
				off[i] = start_off[i]
		await _run("drop", Motion.d(0.45), fast)

	func fly_orbs(fast: bool) -> void:
		## Orbs lift off and fly up to the multiplier.
		_orb_fly = []
		for i in 30:
			if syms[i] == ForgeMath.ORB:
				_orb_fly.append([cell_center(i), vals[i]])
		_orb_k = 0.0
		if _orb_fly.is_empty():
			return
		await _run("fly", Motion.d(0.6), fast)
		_orb_fly = []

	func banner(title: String, sub: String, secs: float) -> void:
		_banner = title
		_banner_sub = sub
		_banner_life = 0.0 if Motion.reduced() and secs <= 0.0 else secs

	func big_win(tier: String, amount: float, fast: bool) -> void:
		_big = tier
		_big_amt = amount
		_big_shown = amount if (fast or Motion.reduced()) else 0.0
		_big_life = 2.6

	func _draw() -> void:
		var o := _origin()
		var win := Rect2(o, Vector2(cell * 6.0, cell * 5.0))
		# Frame: dark iron with rivets, a molten seam along the top.
		var frame := win.grow(PAD)
		draw_rect(frame, UI.SIDE)
		draw_rect(frame, UI.TRACK, false, 2.0)
		var seam := Color(UI.RED, 0.55 + 0.35 * _glow) if _feature else Color(UI.GOLD, 0.5)   # molten red only in the feature
		draw_rect(Rect2(frame.position + Vector2(0, -2), Vector2(frame.size.x, 4)), seam)
		draw_rect(Rect2(Vector2(frame.position.x, frame.end.y - 2), Vector2(frame.size.x, 2)), Color(UI.GOLD, 0.5))
		for k in 8:
			var x := frame.position.x + 6.0 + (frame.size.x - 12.0) * float(k) / 7.0
			draw_circle(Vector2(x, frame.position.y + 5.0), 1.8, UI.DIM)
			draw_circle(Vector2(x, frame.end.y - 5.0), 1.8, UI.DIM)
		draw_rect(win, UI.INK)
		# Gold corner brackets, like a cast frame.
		var L := 18.0
		for cx in [frame.position.x, frame.end.x]:
			for cy in [frame.position.y, frame.end.y]:
				var dx := L if cx == frame.position.x else -L
				var dy := L if cy == frame.position.y else -L
				draw_line(Vector2(cx, cy), Vector2(cx + dx, cy), UI.GOLD, 3.0)
				draw_line(Vector2(cx, cy), Vector2(cx, cy + dy), UI.GOLD, 3.0)
		# A faint plate in every cell.
		for i in 30:
			var pr := Rect2(cell_center(i) - Vector2(cell, cell) * 0.5, Vector2(cell, cell)).grow(-3.0)
			draw_rect(pr, Color(UI.TEXT, 0.025))
		# Column lines and a faint heat haze from below.
		for c in range(1, 6):
			draw_line(o + Vector2(c * cell, 0), o + Vector2(c * cell, cell * 5.0), Color(UI.TEXT, 0.05), 1.0)
		for hz in 8:
			var hy := float(hz) * 6.0
			draw_rect(Rect2(Vector2(win.position.x, win.end.y - hy - 6.0), Vector2(win.size.x, 6.0)), Color(UI.RED, (0.05 if not _feature else 0.09) * (1.0 - float(hz) / 8.0)))
		# Symbols (clipped to the window).
		for i in 30:
			var p := cell_center(i) + Vector2(0, off[i])
			if p.y < o.y - cell * 0.5:
				continue
			var a := clampf((p.y - (o.y - cell * 0.5)) / (cell * 0.5), 0.0, 1.0)
			if scl[i] <= 0.01:
				continue
			if hl[i] == 1:
				var r := Rect2(cell_center(i) - Vector2(cell, cell) * 0.5, Vector2(cell, cell)).grow(-2.0)
				draw_rect(r, Color(UI.GOLD, 0.14 + 0.12 * _glow))
				draw_rect(r, Color(UI.GOLD, 0.7 + 0.3 * _glow), false, 2.0)
			draw_symbol(self, syms[i], vals[i], p, cell, a, scl[i])
		# The top of the frame again, over symbols still dropping in.
		draw_rect(Rect2(frame.position, Vector2(frame.size.x, PAD)), UI.SIDE)
		draw_rect(Rect2(frame.position + Vector2(0, -2), Vector2(frame.size.x, 4)), seam)
		for k in 8:
			var rx := frame.position.x + 6.0 + (frame.size.x - 12.0) * float(k) / 7.0
			draw_circle(Vector2(rx, frame.position.y + 5.0), 1.8, UI.DIM)
		draw_line(frame.position, frame.position + Vector2(L, 0), UI.GOLD, 3.0)
		draw_line(frame.position, frame.position + Vector2(0, L), UI.GOLD, 3.0)
		draw_line(Vector2(frame.end.x, frame.position.y), Vector2(frame.end.x - L, frame.position.y), UI.GOLD, 3.0)
		draw_line(Vector2(frame.end.x, frame.position.y), Vector2(frame.end.x, frame.position.y + L), UI.GOLD, 3.0)
		# Win amounts over their clusters.
		var f: Font = UI.DISPLAY
		for lb in _labels:
			var pos: Vector2 = lb[0]
			var t: String = lb[1]
			var al := clampf(float(lb[2]) / 0.4, 0.0, 1.0)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_rect(Rect2(pos - Vector2(w * 0.5 + 8.0, 16.0), Vector2(w + 16.0, 30.0)), Color(UI.INK, 0.8 * al))
			draw_string(f, pos + Vector2(-w * 0.5, 8.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UI.GOLD, al))
		# Orbs flying up to the multiplier.
		for of in _orb_fly:
			var from: Vector2 = of[0]
			var to := Vector2(size.x * 0.5, -26.0)
			var k := _orb_k
			var pp := from.lerp(to, k * k) + Vector2(0, -sin(k * PI) * 30.0)
			draw_symbol(self, ForgeMath.ORB, int(of[1]), pp, cell * (1.0 - 0.4 * k), 1.0, 1.0)
		# Banners (never block taps: drawn, not a control).
		if _banner_life > 0.0:
			var ba := clampf(_banner_life / 0.3, 0.0, 1.0)
			var br := Rect2(Vector2(win.position.x + 8.0, win.get_center().y - 44.0), Vector2(win.size.x - 16.0, 88.0))
			draw_rect(br, Color(UI.INK, 0.88 * ba))
			draw_rect(br, Color(UI.GOLD, ba), false, 2.0)
			draw_string(f, Vector2(br.position.x, br.position.y + 44.0), _banner, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 30, Color(UI.GOLD, ba))
			if _banner_sub != "":
				draw_string(UI.SEMI, Vector2(br.position.x, br.position.y + 72.0), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 15, Color(UI.TEXT, ba))
		if _big_life > 0.0:
			var ga := clampf(_big_life / 0.4, 0.0, 1.0)
			var gr2 := Rect2(Vector2(win.position.x - 4.0, win.get_center().y - 70.0), Vector2(win.size.x + 8.0, 140.0))
			draw_rect(gr2, Color(UI.INK, 0.92 * ga))
			draw_rect(Rect2(gr2.position, Vector2(gr2.size.x, 6.0)), Color(UI.GOLD, ga))
			draw_rect(Rect2(Vector2(gr2.position.x, gr2.end.y - 6.0), Vector2(gr2.size.x, 6.0)), Color(UI.GOLD, ga))
			draw_rect(gr2.grow(-10.0), Color(UI.GOLD, 0.6 * ga), false, 1.5)
			draw_string(f, Vector2(gr2.position.x, gr2.position.y + 56.0), _big, HORIZONTAL_ALIGNMENT_CENTER, gr2.size.x, 40, Color(UI.GOLD, ga))
			draw_string(f, Vector2(gr2.position.x, gr2.position.y + 108.0), Game.money_short(_big_shown), HORIZONTAL_ALIGNMENT_CENTER, gr2.size.x, 38, Color(UI.TEXT, ga))

	static func draw_symbol(ci: CanvasItem, sym: int, val: int, c: Vector2, s: float, alpha: float, k: float) -> void:
		## Every symbol drawn in code, centred on c, in a box of side s.
		var r := s * 0.38 * k
		if r <= 0.5:
			return
		var A := func(col: Color) -> Color: return Color(col, col.a * alpha)
		match sym:
			0:   # teal shard: a hexagon gem
				_gem(ci, c, r, 6, PI / 6.0, A.call(UI.SLOT_COL["wild"]), alpha)
			1:   # amber shard: an octagon cushion
				_gem(ci, c, r * 0.95, 8, PI / 8.0, A.call(UI.SLOT_COL["bell"]), alpha)
			2:   # violet shard: a triangle, point down
				_gem(ci, c + Vector2(0, -r * 0.1), r * 1.08, 3, PI / 2.0, A.call(UI.SLOT_COL["scatter"]), alpha)
			3:   # ruby shard: a tall diamond
				var pts := PackedVector2Array([c + Vector2(0, -r * 1.05), c + Vector2(r * 0.78, 0), c + Vector2(0, r * 1.05), c + Vector2(-r * 0.78, 0)])
				ci.draw_colored_polygon(pts, A.call(UI.SLOT_COL["cherry"]))
				ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c]), A.call(Color(UI.TEXT, 0.25)))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.45), c + Vector2(r * 0.34, 0), c + Vector2(0, r * 0.45), c + Vector2(-r * 0.34, 0)]), A.call(Color(UI.FLASH, 0.35)))
				ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), A.call(Color(UI.INK, 0.6)), 1.5, true)
			4:   # molten ingot: a glowing trapezoid bar
				ci.draw_circle(c, r * 0.95, A.call(Color(UI.RED, 0.08)))
				var top := PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.35), c + Vector2(r * 0.7, -r * 0.35), c + Vector2(r * 0.95, r * 0.05), c + Vector2(-r * 0.95, r * 0.05)])
				var front := PackedVector2Array([c + Vector2(-r * 0.95, r * 0.05), c + Vector2(r * 0.95, r * 0.05), c + Vector2(r * 0.95, r * 0.55), c + Vector2(-r * 0.95, r * 0.55)])
				ci.draw_colored_polygon(front, A.call(UI.RED))
				ci.draw_colored_polygon(top, A.call(UI.FLASH))
				ci.draw_line(c + Vector2(-r * 0.6, r * 0.3), c + Vector2(r * 0.5, r * 0.3), A.call(Color(UI.GOLD, 0.8)), 2.0)
			5:   # anvil
				var col: Color = A.call(UI.SUB)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.0, -r * 0.45), c + Vector2(r * 0.75, -r * 0.45), c + Vector2(r * 1.05, -r * 0.6), c + Vector2(r * 0.9, -r * 0.2), c + Vector2(r * 0.35, -r * 0.05), c + Vector2(-r * 0.55, -r * 0.05)]), col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.3, -r * 0.05), c + Vector2(r * 0.3, -r * 0.05), c + Vector2(r * 0.22, r * 0.45), c + Vector2(-r * 0.22, r * 0.45)]), A.call(UI.DIM))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, r * 0.45), c + Vector2(r * 0.7, r * 0.45), c + Vector2(r * 0.8, r * 0.75), c + Vector2(-r * 0.8, r * 0.75)]), col)
				ci.draw_line(c + Vector2(-r * 0.95, -r * 0.45), c + Vector2(r * 0.7, -r * 0.45), A.call(UI.TEXT), 2.0)
				ci.draw_circle(c + Vector2(r * 0.15, -r * 0.75), r * 0.1, A.call(UI.RED))   # a spark
			6:   # sun key
				var g: Color = A.call(UI.GOLD)
				ci.draw_arc(c + Vector2(-r * 0.45, 0), r * 0.42, 0.0, TAU, 28, g, r * 0.2, true)
				ci.draw_circle(c + Vector2(-r * 0.45, 0), r * 0.16, A.call(UI.RED))
				ci.draw_rect(Rect2(c + Vector2(-r * 0.05, -r * 0.1), Vector2(r * 1.05, r * 0.2)), g)
				ci.draw_rect(Rect2(c + Vector2(r * 0.6, r * 0.08), Vector2(r * 0.14, r * 0.32)), g)
				ci.draw_rect(Rect2(c + Vector2(r * 0.85, r * 0.08), Vector2(r * 0.14, r * 0.22)), g)
			7:   # iron crown
				var base_c: Color = A.call(UI.SUB)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.5), c + Vector2(-r, -r * 0.35), c + Vector2(-r * 0.5, r * 0.05), c + Vector2(0, -r * 0.7), c + Vector2(r * 0.5, r * 0.05), c + Vector2(r, -r * 0.35), c + Vector2(r, r * 0.5)]), base_c)
				ci.draw_rect(Rect2(c + Vector2(-r, r * 0.35), Vector2(r * 2.0, r * 0.25)), A.call(UI.DIM))
				for gx in [-0.5, 0.0, 0.5]:
					ci.draw_circle(c + Vector2(r * gx, r * 0.47), r * 0.09, A.call(UI.GOLD))
				ci.draw_circle(c + Vector2(0, -r * 0.7), r * 0.13, A.call(UI.RED))
			8:   # red sun disc, the top symbol
				for k2 in 12:
					var a := TAU * float(k2) / 12.0
					ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.82, c + Vector2(cos(a), sin(a)) * r * 1.08, A.call(UI.GOLD), 2.0, true)
				ci.draw_circle(c, r * 0.78, A.call(UI.RED))
				ci.draw_arc(c, r * 0.78, 0.0, TAU, 36, A.call(UI.GOLD), 2.0, true)
				ci.draw_circle(c + Vector2(-r * 0.22, -r * 0.22), r * 0.2, A.call(Color(UI.FLASH, 0.45)))
			9:   # forge sigil (scatter): an eight point star in a ring
				ci.draw_circle(c, r * 1.02, A.call(UI.HAZE))
				ci.draw_arc(c, r * 1.0, 0.0, TAU, 40, A.call(UI.GOLD), 2.5, true)
				var star := PackedVector2Array()
				for k3 in 16:
					var a2 := TAU * float(k3) / 16.0 - PI / 2.0
					star.append(c + Vector2(cos(a2), sin(a2)) * r * (0.82 if k3 % 2 == 0 else 0.36))
				ci.draw_colored_polygon(star, A.call(UI.GOLD))
				ci.draw_circle(c, r * 0.24, A.call(UI.RED))
			10:  # sun orb with its multiplier
				ci.draw_circle(c, r * 1.05, A.call(Color(UI.RED, 0.25)))
				ci.draw_circle(c, r * 0.86, A.call(UI.RED))
				ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.25), r * 0.4, A.call(Color(UI.FLASH, 0.45)))
				ci.draw_arc(c, r * 0.86, 0.0, TAU, 32, A.call(UI.GOLD), 2.0, true)
				var f: Font = UI.DISPLAY
				var fs := int(maxf(10.0, r * (0.8 if val < 100 else 0.62)))
				var t := "×%d" % val
				ci.draw_string(f, c + Vector2(-r * 1.2, fs * 0.36), t, HORIZONTAL_ALIGNMENT_CENTER, r * 2.4, fs, A.call(UI.TEXT))

	static func _gem(ci: CanvasItem, c: Vector2, r: float, n: int, rot: float, col: Color, alpha: float) -> void:
		## A faceted gem: the shape, a lit upper half, an inner table, an edge.
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in n:
			var a := rot + TAU * float(i) / float(n)
			outer.append(c + Vector2(cos(a), sin(a)) * r)
			inner.append(c + Vector2(cos(a), sin(a)) * r * 0.5)
		ci.draw_colored_polygon(outer, col)
		for i in n:
			var j := (i + 1) % n
			var mid_a := rot + TAU * (float(i) + 0.5) / float(n)
			var lit := sin(mid_a) < 0.0   # facets facing up catch the light
			ci.draw_colored_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), Color(UI.TEXT, (0.22 if lit else 0.0) * alpha) if lit else Color(UI.INK, 0.22 * alpha))
		ci.draw_colored_polygon(inner, Color(UI.TEXT, 0.18 * alpha))
		var edge := outer.duplicate()
		edge.append(outer[0])
		ci.draw_polyline(edge, Color(UI.INK, 0.55 * alpha), 1.5, true)
