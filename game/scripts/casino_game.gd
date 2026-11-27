class_name CasinoGame
extends Page
## The shared frame for every casino game, so all nine tables work the same:
##   title row    the game's name and an "i" (rules and pays, in a sheet)
##   status row   chips (as the page wants them shown), max bet, this round's
##                win counting up in gold, and "+" to buy chips
##   area         the game itself; it takes the height that is left
##   dock         bet bar or chip tray, an optional row of quiet buttons, and
##                ONE primary button, 56 px, its bottom just above the nav bar
## Subclasses write build_game() (not build()) and fill `area` and `dock`.
##
## Colour rule (design pass): the primary is a TEXT fill; RED only for the one
## live action (Cash out while climbing) or the winning thing; GOLD for wins.

const PRIMARY_H := 56.0
const CONFETTI_X := 10.0          # a win this many times the stake gets confetti

var status: StatusRow
var area: VBoxContainer
var dock: VBoxContainer
var info_b: Button
var auto_on := false         # autoplay (slots), shared so leaving always stops it
var auto_left := 0


func _init(t := "", _back := true) -> void:   # pushed page: back in the bottom bar (R10)
	super(t, true)


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # the table never scrolls while you play
	# Fill the screen, so the dock sits on the bottom bar on every game.
	var margin := body.get_parent() as Control
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title_row()
	status = StatusRow.new()
	body.add_child(status)
	area = VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.add_theme_constant_override("separation", 10)
	body.add_child(area)
	dock = VBoxContainer.new()
	dock.add_theme_constant_override("separation", 8)
	body.add_child(dock)
	build_game()
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			stop_auto())
	tree_exiting.connect(stop_auto)


func build_game() -> void:
	pass


func _title_row() -> void:
	if _title_label == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var at := _title_label.get_index()
	body.remove_child(_title_label)
	body.add_child(row)
	body.move_child(row, at)
	row.add_child(_title_label)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Tanker 36, smaller for a long name so it stays on one line.
	var avail := 358.0 - 56.0
	var fs := 36
	while fs > 24 and UI.DISPLAY.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 2
	_title_label.add_theme_font_size_override("font_size", fs)
	info_b = UI.pill("", UI.RAISED, UI.TEXT, 15, 24)
	info_b.custom_minimum_size = Vector2(48, 48)
	info_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := Icon.new("info", UI.TEXT, 22.0)
	ic.position = Vector2(13, 13)
	info_b.add_child(ic)
	info_b.pressed.connect(func():
		Kit.tick()
		show_info())
	Kit.press_fx(info_b)
	row.add_child(info_b)


# ---- the "i" sheet ---------------------------------------------------------------

func show_info() -> void:
	## Rules and pays in a centred sheet. Games give info_content().
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(info_content())
	box.add_child(note("Max bet %s, max win %s a round. Both grow with your income." % [Game.money_short(Game.casino_max_bet()), Game.money_short(Game.casino_max_win())]))
	Kit.sheet(title, "", [{"text": "Close", "style": "plain"}], true, box)


func info_content() -> Control:
	return note("")


