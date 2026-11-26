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
var _typed := -1.0        # an amount typed in £ (-1 = use the slider)
var _amount := 0.0        # what the button shows, in £
var _panel: Control       # the sheet, lifted above the phone keyboard
var _rest_y := NAN


static func open(k: String, s: String, m: String) -> void:
	var ts := TradeSheet.new()
	ts.kind = k
	ts.sym = s
	ts.mode = m
	var title: String = {"buy": "Buy ", "sell": "Sell ", "convert": "Convert ", "lock": "Lock "}[m] + s
	Kit.sheet(title, "", [{"text": "Close", "style": "plain"}], true, ts)


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_have = UI.label("", 15, UI.SUB)
	add_child(_have)
	if mode == "convert":
		add_child(UI.label("Into", 13, UI.SUB))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		add_child(grid)
		for c in Data.COINS:
			if c[0] == sym:
				continue
			var b := UI.pill("", UI.RAISED, UI.TEXT, 13, 12)
			b.custom_minimum_size = Vector2(0, 48)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var tile := AssetTile.new(c[0], 26.0)
			tile.position = Vector2(6, 11)
			b.add_child(tile)
			var l := UI.label(c[0], 13, UI.TEXT, true)
			l.position = Vector2(34, 14)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(l)
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
	add_child(_sub)
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
	# Or type an amount in pounds.
	_field = LineEdit.new()
	_field.placeholder_text = "Type an amount in £"
	_field.select_all_on_focus = true   # a tap replaces the amount, never mixes into it
	_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_field.custom_minimum_size = Vector2(0, 48)
	_field.add_theme_font_override("font", UI.REG)
	_field.add_theme_font_size_override("font_size", 17)
	_field.add_theme_color_override("font_color", UI.TEXT)
	_field.add_theme_color_override("font_placeholder_color", UI.SUB)
	_field.add_theme_stylebox_override("normal", UI.box(UI.RAISED, 12, 14, 10))
	_field.add_theme_stylebox_override("focus", UI.box(UI.RAISED, 12, 14, 10))
	_field.text_changed.connect(_on_typed)
	add_child(_field)
	_after = UI.label("", 13, UI.SUB)
	_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_after)
	_go = UI.pill("", UI.TEXT, UI.INK, 17, 24)
	_go.custom_minimum_size = Vector2(0, 52)
	_go.pressed.connect(_confirm)
	Kit.press_fx(_go)
	add_child(_go)
	frac = {"buy": 0.1, "lock": 1.0}.get(mode, 0.5)
	_slider.set_value(frac)
	_update()
	Game.changed.connect(_update)   # cash and prices move while it is open
	_field.focus_exited.connect(func(): _field.text = "" if _amount <= 0.0 else Game.money(_amount))


func _book() -> Dictionary:
	return Game.shares if kind == "share" else Game.coins


func _max_value() -> float:
	## The most this trade can move, in £.
	if mode == "buy":
		return Game.cash
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
	if mode == "buy":
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
			_sub.text = "Earns up to %.2f%% a day · can't sell for 24 h" % rate
			if Game.staked(sym) > 0.0:
				_sub.text = "Adds to your lock · the 24 h starts again"
			_after.text = "After: %s %s free · %s locked" % [AssetDetail.qty_text(free - units), sym, AssetDetail.qty_text(Game.staked(sym) + units)]
			_go.text = "Lock · %s %s" % [AssetDetail.qty_text(units), sym]
		elif mode == "sell":
			_sub.text = "You get %s" % Game.money(got)
			_after.text = "After: %s %s left · %s cash" % [AssetDetail.qty_text(free - units), sym, Game.money_short(Game.cash + got)]
			_go.text = "Sell · " + Game.money_short(got)
		else:
			var tp := Game.price(to_sym)
			var to_units := got / tp if tp > 0.0 else 0.0
			_sub.text = "Becomes %s %s" % [AssetDetail.qty_text(to_units), to_sym]
			_after.text = "After: %s %s left · %s %s" % [AssetDetail.qty_text(free - units), sym, AssetDetail.qty_text(Game.holding(Game.coins, to_sym) + to_units), to_sym]
			_go.text = "Convert into %s" % String(Data.coin(to_sym)[1])
		if Game.staked(sym) > 0.0:
			_have.text += " (%s locked)" % AssetDetail.qty_text(Game.staked(sym))
	Page.set_enabled(_go, amount >= 0.01)
	if not _typing and not _field.has_focus():
		_field.text = "" if frac <= 0.0 else Game.money(amount)


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

	func _set_from(x: float) -> void:
		var pad := 14.0
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
		var pad := 14.0
		var y := size.y * 0.5
		var w := size.x - pad * 2.0
		draw_line(Vector2(pad, y), Vector2(pad + w, y), UI.TRACK, 8.0, true)
		draw_line(Vector2(pad, y), Vector2(pad + w * value, y), UI.TEXT, 8.0, true)
		for q in [0.25, 0.5, 0.75]:
			draw_circle(Vector2(pad + w * q, y), 3.0, UI.SUB)
		draw_circle(Vector2(pad + w * value, y), 14.0, UI.TEXT)
		draw_circle(Vector2(pad + w * value, y), 6.0, UI.INK)
