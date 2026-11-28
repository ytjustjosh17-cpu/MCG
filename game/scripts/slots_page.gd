class_name SlotsPage
extends CasinoGame
## One slot machine (theme: classic, neon or vault). 5 reels, 3 rows, 20
## lines. Each spin is settled first (stake taken, result worked out by
## SlotMath, win paid and saved), then the reels play it out, so closing the
## app mid-spin can never undo a loss. The chips shown lag the real chips
## until the reels stop, like a real machine.
##
## Extras: slam stop (tap Spin while spinning), win lines shown one by one,
## free spins (3+ scatters, wins x2, can retrigger, kept if the app closes),
## a bonus buy, autospin (10, 25, 50 or until free spins), and a paytable.

const AUTO_STOP_X := 50.0       # autospin stops on a win this many times the bet
const BIG_WIN_X := 20.0

var theme_id := "classic"
var math: SlotMath
var _ladder: Array = []         # line bets allowed now
var _bet_i := 0
var _machine: SlotMachine
var _bet: BetBar
var _spin_b: Button
var _auto_b: Button
var _bonus_b: Button
var _shown_chips := 0.0         # what the status row shows (lags while reels spin)
var _busy := false              # reels moving or a result still playing out
var _free_left := 0
var _free_won := 0.0
var _free_line := 0.0
var _last: Dictionary = {}      # last result, for tests


func _init(t := "classic") -> void:
	theme_id = t if SlotMath.THEMES.has(t) else "classic"
	super(String(SlotMath.THEMES[theme_id]["name"]), true)


func build_game() -> void:
	math = SlotMath.new(theme_id)
	_machine = SlotMachine.new(theme_id)
	_machine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_machine.reels_stopped.connect(_on_stopped)
	_machine.reel_landed.connect(func(_i: int):
		Kit.sound("tap")
		Kit.haptic("selection"))
	area.add_child(_machine)
	# Dock: the bet (total, with the line bet under it), Auto and Bonus, SPIN.
	_bet = BetBar.new()
	_bet.external = true
	_bet.stepped.connect(_step_bet)
	_bet.maxed.connect(func():
		if _busy or _free_left > 0:
			return
		_bet_i = _ladder.size() - 1
		_refresh_bet())
	dock.add_child(_bet)
	_auto_b = quiet("Auto", _on_auto)
	_bonus_b = quiet("Bonus buy", _on_bonus)
	dock_row([_auto_b, _bonus_b])
	_spin_b = primary("SPIN", _on_spin_pressed)
	_spin_b.add_theme_font_size_override("font_size", 20)
	dock.add_child(_spin_b)
	_shown_chips = Game.chips()
	_build_ladder()
	_bet_i = _default_bet()
	_resume_free()


func show_info() -> void:
	_show_paytable()


func auto_spin() -> bool:
	return spin()


func is_busy() -> bool:
	return _busy


# ---- bets -------------------------------------------------------------------

func _build_ladder() -> void:
	## Line bets in 1-2-5 steps; the total (x20 lines) never passes the max bet.
	var cap := Game.casino_max_bet()
	_ladder = []
	for e in range(-2, 16):
		for m in [1.0, 2.0, 5.0]:
			var v: float = m * pow(10.0, e)
			if math.total_bet(v) <= cap + 0.0001:
				_ladder.append(v)
	if _ladder.is_empty():
		_ladder = [0.01]
	_bet_i = clampi(_bet_i, 0, _ladder.size() - 1)


func _default_bet() -> int:
	## About 1% of your chips, within the limits.
	var want := maxf(Game.chips() * 0.01, 0.2)
	var best := 0
	for i in range(_ladder.size()):
		if math.total_bet(float(_ladder[i])) <= want:
			best = i
	return best


func line_bet() -> float:
	return float(_ladder[_bet_i])


func total_bet() -> float:
	return math.total_bet(line_bet())


func _step_bet(d: int) -> void:
	if _busy or _free_left > 0:
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


func _refresh_bet() -> void:
	var lb := line_bet() if _free_left <= 0 else _free_line
	_bet.show_text(Game.money_short(math.total_bet(lb)), "%s a line" % Game.money_short(lb))


func refresh() -> void:
	if _spin_b == null:
		return
	var keep := line_bet() if not _ladder.is_empty() else 0.0
	_build_ladder()
	# Income moved the limit: keep the same bet if still allowed.
	var idx := _ladder.find(keep)
	if idx >= 0:
		_bet_i = idx
	if not _busy:
		_shown_chips = Game.chips()
		status.set_chips(_shown_chips)
	_refresh_bet()
	_update_buttons()


func _update_buttons() -> void:
	if _spin_b == null:
		return
	if _free_left > 0:
		_spin_b.text = "FREE SPINS · %d" % _free_left
	elif _busy:
		_spin_b.text = "STOP"
	elif auto_on:
		_spin_b.text = "STOP AUTO"
	else:
		_spin_b.text = "SPIN"
	set_go(_spin_b, _busy or _free_left > 0 or auto_on or Game.chips() >= total_bet())
	_auto_b.text = ("Auto · %d left" % auto_left if auto_left > 0 else "Auto · on") if auto_on else "Auto"
	UI.paint(_auto_b, UI.RAISED, UI.GOLD if auto_on else UI.TEXT, 24)
	var idle := not _busy and _free_left <= 0
	_bet.locked = not idle
	_bonus_b.modulate.a = 1.0 if idle else 0.4


# ---- spinning -----------------------------------------------------------------

func _on_spin_pressed() -> void:
	if _busy:
		_machine.slam()     # tap again to stop the reels at once
		return
	if auto_on:
		stop_auto()
		return
	spin()


func spin() -> bool:
	## One paid spin (or the next free spin). Returns false if it couldn't start.
	if _busy:
		return false
	if _free_left > 0:
		_free_spin()
		return true
	var tb := total_bet()
	if tb > Game.casino_max_bet() + 0.001:
		_build_ladder()
		_refresh_bet()
		Kit.toast("Bet lowered to the table limit")
		return false
	if Game.chips() < tb - 0.001:
		stop_auto()
		Motion.shake(_spin_b)
		Kit.toast("Not enough chips · buy more in the casino")
		offer_chips()
		return false
	var before := Game.chips()
	if not Game.casino_stake(tb):
		Motion.shake(_spin_b)
		Kit.toast("That bet isn't allowed")
		return false
	# Settled now (saved), shown after.
	var res := math.spin(line_bet(), false)
	var paid := Game.casino_pay(float(res["total"])) if float(res["total"]) > 0.0 else 0.0
	res["paid"] = paid
	_shown_chips = before - tb
	_play(res)
	return true


func _free_spin() -> void:
	_free_left -= 1
	var res := math.spin(_free_line, true)
	_save_free(res)   # the count and the win go to disk with the payout
	var paid := Game.casino_pay(float(res["total"])) if float(res["total"]) > 0.0 else 0.0
	res["paid"] = paid
	_free_won += paid
	_play(res)


func _play(res: Dictionary) -> void:
	_last = res
	_busy = true
	status.clear_win()
	status.set_chips(_shown_chips)
	_update_buttons()
	_machine.spin_to(res)


