class_name InvestPage
extends Page
## Invest tab: shares, property and crypto.

var _seg: Segmented
var _views: Array = []
var _sum_value: Label
var _sum_sub: Label
var _sum_right: Label
var _sum_right_sub: Label
var _share_rows := {}
var _prop_rows := {}
var _coin_rows := {}


func _init() -> void:
	super("Invest")


func build() -> void:
	_seg = Segmented.new(["Shares", "Property", "Crypto"])
	_seg.changed.connect(func(_i): refresh_view())
	body.add_child(_seg)
	var sc := card()
	var sp := padded(sc, 16, 2)
	var h := HBoxContainer.new()
	sp.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	_sum_sub = UI.label("", 13, UI.SUB)
	left.add_child(_sum_sub)
	_sum_value = UI.label("", 22, UI.TEXT, true)
	left.add_child(_sum_value)
	var right := VBoxContainer.new()
	h.add_child(right)
	_sum_right_sub = UI.label("", 13, UI.SUB)
	_sum_right_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_sum_right_sub)
	_sum_right = UI.label("", 17, UI.TEXT, true)
	_sum_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_sum_right)

	# Shares list.
	var shares_v := card()
	for i in range(Data.STOCKS.size()):
		var s: Array = Data.STOCKS[i]
		if i > 0:
			separator(shares_v)
		var r := Row.new()
		var sym: String = s[0]
		r.pressed.connect(func(): _share_sheet(sym))
		shares_v.add_child(r)
		_share_rows[sym] = r
	# Property list.
	var props_v := card()
	for i in range(Data.PROPERTIES.size()):
		if i > 0:
			separator(props_v, 80)
		var p: Array = Data.PROPERTIES[i]
		var r := Row.new("", p[3])
		var idx := i
		r.pressed.connect(func(): _property(idx))
		props_v.add_child(r)
		_prop_rows[i] = r
	# Coins list.
	var coins_v := card()
	for i in range(Data.COINS.size()):
		if i > 0:
			separator(coins_v)
		var c: Array = Data.COINS[i]
		var r := Row.new()
		var sym: String = c[0]
		r.pressed.connect(func():
			Kit.tick()
			push_page.emit(CoinDetail.new(sym)))
		coins_v.add_child(r)
		_coin_rows[sym] = r
	_views = [shares_v.get_parent(), props_v.get_parent(), coins_v.get_parent()]
	refresh_view()


func refresh_view() -> void:
	for i in range(_views.size()):
		_views[i].visible = i == _seg.index
	refresh()


func refresh() -> void:
	if _seg == null:
		return
	match _seg.index:
		0:
			var v := Game.book_value(Game.shares)
			var gain := v - Game.book_cost(Game.shares)
			_sum_sub.text = "My shares"
			_sum_value.text = Game.money(v)
			_sum_right_sub.text = "Dividends"
			_sum_right.text = Game.money_short(Game.dividends_per_hour()) + " /h"
			if v > 0.0:
				_sum_sub.text = "My shares · %s%s" % ["▲ +" if gain >= 0 else "▼ −", Game.money_short(absf(gain))]
			for s in Data.STOCKS:
				var r: Row = _share_rows[s[0]]
				r.set_texts(s[1], "%s · %.1f%%" % [s[0], float(s[3]) * 1000.0], Game.money(Game.price(s[0])))
				r.set_change(PriceChart.change_pct(s[0]))
				r.mark.visible = Game.shares.has(s[0])
		1:
			_sum_sub.text = "Property · %d of %d owned" % [Game.props_owned(), Data.PROPERTIES.size()]
			_sum_value.text = Game.money(Game.props_value())
			_sum_right_sub.text = "Rent"
			_sum_right.text = Game.money_short(Game.rent_per_hour()) + " /h"
			for i in range(Data.PROPERTIES.size()):
				var p: Array = Data.PROPERTIES[i]
				var r: Row = _prop_rows[i]
				if Game.prop_owned(i):
					r.set_texts(p[0], p[1], Game.money_short(Game.prop_rent(i)) + " /h")
				else:
					r.set_texts(p[0], p[1], Game.money_short(Game.prop_price(i)), "+%s /h" % Game.money_short(Game.prop_price(i) * Data.RENT_PER_H * Game.global_mult()))
				r.mark.visible = Game.prop_owned(i)
				r.modulate.a = 1.0 if (Game.prop_owned(i) or Game.cash >= Game.prop_price(i)) else 0.6
		2:
			var v := Game.book_value(Game.coins)
			var gain := v - Game.book_cost(Game.coins)
			_sum_sub.text = "My crypto"
			_sum_value.text = Game.money(v)
			_sum_right_sub.text = "Profit"
			_sum_right.text = ("+" if gain >= 0 else "−") + Game.money_short(absf(gain))
			for c in Data.COINS:
				var r: Row = _coin_rows[c[0]]
				var held := Game.holding(Game.coins, c[0])
				r.set_texts(c[1], c[0] + (" · " + Game.money_short(held * Game.price(c[0])) if held > 0 else ""), _coin_price(Game.price(c[0])))
				r.set_change(PriceChart.change_pct(c[0]))
				r.mark.visible = held > 0


static func _coin_price(p: float) -> String:
	if p < 0.01:
		return "$%.5f" % p
	if p < 1.0:
		return "$%.3f" % p
	return Game.money(p)


func _share_sheet(sym: String) -> void:
	var s := Game._stock(sym)
	var held := Game.holding(Game.shares, sym)
	var worth := held * Game.price(sym)
	var div := worth * float(s[3]) * Data.STOCK_DIV_SCALE * Game.global_mult()
	var body_text := "%s per share. %.1f%% dividend." % [Game.money(Game.price(sym)), float(s[3]) * 1000.0]
	if held > 0:
		body_text += "\nYou own %s, paying %s an hour." % [Game.money(worth), Game.money(div)]
	var actions: Array = []
	for f in [0.1, 0.5]:
		var amt: float = Game.cash * f
		if amt >= 1.0:
			var ff: float = f
			actions.append({"text": "Buy %d%% of cash · %s" % [int(ff * 100), Game.money_short(amt)], "style": "primary" if f < 0.2 else "secondary", "call": func():
				if Game.buy_asset("share", sym, Game.cash * ff):
					Kit.toast("Bought %s shares" % sym, true)})
	if held > 0:
		actions.append({"text": "Sell all · " + Game.money_short(worth), "style": "secondary", "call": func():
			var got := Game.sell_asset("share", sym, 1.0)
			Kit.toast("Sold for " + Game.money_short(got))})
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet(s[1], body_text, actions)


func _property(i: int) -> void:
	Kit.tick()
	if Game.prop_owned(i):
		push_page.emit(PropertyDetail.new(i))
		return
	var p: Array = Data.PROPERTIES[i]
	var price := Game.prop_price(i)
	var rent := price * Data.RENT_PER_H * Game.global_mult()
	var can := Game.cash >= price
	Kit.sheet(p[0], "%s · %s\nEarns %s rent an hour. You can improve it later." % [p[1], Game.money(price), Game.money(rent)], [
		{"text": ("Buy for " + Game.money_short(price)) if can else ("Need " + Game.money_short(price - Game.cash) + " more"), "style": "primary", "disabled": not can, "call": func():
			if Game.buy_property(i):
				Kit.toast("You own " + String(p[0]), true)},
		{"text": "Close", "style": "plain"},
	])
