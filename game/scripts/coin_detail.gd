class_name CoinDetail
extends Page
## A coin: live chart, holdings, buy and sell.

var sym := ""
var _price: Label
var _change: Label
var _chart: PriceChart
var _hold: Label
var _worth: Label
var _paid: Label
var _profit: Label
var _sell: Button


func _init(s := "") -> void:
	sym = s
	super(Game._coin(s)[1] if not Game._coin(s).is_empty() else "Coin", true)


func build() -> void:
	_price = UI.label("", 34)
	body.add_child(_price)
	_change = UI.label("", 13)
	body.add_child(_change)
	_chart = PriceChart.new(sym)
	_chart.custom_minimum_size = Vector2(0, 170)
	body.add_child(_chart)
	var c := card()
	_hold = _line(c, "You hold")
	separator(c)
	_worth = _line(c, "Worth now")
	separator(c)
	_paid = _line(c, "You paid")
	separator(c)
	_profit = _line(c, "Profit")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	body.add_child(h)
	_sell = button("Sell", false, _on_sell)
	h.add_child(_sell)
	h.add_child(button("Buy", true, _on_buy))


func _line(c: VBoxContainer, label: String) -> Label:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.custom_minimum_size = Vector2(0, 48)
	c.add_child(m)
	var h := HBoxContainer.new()
	m.add_child(h)
	var l := UI.label(label, 17, UI.SUB)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var v := UI.label("", 17)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	return v


func refresh() -> void:
	if _price == null:
		return
	_price.text = InvestPage._coin_price(Game.price(sym))
	var pct := PriceChart.change_pct(sym)
	var up := pct >= 0.0
	_change.text = "%s%.2f%% · 1 h" % ["▲ +" if up else "▼ −", absf(pct)]
	_change.add_theme_color_override("font_color", UI.TEXT if up else UI.SUB)
	_chart.queue_redraw()
	var held := Game.holding(Game.coins, sym)
	var worth := held * Game.price(sym)
	var paid: float = float(Game.coins[sym]["cost"]) if Game.coins.has(sym) else 0.0
	_hold.text = "%s %s" % [_qty(held), sym]
	_worth.text = Game.money(worth)
	_paid.text = Game.money(paid)
	var gain := worth - paid
	_profit.text = "%s%s" % ["▲ +" if gain >= 0 else "▼ −", Game.money(absf(gain))]
	Page.set_enabled(_sell, held > 0, false)


static func _qty(q: float) -> String:
	if q >= 1000.0:
		return Game.group(int(q))
	return "%.4f" % q


func _on_buy() -> void:
	var actions: Array = []
	for f in [0.05, 0.25]:
		var ff: float = f
		var amt := Game.cash * ff
		if amt >= 1.0:
			actions.append({"text": "Buy with %d%% of cash · %s" % [int(ff * 100), Game.money_short(amt)], "style": "primary" if ff < 0.1 else "secondary", "call": func():
				if Game.buy_asset("coin", sym, Game.cash * ff):
					Kit.toast("Bought " + sym, true)})
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet("Buy " + sym, "Price " + InvestPage._coin_price(Game.price(sym)), actions)


func _on_sell() -> void:
	var held := Game.holding(Game.coins, sym)
	var worth := held * Game.price(sym)
	Kit.sheet("Sell " + sym, "You hold %s worth %s." % [_qty(held), Game.money(worth)], [
		{"text": "Sell half · " + Game.money_short(worth * 0.5), "style": "secondary", "call": func():
			Kit.toast("Sold for " + Game.money_short(Game.sell_asset("coin", sym, 0.5)))},
		{"text": "Sell all · " + Game.money_short(worth), "style": "secondary", "call": func():
			Kit.toast("Sold for " + Game.money_short(Game.sell_asset("coin", sym, 1.0)))},
		{"text": "Keep them", "style": "primary"},
	])