func _on_stopped() -> void:
	var res := _last
	var paid := float(res.get("paid", 0.0))
	var tb := float(res.get("total_bet", total_bet()))
	var x := paid / maxf(tb, 0.0001)
	win_fx(paid, tb, BIG_WIN_X, _machine.get_global_rect().get_center())
	if x >= BIG_WIN_X:
		_machine.banner("MEGA WIN" if x >= AUTO_STOP_X else "BIG WIN", Game.money_short(paid), 2.2)
	var to := Game.chips()
	status.tween_chips(_shown_chips, to)
	_shown_chips = to
	var awarded := int(res.get("free_spins_awarded", 0))
	var wait := 0.25
	if paid > 0.0:
		wait = 1.1 if _machine.win_count() > 0 else 0.6
	if awarded > 0:
		var was_free := bool(res.get("free", false))
		if not was_free:
			_free_line = line_bet()
			_free_won = 0.0
		_free_left += awarded
		_save_free({})
		Kit.sound("sun")
		Kit.haptic("success")
		_machine.banner("%d FREE SPINS" % awarded if not was_free else "+%d FREE SPINS" % awarded, "Wins pay ×2", 1.8)
		wait = maxf(wait, 1.9)
		if auto_on and auto_left == -1:
			stop_auto()   # "until free spins" got there
	elif bool(res.get("free", false)) and _free_left <= 0:
		# The feature is over: show what it paid, then back to normal.
		_machine.banner("FREE SPINS WON", Game.money_short(_free_won), 2.2)
		_clear_free()
		wait = maxf(wait, 2.0)
	if auto_on and x >= AUTO_STOP_X:
		stop_auto()
		Kit.toast("Autospin stopped on a big win")
	_machine.set_free(_free_left, _free_won)
	await get_tree().create_timer(Motion.d(wait) if paid > 0.0 or awarded > 0 else 0.05).timeout
	if not is_inside_tree():
		return
	_busy = false
	_update_buttons()
	_refresh_bet()
	if _free_left > 0:
		if is_visible_in_tree():
			_free_spin()
		return
	if auto_on:
		if auto_left > 0:
			auto_left -= 1
		if auto_left == 0:
			stop_auto()
		elif is_visible_in_tree():
			await get_tree().create_timer(Motion.d(0.3)).timeout
			if auto_on and not _busy and is_inside_tree():
				if not spin():
					stop_auto()
	_update_buttons()


# ---- free spins kept on disk ----------------------------------------------------

func _save_free(_res: Dictionary) -> void:
	## Free spins survive closing the app (they were paid for or won).
	Game.ui["slots_free"] = {"theme": theme_id, "left": _free_left, "line": _free_line, "won": _free_won, "run": Game.rebirths()}
	Game.save_game()


func _clear_free() -> void:
	_free_left = 0
	Game.ui.erase("slots_free")
	Game.save_game()


func _resume_free() -> void:
	var f: Dictionary = Game.ui.get("slots_free", {})
	if f.is_empty() or String(f.get("theme", "")) != theme_id:
		return
	if int(f.get("run", 0)) != Game.rebirths():
		Game.ui.erase("slots_free")   # from a run before a rebirth: gone
		return
	_free_left = int(f.get("left", 0))
	_free_line = float(f.get("line", 0.0))
	_free_won = float(f.get("won", 0.0))
	if _free_left <= 0:
		Game.ui.erase("slots_free")
		return
	_machine.set_free(_free_left, _free_won)
	await get_tree().create_timer(0.8).timeout
	if is_inside_tree() and not _busy:
		_machine.banner("FREE SPINS", "%d left" % _free_left, 1.4)
		await get_tree().create_timer(Motion.d(1.2)).timeout
		if is_inside_tree() and not _busy and is_visible_in_tree():
			_free_spin()


# ---- autospin, bonus buy, paytable ---------------------------------------------

func _on_auto() -> void:
	if auto_on:
		stop_auto()
		return
	if _free_left > 0:
		return
	Kit.tick()
	var acts: Array = []
	for n in [10, 25, 50]:
		var nn: int = n
		acts.append({"text": "%d spins" % nn, "style": "secondary", "call": func(): _start_auto(nn)})
	acts.append({"text": "Until free spins", "style": "secondary", "call": func(): _start_auto(-1)})
	acts.append({"text": "Close", "style": "plain"})
	Kit.sheet("Autospin", "Spins at %s each. Stops on a win over %d× the bet, when chips run out, or when you leave." % [Game.money_short(total_bet()), int(AUTO_STOP_X)], acts)


func _on_bonus() -> void:
	if _busy or _free_left > 0:
		return
	Kit.tick()
	var cost := math.bonus_buy_cost(line_bet())
	var body := "Buy %d free spins at %s a line (wins pay ×2). Costs %s, %s× your bet." % [SlotMath.FREE_SPINS, Game.money_short(line_bet()), Game.money_short(cost), str(math.bonus_buy_cost_mult())]
	var acts: Array = []
	if Game.chips() >= cost:
		acts.append({"text": "Buy · " + Game.money_short(cost), "style": "primary", "call": func(): buy_bonus()})
	else:
		body += "\n\nYou have %s in chips." % Game.money_short(Game.chips())
		acts.append({"text": "Buy chips", "style": "primary", "call": func(): TradeSheet.open("chips", "", "chips_in")})
	acts.append({"text": "Not now", "style": "plain"})
	Kit.sheet("Bonus buy", body, acts)


func buy_bonus() -> bool:
	var cost := math.bonus_buy_cost(line_bet())
	var before := Game.chips()
	if _busy or _free_left > 0 or not Game.casino_stake(cost, math.bonus_buy_cost_mult() + 1.0):
		Kit.haptic("error")
		Kit.toast("Can't buy the bonus now")
		return false
	_shown_chips = before - cost
	status.set_chips(_shown_chips)
	status.clear_win()
	_free_line = line_bet()
	_free_won = 0.0
	_free_left = SlotMath.FREE_SPINS
	_save_free({})
	Kit.sound("sun")
	_machine.set_free(_free_left, 0.0)
	_machine.banner("%d FREE SPINS" % SlotMath.FREE_SPINS, "Wins pay ×2", 1.6)
	_update_buttons()
	_busy = true
	await get_tree().create_timer(Motion.d(1.5)).timeout
	_busy = false
	if is_inside_tree():
		_free_spin()
	return true


func _show_paytable() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var pt := math.paytable()
	var lb := line_bet() if _free_left <= 0 else _free_line
	for sym in ["sun", "wild", "crown", "bar", "seven", "bell", "cherry", "lemon"]:
		var pays: Array = pt[sym]
		box.add_child(_pay_row(sym, "5 %s · 4 %s · 3 %s" % [Game.money_short(float(pays[2]) * lb), Game.money_short(float(pays[1]) * lb), Game.money_short(float(pays[0]) * lb)]))
	var sp: Array = pt["scatter"]
	var tb := math.total_bet(lb)
	box.add_child(_pay_row("scatter", "Anywhere: 5 %s · 4 %s · 3 %s + free spins" % [Game.money_short(float(sp[2]) * tb), Game.money_short(float(sp[1]) * tb), Game.money_short(float(sp[0]) * tb)]))
	var th := math.theoretical()
	box.add_child(note("20 lines, pay left to right. Wild stands in for everything but the scatter. 3 or more scatters anywhere give 10 free spins with wins ×2, and they can come again. Pays back about %.1f%% over time. One spin pays at most %d× the bet, and the casino caps a round at %s." % [float(th["rtp"]) * 100.0, int(SlotMath.MAX_WIN_X), Game.money_short(Game.casino_max_win())]))
	box.add_child(jackpot_note())
	Kit.sheet("Paytable", "", [
		{"text": "See the 20 lines", "style": "secondary", "keep_open": false, "call": _show_lines},
		{"text": "Close", "style": "plain"}], true, box)


