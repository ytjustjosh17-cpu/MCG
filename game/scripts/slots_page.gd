class_name SlotsPage
extends Page
## One slot machine (theme: classic, neon or vault). 5 reels, 3 rows, 20
## lines. Each spin is settled first (stake taken, result worked out by
## SlotMath, win paid and saved), then the reels play it out, so closing the
## app mid-spin can never undo a loss. The credits meter lags the real chips
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
var _credits: Label
var _bet_l: Label
var _bet_sub: Label
var _win_l: Label
var _minus: Button
var _plus: Button
var _max: Button
var _spin_b: Button
var _auto_b: Button
var _bonus_b: Button
var _info_b: Button
var _shown_chips := 0.0         # what the meter shows (lags while reels spin)
var _shown_win := 0.0
var _busy := false              # reels moving or a result still playing out
var _auto_left := 0             # spins left on autospin (-1 = until free spins)
var _auto_on := false
var _free_left := 0
var _free_won := 0.0
var _free_line := 0.0
var _last: Dictionary = {}      # last result, for tests


func _init(t := "classic") -> void:
	theme_id = t if SlotMath.THEMES.has(t) else "classic"
	super(String(SlotMath.THEMES[theme_id]["name"]), true)


func build() -> void:
	math = SlotMath.new(theme_id)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # the machine never scrolls while you play
	if _title_label:
		_title_label.add_theme_font_size_override("font_size", 32)
	_machine = SlotMachine.new(theme_id)
	_machine.reels_stopped.connect(_on_stopped)
	_machine.reel_landed.connect(func(_i: int):
		Kit.sound("tap")
		Kit.haptic("selection"))
	body.add_child(_machine)
	# Meters: credits, bet, win.
	var meters := PanelContainer.new()
	meters.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16, 14, 8))
	body.add_child(meters)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 6)
	meters.add_child(mh)
	_credits = _meter(mh, "Credits")
	_bet_l = _meter(mh, "Bet")
	_win_l = _meter(mh, "Win")
	_win_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	(_win_l.get_parent().get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bet_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(_bet_l.get_parent().get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Bet row: - [per line] + Max.
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 8)
	body.add_child(br)
	_minus = _small("-", func(): _step_bet(-1))
	br.add_child(_minus)
	_bet_sub = UI.label("", 13, UI.SUB)
	_bet_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bet_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(_bet_sub)
	_plus = _small("+", func(): _step_bet(1))
	br.add_child(_plus)
	_max = _small("Max", func():
		if _busy or _free_left > 0:
			return
		Kit.haptic("selection")
		_bet_i = _ladder.size() - 1
		_refresh_bet())
	_max.custom_minimum_size = Vector2(72, 48)
	br.add_child(_max)
	# Action row: info, auto, SPIN, bonus.
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 8)
	body.add_child(ar)
	_info_b = _small("", _show_paytable)
	var ic := Icon.new("info", UI.TEXT, 22.0)
	ic.position = Vector2(13, 13)
	_info_b.add_child(ic)
	ar.add_child(_info_b)
	_auto_b = _small("Auto", _on_auto)
	_auto_b.custom_minimum_size = Vector2(76, 56)
	ar.add_child(_auto_b)
	_spin_b = UI.pill("SPIN", UI.TEXT, UI.INK, 20, 28)
	_spin_b.custom_minimum_size = Vector2(0, 56)
	_spin_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_b.pressed.connect(_on_spin_pressed)
	Kit.press_fx(_spin_b)
	ar.add_child(_spin_b)
	_bonus_b = _small("Bonus", _on_bonus)
	_bonus_b.custom_minimum_size = Vector2(76, 56)
	ar.add_child(_bonus_b)
	_shown_chips = Game.chips()
	_build_ladder()
	_bet_i = _default_bet()
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			_stop_auto())
	tree_exiting.connect(_stop_auto)
	_resume_free()


func _meter(parent: Control, cap: String) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	v.add_child(UI.label(cap, 13, UI.SUB))
	var l := UI.label("", 17, UI.TEXT, true)
	l.clip_text = true
	v.add_child(l)
	return l


func _small(text: String, cb: Callable) -> Button:
	var b := UI.pill(text, UI.RAISED, UI.TEXT, 17, 16)
	b.custom_minimum_size = Vector2(48, 48)
	b.pressed.connect(cb)
	Kit.press_fx(b)
	return b


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
		return
	var ni := clampi(_bet_i + d, 0, _ladder.size() - 1)
	if ni == _bet_i:
		Motion.shake(_plus if d > 0 else _minus)
		if d > 0:
			Kit.toast("Table limit: %s a spin" % Game.money_short(Game.casino_max_bet()))
		return
	Kit.haptic("selection")
	_bet_i = ni
	_refresh_bet()


