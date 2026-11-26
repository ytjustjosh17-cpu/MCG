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
var _stake_card: Control
var _staked: Label
var _stake_info: Label
var _stake_btn: Button
var _unstake_btn: Button
var _rigs_l: Label
var _mine_l: Label
var _rig_btn: Button
var _mine_note: Label
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
	h.add_child(button("Buy", true, _on_buy))

	# What you own: three short lines, hidden when you own none.
	var c := card()
	_own_card = c.get_parent()
	_own = _line(c, "Owned")
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
	_extra = _line(c, "Pays" if kind == "share" else "Staking")

	if kind == "coin":
		section("Lock", "+%.2f%%/day" % (Game.stake_rate(sym) * 2400.0))
		var hint := UI.label("Lock 24 h. Earn more coins.", 13, UI.SUB)
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
		_stake_btn = button("Lock", false, _on_stake)
		sh.add_child(_stake_btn)
		# Mining: rigs that mine this coin all the time, even while away (up to 8 h).
		section("Mine")
		_mine_note = UI.label("", 13, UI.SUB)
		_mine_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(_mine_note)
		var mc := card()
		_rigs_l = _line(mc, "Rigs")
		separator(mc)
		_mine_l = _line(mc, "Mines")
		_rig_btn = button("Buy rig", true, _on_rig)
		body.add_child(_rig_btn)
	else:
		section("Stats")
		var st := card()
		_line(st, "Pays").text = "%.2f%% /day" % (float(a[3]) * Data.STOCK_DIV_SCALE * 24.0 * 100.0)
		separator(st)
		_line(st, "Sector").text = a[4]
		separator(st)
		_hi = _line(st, "7d high")
		separator(st)
		_lo = _line(st, "7d low")

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
		return Game.CUR + "%.5f" % p
	if p < 1.0:
		return Game.CUR + "%.3f" % p
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
	var avg := Game.avg_price(book, sym) if total > 0.0 else 0.0
	_chart.avg_price = avg
	_own_card.visible = total > 0.0
	_own.text = "%s · %s" % [qty_text(total), Game.money_short(worth)]
	var gain := worth - paid
	var pct := gain / paid * 100.0 if paid > 0.0 else 0.0
	_profit.text = "%s%s (%.1f%%) · avg %s" % ["▲ +" if gain >= 0 else "▼ −", Game.money_short(absf(gain)), absf(pct), price_text(avg)]
	_profit.add_theme_color_override("font_color", UI.change_color(gain))
	if absf(pct) < 0.05:
		_profit.text = "No change · avg " + price_text(avg)
		_profit.add_theme_color_override("font_color", UI.SUB)
	if kind == "share":
		var a := _asset()
		_extra.text = price_text(free * Game.price(sym) * float(a[3]) * Data.STOCK_DIV_SCALE * Game.global_mult()) + " /h"
		var wk: Array = Game.series(sym, "1W")
		if wk.size() > 0:
			_hi.text = price_text(maxf(wk.max(), Game.price(sym)))
			_lo.text = price_text(minf(wk.min(), Game.price(sym)))
	else:
		_extra.text = ("+" + Game.money_short(Game.stake_earn_per_hour(sym)) + " /h") if locked > 0.0 else "None locked"
		_staked.text = qty_text(locked) + " " + sym
		var left := Game.stake_left(sym)
		_stake_info.text = "None" if locked <= 0.0 else ("Ready" if left <= 0.0 else Game.clock(left))
		# Lock stays tappable so an empty tap explains "Nothing to lock".
		Page.set_enabled(_unstake_btn, locked > 0.0 and left <= 0.0, false)
		_stake_btn.modulate.a = 1.0 if free > 0.0 else 0.4
		_unstake_btn.modulate.a = 1.0 if locked > 0.0 and left <= 0.0 else 0.4
		var nr := Game.rig_count(sym)
		_rigs_l.text = "%d  (%d / %d in all)" % [nr, Game.rigs_total(), Data.RIG_MAX]
		var mph := Game.mine_per_hour(sym)
		_mine_l.text = ("%s %s /h · %s" % [qty_text(mph), sym, Game.money_short(mph * Game.price(sym))]) if nr > 0 else "Nothing yet"
		var eff := float(Game.mine_eff.get(sym, 1.0))
		var notes: Array = ["Mined coins land in your wallet, even while away (up to 8 h)."]
		if absf(eff - 1.0) > 0.02:
			notes.append("Mining speed ×%.2f from news." % eff)
		if Game.mining_capped():
			notes.append("All mining is capped at %d%% of your income." % int(Data.MINE_CAP * 100.0))
		_mine_note.text = " ".join(notes)
		if Game.rigs_total() >= Data.RIG_MAX:
			_rig_btn.text = "All rigs bought"
			Page.set_enabled(_rig_btn, false)
		else:
			_rig_btn.text = "Buy rig · " + Game.money_short(Game.rig_price())
			Page.set_enabled(_rig_btn, Game.cash >= Game.rig_price())
	Page.set_enabled(_sell, free > 0.0, false)
	_sell.modulate.a = 1.0 if free > 0.0 else 0.4
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
			var label := Game.money_short(amt) + (" · All" if ff >= 1.0 else " · %d%%" % int(ff * 100))
			actions.append({"text": label, "style": "primary" if ff == 0.1 else "secondary", "call": func():
				var spend := Game.cash * ff
				if Game.buy_asset(kind, sym, spend):
					Kit.haptic("success")
					Kit.toast("Bought %s · %s" % [sym, Game.money_short(spend)], true)})
	if actions.is_empty():
		Kit.toast("No cash to spend")
		return
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet("Buy " + sym, "", actions, true, UI.display(price_text(Game.price(sym)), 36))


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
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet("Sell " + sym, "", actions, true, UI.display(price_text(Game.price(sym)), 36))


func _on_stake() -> void:
	var free := Game.holding(Game.coins, sym)
	if free <= 0.0:
		Kit.sheet("Lock " + sym, "Nothing to lock", [{"text": "Close", "style": "plain"}])
		return
	var actions: Array = []
	for f in [0.5, 1.0]:
		var ff: float = f
		var label := ("Lock all · " if ff >= 1.0 else "Lock half · ") + qty_text(free * ff)
		actions.append({"text": label, "style": "primary" if ff >= 1.0 else "secondary", "call": func():
			if Game.stake(sym, ff):
				Kit.haptic("success")
				Kit.toast("Locked for 24 h", true)})
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet("Lock " + sym, "Earns %.2f%% a day.\nLocked 24 h." % (Game.stake_rate(sym) * 2400.0), actions)


func _on_rig() -> void:
	if Game.buy_rig(sym):
		Kit.haptic("success")
		Motion.pop(_rigs_l, 1.1)
		Kit.toast("Rig mining %s" % sym, true)
		Game.flush_changes()
	else:
		Kit.haptic("error")
		Motion.shake(_rig_btn)
		if Game.rigs_total() < Data.RIG_MAX:
			Kit.toast("Need %s more" % Game.money_short(Game.rig_price() - Game.cash))


func _on_unstake() -> void:
	if Game.unstake(sym):
		Kit.haptic("success")
		Kit.toast("Unlocked " + sym, true)
