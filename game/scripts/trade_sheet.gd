class_name TradeSheet
extends VBoxContainer
## The buy / sell / convert pop-up: a slider, quick 25/50/75/Max chips and an
## amount box, with live numbers for what you have, what you get and what's
## left. mode: "buy", "sell", "convert" or "lock" (coins only). Numbers stay
## live while it is open, and a typed amount stays fixed in pounds.

var kind := "coin"
var sym := ""
var mode := "sell"
var to_sym := ""          # convert target
var frac := 0.0           # 0..1 of the most you can trade
var _have: Label
var _big: Label
var _sub: Label
var _after: Label
var _slider: AmountSlider
var _field: LineEdit
var _go: Button
var _targets: Dictionary = {}
var _typing := false
var _type_btn: Button     # looks like the amount box; a tap opens the real one
var _field_box: Control   # the amount box: £ then the typed number
var _warn: Control        # a short warning line with an icon (lock: the 24 h restarts)
var _warn_l: Label
var _typed := -1.0        # an amount typed in £ (-1 = use the slider)
var _amount := 0.0        # what the button shows, in £
var _panel: Control       # the sheet, lifted above the phone keyboard
var _rest_y := NAN


static func open(k: String, s: String, m: String) -> void:
	var ts := TradeSheet.new()
	ts.kind = k
	ts.sym = s
	ts.mode = m
	var title: String = {"buy": "Buy ", "sell": "Sell ", "convert": "Convert ", "lock": "Lock ", "chips_in": "Buy chips", "chips_out": "Cash out", "bank_in": "Deposit", "bank_out": "Withdraw", "loan": "Borrow"}[m] + s
	Kit.sheet(title, "", [{"text": "Close", "style": "plain"}], true, ts)


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_have = UI.label("", 15, UI.SUB)
	add_child(_have)
	if mode == "convert":
		add_child(UI.label("Into", 13, UI.SUB))
		# The other 12 coins, 3 across, so no coin sits alone on a row.
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		add_child(grid)
		for c in Data.COINS:
			if c[0] == sym:
				continue
			var b := InvestPage.coin_chip(c[0], false)
			var target: String = c[0]
			b.pressed.connect(func():
				Kit.haptic("selection")
				_field.release_focus()
				to_sym = target
				_paint_targets()
				_update())
			grid.add_child(b)
			_targets[target] = b
		to_sym = "BTC" if sym != "BTC" else "ETH"
		_paint_targets()
	_big = UI.display("", 40)
	add_child(_big)
	_sub = UI.label("", 15, UI.TEXT)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_sub)
	var wh := HBoxContainer.new()
	wh.add_theme_constant_override("separation", 8)
	wh.visible = false
	add_child(wh)
	_warn = wh
	var wi := Icon.new("clock", UI.TEXT, 18.0)
	wi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wh.add_child(wi)
	_warn_l = UI.label("", 15, UI.TEXT)
	_warn_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warn_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wh.add_child(_warn_l)
	_slider = AmountSlider.new()
	_slider.changed.connect(func(v: float):
		_field.release_focus()
		_typed = -1.0
		frac = v
		_update())
	add_child(_slider)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	add_child(chips)
	for p in [0.25, 0.5, 0.75, 1.0]:
		var pv: float = p
		var b := UI.pill("Max" if pv >= 1.0 else "%d%%" % int(pv * 100.0), UI.RAISED, UI.TEXT, 15, 16)
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Kit.haptic("selection")
			_field.release_focus()
			_typed = -1.0
			frac = pv
			_slider.set_value(pv)
			_update())
		Kit.press_fx(b)
		chips.add_child(b)
	# Or type an amount in pounds: a real-looking box with a £ in front.
	var fb := PanelContainer.new()
	fb.add_theme_stylebox_override("panel", _field_style())
	fb.visible = false   # shown by a tap, so the amount isn't on screen three times
	add_child(fb)
	_field_box = fb
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 6)
	fb.add_child(fh)
	var cur := UI.label(Game.CUR, 17, UI.SUB)
	cur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fh.add_child(cur)
	_field = LineEdit.new()
	_field.placeholder_text = "Type an amount"
	_field.select_all_on_focus = true   # a tap replaces the amount, never mixes into it
	_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_field.custom_minimum_size = Vector2(0, 46)
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.add_theme_font_override("font", UI.REG)
	_field.add_theme_font_size_override("font_size", 17)
	_field.add_theme_color_override("font_color", UI.TEXT)
	_field.add_theme_color_override("font_placeholder_color", UI.SUB)
	for st in ["normal", "focus", "read_only"]:
		_field.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_field.text_changed.connect(_on_typed)
	fh.add_child(_field)
	# Until tapped, the same box shows "£  Type an amount" as a button.
	_type_btn = Button.new()
	_type_btn.text = Game.CUR + "   Type an amount"
	_type_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_type_btn.focus_mode = Control.FOCUS_NONE
	_type_btn.custom_minimum_size = Vector2(0, 48)
	_type_btn.add_theme_font_override("font", UI.REG)
	_type_btn.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_type_btn.add_theme_stylebox_override(st, _field_style())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_type_btn.add_theme_color_override(st, UI.SUB)
	_type_btn.pressed.connect(func():
		Kit.haptic("selection")
		show_field())
	add_child(_type_btn)
	_after = UI.label("", 13, UI.SUB)
	_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_after)
	_go = UI.pill("", UI.TEXT, UI.INK, 17, 24)
	_go.custom_minimum_size = Vector2(0, 52)
	_go.pressed.connect(_confirm)
	Kit.press_fx(_go)
	add_child(_go)
	frac = {"buy": 0.1, "lock": 1.0, "chips_in": 0.1, "chips_out": 1.0, "bank_in": 0.5, "bank_out": 1.0, "loan": 0.5}.get(mode, 0.5)
	_slider.set_value(frac)
	_update()
	Game.changed.connect(_update)   # cash and prices move while it is open
	_field.focus_exited.connect(func(): _field.text = _plain(_amount))


