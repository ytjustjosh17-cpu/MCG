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
var _own: Label
var _profit: Label
var _extra: Label
var _sell: Button
var _convert: Button
var _lock_row: Row
var _mine_line: Control
var _mine_l: Label
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
	var tag_text := "%s · %s · pays %.2f%%/day" % [sym, a[4], float(a[3]) * Data.STOCK_DIV_SCALE * 24.0 * 100.0] if kind == "share" else "%s · Crypto" % sym
	var tag := UI.label(tag_text, 13, UI.asset_color(sym))
	hv.add_child(tag)
	_price = UI.display("", 40)
	hv.add_child(_price)
	_change = UI.label("", 13)
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
	# Buy and sell sit right under the chart, so the tab bar never hides them.
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	body.add_child(h)
	_sell = button("Sell", false, _on_sell)
	h.add_child(_sell)
	if kind == "coin":
		# Swap these coins for another kind in one go.
		_convert = button("Convert", false, _on_convert)
		h.add_child(_convert)
	h.add_child(button("Buy", true, _on_buy))

	# What you own, in one card: hidden when you own none.
	var c := card()
	_own_card = c.get_parent()
	_own = _line(c, "You own")
	separator(c)
	_profit = _line(c, "Profit")
	# Long gains shrink and trim rather than push the card off screen.
	_profit.add_theme_font_size_override("font_size", 15)
	_profit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_profit.clip_text = true
	_profit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var pl: Label = _profit.get_parent().get_child(0)
	pl.size_flags_horizontal = Control.SIZE_FILL
	separator(c)
	_extra = _line(c, "Pays" if kind == "share" else "Earns")
	if kind == "coin":
		separator(c)
		_mine_l = _line(c, "Mining")
		_mine_line = _mine_l.get_parent().get_parent()
		# Locking (staking) is one row; tap it for the choices.
		var lc := card()
		_lock_row = Row.new("lock", "", true)
		_lock_row.custom_minimum_size = Vector2(0, 64)
		_lock_row.pressed.connect(_on_stake)
		lc.add_child(_lock_row)

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
	_own.text = "%s · %s" % [qty_text(total), Game.money_short(worth)]
	var gain := worth - paid
	var pct := gain / paid * 100.0 if paid > 0.0 else 0.0
	_profit.text = "%s%s (%.1f%%) · avg %s" % ["▲ +" if gain >= 0 else "▼ −", Game.money_short(absf(gain)), absf(pct), price_text(avg)]
	_profit.add_theme_color_override("font_color", UI.change_color(gain))
	if paid <= 0.0 and worth > 0.0:
		_profit.text = "Mined · all profit · ▲ +" + Game.money_short(worth)
		_profit.add_theme_color_override("font_color", UI.UP)
	elif absf(pct) < 0.05:
		_profit.text = "No change · avg " + price_text(avg)
		_profit.add_theme_color_override("font_color", UI.SUB)
	if kind == "share":
		var a := _asset()
		_extra.text = price_text(free * Game.price(sym) * float(a[3]) * Data.STOCK_DIV_SCALE * Game.global_mult()) + " /h"
	else:
		var earn := Game.stake_earn_per_hour(sym) + Game.mine_per_hour(sym) * Game.price(sym)
		_extra.text = ("+" + Game.money_short(earn) + " /h") if earn > 0.0 else "Nothing yet"
		var nr := Game.rig_count(sym)
		_mine_line.visible = nr > 0
		if nr > 0:
			_mine_l.text = "%d miner%s · %s %s /h" % [nr, "" if nr == 1 else "s", qty_text(Game.mine_per_hour(sym)), sym]
		_lock_row.get_parent().get_parent().visible = total > 0.0   # nothing to lock until you own some
		var left := Game.stake_left(sym)
		var rate := "+%.2f%% a day" % (Game.stake_rate(sym) * 2400.0)
		if locked <= 0.0:
			_lock_row.set_texts("Lock to earn", rate + " · 24 h", "")
		elif left > 0.0:
			_lock_row.set_texts("Locked " + qty_text(locked), rate, Game.clock(left))
		else:
			_lock_row.set_texts("Locked " + qty_text(locked), "Earning · can unlock", "Unlock")
	Page.set_enabled(_sell, free > 0.0, false)
	_sell.modulate.a = 1.0 if free > 0.0 else 0.4
	if _convert:
		_convert.modulate.a = 1.0 if free > 0.0 else 0.4
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
	var body_t := "Locked coins earn up to %.2f%% a day (all locks together pay at most %d%% of your income). You can't sell them for 24 h." % [Game.stake_rate(sym) * 2400.0, int(Data.STAKE_CAP * 100.0)]
	if free <= 0.0 and locked <= 0.0:
		body_t = "Buy some %s first, then lock them to earn more." % sym
	elif locked > 0.0 and Game.stake_left(sym) > 0.0:
		body_t += "\nUnlocks in " + Game.clock(Game.stake_left(sym)) + "."
	Kit.sheet("Lock " + sym, body_t, actions)


func _on_unstake() -> void:
	if Game.unstake(sym):
		Kit.haptic("success")
		Kit.toast("Unlocked " + sym, true)