func _refresh_bet() -> void:
	var tb := total_bet() if _free_left <= 0 else math.total_bet(_free_line)
	_bet_l.text = Game.money_short(tb)
	_bet_sub.text = "%s a line" % Game.money_short(line_bet() if _free_left <= 0 else _free_line)


func refresh() -> void:
	if _credits == null:
		return
	var keep := line_bet() if not _ladder.is_empty() else 0.0
	_build_ladder()
	# Income moved the limit: keep the same bet if still allowed.
	var idx := _ladder.find(keep)
	if idx >= 0:
		_bet_i = idx
	if not _busy:
		_shown_chips = Game.chips()
	_credits.text = Game.money_short(_shown_chips)
	_refresh_bet()
	if _shown_win <= 0.0:
		_win_l.text = "-"
	_update_buttons()


func _update_buttons() -> void:
	if _spin_b == null:
		return
	if _free_left > 0:
		_spin_b.text = "FREE %d" % _free_left
	elif _busy:
		_spin_b.text = "STOP"
	else:
		_spin_b.text = "SPIN"
	Page.set_enabled(_spin_b, _busy or _free_left > 0 or Game.chips() >= total_bet())
	_auto_b.text = ("Stop %d" % _auto_left if _auto_left > 0 else "Stop") if _auto_on else "Auto"
	UI.paint(_auto_b, UI.RED if _auto_on else UI.RAISED, UI.TEXT, 16)
	var idle := not _busy and _free_left <= 0
	for b in [_minus, _plus, _max, _bonus_b]:
		(b as Button).modulate.a = 1.0 if idle else 0.45


# ---- spinning -----------------------------------------------------------------

func _on_spin_pressed() -> void:
	if _busy:
		_machine.slam()     # tap again to stop the reels at once
		return
	if _auto_on:
		_stop_auto()
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
		_stop_auto()
		Motion.shake(_spin_b)
		Kit.toast("Not enough chips · buy more in the casino")
		_offer_chips()
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
	_shown_win = 0.0
	_win_l.text = "-"
	_credits.text = Game.money_short(_shown_chips)
	_update_buttons()
	_machine.spin_to(res)


func _on_stopped() -> void:
	var res := _last
	var paid := float(res.get("paid", 0.0))
	var tb := float(res.get("total_bet", total_bet()))
	var x := paid / maxf(tb, 0.0001)
	if paid > 0.0:
		_count_win(paid)
		Kit.sound("buy" if x < BIG_WIN_X else "fanfare")
		Kit.haptic("success")
		if x >= BIG_WIN_X:
			_machine.banner("MEGA WIN" if x >= AUTO_STOP_X else "BIG WIN", Game.money_short(paid), 2.2)
			if not Motion.reduced():
				var c := Confetti.new(Vector2(Kit.screen().x * 0.5, _machine.global_position.y + 120.0), 70)
				get_tree().root.get_node("Kit").add_child(c)
	_tween_credits()
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
		if _auto_on and _auto_left == -1:
			_stop_auto()   # "until free spins" got there
	elif bool(res.get("free", false)) and _free_left <= 0:
		# The feature is over: show what it paid, then back to normal.
		_machine.banner("FREE SPINS WON", Game.money_short(_free_won), 2.2)
		_clear_free()
		wait = maxf(wait, 2.0)
	if _auto_on and x >= AUTO_STOP_X:
		_stop_auto()
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
	if _auto_on:
		if _auto_left > 0:
			_auto_left -= 1
		if _auto_left == 0:
			_stop_auto()
		elif is_visible_in_tree():
			await get_tree().create_timer(Motion.d(0.3)).timeout
			if _auto_on and not _busy and is_inside_tree():
				if not spin():
					_stop_auto()
	_update_buttons()