func show_field() -> void:
	## Swaps the "Type an amount" button for the amount box and focuses it.
	_type_btn.visible = false
	_field_box.visible = true
	_field.text = _plain(_amount)
	_field.grab_focus()


static func _field_style() -> StyleBoxFlat:
	## The amount box: raised fill, a thin border, so it reads as somewhere to type.
	var sb := UI.box(UI.RAISED, 12, 14, 0)
	sb.border_color = UI.TRACK
	sb.set_border_width_all(1)
	return sb


static func _plain(v: float) -> String:
	## An amount for the box, without the £ (the box shows its own).
	return "" if v <= 0.0 else Game.money(v).replace(Game.CUR, "")


func _book() -> Dictionary:
	return Game.shares if kind == "share" else Game.coins


func _max_value() -> float:
	## The most this trade can move, in £.
	if mode == "buy" or mode == "chips_in":
		return Game.cash
	if mode == "chips_out":
		return Game.chips()
	if mode == "bank_in":
		return maxf(0.0, Game.cash)
	if mode == "bank_out":
		return Game.savings()
	if mode == "loan":
		return Game.loan_limit()
	return Game.holding(_book(), sym) * Game.price(sym)


func _paint_targets() -> void:
	for t in _targets.keys():
		UI.paint(_targets[t], UI.TEXT if t == to_sym else UI.RAISED, UI.INK if t == to_sym else UI.TEXT, 12)
		for ch in (_targets[t] as Control).get_children():
			if ch is Label:
				(ch as Label).add_theme_color_override("font_color", UI.INK if t == to_sym else UI.TEXT)


func _on_typed(t: String) -> void:
	var v := t.replace("£", "").replace(",", "").strip_edges().to_float()
	var mx := _max_value()
	if mx <= 0.0:
		return
	_typing = true
	_typed = maxf(0.0, v)
	frac = clampf(v / mx, 0.0, 1.0)
	_slider.set_value(frac)
	_update()
	_typing = false