static func note(text: String, color: Color = UI.SUB) -> Label:
	## A wrapped 13 px line for info sheets.
	var l := UI.label(text, 13, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	return l


static func pay_line(left: String, right: String, lit := false) -> Control:
	## One row of a pay table: name on the left, pay on the right.
	var h := HBoxContainer.new()
	var a := UI.label(left, 15, UI.GOLD if lit else UI.TEXT)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(UI.label(right, 15, UI.GOLD if lit else UI.SUB, true))
	return h


# ---- the dock ----------------------------------------------------------------------

func primary(text: String, call: Callable) -> Button:
	## The one main button: full width, 56 px, TEXT fill. Added to the dock last.
	var b := UI.pill(text, UI.TEXT, UI.INK, 17, 28)
	b.custom_minimum_size = Vector2(0, PRIMARY_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A "not yet" button still calls the page, which says why (and may offer chips).
	b.pressed.connect(call)
	Kit.press_fx(b)
	return b


static func set_go(b: Button, on: bool, live := false) -> void:
	## Ready: TEXT fill. Live (the one thing to tap now): RED. Not yet: RAISED,
	## still tappable so a tap can shake and say why.
	b.disabled = false
	b.set_meta("blocked", not on)
	if not on:
		UI.paint(b, UI.RAISED, UI.SUB, 28)
	elif live:
		UI.paint(b, UI.RED, UI.TEXT, 28)
	else:
		UI.paint(b, UI.TEXT, UI.INK, 28)


static func quiet(text: String, call: Callable) -> Button:
	## A second action (Auto, Bonus, Undo, Clear...): RAISED, 48 px, 15 px text.
	var b := UI.pill(text, UI.RAISED, UI.TEXT, 15, 24)
	b.custom_minimum_size = Vector2(48, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if call.is_valid():
		b.pressed.connect(call)
	Kit.press_fx(b)
	return b


func dock_row(buttons: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for b in buttons:
		h.add_child(b)
	dock.add_child(h)
	return h


# ---- results -------------------------------------------------------------------------

func win_fx(paid: float, stake: float, big_x := CONFETTI_X, at := Vector2.INF) -> void:
	## The same answer on every game: the win counts up in gold, a win buzzes,
	## a big one throws confetti, a loss gives a soft tap. Never blocks a tap.
	status.set_win(paid, paid > stake + 0.001)
	if paid > stake + 0.001:
		Kit.haptic("success")
		if paid >= stake * big_x:
			Kit.sound("fanfare")
			if not Motion.reduced():
				var p := at if at != Vector2.INF else area.get_global_rect().get_center()
				get_tree().root.get_node("Kit").add_child(Confetti.new(p, 60))
	elif paid > 0.0:
		Kit.haptic("selection")
	else:
		Kit.haptic("light")


func offer_chips() -> void:
	if Game.cash >= 0.01:
		TradeSheet.open("chips", "", "chips_in")


# ---- autoplay (slots) ----------------------------------------------------------------

func auto_spin() -> bool:
	## One autoplay round. Games with autoplay return false when it can't start.
	return false


func _start_auto(n: int) -> void:
	auto_on = true
	auto_left = n
	refresh()
	if not is_busy() and not auto_spin():
		stop_auto()


func is_busy() -> bool:
	return false


func stop_auto() -> void:
	if not auto_on:
		return
	auto_on = false
	auto_left = 0
	if is_inside_tree():
		refresh()


func is_auto() -> bool:
	return auto_on


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		stop_auto()


# ---- chips and bets (shared maths for the tables) ----------------------------------

static func nice(x: float) -> float:
	## Rounds down to 1, 2 or 5 times a power of ten.
	if x < 1.0:
		return 1.0
	var p := pow(10.0, floor(log(x) / log(10.0)))
	var m := x / p
	return (1.0 if m < 2.0 else (2.0 if m < 5.0 else 5.0)) * p


static func denoms(max_bet: float) -> Array:
	## Five chip values that fit the table limit.
	var out: Array = []
	for f in [0.01, 0.05, 0.1, 0.25, 0.5]:
		var v := nice(max_bet * f)
		if not out.has(v):
			out.append(v)
	return out


static func chip_text(v: float) -> String:
	if v >= 1000.0:
		return Game.money_short(v).substr(1)
	return str(int(v))


static func chip_tier(amount: float) -> int:
	var ds := denoms(Game.casino_max_bet())
	var tier := 0
	for i in range(ds.size()):
		if amount >= float(ds[i]):
			tier = i
	return tier


static func draw_chip(ci: CanvasItem, c: Vector2, r: float, tier: int, text: String) -> void:
	## A flat casino chip: coloured body, light edge marks, inner ring, value.
	var col: Color = UI.CHIP_COL[tier % UI.CHIP_COL.size()]
	var light := tier % UI.CHIP_COL.size() == 0
	ci.draw_circle(c, r, col)
	var mark: Color = UI.INK if light else UI.TEXT
	for i in 6:
		var a := TAU * float(i) / 6.0
		ci.draw_arc(c, r * 0.86, a - 0.16, a + 0.16, 6, mark, r * 0.22, true)
	ci.draw_circle(c, r * 0.64, col)
	ci.draw_arc(c, r * 0.64, 0.0, TAU, 32, Color(mark, 0.6), 1.5, true)
	var fs := int(clampf(r * 0.62, 9.0, 15.0))
	if text.length() > 3:
		fs = int(fs * 0.8)
	ci.draw_string(UI.SEMI, c + Vector2(-r, fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, UI.INK if light else UI.TEXT)


# =====================================================================================

class StatusRow extends HBoxContainer:
	## Chips and max bet on the left, this round's win on the right, then "+".
	## Pages pass the chips to show: they lag while a result plays out.
	var chips_l: Label
	var max_l: Label
	var win_l: Label
	var buy_b: Button
	var _tw: Tween
	var _ctw: Tween

	func _init() -> void:
		custom_minimum_size = Vector2(0, 48)
		add_theme_constant_override("separation", 12)
		var lv := VBoxContainer.new()
		lv.add_theme_constant_override("separation", -2)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(lv)
		chips_l = UI.display("", 22)
		lv.add_child(chips_l)
		max_l = UI.label("", 13, UI.SUB)
		lv.add_child(max_l)
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", -2)
		rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(rv)
		win_l = UI.display("-", 22, UI.SUB)
		win_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rv.add_child(win_l)
		var wc := UI.label("Win", 13, UI.SUB)
		wc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rv.add_child(wc)
		buy_b = UI.pill("", UI.RAISED, UI.TEXT, 15, 24)
		buy_b.custom_minimum_size = Vector2(48, 48)
		buy_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ic := Icon.new("plus", UI.TEXT, 22.0)
		ic.position = Vector2(13, 13)
		buy_b.add_child(ic)
		buy_b.pressed.connect(func():
			Kit.tick()
			if Game.cash < 0.01:
				Kit.toast("No cash to spend")
				return
			TradeSheet.open("chips", "", "chips_in"))
		Kit.press_fx(buy_b)
		add_child(buy_b)

	func set_chips(v: float) -> void:
		if _ctw and _ctw.is_valid():
			_ctw.kill()
		chips_l.text = Game.money(v)
		max_l.text = "Chips · max bet " + Game.money_short(Game.casino_max_bet())

	func tween_chips(from: float, to: float) -> void:
		## The chips glide to their new value (slots, after the reels stop).
		max_l.text = "Chips · max bet " + Game.money_short(Game.casino_max_bet())
		if Motion.reduced() or absf(to - from) < 0.005:
			set_chips(to)
			return
		if _ctw and _ctw.is_valid():
			_ctw.kill()
		_ctw = create_tween()
		_ctw.tween_method(func(f: float): chips_l.text = Game.money(f), from, to, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	func set_win(v: float, gold := true) -> void:
		## Counts up; gold only when more came back than was staked. 0 shows a dash.
		if _tw and _tw.is_valid():
			_tw.kill()
		if v <= 0.0:
			win_l.text = "-"
			win_l.add_theme_color_override("font_color", UI.SUB)
			return
		win_l.add_theme_color_override("font_color", UI.GOLD if gold else UI.TEXT)
		if Motion.reduced():
			win_l.text = Game.money_short(v)
			return
		_tw = create_tween()
		_tw.tween_method(func(f: float): win_l.text = Game.money_short(f), 0.0, v, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	func clear_win() -> void:
		set_win(0.0)


class BetBar extends HBoxContainer:
	## The bet: - and + step through round amounts up to the table limit, Max
	## jumps to the limit. `locked` while a round runs (the amount stays
	## readable; only the buttons fade). Slots with their own ladders set
	## `external` and answer the stepped / maxed signals themselves.
	signal stepped(d: int)
	signal maxed
	var value := 0.0
	var locked := false:
		set(v):
			locked = v
			for b in [minus, plus, mx]:
				if b:
					(b as Control).modulate.a = 0.4 if v else 1.0
	var external := false
	var minus: Button
	var plus: Button
	var mx: Button
	var _l: Label
	var _sub: Label
	var _ladder: Array = []

	func _init() -> void:
		add_theme_constant_override("separation", 8)
		custom_minimum_size = Vector2(0, 52)
		minus = _b("-", 52)
		minus.pressed.connect(func(): _step(-1))
		add_child(minus)
		var mid := VBoxContainer.new()
		mid.add_theme_constant_override("separation", -4)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mid)
		_l = UI.display("", 24)
		_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.add_child(_l)
		_sub = UI.label("", 13, UI.SUB)
		_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sub.visible = false
		mid.add_child(_sub)
		plus = _b("+", 52)
		plus.pressed.connect(func(): _step(1))
		add_child(plus)
		mx = _b("Max", 64)
		mx.add_theme_font_size_override("font_size", 15)
		mx.pressed.connect(func():
			if locked:
				Motion.shake(mx)
				return
			Kit.haptic("selection")
			if external:
				maxed.emit()
				return
			_rebuild()
			value = _ladder[_ladder.size() - 1]
			_show())
		add_child(mx)

	func _b(t: String, w: float) -> Button:
		var b := UI.pill(t, UI.RAISED, UI.TEXT, 22, 14)
		b.custom_minimum_size = Vector2(w, 52)
		Kit.press_fx(b)
		return b

	func show_text(t: String, sub := "") -> void:
		_l.text = t
		_sub.text = sub
		_sub.visible = sub != ""

	func _rebuild() -> void:
		var top := Game.casino_max_bet()
		_ladder = []
		var v := CasinoGame.nice(maxf(1.0, top / 500.0))
		while v < top - 0.001 and _ladder.size() < 40:
			_ladder.append(v)
			var p := pow(10.0, floor(log(v) / log(10.0)))
			var m := roundf(v / p)
			v = (2.0 if m < 2.0 else (5.0 if m < 5.0 else 10.0)) * p
		_ladder.append(top)

	func refresh() -> void:
		if external:
			return
		_rebuild()
		if value <= 0.0:
			value = _ladder[mini(3, _ladder.size() - 1)]
		value = minf(value, _ladder[_ladder.size() - 1])
		_show()

	func _step(d: int) -> void:
		if locked:
			Motion.shake(minus if d < 0 else plus)
			return
		if external:
			stepped.emit(d)
			return
		Kit.haptic("selection")
		_rebuild()
		var i := 0
		for k in range(_ladder.size()):
			if _ladder[k] <= value + 0.001:
				i = k
		var ni := clampi(i + d, 0, _ladder.size() - 1)
		if ni == i and d > 0 and value >= _ladder[_ladder.size() - 1] - 0.001:
			Motion.shake(plus)
			Kit.toast("Table limit: %s" % Game.money_short(Game.casino_max_bet()))
		value = _ladder[ni]
		_show()

	func _show() -> void:
		show_text(Game.money_short(value))


class ChipButton extends Button:
	## A round casino chip you can tap; the chosen one sits up on a gold ring.
	var value := 1.0
	var tier := 0
	var selected := false

	func _init(v := 1.0, t := 0) -> void:
		value = v
		tier = t
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(52, 52)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5 - Vector2(0, 3.0 if selected else 0.0)
		if selected:
			draw_circle(c + Vector2(0, 3), 26.0, UI.GOLD)
		CasinoGame.draw_chip(self, c, 22.0, tier, CasinoGame.chip_text(value))
