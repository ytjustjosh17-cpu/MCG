class_name AssetDetail
extends Page
## One company share or one coin: chart, what you own, buy, sell, staking and news.

const RANGES := ["1H", "1D", "1W"]
const RANGE_MIN := [60, 1440, 10080]

var kind := "share"   # "share" or "coin"
var sym := ""
var _price: Label
var _change: Label
var _seg: Segmented
var _chart: PriceChart
var _own: Label
var _worth: Label
var _avg: Label
var _profit: Label
var _extra: Label
var _extra_name: Label
var _sell: Button
var _stake_card: Control
var _staked: Label
var _stake_info: Label
var _stake_btn: Button
var _unstake_btn: Button
var _hi: Label
var _lo: Label
var _news_box: VBoxContainer
var _news_count := -1
var _scrubbing := false


func _init(k := "share", s := "") -> void:
	kind = k
	sym = s
	var a := _asset()
	super(a[1] if not a.is_empty() else sym, true)


func _asset() -> Array:
	return Game._stock(sym) if kind == "share" else Game._coin(sym)


func _book() -> Dictionary:
	return Game.shares if kind == "share" else Game.coins


func build() -> void:
	var a := _asset()
	# Header: a big colour badge beside the price.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	body.add_child(head)
	var tile := AssetTile.new(sym, 64.0)
	tile.cut = UI.BG
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tile)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	var tag := UI.label("%s · %s" % [sym, a[4] if kind == "share" else "Crypto"], 13, UI.asset_color(sym))
	hv.add_child(tag)
	_price = UI.display("", 40)
	hv.add_child(_price)
	_change = UI.label("", 13)
	hv.add_child(_change)
	_chart = PriceChart.new(sym, "1H", true)
	_chart.line_col = UI.asset_color(sym)
	_chart.custom_minimum_size = Vector2(0, 180)
	_chart.scrub.connect(_on_scrub)
	body.add_child(_chart)
	_seg = Segmented.new(RANGES)
	_seg.select(1)  # 1D, the same window the lists show
	_chart.set_range("1D")
	_seg.changed.connect(func(i: int):
		Kit.haptic("selection")
		_chart.set_range(RANGES[i])
		refresh())
	body.add_child(_seg)

	# What you own.
	var c := card()
	_own = _line(c, "You own")
	separator(c)
	_worth = _line(c, "Worth")
	separator(c)
	_avg = _line(c, "Avg price")
	separator(c)
	_profit = _line(c, "Profit")
	separator(c)
	_extra = _line(c, "Pays you" if kind == "share" else "Staking earns")
	_extra_name = _extra.get_parent().get_child(0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	body.add_child(h)
	_sell = button("Sell", false, _on_sell)
	h.add_child(_sell)
	h.add_child(button("Buy", true, _on_buy))

	if kind == "coin":
		section("Staking", "%.2f%% a day" % (Game.stake_rate(sym) * 2400.0))
		var hint := UI.label("Lock coins for 24 h and they earn more coins.", 13, UI.SUB)
		body.add_child(hint)
		var sc := card()
		_stake_card = sc.get_parent()
		_staked = _line(sc, "Locked")
		separator(sc)
		_stake_info = _line(sc, "Unlocks")
		var sh := HBoxContainer.new()
		sh.add_theme_constant_override("separation", 8)
		body.add_child(sh)
		_unstake_btn = button("Unlock", false, _on_unstake)
		sh.add_child(_unstake_btn)
		_stake_btn = button("Stake", false, _on_stake)
		sh.add_child(_stake_btn)
	else:
		section("Stats")
		var st := card()
		_line(st, "Yearly payout").text = "%.1f%%" % (float(a[3]) * 1000.0)
		separator(st)
		_line(st, "Sector").text = a[4]
		separator(st)
		_hi = _line(st, "Week high")
		separator(st)
		_lo = _line(st, "Week low")

	section("News")
	_news_box = card()


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


static func price_text(p: float) -> String:
	if p <= 0.0:
		return "$0.00"
	if p < 0.01:
		return "$%.5f" % p
	if p < 1.0:
		return "$%.3f" % p
	return Game.money(p)


static func qty_text(q: float) -> String:
	if q >= 1000.0:
		return Game.group(int(q))
	if q >= 1.0:
		return "%.2f" % q
	return "%.4f" % q


static func change_text(pct: float) -> String:
	return "%s%.2f%%" % ["▲ +" if pct >= 0.0 else "▼ −", absf(pct)]


func _on_scrub(p: float, i: int, n: int) -> void:
	_scrubbing = p >= 0.0
	if _scrubbing:
		_price.text = price_text(p)
		var steps := n - 1 - i
		var unit: int = [1, 15, 60][_seg.index]
		_change.text = "now" if steps == 0 else "%s ago" % Game.clock(float(steps * unit * 60))
		_change.add_theme_color_override("font_color", UI.SUB)
	else:
		refresh()


func refresh() -> void:
	if _price == null:
		return
	if not _scrubbing:
		_price.text = price_text(Game.price(sym))
		var move := Game.change_pct(sym, RANGE_MIN[_seg.index])
		_change.text = "%s · %s" % [change_text(move), RANGES[_seg.index]]
		_change.add_theme_color_override("font_color", UI.change_color(move))
		_chart.queue_redraw()
	var book := _book()
	var free := Game.holding(book, sym)
	var locked := Game.staked(sym) if kind == "coin" else 0.0
	var total := free + locked
	var worth := total * Game.price(sym)
	var paid: float = float(book[sym]["cost"]) if book.has(sym) else 0.0
	_own.text = qty_text(total) + (" shares" if kind == "share" else " " + sym)
	_worth.text = Game.money(worth)
	_avg.text = price_text(Game.avg_price(book, sym)) if total > 0.0 else "None"
	var gain := worth - paid
	var pct := gain / paid * 100.0 if paid > 0.0 else 0.0
	_profit.text = "None" if total <= 0.0 else "%s%s (%.1f%%)" % ["▲ +" if gain >= 0 else "▼ −", Game.money_short(absf(gain)), absf(pct)]
	_profit.add_theme_color_override("font_color", UI.TEXT if total <= 0.0 else UI.change_color(gain))
	if total > 0.0 and absf(pct) < 0.05:
		_profit.text = "No change yet"
		_profit.add_theme_color_override("font_color", UI.SUB)
	if kind == "share":
		var a := _asset()
		_extra.text = Game.money_short(free * Game.price(sym) * float(a[3]) * Data.STOCK_DIV_SCALE * Game.global_mult()) + " /h"
		var wk: Array = Game.series(sym, "1W")
		if wk.size() > 0:
			_hi.text = price_text(maxf(wk.max(), Game.price(sym)))
			_lo.text = price_text(minf(wk.min(), Game.price(sym)))
	else:
		_extra.text = Game.money_short(locked * Game.stake_rate(sym) * Game.price(sym)) + " /h"
		_staked.text = qty_text(locked) + " " + sym
		var left := Game.stake_left(sym)
		_stake_info.text = "None" if locked <= 0.0 else ("Ready" if left <= 0.0 else Game.clock(left))
		Page.set_enabled(_stake_btn, free > 0.0, false)
		Page.set_enabled(_unstake_btn, locked > 0.0 and left <= 0.0, false)
	Page.set_enabled(_sell, free > 0.0, false)
	var news_n := int(Game.counters.get("news_total", 0))
	if news_n != _news_count:
		_news_count = news_n
		_fill_news()


func _fill_news() -> void:
	for ch in _news_box.get_children():
		ch.queue_free()
	var items := Game.news_for(sym)
	if items.is_empty():
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.custom_minimum_size = Vector2(0, 48)
		_news_box.add_child(m)
		var l := UI.label("No news yet", 15, UI.SUB)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.add_child(l)
		return
	for i in range(mini(items.size(), 5)):
		if i > 0:
			separator(_news_box)
		_news_box.add_child(NewsPage.news_row(items[i], false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _scrubbing:
		_scrubbing = false
		if _chart:
			_chart.set_range(_chart.range_name)


func _on_buy() -> void:
	var actions: Array = []
	var fracs := [0.1, 0.25, 0.5, 1.0]
	for f in fracs:
		var ff: float = f
		var amt := Game.cash * ff
		if amt >= 0.01:
			var label := ("All cash · " if ff >= 1.0 else "%d%% of cash · " % int(ff * 100)) + Game.money_short(amt)
			actions.append({"text": label, "style": "primary" if ff == 0.1 else "secondary", "call": func():
				var spend := Game.cash * ff
				if Game.buy_asset(kind, sym, spend):
					Kit.haptic("success")
					Kit.toast("Bought %s · %s" % [sym, Game.money_short(spend)], true)})
	if actions.is_empty():
		Kit.toast("No cash to spend")
		return
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet("Buy " + sym, "Price " + price_text(Game.price(sym)), actions)


func _on_sell() -> void:
	var free := Game.holding(_book(), sym)
	var worth := free * Game.price(sym)
	var actions: Array = []
	for f in [0.25, 0.5, 1.0]:
		var ff: float = f
		var label := ("Sell all · " if ff >= 1.0 else "Sell %d%% · " % int(ff * 100)) + Game.money_short(worth * ff)
		actions.append({"text": label, "style": "secondary", "call": func():
			var got := Game.sell_asset(kind, sym, ff)
			if got > 0.0:
				Kit.haptic("success")
				Kit.toast("Sold for " + Game.money_short(got))})
	actions.append({"text": "Keep them", "style": "primary"})
	Kit.sheet("Sell " + sym, "You have %s worth %s." % [qty_text(free), Game.money(worth)], actions)


func _on_stake() -> void:
	var free := Game.holding(Game.coins, sym)
	var actions: Array = []
	for f in [0.5, 1.0]:
		var ff: float = f
		var label := ("Stake all · " if ff >= 1.0 else "Stake half · ") + qty_text(free * ff)
		actions.append({"text": label, "style": "primary" if ff >= 1.0 else "secondary", "call": func():
			if Game.stake(sym, ff):
				Kit.haptic("success")
				Kit.toast("Locked for 24 h", true)})
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet("Stake " + sym, "Locked coins earn %.2f%% more coins a day.\nYou can't sell them for 24 hours." % (Game.stake_rate(sym) * 2400.0), actions)


func _on_unstake() -> void:
	if Game.unstake(sym):
		Kit.haptic("success")
		Kit.toast("Unlocked " + sym, true)