func _update() -> void:
	var p := Game.price(sym)
	var free := Game.holding(_book(), sym)
	var mx := _max_value()
	if _typed >= 0.0:
		frac = clampf(_typed / mx, 0.0, 1.0) if mx > 0.0 else 0.0
		_slider.set_value(frac)
	var amount := mx * frac
	_amount = amount
	var units := amount / p if p > 0.0 else 0.0
	_warn.visible = false
	if mode == "bank_in" or mode == "bank_out":
		var dep := mode == "bank_in"
		_have.text = "Cash %s · saved %s" % [Game.money(Game.cash), Game.money(Game.savings())]
		_big.text = Game.money_short(amount)
		_sub.text = "Earns 0.2% an hour" if dep else "Back to your cash"
		_after.text = "After: %s saved · %s cash" % [Game.money_short(Game.savings() + (amount if dep else -amount)), Game.money_short(Game.cash + (-amount if dep else amount))]
		_go.text = ("Deposit · " if dep else "Withdraw · ") + Game.money_short(amount)
	elif mode == "loan":
		var pay := amount * (1.0 + Data.LOAN_FEE) / float(Data.LOAN_PAYMENTS)
		_have.text = "You can borrow up to %s" % Game.money_short(Game.loan_limit())
		_big.text = Game.money_short(amount)
		_sub.text = "Pay back %d × %s, one every %d h" % [Data.LOAN_PAYMENTS, Game.money_short(pay), int(Data.LOAN_EVERY_H)]
		_after.text = "Total %s (25%% fee). Short on a payment? Your cash goes into the minus." % Game.money_short(amount * (1.0 + Data.LOAN_FEE))
		_go.text = "Borrow · " + Game.money_short(amount)
	elif mode == "chips_in" or mode == "chips_out":
		var inn := mode == "chips_in"
		_have.text = "Cash %s · chips %s" % [Game.money(Game.cash), Game.money(Game.chips())]
		_big.text = Game.money_short(amount)
		_sub.text = ("Chips to play with" if inn else "Back to your cash")
		_after.text = "After: %s chips · %s cash" % [Game.money_short(Game.chips() + (amount if inn else -amount)), Game.money_short(Game.cash + (-amount if inn else amount))]
		_go.text = ("Buy chips · " if inn else "Cash out · ") + Game.money_short(amount)
	elif mode == "buy":
		_have.text = "Cash %s · you own %s %s" % [Game.money(Game.cash), AssetDetail.qty_text(free), sym]
		_big.text = Game.money_short(amount)
		_sub.text = "You get %s %s at %s" % [AssetDetail.qty_text(units), sym, AssetDetail.price_text(p)]
		_after.text = "After: %s %s · %s cash" % [AssetDetail.qty_text(free + units), sym, Game.money_short(Game.cash - amount)]
		_go.text = "Buy · " + Game.money_short(amount)
	else:
		var got := amount * (1.0 - Data.SELL_SPREAD)
		_have.text = "You own %s %s · %s" % [AssetDetail.qty_text(free), sym, Game.money_short(free * p)]
		_big.text = "%s %s" % [AssetDetail.qty_text(units), sym]
		if mode == "lock":
			var rate := Game.stake_rate(sym) * 2400.0
			_sub.text = "Earns up to %.2f%% a day. Can't sell for 24 h." % rate
			if Game.staked(sym) > 0.0:
				_warn.visible = true
				_warn_l.text = "Adds to your lock. The 24 h starts again."
			_after.text = "After: %s %s free · %s locked" % [AssetDetail.qty_text(free - units), sym, AssetDetail.qty_text(Game.staked(sym) + units)]
			_go.text = "Lock · %s %s" % [AssetDetail.qty_text(units), sym]
		elif mode == "sell":
			_sub.text = "You get %s (%s%% fee)" % [Game.money(got), str(snappedf(Data.SELL_SPREAD * 100.0, 0.1))]
			_after.text = "After: %s %s left · %s cash" % [AssetDetail.qty_text(free - units), sym, Game.money_short(Game.cash + got)]
			_go.text = "Sell · " + Game.money_short(got)
		else:
			var tp := Game.price(to_sym)
			var to_units := got / tp if tp > 0.0 else 0.0
			_sub.text = "Becomes %s %s (%s%% fee)" % [AssetDetail.qty_text(to_units), to_sym, str(snappedf(Data.SELL_SPREAD * 100.0, 0.1))]
			_after.text = "After: %s %s left · %s %s" % [AssetDetail.qty_text(free - units), sym, AssetDetail.qty_text(Game.holding(Game.coins, to_sym) + to_units), to_sym]
			_go.text = "Convert into %s" % String(Data.coin(to_sym)[1])
		if Game.staked(sym) > 0.0:
			_have.text += " (%s locked)" % AssetDetail.qty_text(Game.staked(sym))
	Page.set_enabled(_go, amount >= 0.01)
	if not _typing and not _field.has_focus():
		_field.text = "" if frac <= 0.0 else _plain(amount)