func _count_win(v: float) -> void:
	_shown_win = v
	if Motion.reduced():
		_win_l.text = Game.money_short(v)
		return
	var t := create_tween()
	t.tween_method(func(f: float): _win_l.text = Game.money_short(f), 0.0, v, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _tween_credits() -> void:
	var to := Game.chips()
	var from := _shown_chips
	_shown_chips = to
	if Motion.reduced() or absf(to - from) < 0.005:
		_credits.text = Game.money_short(to)
		return
	var t := create_tween()
	t.tween_method(func(f: float): _credits.text = Game.money_short(f), from, to, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


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
	if _auto_on:
		_stop_auto()
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


func _start_auto(n: int) -> void:
	_auto_on = true
	_auto_left = n
	_update_buttons()
	if not _busy:
		if not spin():
			_stop_auto()


func _stop_auto() -> void:
	if not _auto_on:
		return
	_auto_on = false
	_auto_left = 0
	_update_buttons()


func is_auto() -> bool:
	return _auto_on


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_stop_auto()


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
	_credits.text = Game.money_short(_shown_chips)
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


func _offer_chips() -> void:
	if Game.cash >= 0.01:
		TradeSheet.open("chips", "", "chips_in")


func _show_paytable() -> void:
	Kit.tick()
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
	var note := UI.label("20 lines, pay left to right. Wild stands in for everything but the scatter. 3 or more scatters anywhere give 10 free spins with wins ×2, and they can come again. Pays back about %.1f%% over time. One spin pays at most %d× the bet, and the casino caps a round at %s." % [float(th["rtp"]) * 100.0, int(SlotMath.MAX_WIN_X), Game.money_short(Game.casino_max_win())], 13, UI.SUB)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 330
	box.add_child(note)
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
		d.custom_minimum_size = Vector2(62, 40)
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
		draw_string(UI.SEMI, Vector2(2, 10), str(line + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.TEXT)


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
	var _rng := RandomNumberGenerator.new()
	var _reels: Control             # clipped layer for the reels
	var _over: Control              # lines and banners on top

	func _init(t := "classic") -> void:
		theme_id = t
		custom_minimum_size = Vector2(0, 318)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.randomize()
		_reels = Control.new()
		_reels.clip_contents = true
		_reels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_reels)
		_reels.draw.connect(_draw_reels)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		_redraw()

	# ---- drawing
	func _draw() -> void:
		var s := size
		var frame: Color
		var trim: Color
		match theme_id:
			"neon":
				frame = UI.SKY
				trim = UI.SLOT_COL["wild"]
			"vault":
				frame = UI.SIDE
				trim = UI.DIM
			_:
				frame = UI.SIDE
				trim = UI.RED
		# Cabinet.
		draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2.ZERO, s), 22.0), frame)
		var outline := UI.rounded_rect_poly(Rect2(Vector2(1, 1), s - Vector2(2, 2)), 21.0)
		outline.append(outline[0])
		var glow := 0.55 + 0.25 * sin(_t * 2.0) if theme_id == "neon" and not Game.reduce_motion else 0.8
		draw_polyline(outline, Color(trim, glow), 2.0, true)
		if theme_id == "vault":
			# Rivets round the edge.
			for i in 12:
				var x := 18.0 + (s.x - 36.0) * float(i) / 11.0
				draw_circle(Vector2(x, 10), 2.5, UI.SUB)
				draw_circle(Vector2(x, s.y - 10), 2.5, UI.SUB)
		# Marquee: lights chasing, the machine's name, free spins counter.
		var lights := 15
		for i in lights:
			var lit := fmod(_t * 6.0 - float(i), float(lights)) < 3.0 if not Game.reduce_motion else i % 3 == 0
			draw_circle(Vector2(26.0 + (s.x - 52.0) * float(i) / float(lights - 1), 14.0), 2.6, UI.GOLD if lit else UI.TRACK)
		if theme_id == "classic":
			draw_circle(Vector2(s.x - 34.0, 34.0), 9.0, UI.RED)   # the red sun on the marquee
		var title := "%s SWINGS · 20 LINES" % String(SlotMath.THEMES[theme_id]["volatility"]).to_upper()
		if _free_left > 0:
			title = "FREE SPINS · %d LEFT · ×2" % _free_left
		draw_string(UI.DISPLAY, Vector2(0, 42), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, UI.GOLD if _free_left > 0 else UI.TEXT)
		# Reel window frame (the reels draw in their own clipped layer).
		var w := _window()
		draw_rect(w.grow(4.0), UI.RAISED)
		draw_rect(w, UI.INK)
		# Info strip under the reels.
		var info := _info_text()
		draw_string(UI.SEMI, Vector2(0, s.y - 18), info, HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, UI.GOLD if info.begins_with("Line") or info.begins_with("Scatter") else UI.SUB)

	func _draw_reels() -> void:
		## Drawn in _reels, which clips: spinning symbols never spill out.
		var ci: Control = _reels
		var w := _window()
		ci.draw_set_transform(-w.position)
		var cw := w.size.x / REELS
		var ch := w.size.y / ROWS
		for r in REELS:
			var col_r := Rect2(w.position + Vector2(r * cw + 2, 0), Vector2(cw - 4, w.size.y))
			ci.draw_rect(col_r, UI.WINDOW)
			if _hot[r] and _spinning[r]:
				var a := 0.35 + 0.25 * sin(_t * 12.0)
				ci.draw_rect(col_r, Color(UI.SLOT_COL["scatter"], a), false, 3.0)
			if _spinning[r]:
				_draw_tape(ci, r, col_r, ch)
			else:
				for row in ROWS:
					var cr := _cell(r, row).grow(-6.0)
					var sym := String(cells[r][row])
					var hl := _is_hl(r, row)
					if hl:
						var p := 0.5 + 0.5 * sin(_pulse * 8.0) if not Game.reduce_motion else 1.0
						ci.draw_rect(_cell(r, row).grow(-3.0), Color(UI.GOLD, 0.18 + 0.22 * p))
						ci.draw_rect(_cell(r, row).grow(-3.0), UI.GOLD, false, 2.0)
					var dim := 1.0
					if _show_line != -1 and not hl:
						dim = 0.45
					var grow := 1.0
					if hl and not Game.reduce_motion:
						grow = 1.0 + 0.06 * (0.5 + 0.5 * sin(_pulse * 8.0))
					var sr := Rect2(cr.get_center() - cr.size * 0.5 * grow, cr.size * grow)
					SlotMachine.draw_symbol(ci, sym, sr, dim)
		# Shade top and bottom of the window like a curved drum.
		ci.draw_rect(Rect2(w.position, Vector2(w.size.x, 12)), Color(UI.INK, 0.55))
		ci.draw_rect(Rect2(w.position + Vector2(0, w.size.y - 12), Vector2(w.size.x, 12)), Color(UI.INK, 0.55))

	func _draw_over() -> void:
		## Win lines and banners, above the reels. Never takes a tap.
		var ci: Control = _over
		var s := size
		var w := _window()
		_draw_lines(ci, w)
		if _banner_t > 0.0:
			var a := clampf(_banner_t * 3.0, 0.0, 1.0)
			var br := Rect2(Vector2(PAD - 2.0, w.get_center().y - 46.0), Vector2(s.x - PAD * 2.0 + 4.0, 92.0))
			ci.draw_rect(br, Color(UI.INK, 0.88 * a))
			ci.draw_rect(br, Color(UI.GOLD, a), false, 2.0)
			ci.draw_string(UI.DISPLAY, Vector2(0, br.position.y + 46.0), _banner, HORIZONTAL_ALIGNMENT_CENTER, s.x, 34, Color(UI.GOLD, a))
			ci.draw_string(UI.SEMI, Vector2(0, br.position.y + 74.0), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, s.x, 17, Color(UI.TEXT, a))

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
			ci.draw_polyline(pts, Color(UI.INK, 0.7), 6.0, true)
			ci.draw_polyline(pts, UI.GOLD, 3.0, true)
			# The line number on the left edge, like a real machine.
			var lp := pts[0]
			ci.draw_circle(lp, 9.0, UI.GOLD)
			ci.draw_string(UI.SEMI, lp + Vector2(-9, 4), str(int(wn["line"]) + 1), HORIZONTAL_ALIGNMENT_CENTER, 18, 10, UI.INK)

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
		## Every symbol, drawn to fit r (any size). alpha fades it.
		var c := r.get_center()
		var u := minf(r.size.x, r.size.y)
		var col: Color = UI.SLOT_COL.get(sym, UI.TEXT)
		col.a *= alpha
		var ink := Color(UI.INK, alpha)
		match sym:
			"sun":
				for i in 12:
					var a := TAU * float(i) / 12.0
					ci.draw_line(c + Vector2(cos(a), sin(a)) * u * 0.3, c + Vector2(cos(a), sin(a)) * u * 0.46, col, maxf(1.5, u * 0.05), true)
				ci.draw_circle(c, u * 0.27, col)
				ci.draw_circle(c + Vector2(-u * 0.08, -u * 0.08), u * 0.08, Color(UI.FLASH, 0.5 * alpha))
			"crown":
				var b := u * 0.42
				var pts := PackedVector2Array([
					c + Vector2(-b, b * 0.55), c + Vector2(-b, -b * 0.35), c + Vector2(-b * 0.5, b * 0.05),
					c + Vector2(0, -b * 0.6), c + Vector2(b * 0.5, b * 0.05), c + Vector2(b, -b * 0.35), c + Vector2(b, b * 0.55)])
				ci.draw_colored_polygon(pts, col)
				for p in [Vector2(-b, -b * 0.35), Vector2(0, -b * 0.6), Vector2(b, -b * 0.35)]:
					ci.draw_circle(c + p, u * 0.06, col)
				ci.draw_rect(Rect2(c + Vector2(-b, b * 0.32), Vector2(b * 2.0, b * 0.12)), ink)
			"bar":
				var br := Rect2(c - Vector2(u * 0.44, u * 0.2), Vector2(u * 0.88, u * 0.4))
				ci.draw_colored_polygon(UI.rounded_rect_poly(br, u * 0.07), col)
				ci.draw_string(UI.DISPLAY, Vector2(br.position.x, c.y + u * 0.12), "BAR", HORIZONTAL_ALIGNMENT_CENTER, br.size.x, int(u * 0.34), ink)
			"seven":
				var fs := int(u * 0.86)
				ci.draw_string(UI.DISPLAY, Vector2(r.position.x + 2.0, c.y + u * 0.32 + 2.0), "7", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, ink)
				ci.draw_string(UI.DISPLAY, Vector2(r.position.x, c.y + u * 0.32), "7", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)
			"bell":
				var b := u * 0.36
				var pts := PackedVector2Array()
				for i in 13:
					var a := PI + PI * float(i) / 12.0
					pts.append(c + Vector2(cos(a) * b * 0.75, sin(a) * b * 0.9 - b * 0.05))
				pts.append(c + Vector2(b, b * 0.55))
				pts.append(c + Vector2(-b, b * 0.55))
				ci.draw_colored_polygon(pts, col)
				ci.draw_circle(c + Vector2(0, b * 0.72), u * 0.08, col)
				ci.draw_circle(c + Vector2(0, -b * 0.98), u * 0.05, col)
			"cherry":
				var b := u * 0.18
				ci.draw_line(c + Vector2(-b, b * 0.6), c + Vector2(b * 0.4, -b * 2.0), Color(UI.UP, alpha), maxf(1.5, u * 0.04), true)
				ci.draw_line(c + Vector2(b * 1.2, b * 0.9), c + Vector2(b * 0.4, -b * 2.0), Color(UI.UP, alpha), maxf(1.5, u * 0.04), true)
				ci.draw_circle(c + Vector2(-b, b * 0.9), b * 1.05, col)
				ci.draw_circle(c + Vector2(b * 1.2, b * 1.2), b * 1.05, col)
				ci.draw_circle(c + Vector2(-b * 1.3, b * 0.6), b * 0.25, Color(UI.FLASH, 0.6 * alpha))
			"lemon":
				var pts := PackedVector2Array()
				for i in 24:
					var a := TAU * float(i) / 24.0
					var k := 1.0 + 0.18 * absf(cos(a)) * absf(cos(a)) * absf(cos(a))
					pts.append(c + Vector2(cos(a) * u * 0.38 * k, sin(a) * u * 0.27))
				ci.draw_colored_polygon(pts, col)
				ci.draw_line(c + Vector2(-u * 0.15, -u * 0.08), c + Vector2(u * 0.1, -u * 0.12), Color(UI.FLASH, 0.6 * alpha), maxf(1.0, u * 0.03), true)
			"wild":
				var wr := Rect2(c - Vector2(u * 0.46, u * 0.3), Vector2(u * 0.92, u * 0.6))
				ci.draw_colored_polygon(UI.rounded_rect_poly(wr, u * 0.1), col)
				ci.draw_string(UI.DISPLAY, Vector2(wr.position.x, c.y + u * 0.12), "WILD", HORIZONTAL_ALIGNMENT_CENTER, wr.size.x, int(u * 0.3), ink)
			"scatter":
				var pts := PackedVector2Array()
				for i in 16:
					var a := -PI / 2.0 + TAU * float(i) / 16.0
					var rr := u * (0.46 if i % 2 == 0 else 0.22)
					pts.append(c + Vector2(cos(a), sin(a)) * rr)
				ci.draw_colored_polygon(pts, col)
				ci.draw_string(UI.SEMI, Vector2(r.position.x, c.y + u * 0.06), "FREE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(maxf(8.0, u * 0.16)), ink)