func _pay_row(sym: String, text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ic := SymbolIcon.new(sym)
	ic.custom_minimum_size = Vector2(36, 36)
	h.add_child(ic)
	var l := UI.label(text, 13, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


func _show_lines() -> void:
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for i in range(SlotMath.LINES):
		var d := LineDiagram.new(i)
		d.custom_minimum_size = Vector2(62, 44)
		g.add_child(d)
	Kit.sheet("The 20 lines", "", [{"text": "Close", "style": "plain"}], true, g)


# ===================================================================================

class SymbolIcon extends Control:
	## One reel symbol, drawn in code to fill its box.
	var sym := "sun"

	func _init(s := "sun") -> void:
		sym = s
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		SlotMachine.draw_symbol(self, sym, Rect2(Vector2.ZERO, size), 1.0)


class LineDiagram extends Control:
	## A tiny 5 x 3 grid with one payline drawn through it.
	var line := 0

	func _init(i := 0) -> void:
		line = i
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UI.INK)
		var cw := size.x / 5.0
		var ch := size.y / 3.0
		var pts := PackedVector2Array()
		var rows: Array = SlotMath.PAYLINES[line]
		for r in 5:
			for row in 3:
				var on := int(rows[r]) == row
				draw_rect(Rect2(Vector2(r * cw + 1, row * ch + 1), Vector2(cw - 2, ch - 2)), UI.GOLD if on else UI.WINDOW)
			pts.append(Vector2(r * cw + cw * 0.5, int(rows[r]) * ch + ch * 0.5))
		draw_polyline(pts, UI.RED, 1.5, true)
		draw_string(UI.SEMI, Vector2(2, 12), str(line + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.TEXT)


class SlotMachine extends Control:
	## The cabinet, the reels and everything drawn on them.
	signal reels_stopped
	signal reel_landed(i: int)
	const ROWS := 3
	const REELS := 5
	const PAD := 14.0
	var theme_id := "classic"
	var cells: Array = []          # [reel] -> Array of 3 symbols (what shows at rest)
	var _tape: Array = []          # [reel] -> long Array of symbols while spinning
	var _pos: Array = []           # [reel] -> float position on the tape (in cells)
	var _len: Array = []           # [reel] -> where the tape stops
	var _spinning: Array = []      # [reel] -> bool
	var _tweens: Array = []
	var _hot: Array = []           # [reel] -> anticipation glow
	var _res: Dictionary = {}
	var _show_line := -1           # index into _res.wins being shown; -2 = all
	var _line_t := 0.0
	var _pulse := 0.0
	var _banner := ""
	var _banner_sub := ""
	var _banner_t := 0.0
	var _free_left := 0
	var _free_won := 0.0
	var _t := 0.0
	var _acc := 0.0
	var _rng := RandomNumberGenerator.new()
	var _reels: Control             # clipped layer for the reels
	var _over: Control              # lines and banners on top

	func _init(t := "classic") -> void:
		theme_id = t
		custom_minimum_size = Vector2(0, 250)   # grows to fill the page; shorter screens get shorter reels
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.randomize()
		_reels = Control.new()
		_reels.clip_contents = true
		_reels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_reels)
		_reels.draw.connect(_draw_reels)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.clip_contents = true   # banner rays stay inside the cabinet
		add_child(_over)
		_over.draw.connect(_draw_over)
		resized.connect(func():
			var w := _window()
			_reels.position = w.position
			_reels.size = w.size
			_over.position = Vector2.ZERO
			_over.size = size
			_redraw())
		for r in REELS:
			cells.append(_random_col())
			_tape.append([])
			_pos.append(0.0)
			_len.append(0.0)
			_spinning.append(false)
			_tweens.append(null)
			_hot.append(false)

	func _redraw() -> void:
		queue_redraw()
		if _reels:
			_reels.queue_redraw()
			_over.queue_redraw()

	func _random_col() -> Array:
		var out: Array = []
		for i in ROWS:
			out.append(_rand_sym())
		return out

	func _rand_sym() -> String:
		var pool := ["sun", "crown", "bar", "seven", "bell", "cherry", "cherry", "lemon", "lemon", "bell", "wild", "scatter"]
		return String(pool[_rng.randi() % pool.size()])

	# ---- geometry
	func _window() -> Rect2:
		return Rect2(Vector2(PAD, 52.0), Vector2(size.x - PAD * 2.0, size.y - 52.0 - 46.0))

	func _cell(r: int, row: int) -> Rect2:
		var w := _window()
		var cw := w.size.x / REELS
		var ch := w.size.y / ROWS
		return Rect2(w.position + Vector2(r * cw, row * ch), Vector2(cw, ch))

	# ---- spinning
	func spin_to(res: Dictionary) -> void:
		_res = res
		_show_line = -1
		var grid: Array = res["grid"]
		var scat_seen := 0
		var base := 0.55
		var extra := 0.0
		for r in REELS:
			var dur := base + 0.17 * r + extra
			# Anticipation: two scatters already down, so the next reels slow and glow.
			_hot[r] = scat_seen >= 2
			if _hot[r]:
				extra += 0.55
				dur += 0.55
			var n := int(dur * 24.0) + 3
			# The tape runs bottom row first, so it scrolls downwards.
			var tape: Array = (cells[r] as Array).duplicate()
			tape.reverse()
			for i in n:
				tape.append(_rand_sym())
			_len[r] = float(tape.size())
			var fin: Array = (grid[r] as Array).duplicate()
			fin.reverse()
			for sy in fin:
				tape.append(String(sy))
			tape.append(_rand_sym())   # shows above during the bounce
			tape.append(_rand_sym())
			_tape[r] = tape
			_pos[r] = 0.0
			_spinning[r] = true
			for s in grid[r]:
				if String(s) == "scatter":
					scat_seen += 1
			if Motion.reduced():
				_pos[r] = _len[r]
				continue
			var t := create_tween()
			t.tween_method(_set_pos.bind(r), 0.0, float(_len[r]), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_callback(_land.bind(r))
			_tweens[r] = t
		if Motion.reduced():
			for r in REELS:
				_land(r)
		set_process(true)

	func _set_pos(v: float, r: int) -> void:
		_pos[r] = v
		_redraw()

	func slam() -> void:
		## Stop every reel now (tap Spin again while spinning).
		for r in REELS:
			if _spinning[r]:
				var t = _tweens[r]
				if t is Tween and (t as Tween).is_valid():
					(t as Tween).kill()
				_pos[r] = _len[r]
				_land(r)

	func _land(r: int) -> void:
		if not _spinning[r]:
			return
		_spinning[r] = false
		_hot[r] = false
		cells[r] = (_res["grid"][r] as Array).duplicate()
		_pos[r] = 0.0
		_tape[r] = []
		reel_landed.emit(r)
		_redraw()
		if not _spinning.has(true):
			_show_line = -2 if not (_res.get("wins", []) as Array).is_empty() else -1
			_line_t = 0.0
			reels_stopped.emit()

	func win_count() -> int:
		return (_res.get("wins", []) as Array).size()

	func banner(title: String, sub: String, secs: float) -> void:
		## A message across the reels. Draws only: it never takes a tap.
		_banner = title
		_banner_sub = sub
		_banner_t = secs
		set_process(true)

	func set_free(left: int, won: float) -> void:
		_free_left = left
		_free_won = won
		_redraw()

	func _process(delta: float) -> void:
		_t += delta
		_pulse += delta
		if _banner_t > 0.0:
			_banner_t -= delta
		if _show_line == -2 or _show_line >= 0:
			_line_t += delta
			var wins: Array = _res.get("wins", [])
			if _show_line == -2 and _line_t > 0.9:
				_show_line = 0 if wins.size() > 1 else -2
				_line_t = 0.0
			elif _show_line >= 0 and _line_t > 1.1:
				_show_line = (_show_line + 1) % maxi(1, wins.size())
				_line_t = 0.0
		if not is_visible_in_tree():
			return
		# Full speed only while something moves (reels, a banner, win lines);
		# at rest the marquee lights chase at 15 frames a second (battery).
		if _spinning.has(true) or _banner_t > 0.0:
			_acc = 0.0
			_redraw()
			return
		_acc += delta
		if _show_line != -1:
			# Win lines pulse until the next spin: 20 frames a second is smooth enough.
			if _acc >= 1.0 / 20.0:
				_acc = 0.0
				_redraw()
			return
		if not Game.reduce_motion and _acc >= 1.0 / 15.0:
			_acc = 0.0
			queue_redraw()

	# ---- drawing (1.2 craft pass: lit cabinet, drum-shaded reels, detailed symbols)
	func _theme_cols() -> Dictionary:
		## The cabinet's palette per theme, all from UI tokens.
		match theme_id:
			"neon":
				return {"top": UI.SKY.lerp(UI.HAZE, 0.55), "bot": UI.INK, "trim": UI.SLOT_COL["wild"], "trim2": UI.SLOT_COL["seven"], "plate": UI.INK}
			"vault":
				return {"top": UI.RAISED.lerp(UI.TRACK, 0.3), "bot": UI.SIDE, "trim": UI.SUB, "trim2": UI.GOLD, "plate": UI.SIDE}
		return {"top": UI.SIDE.lerp(UI.RAISED, 0.55), "bot": UI.INK, "trim": UI.GOLD, "trim2": UI.GOLD, "plate": UI.INK}

	static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bot: Color) -> void:
		ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([top, top, bot, bot]))

	static func hgrad(ci: CanvasItem, r: Rect2, left: Color, right: Color) -> void:
		ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([left, right, right, left]))

	static func rgrad(ci: CanvasItem, poly: PackedVector2Array, top_y: float, bot_y: float, top: Color, bot: Color) -> void:
		## A polygon shaded top to bottom (cabinet bodies, plates).
		var cols := PackedColorArray()
		for p in poly:
			cols.append(top.lerp(bot, clampf((p.y - top_y) / maxf(1.0, bot_y - top_y), 0.0, 1.0)))
		ci.draw_polygon(poly, cols)

	static func closed(poly: PackedVector2Array) -> PackedVector2Array:
		var o := poly.duplicate()
		o.append(poly[0])
		return o

	func _draw() -> void:
		var s := size
		var tc := _theme_cols()
		var body := Rect2(Vector2.ZERO, s)
		var neon_k := 0.75 + 0.25 * sin(_t * 2.0) if theme_id == "neon" and not Game.reduce_motion else 0.85
		# Drop shadow, then the cabinet body lit from above.
		draw_colored_polygon(UI.rounded_rect_poly(body.grow(-1.0).grow_side(SIDE_BOTTOM, 3.0), 22.0), Color(UI.INK, 0.6))
		var bp := UI.rounded_rect_poly(body, 22.0)
		rgrad(self, bp, 0.0, s.y, tc["top"], tc["bot"])
		# Bevel: a lit top edge and a dark lower edge, then the trim.
		var inner := UI.rounded_rect_poly(body.grow(-5.0), 18.0)
		draw_polyline(closed(inner), Color(UI.INK, 0.55), 2.0, true)
		draw_polyline(closed(UI.rounded_rect_poly(body.grow(-1.0), 21.0)), Color(tc["trim"], 0.55 * neon_k), 1.5, true)
		draw_line(Vector2(24, 2.5), Vector2(s.x - 24, 2.5), Color(UI.TEXT, 0.16), 1.0, true)
		if theme_id == "neon":
			# A soft tube glow just inside the trim.
			draw_polyline(closed(UI.rounded_rect_poly(body.grow(-3.0), 20.0)), Color(tc["trim"], 0.14 * neon_k), 4.0, true)
		if theme_id == "vault":
			# Bolts round the edge, each with a lit side.
			for i in 12:
				var x := 20.0 + (s.x - 40.0) * float(i) / 11.0
				for y in [11.0, s.y - 11.0]:
					draw_circle(Vector2(x, y), 3.2, UI.INK)
					draw_circle(Vector2(x, y), 2.6, UI.DIM)
					draw_circle(Vector2(x - 0.8, y - 0.8), 1.0, Color(UI.TEXT, 0.5))
		# Marquee: a dark sign plate with bulbs that chase, then the machine's name.
		var plate := Rect2(Vector2(12, 7), Vector2(s.x - 24, 40))
		draw_colored_polygon(UI.rounded_rect_poly(plate, 12.0), Color(tc["plate"], 0.75))
		draw_polyline(closed(UI.rounded_rect_poly(plate, 12.0)), Color(tc["trim2"], 0.35), 1.0, true)
		var lights := 17
		for i in lights:
			var lit := fmod(_t * 6.0 - float(i), float(lights)) < 3.0 if not Game.reduce_motion else i % 3 == 0
			var bc := Vector2(26.0 + (s.x - 52.0) * float(i) / float(lights - 1), 13.5)
			var bulb: Color = tc["trim2"] if theme_id == "neon" and i % 2 == 1 else UI.GOLD
			if lit:
				draw_circle(bc, 6.0, Color(bulb, 0.16))
				draw_circle(bc, 3.0, bulb)
				draw_circle(bc + Vector2(-0.9, -0.9), 1.0, Color(UI.FLASH, 0.9))
			else:
				draw_circle(bc, 2.8, Color(UI.INK, 0.8))
				draw_circle(bc, 2.2, UI.TRACK)
		var title := "%s SWINGS · 20 LINES" % String(SlotMath.THEMES[theme_id]["volatility"]).to_upper()
		if _free_left > 0:
			title = "FREE SPINS · %d LEFT · ×2" % _free_left
		var tcol: Color = UI.GOLD if _free_left > 0 else UI.TEXT
		draw_string(UI.DISPLAY, Vector2(1, 43), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color(UI.INK, 0.9))
		draw_string(UI.DISPLAY, Vector2(0, 42), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, tcol)
		# Reel window: a recessed bezel with a gold lip and four studs.
		var w := _window()
		draw_colored_polygon(UI.rounded_rect_poly(w.grow(9.0), 10.0), Color(UI.INK, 0.65))
		draw_colored_polygon(UI.rounded_rect_poly(w.grow(7.0), 9.0), tc["bot"].lerp(UI.RAISED, 0.35))
		draw_polyline(closed(UI.rounded_rect_poly(w.grow(7.0), 9.0)), Color(tc["trim"], 0.45 * neon_k), 1.2, true)
		draw_line(Vector2(w.position.x - 5, w.position.y - 6.5), Vector2(w.end.x + 5, w.position.y - 6.5), Color(UI.TEXT, 0.12), 1.0)
		draw_rect(w.grow(3.0), UI.INK)
		for cx in [w.position.x - 4.0, w.end.x + 4.0]:
			for cy in [w.position.y - 4.0, w.end.y + 4.0]:
				draw_circle(Vector2(cx, cy), 2.6, Color(tc["trim"], 0.9))
				draw_circle(Vector2(cx - 0.7, cy - 0.7), 0.9, Color(UI.FLASH, 0.8))
		# Info strip under the reels, on its own little plate.
		var info := _info_text()
		var hot := info.begins_with("Line") or info.begins_with("Scatter")
		var ir := Rect2(Vector2(s.x * 0.18, s.y - 36.0), Vector2(s.x * 0.64, 26.0))
		draw_colored_polygon(UI.rounded_rect_poly(ir, 13.0), Color(UI.INK, 0.55))
		if hot:
			draw_polyline(closed(UI.rounded_rect_poly(ir, 13.0)), Color(UI.GOLD, 0.5), 1.0, true)
		draw_string(UI.SEMI, Vector2(0, s.y - 18), info, HORIZONTAL_ALIGNMENT_CENTER, s.x, 15, UI.GOLD if hot else UI.SUB)

	func _draw_reels() -> void:
		## Drawn in _reels, which clips: spinning symbols never spill out.
		var ci: Control = _reels
		var w := _window()
		ci.draw_set_transform(-w.position)
		var cw := w.size.x / REELS
		var ch := w.size.y / ROWS
		# Each machine's drums catch a little of its own colour.
		var tint: Color = {"neon": UI.SLOT_COL["wild"], "vault": UI.SUB}.get(theme_id, UI.GOLD)
		var lit := UI.WINDOW.lerp(UI.TEXT, 0.06).lerp(tint, 0.07)
		for r in REELS:
			var col_r := Rect2(w.position + Vector2(r * cw + 1.5, 0), Vector2(cw - 3.0, w.size.y))
			# A curved drum: dark at the top and bottom, lit across the middle, dark at the sides.
			var mid := col_r.position.y + col_r.size.y * 0.42
			vgrad(ci, Rect2(col_r.position, Vector2(col_r.size.x, mid - col_r.position.y)), UI.INK.lerp(UI.WINDOW, 0.3), lit)
			vgrad(ci, Rect2(Vector2(col_r.position.x, mid), Vector2(col_r.size.x, col_r.end.y - mid)), lit, UI.INK.lerp(UI.WINDOW, 0.25))
			hgrad(ci, Rect2(col_r.position, Vector2(col_r.size.x * 0.18, col_r.size.y)), Color(UI.INK, 0.45), Color(UI.INK, 0.0))
			hgrad(ci, Rect2(Vector2(col_r.end.x - col_r.size.x * 0.18, col_r.position.y), Vector2(col_r.size.x * 0.18, col_r.size.y)), Color(UI.INK, 0.0), Color(UI.INK, 0.45))
			if _hot[r] and _spinning[r]:
				var a := 0.35 + 0.25 * sin(_t * 12.0)
				ci.draw_rect(col_r.grow(-1.0), Color(UI.GOLD, a * 0.25))
				ci.draw_rect(col_r.grow(-1.0), Color(UI.GOLD, a), false, 3.0)
			if _spinning[r]:
				_draw_tape(ci, r, col_r, ch)
			else:
				for row in ROWS:
					var cell := _cell(r, row)
					var cr := cell.grow(-5.0)
					var sym := String(cells[r][row])
					var hl := _is_hl(r, row)
					if hl:
						var p := 0.5 + 0.5 * sin(_pulse * 8.0) if not Game.reduce_motion else 1.0
						var hr := cell.grow(-3.0)
						for g in 3:
							ci.draw_rect(hr.grow(-float(g) * 3.0), Color(UI.GOLD, (0.10 + 0.08 * p) * (1.0 - float(g) * 0.3)))
						ci.draw_rect(hr, Color(UI.GOLD, 0.85 + 0.15 * p), false, 2.0)
						var L := minf(10.0, hr.size.x * 0.2)
						for cx in [hr.position.x, hr.end.x]:
							for cy in [hr.position.y, hr.end.y]:
								var dx := L if cx == hr.position.x else -L
								var dy := L if cy == hr.position.y else -L
								ci.draw_line(Vector2(cx, cy), Vector2(cx + dx, cy), UI.TEXT, 2.0)
								ci.draw_line(Vector2(cx, cy), Vector2(cx, cy + dy), UI.TEXT, 2.0)
					var dim := 1.0
					if _show_line != -1 and not hl:
						dim = 0.4
					var grow := 1.0
					if hl and not Game.reduce_motion:
						grow = 1.0 + 0.06 * (0.5 + 0.5 * sin(_pulse * 8.0))
					var sr := Rect2(cr.get_center() - cr.size * 0.5 * grow, cr.size * grow)
					SlotMachine.draw_symbol(ci, sym, sr, dim)
			# The seam between drums: a dark groove with a lit edge.
			if r > 0:
				var x := w.position.x + r * cw
				ci.draw_line(Vector2(x, w.position.y), Vector2(x, w.end.y), UI.INK, 3.0)
				ci.draw_line(Vector2(x + 1.5, w.position.y), Vector2(x + 1.5, w.end.y), Color(UI.TEXT, 0.06), 1.0)
		# The drum curving away at the top and bottom, then a faint glass glare.
		var fade := minf(26.0, w.size.y * 0.12)
		vgrad(ci, Rect2(w.position, Vector2(w.size.x, fade)), Color(UI.INK, 0.85), Color(UI.INK, 0.0))
		vgrad(ci, Rect2(Vector2(w.position.x, w.end.y - fade), Vector2(w.size.x, fade)), Color(UI.INK, 0.0), Color(UI.INK, 0.85))
		var gl := PackedVector2Array([w.position + Vector2(w.size.x * 0.08, 0), w.position + Vector2(w.size.x * 0.30, 0),
			w.position + Vector2(w.size.x * 0.12, w.size.y), w.position + Vector2(-w.size.x * 0.10, w.size.y)])
		ci.draw_colored_polygon(gl, Color(UI.TEXT, 0.025))

	func _draw_over() -> void:
		## Win lines and banners, above the reels. Never takes a tap.
		var ci: Control = _over
		var s := size
		var w := _window()
		_draw_lines(ci, w)
		if _banner_t > 0.0:
			var a := clampf(_banner_t * 3.0, 0.0, 1.0)
			var br := Rect2(Vector2(PAD - 2.0, w.get_center().y - 50.0), Vector2(s.x - PAD * 2.0 + 4.0, 100.0))
			var c := br.get_center()
			# Slow rays behind the plate, then the plate with a double gold rule.
			if not Game.reduce_motion:
				for i in 12:
					var ang := _t * 0.6 + TAU * float(i) / 12.0
					var d1 := Vector2(cos(ang), sin(ang))
					var d2 := Vector2(cos(ang + 0.12), sin(ang + 0.12))
					ci.draw_colored_polygon(PackedVector2Array([c, c + d1 * s.x * 0.7, c + d2 * s.x * 0.7]), Color(UI.GOLD, 0.06 * a))
			ci.draw_colored_polygon(UI.rounded_rect_poly(br, 14.0), Color(UI.INK, 0.9 * a))
			vgrad(ci, Rect2(br.position + Vector2(0, 4), Vector2(br.size.x, br.size.y * 0.45)), Color(UI.GOLD, 0.10 * a), Color(UI.GOLD, 0.0))
			ci.draw_polyline(closed(UI.rounded_rect_poly(br, 14.0)), Color(UI.GOLD, a), 2.0, true)
			ci.draw_polyline(closed(UI.rounded_rect_poly(br.grow(-5.0), 10.0)), Color(UI.GOLD, 0.35 * a), 1.0, true)
			ci.draw_string(UI.DISPLAY, Vector2(2, br.position.y + 52.0), _banner, HORIZONTAL_ALIGNMENT_CENTER, s.x, 36, Color(UI.INK, a))
			ci.draw_string(UI.DISPLAY, Vector2(0, br.position.y + 50.0), _banner, HORIZONTAL_ALIGNMENT_CENTER, s.x, 36, Color(UI.GOLD, a))
			ci.draw_string(UI.SEMI, Vector2(0, br.position.y + 80.0), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, s.x, 17, Color(UI.TEXT, a))

	func _info_text() -> String:
		if _spinning.has(true):
			return "Good luck"
		var wins: Array = _res.get("wins", [])
		if _show_line >= 0 and _show_line < wins.size():
			var wn: Dictionary = wins[_show_line]
			return "Line %d · %d × %s · %s" % [int(wn["line"]) + 1, int(wn["count"]), String(wn["symbol"]).capitalize(), Game.money_short(float(wn["pay"]))]
		if _show_line == -2 and int(_res.get("scatter", 0)) >= 3 and wins.is_empty():
			return "Scatter · %d anywhere" % int(_res.get("scatter", 0))
		if _show_line == -2:
			return "%d winning line%s" % [wins.size(), "" if wins.size() == 1 else "s"]
		if _free_left > 0 and _free_won > 0.0:
			return "Free spins so far · " + Game.money_short(_free_won)
		if not _res.is_empty() and float(_res.get("total", 0.0)) <= 0.0:
			return "No win this time"
		return "Tap SPIN"

	func _is_hl(r: int, row: int) -> bool:
		if _show_line == -1 or _res.is_empty():
			return false
		var grid: Array = _res["grid"]
		if String(grid[r][row]) == "scatter" and int(_res.get("scatter", 0)) >= 3:
			return true
		var wins: Array = _res.get("wins", [])
		var list: Array = wins if _show_line == -2 else ([wins[_show_line]] if _show_line < wins.size() else [])
		for wn in list:
			var rows: Array = SlotMath.PAYLINES[int(wn["line"])]
			if r < int(wn["count"]) and int(rows[r]) == row:
				return true
		return false

	func _draw_lines(ci: CanvasItem, w: Rect2) -> void:
		if _show_line == -1 or _res.is_empty():
			return
		var wins: Array = _res.get("wins", [])
		var list: Array = []
		if _show_line == -2:
			list = wins
		elif _show_line < wins.size():
			list = [wins[_show_line]]
		for wn in list:
			var rows: Array = SlotMath.PAYLINES[int(wn["line"])]
			var pts := PackedVector2Array()
			pts.append(Vector2(w.position.x - 4.0, _cell(0, int(rows[0])).get_center().y))
			for r in REELS:
				pts.append(_cell(r, int(rows[r])).get_center())
			pts.append(Vector2(w.end.x + 4.0, _cell(4, int(rows[4])).get_center().y))
			# A glowing line: a soft halo, a gold band, a bright core.
			ci.draw_polyline(pts, Color(UI.INK, 0.6), 9.0, true)
			ci.draw_polyline(pts, Color(UI.GOLD, 0.16), 14.0, true)
			ci.draw_polyline(pts, Color(UI.GOLD, 0.35), 7.0, true)
			ci.draw_polyline(pts, UI.GOLD, 3.5, true)
			ci.draw_polyline(pts, Color(UI.FLASH, 0.75), 1.2, true)
			# The line number on the left edge, like a real machine.
			var lp := pts[0]
			ci.draw_circle(lp, 13.0, Color(UI.INK, 0.8))
			ci.draw_circle(lp, 11.5, UI.GOLD)
			ci.draw_arc(lp, 9.5, PI * 1.1, PI * 1.9, 10, Color(UI.FLASH, 0.7), 1.2, true)
			ci.draw_string(UI.SEMI, lp + Vector2(-11, 5), str(int(wn["line"]) + 1), HORIZONTAL_ALIGNMENT_CENTER, 22, 13, UI.INK)

	func _draw_tape(ci: CanvasItem, r: int, col_r: Rect2, ch: float) -> void:
		var pos := float(_pos[r])
		var tape: Array = _tape[r]
		var first := int(floor(pos))
		var frac := pos - float(first)
		# Speed blur: stretch the symbols and fade them while fast.
		var left := float(_len[r]) - pos
		var fast := clampf(left / 6.0, 0.0, 1.0)
		for k in range(-1, ROWS + 1):
			var idx := first + k
			if idx < 0 or idx >= tape.size():
				continue
			# Tape runs downwards: later symbols come in from the top.
			var y := col_r.position.y + (float(ROWS - 1 - k) + frac) * ch
			var cell := Rect2(Vector2(col_r.position.x + 4.0, y + 6.0), Vector2(col_r.size.x - 8.0, ch - 12.0))
			if cell.end.y < col_r.position.y or cell.position.y > col_r.end.y:
				continue
			var stretch := 1.0 + 0.45 * fast
			var sr := Rect2(cell.get_center() - Vector2(cell.size.x * 0.5, cell.size.y * 0.5 * stretch), Vector2(cell.size.x, cell.size.y * stretch))
			SlotMachine.draw_symbol(ci, String(tape[idx]), sr, 1.0 - 0.45 * fast)
		# Motion streaks.
		if fast > 0.2:
			for i in 3:
				var x := col_r.position.x + col_r.size.x * (0.25 + 0.25 * i)
				ci.draw_line(Vector2(x, col_r.position.y), Vector2(x, col_r.end.y), Color(UI.TEXT, 0.04 * fast), 2.0)

	static func draw_symbol(ci: CanvasItem, sym: String, r: Rect2, alpha: float) -> void:
		## Every symbol, drawn to fit r (any size). alpha fades it. Light comes
		## from the top left: a soft shadow down-right, highlights up-left.
		var c := r.get_center()
		var u := minf(r.size.x, r.size.y)
		var col: Color = UI.SLOT_COL.get(sym, UI.TEXT)
		col.a *= alpha
		var ink := Color(UI.INK, alpha)
		var shade := Color(col.darkened(0.28), alpha)
		var light := Color(col.lightened(0.35), alpha)
		if sym == "lemon":
			shade = Color(col.darkened(0.1), alpha)   # yellow goes muddy if shaded hard
			light = Color(col.lightened(0.22), alpha)
		var shadow := Color(UI.INK, 0.45 * alpha)
		var hi := Color(UI.FLASH, 0.7 * alpha)
		var sh := Vector2(u * 0.035, u * 0.05)   # shadow offset
		var lw := maxf(1.0, u * 0.025)          # outline width
		match sym:
			"sun":
				ci.draw_circle(c, u * 0.47, Color(col, 0.12 * alpha))
				for i in 16:
					var a := TAU * float(i) / 16.0
					var long := i % 2 == 0
					var r1 := u * 0.3
					var r2 := u * (0.47 if long else 0.39)
					var wd := 0.09 if long else 0.07
					var tip := c + Vector2(cos(a), sin(a)) * r2
					var b1 := c + Vector2(cos(a - wd), sin(a - wd)) * r1
					var b2 := c + Vector2(cos(a + wd), sin(a + wd)) * r1
					ci.draw_colored_polygon(PackedVector2Array([b1 + sh, tip + sh, b2 + sh]), shadow)
					ci.draw_colored_polygon(PackedVector2Array([b1, tip, b2]), col if long else shade)
				ci.draw_circle(c + sh, u * 0.29, shadow)
				ci.draw_circle(c, u * 0.29, shade)
				ci.draw_circle(c + Vector2(-u * 0.02, -u * 0.02), u * 0.26, col)
				ci.draw_circle(c + Vector2(-u * 0.06, -u * 0.06), u * 0.17, Color(light, 0.55 * alpha))
				ci.draw_arc(c, u * 0.29, 0.0, TAU, 32, Color(UI.GOLD, 0.8 * alpha), lw, true)
				ci.draw_circle(c + Vector2(-u * 0.1, -u * 0.1), u * 0.06, hi)
			"crown":
				var b := u * 0.42
				var pts := PackedVector2Array([
					c + Vector2(-b, b * 0.55), c + Vector2(-b, -b * 0.35), c + Vector2(-b * 0.5, b * 0.05),
					c + Vector2(0, -b * 0.6), c + Vector2(b * 0.5, b * 0.05), c + Vector2(b, -b * 0.35), c + Vector2(b, b * 0.55)])
				var shp := PackedVector2Array()
				for p in pts:
					shp.append(p + sh)
				ci.draw_colored_polygon(shp, shadow)
				rgrad(ci, pts, c.y - b * 0.6, c.y + b * 0.55, light, shade)
				ci.draw_polyline(closed(pts), Color(UI.INK, 0.55 * alpha), lw, true)
				# The band with set stones.
				var band := Rect2(c + Vector2(-b, b * 0.28), Vector2(b * 2.0, b * 0.27))
				ci.draw_rect(band, shade)
				ci.draw_line(band.position, Vector2(band.end.x, band.position.y), Color(light, 0.8 * alpha), lw)
				for k in [-0.55, 0.0, 0.55]:
					var gc := c + Vector2(b * k, b * 0.415)
					var gcol: Color = UI.RED if k == 0.0 else UI.SLOT_COL["wild"]
					ci.draw_circle(gc, u * 0.045, Color(gcol, alpha))
					ci.draw_circle(gc + Vector2(-u * 0.012, -u * 0.012), u * 0.015, hi)
				for p in [Vector2(-b, -b * 0.35), Vector2(0, -b * 0.6), Vector2(b, -b * 0.35)]:
					ci.draw_circle(c + p, u * 0.065, col)
					ci.draw_circle(c + p + Vector2(-u * 0.018, -u * 0.018), u * 0.022, hi)
			"bar":
				var br := Rect2(c - Vector2(u * 0.44, u * 0.21), Vector2(u * 0.88, u * 0.42))
				ci.draw_colored_polygon(UI.rounded_rect_poly(Rect2(br.position + sh, br.size), u * 0.08), shadow)
				ci.draw_colored_polygon(UI.rounded_rect_poly(br, u * 0.08), Color(UI.INK, 0.9 * alpha))
				var face := br.grow(-u * 0.035)
				var fp := UI.rounded_rect_poly(face, u * 0.06)
				rgrad(ci, fp, face.position.y, face.end.y, light, shade)
				ci.draw_rect(Rect2(face.position + Vector2(u * 0.03, u * 0.02), Vector2(face.size.x - u * 0.06, face.size.y * 0.16)), Color(UI.FLASH, 0.35 * alpha))
				var fs := int(u * 0.3)
				ci.draw_string(UI.DISPLAY, Vector2(br.position.x + 1.0, c.y + u * 0.11 + 1.0), "BAR", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, fs, Color(UI.TEXT, 0.35 * alpha))
				ci.draw_string(UI.DISPLAY, Vector2(br.position.x, c.y + u * 0.11), "BAR", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, fs, ink)
			"seven":
				var fs := int(u * 0.86)
				var base := Vector2(r.position.x, c.y + u * 0.32)
				var o := maxf(1.5, u * 0.035)
				ci.draw_string(UI.DISPLAY, base + sh * 1.6, "7", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, shadow)
				# A dark outline all round, a deep bevel below, the face, a lit edge above.
				for d in [Vector2(-o, 0), Vector2(o, 0), Vector2(0, -o), Vector2(0, o), Vector2(-o, -o), Vector2(o, o), Vector2(-o, o), Vector2(o, -o)]:
					ci.draw_string(UI.DISPLAY, base + d, "7", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, ink)
				ci.draw_string(UI.DISPLAY, base + Vector2(0, o * 0.8), "7", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, shade)
				ci.draw_string(UI.DISPLAY, base + Vector2(-o * 0.5, -o * 0.5), "7", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, light)
				ci.draw_string(UI.DISPLAY, base, "7", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)
			"bell":
				var b := u * 0.36
				var pts := PackedVector2Array()
				for i in 15:
					var a := PI + PI * float(i) / 14.0
					pts.append(c + Vector2(cos(a) * b * 0.75, sin(a) * b * 0.9 - b * 0.05))
				pts.append(c + Vector2(b * 0.85, b * 0.4))
				pts.append(c + Vector2(b, b * 0.58))
				pts.append(c + Vector2(-b, b * 0.58))
				pts.append(c + Vector2(-b * 0.85, b * 0.4))
				var shp := PackedVector2Array()
				for p in pts:
					shp.append(p + sh)
				ci.draw_colored_polygon(shp, shadow)
				ci.draw_circle(c + Vector2(0, b * 0.74) + sh, u * 0.085, shadow)
				ci.draw_circle(c + Vector2(0, b * 0.74), u * 0.085, shade)
				rgrad(ci, pts, c.y - b, c.y + b * 0.6, light, shade)
				# A shine down the left side and the rolled lip.
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-b * 0.45, -b * 0.6), c + Vector2(-b * 0.25, -b * 0.75), c + Vector2(-b * 0.45, b * 0.3), c + Vector2(-b * 0.65, b * 0.3)]), Color(UI.FLASH, 0.35 * alpha))
				ci.draw_rect(Rect2(c + Vector2(-b, b * 0.46), Vector2(b * 2.0, b * 0.12)), Color(col.darkened(0.15), alpha))
				ci.draw_line(c + Vector2(-b, b * 0.46), c + Vector2(b, b * 0.46), Color(light, 0.9 * alpha), lw)
				ci.draw_polyline(closed(pts), Color(UI.INK, 0.5 * alpha), lw, true)
				ci.draw_circle(c + Vector2(0, -b * 0.98), u * 0.055, col)
				ci.draw_circle(c + Vector2(-u * 0.015, -b * 1.0), u * 0.02, hi)
			"cherry":
				var b := u * 0.18
				var stem := Color(UI.UP.darkened(0.25), alpha)
				var top := c + Vector2(b * 0.4, -b * 2.0)
				ci.draw_line(c + Vector2(-b, b * 0.5), top, stem, maxf(1.5, u * 0.045), true)
				ci.draw_line(c + Vector2(b * 1.2, b * 0.8), top, stem, maxf(1.5, u * 0.045), true)
				# A leaf off the top of the stems.
				var leaf := PackedVector2Array([top, top + Vector2(b * 0.7, -b * 0.55), top + Vector2(b * 1.5, -b * 0.35), top + Vector2(b * 0.8, b * 0.05)])
				ci.draw_colored_polygon(leaf, Color(UI.UP, alpha))
				ci.draw_line(top, top + Vector2(b * 1.3, -b * 0.3), Color(UI.UP.darkened(0.3), alpha), maxf(1.0, u * 0.015), true)
				for cc in [c + Vector2(-b, b * 0.95), c + Vector2(b * 1.2, b * 1.25)]:
					ci.draw_circle(cc + sh, b * 1.08, shadow)
					ci.draw_circle(cc, b * 1.08, shade)
					ci.draw_circle(cc + Vector2(-b * 0.1, -b * 0.12), b * 0.92, col)
					ci.draw_circle(cc + Vector2(-b * 0.38, -b * 0.4), b * 0.26, hi)
			"lemon":
				var outer := PackedVector2Array()
				for i in 28:
					var a := TAU * float(i) / 28.0
					var k := 1.0 + 0.2 * absf(cos(a)) * absf(cos(a)) * absf(cos(a))
					outer.append(c + Vector2(cos(a) * u * 0.38 * k, sin(a) * u * 0.27))
				var shp := PackedVector2Array()
				for p in outer:
					shp.append(p + sh)
				ci.draw_colored_polygon(shp, shadow)
				rgrad(ci, outer, c.y - u * 0.27, c.y + u * 0.27, light, shade)
				# Pitted skin, a lit stripe, and the two nubs.
				for d in [Vector2(-0.18, -0.05), Vector2(0.05, 0.08), Vector2(0.2, -0.06), Vector2(-0.05, 0.14), Vector2(0.12, 0.16)]:
					ci.draw_circle(c + d * u, maxf(0.8, u * 0.012), Color(UI.INK, 0.18 * alpha))
				ci.draw_line(c + Vector2(-u * 0.17, -u * 0.12), c + Vector2(u * 0.12, -u * 0.16), Color(UI.FLASH, 0.6 * alpha), maxf(1.0, u * 0.035), true)
				ci.draw_circle(c + Vector2(u * 0.46, 0), u * 0.035, shade)
				ci.draw_circle(c + Vector2(-u * 0.46, 0), u * 0.03, shade)
				ci.draw_polyline(closed(outer), Color(UI.INK, 0.35 * alpha), lw, true)
			"wild":
				var wr := Rect2(c - Vector2(u * 0.46, u * 0.3), Vector2(u * 0.92, u * 0.6))
				ci.draw_colored_polygon(UI.rounded_rect_poly(Rect2(wr.position + sh, wr.size), u * 0.1), shadow)
				var wp := UI.rounded_rect_poly(wr, u * 0.1)
				rgrad(ci, wp, wr.position.y, wr.end.y, light, shade)
				ci.draw_polyline(closed(wp), Color(UI.GOLD, alpha), maxf(1.5, u * 0.035), true)
				ci.draw_polyline(closed(UI.rounded_rect_poly(wr.grow(-u * 0.05), u * 0.07)), Color(UI.FLASH, 0.4 * alpha), lw, true)
				ci.draw_string(UI.DISPLAY, Vector2(wr.position.x + 1.0, c.y + u * 0.11 + 1.0), "WILD", HORIZONTAL_ALIGNMENT_CENTER, wr.size.x, int(u * 0.29), Color(UI.TEXT, 0.4 * alpha))
				ci.draw_string(UI.DISPLAY, Vector2(wr.position.x, c.y + u * 0.11), "WILD", HORIZONTAL_ALIGNMENT_CENTER, wr.size.x, int(u * 0.29), ink)
				# Two small sparkles on the corners.
				for sp in [wr.position + Vector2(u * 0.08, u * 0.02), wr.end - Vector2(u * 0.08, u * 0.02)]:
					var sz := u * 0.06
					ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -sz), sp + Vector2(sz * 0.3, 0), sp + Vector2(0, sz), sp + Vector2(-sz * 0.3, 0)]), hi)
					ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(-sz, 0), sp + Vector2(0, -sz * 0.3), sp + Vector2(sz, 0), sp + Vector2(0, sz * 0.3)]), hi)
			"scatter":
				ci.draw_circle(c, u * 0.48, Color(col, 0.14 * alpha))
				var outer := PackedVector2Array()
				var inner := PackedVector2Array()
				for i in 16:
					var a := -PI / 2.0 + TAU * float(i) / 16.0
					outer.append(c + Vector2(cos(a), sin(a)) * u * (0.46 if i % 2 == 0 else 0.23))
					inner.append(c + Vector2(cos(a), sin(a)) * u * (0.33 if i % 2 == 0 else 0.17))
				var shp := PackedVector2Array()
				for p in outer:
					shp.append(p + sh)
				ci.draw_colored_polygon(shp, shadow)
				ci.draw_colored_polygon(outer, shade)
				rgrad(ci, inner, c.y - u * 0.33, c.y + u * 0.33, light, col)
				ci.draw_polyline(closed(outer), Color(UI.GOLD, 0.8 * alpha), lw, true)
				var pill := Rect2(c - Vector2(u * 0.2, u * 0.085), Vector2(u * 0.4, u * 0.17))
				ci.draw_colored_polygon(UI.rounded_rect_poly(pill, u * 0.08), Color(UI.INK, 0.85 * alpha))
				ci.draw_string(UI.SEMI, Vector2(pill.position.x, pill.position.y + pill.size.y * 0.8), "FREE", HORIZONTAL_ALIGNMENT_CENTER, pill.size.x, int(maxf(8.0, u * 0.13)), Color(UI.GOLD, alpha))