func _process(_d: float) -> void:
	# Lift the sheet so the amount box and button sit above the phone keyboard.
	if _panel == null:
		_panel = get_parent().get_parent() as Control
		return
	var kb := 0.0
	if _field.has_focus() and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var win := float(DisplayServer.window_get_size().y)
		kb = float(DisplayServer.virtual_keyboard_get_height()) * get_viewport_rect().size.y / maxf(1.0, win)
	if kb > 0.0 and is_nan(_rest_y):
		_rest_y = _panel.position.y
	if is_nan(_rest_y):
		return
	var lift := 0.0
	if kb > 0.0:
		var bottom := _go.global_position.y + _go.size.y + 12.0 - (_panel.position.y - _rest_y)
		lift = maxf(0.0, bottom - (get_viewport_rect().size.y - kb))
	_panel.position.y = _rest_y - lift
	if kb <= 0.0:
		_rest_y = NAN


func _confirm() -> void:
	_update()   # trade exactly what the button shows right now
	var ok := false
	var msg := ""
	match mode:
		"buy":
			var spend := minf(_amount, Game.cash)
			ok = Game.buy_asset(kind, sym, spend)
			msg = "Bought %s · %s" % [sym, Game.money_short(spend)]
		"sell":
			var got := Game.sell_asset(kind, sym, frac)
			ok = got > 0.0
			msg = "Sold for " + Game.money_short(got)
		"convert":
			var n := Game.convert_coin(sym, to_sym, frac)
			ok = n > 0.0
			msg = "Now %s %s more" % [AssetDetail.qty_text(n), to_sym]
		"lock":
			ok = Game.stake(sym, frac)
			msg = "Locked for 24 h"
		"bank_in":
			ok = Game.deposit(_amount)
			msg = "Saved " + Game.money_short(_amount)
		"bank_out":
			ok = Game.withdraw(_amount)
			msg = "Withdrew " + Game.money_short(_amount)
		"loan":
			ok = Game.take_loan(_amount)
			msg = "Borrowed " + Game.money_short(_amount)
		"chips_in":
			ok = Game.buy_chips(_amount)
			msg = "Chips · " + Game.money_short(_amount)
		"chips_out":
			ok = Game.cash_out(_amount)
			msg = "Cashed out " + Game.money_short(_amount)
	if ok:
		Kit.haptic("success")
		Kit.toast(msg, true)
		Game.flush_changes()
		Kit.close_top()
	else:
		Kit.haptic("error")
		Motion.shake(_go)


class AmountSlider extends Control:
	## A thick, easy slider: drag anywhere on it. Takes the touch, so the sheet
	## behind doesn't slide.
	signal changed(v: float)
	var value := 0.0
	var _drag := false

	func _init() -> void:
		custom_minimum_size = Vector2(0, 48)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_value(v: float) -> void:
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			if e.pressed:
				_set_from(e.position.x)
			accept_event()
		elif e is InputEventMouseMotion and _drag:
			_set_from(e.position.x)
			accept_event()

	const PAD := 20.0   # the knob (14 px) stays inside the sheet at Max

	func _set_from(x: float) -> void:
		var pad := PAD
		var v := clampf((x - pad) / maxf(1.0, size.x - pad * 2.0), 0.0, 1.0)
		# Gentle snaps at the quarters, with a tick you can feel.
		for q in [0.0, 0.25, 0.5, 0.75, 1.0]:
			if absf(v - q) < 0.02:
				if absf(value - q) > 0.001:
					Kit.haptic("selection")
				v = q
		value = v
		queue_redraw()
		changed.emit(value)

	func _draw() -> void:
		var pad := PAD
		var y := size.y * 0.5
		var w := size.x - pad * 2.0
		draw_line(Vector2(pad, y), Vector2(pad + w, y), UI.TRACK, 8.0, true)
		draw_line(Vector2(pad, y), Vector2(pad + w * value, y), UI.TEXT, 8.0, true)
		for q in [0.25, 0.5, 0.75]:
			draw_circle(Vector2(pad + w * q, y), 3.0, UI.SUB)
		draw_circle(Vector2(pad + w * value, y), 14.0, UI.TEXT)
		draw_circle(Vector2(pad + w * value, y), 6.0, UI.INK)
