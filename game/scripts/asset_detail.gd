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
var _own_card: Control
var _own_qty: Label
var _own_val: Label
var _own_earn: Label
var _profit: Label
var _avg: Label
var _div_pct: Label
var _div_each: Label
var _mine_line: Control
var _mine_n: Label
var _mine_rate: Label
var _why: Label
var _news_title: Control
var _sell: Button
var _convert: Button
var _lock_row: Row
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
	# Under the title: ticker and sector (shares) or ticker (coins).
	var info: String = ("%s · %s" % [sym, a[4]]) if kind == "share" else ("Crypto" if String(a[1]) == sym else sym + " · Crypto")
	body.add_child(UI.label(info, 15, UI.SUB))
	# Header: the badge beside the price and how it moved.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	body.add_child(head)
	var tile := AssetTile.new(sym, 56.0)
	tile.cut = UI.BG
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tile)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	_price = UI.display("", 40)
	hv.add_child(_price)
	_change = UI.label("", 15)
	hv.add_child(_change)
	_chart = PriceChart.new(sym, "1H", true)
	_chart.line_col = UI.asset_color(sym)
	_chart.show_range = true
	_chart.custom_minimum_size = Vector2(0, 180)
	_chart.scrub.connect(_on_scrub)
	body.add_child(_chart)
	_seg = Segmented.new(RANGES)
	var r := clampi(int(Game.ui.get("range", 1)), 0, 2)  # default 1D, the lists' window
	_seg.select(r)
	_chart.set_range(RANGES[r])
	_seg.changed.connect(func(i: int):
		Kit.haptic("selection")
		Game.ui["range"] = i
		_chart.set_range(RANGES[i])
		refresh())
	body.add_child(_seg)
	# Buy (the main action) and Sell sit right under the chart, so the tab bar never hides them.
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	body.add_child(bv)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bv.add_child(h)
	_sell = button("Sell", false, _on_sell)
	_sell.custom_minimum_size.y = UI.BTN_PRIMARY_H
	h.add_child(_sell)
	var buy := button("Buy", true, _on_buy)
	buy.custom_minimum_size.y = UI.BTN_PRIMARY_H
	h.add_child(buy)
	# Why Sell can't be used right now, or (shares) what one pays.
	_why = UI.label("", 13, UI.SUB)
	_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(_why)

	# What you own, in one card: hidden when you own none.
	var c := card()
	_own_card = c.get_parent()
	var cols := _cols(c, ["Shares" if kind == "share" else "Coins", "Value", "Earns"])
	_own_qty = cols[0]
	_own_val = cols[1]
	_own_earn = cols[2]
	separator(c)
	var pc := _cols(c, ["Profit", "Avg buy"], [2.0, 1.0])
	_profit = pc[0]
	_avg = pc[1]
	if kind == "share":
		separator(c)
		var dc := _cols(c, ["Dividend", "Per share"], [2.0, 1.0])
		_div_pct = dc[0]
		_div_each = dc[1]
	else:
		var mm := VBoxContainer.new()
		mm.add_theme_constant_override("separation", 0)
		c.add_child(mm)
		_mine_line = mm
		separator(mm)
		var mc := _cols(mm, ["Miners", "Mines"], [2.0, 1.0])
		_mine_n = mc[0]
		_mine_rate = mc[1]
		separator(c)
		# Swap these coins for another kind in one go: easy to find, but quiet.
		_convert = UI.text_btn("Convert to another coin", UI.TEXT)
		_convert.pressed.connect(func():
			Kit.tick()
			_on_convert())
		Kit.press_fx(_convert)
		c.add_child(_convert)
		# Locking (staking) is one row; tap it for the choices.
		var lc := card()
		_lock_row = Row.new("lock", "", true)
		_lock_row.pressed.connect(_on_stake)
		lc.add_child(_lock_row)

	_news_title = section("News")
	_news_box = card()


func _cols(c: Control, caps: Array, ratios: Array = []) -> Array:
	## Labelled columns: a small caption over each value. Returns the value labels.
	## Two-column rows use 2:1, so their second column lines up with the third above.
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	c.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	var out: Array = []
	for k in caps.size():
		var cap: String = caps[k]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_stretch_ratio = float(ratios[k]) if k < ratios.size() else 1.0
		h.add_child(v)
		v.add_child(UI.label(String(cap), 13, UI.SUB))
		var l := UI.label("", 17, UI.TEXT, true)
		v.add_child(l)
		out.append(l)
	return out


static func price_text(p: float) -> String:
	if p <= 0.0:
		return Game.CUR + "0.00"
	if p < 0.01:
		# Tiny prices (Shiba Inu, Pepe): three significant figures.
		var dec := clampi(int(ceil(-log(p) / log(10.0))) + 2, 3, 12)
		return Game.CUR + ("%." + str(dec) + "f") % p
	if p < 1.0:
		return Game.CUR + "%.3f" % p
	return Game.money(p)


static func qty_text(q: float) -> String:
	if q >= 1000.0:
		return Game.group(int(q))
	if q >= 1.0:
		return "%.2f" % q
	if q < 1e-9:
		return "0"
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
	var avg := Game.avg_price(book, sym) if total > 0.0 else 0.0
	_chart.avg_price = avg
	_own_card.visible = total > 0.0
	var earn := free * Game.dividend_rate(sym) if kind == "share" else Game.stake_earn_per_hour(sym) + Game.mine_per_hour(sym) * Game.price(sym)
	_own_qty.text = InvestPage.qty_short(total)
	_own_val.text = Game.money_short(worth)
	_own_earn.text = "+%s /h" % Game.money_short(earn) if earn > 0.0 else Game.CUR + "0 /h"
	var gain := worth - paid
	var pct := gain / paid * 100.0 if paid > 0.0 else 0.0
	_profit.text = "%s%s (%.1f%%)" % ["+" if gain >= 0 else "−", Game.money_short(absf(gain)), absf(pct)]
	_profit.add_theme_color_override("font_color", UI.change_color(gain))
	_avg.text = price_text(avg) if paid > 0.0 else "Mined"
	if paid <= 0.0 and worth > 0.0:
		_profit.text = "+" + Game.money_short(worth)
		_profit.add_theme_color_override("font_color", UI.UP)
	elif absf(pct) < 0.05:
		_profit.text = "No change"
		_profit.add_theme_color_override("font_color", UI.TEXT)
	var div_line := ""
	if kind == "share":
		# A set amount per share each hour; as a % it moves with the price.
		var dp := Game.dividend_rate(sym) * 24.0 / maxf(Game.price(sym), 0.0001) * 100.0
		_div_pct.text = "%.2f%% a day" % dp
		_div_each.text = price_text(Game.dividend_rate(sym)) + " /h"
		div_line = "Pays %.2f%% a day in dividends, every hour" % dp
	if kind == "coin":
		var nr := Game.rig_count(sym)
		_mine_line.visible = nr > 0
		if nr > 0:
			_mine_n.text = str(nr)
			_mine_rate.text = "%s /h" % InvestPage.qty_short(Game.mine_per_hour(sym))
		_lock_row.get_parent().get_parent().visible = total > 0.0   # nothing to lock until you own some
		var left := Game.stake_left(sym)
		var rate := "+%.2f%% a day" % (Game.stake_rate(sym) * 2400.0)
		if locked <= 0.0:
			_lock_row.set_texts("Lock to earn", rate + " · 24 h", "")
		elif left > 0.0:
			_lock_row.set_texts("Locked " + InvestPage.qty_short(locked), rate, Game.clock(left))
		else:
			_lock_row.set_texts("Locked " + InvestPage.qty_short(locked), "Earning · can unlock", "Unlock")
		UI.paint(_convert, Color(0, 0, 0, 0), UI.TEXT if free > 0.0 else UI.SUB, 24)
	Page.set_enabled(_sell, free > 0.0, false)
	# Say why Sell is greyed out, so it never just looks broken.
	var why := ""
	if free <= 0.0 and locked > 0.0:
		why = ("All locked · free in " + Game.clock(Game.stake_left(sym))) if Game.stake_left(sym) > 0.0 else "All locked · tap Locked below to unlock"
	elif total <= 0.0:
		why = div_line if div_line != "" else "Buy some to sell later"
	_why.text = why
	_why.visible = why != ""
	var news_n := int(Game.counters.get("news_total", 0))
	if news_n != _news_count:
		_news_count = news_n
		_fill_news()


func _fill_news() -> void:
	for ch in _news_box.get_children():
		ch.queue_free()
	var items := Game.news_for(sym)
	# No news: no empty section at all.
	_news_title.get_parent().visible = not items.is_empty()
	_news_box.get_parent().visible = not items.is_empty()
	if items.is_empty():
		return
	for i in range(mini(items.size(), 3)):
		if i > 0:
			separator(_news_box)
		_news_box.add_child(NewsPage.news_row(items[i], false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _scrubbing:
		_scrubbing = false
		if _chart:
			_chart.set_range(_chart.range_name)


func _on_buy() -> void:
	if Game.cash < 0.01:
		Kit.toast("No cash to spend")
		return
	TradeSheet.open(kind, sym, "buy")


func _blocked_sell() -> bool:
	## True (with a reason shown) when there are no free coins or shares to move.
	if Game.holding(_book(), sym) > 0.0:
		return false
	Kit.haptic("error")
	if kind == "coin" and Game.staked(sym) > 0.0 and Game.stake_left(sym) > 0.0:
		Kit.toast("All locked · free in " + Game.clock(Game.stake_left(sym)))
	elif kind == "coin" and Game.staked(sym) > 0.0:
		Kit.toast("Unlock them first (tap Locked)")
	else:
		Kit.toast("You don't own any yet")
	return true


func _on_sell() -> void:
	if not _blocked_sell():
		TradeSheet.open(kind, sym, "sell")


func _on_convert() -> void:
	if not _blocked_sell():
		TradeSheet.open(kind, sym, "convert")


func _on_stake() -> void:
	## One sheet for locking and unlocking.
	Kit.tick()
	var free := Game.holding(Game.coins, sym)
	var locked := Game.staked(sym)
	var actions: Array = []
	if locked > 0.0 and Game.stake_left(sym) <= 0.0:
		actions.append({"text": "Unlock " + qty_text(locked), "style": "primary", "call": _on_unstake})
	var matured := locked > 0.0 and Game.stake_left(sym) <= 0.0
	if free > 0.0 and not matured:   # unlock first, so ready coins are never re-locked by mistake
		# Any amount: slider, chips or a typed amount.
		TradeSheet.open(kind, sym, "lock")
		return
	actions.append({"text": "Close", "style": "plain"})
	var body_t := "Earns up to %.2f%% a day (all locks: at most %d%% of income). Locked for 24 h." % [Game.stake_rate(sym) * 2400.0, int(Data.STAKE_CAP * 100.0)]
	if free <= 0.0 and locked <= 0.0:
		body_t = "Buy some %s first, then lock them to earn more." % sym
	elif locked > 0.0 and Game.stake_left(sym) > 0.0:
		body_t += "\nUnlocks in " + Game.clock(Game.stake_left(sym)) + "."
	Kit.sheet("Lock " + sym, body_t, actions)


func _on_unstake() -> void:
	if Game.unstake(sym):
		Kit.haptic("success")
		Kit.toast("Unlocked " + sym, true)
