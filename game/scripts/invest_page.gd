class_name InvestPage
extends Page
## Invest tab: shares, property and crypto.

var _seg: Segmented
var _views: Array = []
var _park: VBoxContainer   # rows not in a list right now (filtered out) wait here, hidden but in the tree
var _my_props_l: Label
var _my_props: VBoxContainer
var _all_props_l: Label
var _all_props: VBoxContainer
var _prop_rows_s := {}
var _isles_l: Label
var _isles_card: Control
var _sum_value: Label
var _sum_sub: Label
var _sum_right: Label
var _sum_right_sub: Label
var _sum_right_note: Label
var _sum_line2: Label
var _sum_line3: Label
var _share_rows := {}
var _prop_rows := {}
var _prop_seg: Segmented
var _prop_filter := 0   # Market filter: 0 all, 1 can buy, 2 locked
var _coin_rows := {}
var _sector := ""
var _sector_pill: Button
var _my_shares: VBoxContainer
var _all_shares: VBoxContainer
var _my_shares_l: Label
var _all_shares_l: Label
var _my_coins: VBoxContainer
var _all_coins: VBoxContainer
var _my_coins_l: Label
var _all_coins_l: Label
var _counts := {}   # "Yours" label -> its count label
var _mine_note: Label
var _mine_title: Label
var _mine_sub: Label
var _mine_tile_box: Control
var _mine_count: Label
var _mine_target_sym := ""
var _rig_btn: Button
var _mup_rows := {}   # miner upgrades: "speed" / "cool" -> Row
var _hint: Label
var _sort_pills: Array = []
var _order_key := {}   # list -> last order, so rows only move when it changes
var _sorted := {}   # list -> [mode, order]; kept until the player asks again
const SORTS := [["", "Sort"], ["up", "Rising"], ["down", "Falling"]]
var _news_rows: Array = []   # one news Row per tab that has one
var _mood_box: Control
var _mood_bar: Control
var _mood_label: Label
var _mood_value := 50.0


func _init() -> void:
	super("Invest")


func build() -> void:
	_seg = Segmented.new(["Shares", "Property", "Crypto"])
	_seg.changed.connect(func(i):
		Kit.haptic("selection")
		Game.ui["invest_tab"] = i
		_sorted.clear()
		refresh_view())
	# Lists re-sort only when the page is shown or a choice is made, so a
	# row never jumps away just as the player taps it.
	visibility_changed.connect(func():
		if is_visible_in_tree():
			_sorted.clear())
	_seg.select(int(Game.ui.get("invest_tab", 0)))
	_totals_strip()
	body.add_child(_seg)
	_summary_card()
	_park = VBoxContainer.new()
	_park.visible = false

	# ---- shares ----
	var shares_box := VBoxContainer.new()
	shares_box.add_theme_constant_override("separation", 12)
	body.add_child(shares_box)
	shares_box.add_child(_news_card())
	# Two simple drop-downs instead of a wall of chips.
	var drops := HBoxContainer.new()
	drops.add_theme_constant_override("separation", 8)
	shares_box.add_child(drops)
	_sector_pill = Kit.drop_pill("")
	_sector_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sector_pill.pressed.connect(func():
		var opts: Array = [["", "All sectors"]]
		for sec in Data.SECTORS:
			opts.append([sec, sec])
		Kit.pick("Sector", opts, _sector, func(v):
			Kit.haptic("selection")
			_sector = String(v)
			Game.ui["sector"] = _sector
			_paint_chips()
			refresh()))
	Kit.press_fx(_sector_pill)
	drops.add_child(_sector_pill)
	var sort_p := _sort_pill()
	sort_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drops.add_child(sort_p)
	_sector = String(Game.ui.get("sector", ""))
	if _sector != "" and not Data.SECTORS.has(_sector):
		_sector = ""
	_paint_chips()
	# Your shares first, then the rest of the market.
	_my_shares_l = _head(shares_box, "Yours")
	_my_shares = card(shares_box)
	_all_shares_l = _head(shares_box, "Market")
	_all_shares = card(shares_box)
	for st in Data.STOCKS:
		var r := Row.new()
		var sym: String = st[0]
		r.set_lead(AssetTile.new(sym))
		r.set_bold()
		r.pressed.connect(func(): _open("share", sym))
		_share_rows[sym] = r
		_park.add_child(r)

	# ---- property ----
	var props_box := VBoxContainer.new()
	props_box.add_theme_constant_override("separation", 12)
	body.add_child(props_box)
	# "Yours" and "Market", like Shares and Crypto.
	_my_props_l = _head(props_box, "Yours")
	_my_props = card(props_box)
	_all_props_l = _head(props_box, "Market")
	# Market filter: everything, only what you can buy now, or only the locked ones.
	_prop_seg = Segmented.new(["All", "Can buy", "Locked"])
	_prop_seg.select(0)
	_prop_seg.changed.connect(func(i: int):
		Kit.haptic("selection")
		_prop_filter = i
		refresh())
	props_box.add_child(_prop_seg)
	_all_props = card(props_box)
	for i in range(Data.PROPERTIES.size()):
		var r := _prop_row(String(Data.PROPERTIES[i][3]), String(Data.PROPERTIES[i][0]), i)
		_prop_rows_s[str(i)] = r
		_park.add_child(r)
	# Island estates: a tree unlock, shown once you own the node.
	_isles_l = _head(props_box, "Island estates")
	var isles_v := card(props_box)
	_isles_card = isles_v.get_parent()
	for k in range(Data.ISLES.size()):
		if k > 0:
			separator(isles_v)
		isles_v.add_child(_prop_row(String(Data.ISLES[k][3]), String(Data.ISLES[k][0]), Data.PROPERTIES.size() + k))

	# ---- crypto ----
	var coins_box := VBoxContainer.new()
	coins_box.add_theme_constant_override("separation", 12)
	body.add_child(coins_box)
	coins_box.add_child(_news_card())
	# One line: "Yours" and its count on the left, the sort drop-down on the right.
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 8)
	coins_box.add_child(sort_row)
	_my_coins_l = _head(sort_row, "Yours")
	_my_coins_l.get_parent().size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gap := Control.new()   # keeps Sort on the right even when "Yours" is hidden
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_row.add_child(gap)
	var csp := _sort_pill()
	csp.custom_minimum_size.x = 150
	sort_row.add_child(csp)
	_my_coins = card(coins_box)
	# Mining is a section of Crypto: the rack, the coin, one button.
	coins_box.add_child(_mining_section())
	_all_coins_l = _head(coins_box, "Market")
	_all_coins = card(coins_box)
	for c in Data.COINS:
		var r := Row.new()
		var sym: String = c[0]
		r.set_lead(AssetTile.new(sym))
		r.set_bold()
		r.pressed.connect(func(): _open("coin", sym))
		_coin_rows[sym] = r
		_park.add_child(r)
	body.add_child(_park)
	_views = [shares_box, props_box, coins_box]
	refresh_view()


func _head(parent: Control, text: String) -> Label:
	## A section title with a small count beside it ("Yours  3").
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var l := UI.label(text, 17, UI.TEXT, true)
	h.add_child(l)
	var n := UI.label("", 13, UI.SUB)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	_counts[l] = n
	return l


func _prop_row(art: String, seed_id: String, i: int) -> Row:
	var r := Row.new("", art)   # its own little scene
	(r.lead as Art.Scene).seed_id = seed_id
	# List thumbnails get a quiet sun; the big red one stays on the detail page.
	if "muted" in r.lead:
		r.lead.set("muted", true)
	r.set_bold()
	r.pressed.connect(func(): _property(i))
	_prop_rows[i] = r
	return r


var _tot_box: Control
var _tot_vals: Array = []   # Value, Earns, Profit labels


func _totals_strip() -> void:
	## Everything invested, in three labelled columns (no dotted run-on): what
	## it's worth, what it all earns an hour, and the profit on shares and coins.
	## Hidden until you own something; each tab keeps its own card below.
	var c := card()
	_tot_box = c.get_parent()
	var p := padded(c, 16, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	for t in ["All investments", "Earns", "Profit"]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		col.add_child(UI.label(t, 13, UI.SUB))
		var v := UI.label("", 17, UI.TEXT, true)
		col.add_child(v)
		_tot_vals.append(v)


func _refresh_totals() -> void:
	if _tot_box == null:
		return
	var worth := Game.book_value(Game.shares) + Game.book_value(Game.coins) + Game.props_value()
	_tot_box.visible = worth > 0.0
	if worth <= 0.0:
		return
	var per_h := Game.dividends_per_hour() + Game.rent_per_hour() + Game.staking_per_hour() + Game.mining_value_per_hour()
	var gain := (Game.book_value(Game.shares) - Game.book_cost(Game.shares)) + (Game.book_value(Game.coins) - Game.book_cost(Game.coins))
	_tot_vals[0].text = Game.money_short(worth)
	_tot_vals[1].text = Game.money_short(per_h) + " /h"
	if absf(gain) < 1.0:
		gain = 0.0   # pennies either way read as noise
	_tot_vals[2].text = (Game.CUR + "0") if gain == 0.0 else ("+" if gain > 0.0 else "−") + Game.money_short(absf(gain))
	_tot_vals[2].add_theme_color_override("font_color", UI.TEXT if gain == 0.0 else UI.change_color(gain))


func _summary_card() -> void:
	## One template for all three tabs: what it's worth on the left, what it
	## earns an hour on the right.
	var sc := card()
	var sp := padded(sc, 16, 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	sp.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	_sum_sub = UI.label("", 13, UI.SUB)
	left.add_child(_sum_sub)
	_sum_value = UI.display("", 28)
	left.add_child(_sum_value)
	_sum_line2 = UI.label("", 13, UI.SUB)
	left.add_child(_sum_line2)
	_sum_line3 = UI.label("", 13, UI.SUB)
	left.add_child(_sum_line3)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	h.add_child(right)
	_sum_right_sub = UI.label("", 13, UI.SUB)
	_sum_right_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_sum_right_sub)
	_sum_right = UI.label("", 17, UI.TEXT, true)
	_sum_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_sum_right)
	_sum_right_note = UI.label("", 13, UI.SUB)
	_sum_right_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_sum_right_note)
	# For someone who owns nothing yet: what this tab is for, in one line.
	_hint = UI.label("", 13, UI.SUB)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sp.add_child(_hint)
	# Crypto only: market mood as a word and a thin bar with one marker.
	var mb := HBoxContainer.new()
	mb.add_theme_constant_override("separation", 12)
	sp.add_child(mb)
	_mood_box = mb
	_mood_label = UI.label("", 13, UI.SUB)
	mb.add_child(_mood_label)
	_mood_bar = Control.new()
	_mood_bar.custom_minimum_size = Vector2(0, 16)
	_mood_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mood_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood_bar.draw.connect(_draw_mood)
	mb.add_child(_mood_bar)


func _news_card() -> Control:
	## A single tappable row with the latest headline; opens the news feed.
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var r := Row.new()
	r.caption_on_top()
	r.title_l.add_theme_font_size_override("font_size", 15)
	# A long headline wraps to a second line rather than being cut off.
	r.title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.title_l.max_lines_visible = 2
	r.value_l.add_theme_font_size_override("font_size", 15)
	r.align_top(10)
	r.pressed.connect(func():
		Kit.tick()
		push_page.emit(NewsPage.new({0: 1, 2: 2}.get(_seg.index, 0))))
	pc.add_child(r)
	_news_rows.append(r)
	return pc


func _paint_chips() -> void:
	if _sector_pill:
		_sector_pill.text = ("All sectors" if _sector == "" else _sector) + "  ▾"


func _draw_mood() -> void:
	## A thin track with one marker: fear on the left, greed on the right.
	var w := _mood_bar.size.x
	var y := _mood_bar.size.y * 0.5
	_mood_bar.draw_line(Vector2(0, y), Vector2(w, y), UI.TRACK, 4.0, true)
	var x := clampf(w * _mood_value / 100.0, 6.0, w - 6.0)
	_mood_bar.draw_circle(Vector2(x, y), 6.0, UI.TEXT)


static func mood_name(v: float) -> String:
	if v < 20.0:
		return "Panic"
	if v < 40.0:
		return "Fear"
	if v <= 60.0:
		return "Calm"
	if v <= 80.0:
		return "Greed"
	return "Frenzy"


func _open(k: String, sym: String) -> void:
	Kit.tick()
	push_page.emit(AssetDetail.new(k, sym))


func refresh_view() -> void:
	var was: Control = null
	for v in _views:
		if v.visible:
			was = v
	for i in range(_views.size()):
		_views[i].visible = i == _seg.index
	refresh()
	# Shares, Property and Crypto fade in, not a hard cut.
	var now: Control = _views[_seg.index]
	if was != null and was != now:
		now.modulate.a = 0.0
		var t := Motion.tween(now, "seg")
		t.set_parallel(true)
		t.tween_property(now, "modulate:a", 1.0, Motion.d(0.2))


func _latest_news(kind: String) -> Dictionary:
	for i in range(Game.news.size() - 1, -1, -1):
		var it: Dictionary = Game.news[i]
		var is_coin := not Game._coin(String(it["sym"])).is_empty()
		if is_coin == (kind == "coin"):
			return it
	return {}


func _set_news(r: Row, it: Dictionary) -> void:
	## A "News" caption with the ticker, the headline, then the move it caused.
	r.get_parent().visible = not it.is_empty()   # no empty "No news" card
	if it.is_empty():
		return
	var pct := float(it["pct"])
	var move := AssetDetail.change_text(pct)
	if it.has("mine"):
		move = "Mining ×%s" % str(snappedf(1.0 + pct / 100.0, 0.1))
	r.set_texts(String(it["text"]), "News · " + String(it["sym"]), move)
	r.value_l.add_theme_color_override("font_color", UI.change_color(pct))


static func qty_short(q: float) -> String:
	## A count that always fits a row: 5,534 or 12.4M.
	if q >= 1.0e6:
		return Game.money_short(q).substr(Game.CUR.length())
	return AssetDetail.qty_text(q)


func _today(book: Dictionary, coins: bool) -> float:
	## How much what you hold moved in the last 24 hours, in £.
	var d := 0.0
	for sym in book.keys():
		var held := Game.holding(book, sym) + (Game.staked(sym) if coins else 0.0)
		if held <= 0.0:
			continue
		var pct := Game.change_pct(sym, 1440)
		var v := held * Game.price(sym)
		d += v - v / (1.0 + pct / 100.0)
	return d


func _sum_lines(v: float, today: float, gain: float) -> void:
	## Today's market move as a % (coloured), then the all-time profit; each hidden when it's nothing.
	# As a %: a £ move would count coins bought minutes ago as a day's loss.
	var pct := today / maxf(v - today, 0.01) * 100.0
	_sum_line2.visible = v > 0.0 and absf(pct) >= 0.05
	_sum_line2.text = ("▲ +" if pct >= 0.0 else "▼ −") + "%.1f%% today" % absf(pct)
	_sum_line2.add_theme_color_override("font_color", UI.change_color(today))
	_sum_line3.visible = v > 0.0 and absf(gain) >= maxf(0.01, v * 0.001)
	_sum_line3.text = "Profit " + ("+" if gain >= 0.0 else "−") + Game.money_short(absf(gain))


func refresh() -> void:
	if _seg == null:
		return
	var hints := ["Shares pay you every hour. Tap one to buy.", "Homes and offices pay rent every hour.", "Coins go up and down. Miners dig up more for you."]
	var none: bool = [Game.shares.is_empty(), Game.props.is_empty(), Game.coins.is_empty() and Game.rigs_total() == 0][_seg.index]
	_hint.text = hints[_seg.index]
	_hint.visible = none
	_refresh_totals()
	match _seg.index:
		0:
			var v := Game.book_value(Game.shares)
			_sum_sub.text = "My shares"
			_sum_value.text = Game.money(v)
			_sum_lines(v, _today(Game.shares, false), v - Game.book_cost(Game.shares))
			_sum_right_sub.text = "Dividends"
			_sum_right.text = Game.money_short(Game.dividends_per_hour()) + " /h"
			_sum_right_note.text = "next in %d min" % int(ceil(Game.next_dividend_in() / 60.0))
			_sum_right_note.visible = Game.dividends_per_hour() > 0.0
			_mood_box.visible = false
			_set_news(_news_rows[0], _latest_news("share"))
			var stocks := _ordered(Data.STOCKS, "shares")
			var mine: Array = []
			var rest: Array = []
			var owned := _owned_set("shares", Game.shares)
			for st in stocks:
				if owned.has(st[0]):
					mine.append(st)
				elif _sector == "" or st[4] == _sector:
					rest.append(st)
			_place("shares", mine, rest, _share_rows, _my_shares, _all_shares, _my_shares_l, _all_shares_l)
			for st in mine + rest:
				var r: Row = _share_rows[st[0]]
				var held := Game.holding(Game.shares, st[0])
				var sub: String = "%s · %s risk" % [st[0], risk_name("share", st[0])]
				if held > 0.0:
					sub = "%s shares · %s" % [qty_short(held), Game.money_short(held * Game.price(st[0]))]
				r.set_texts(st[1], sub, AssetDetail.price_text(Game.price(st[0])))
				r.set_change(Game.change_pct(st[0], 1440))
		1:
			var isles := Game.rb("u_isles") > 0.0
			_isles_l.get_parent().visible = isles
			_isles_card.visible = isles
			_sum_sub.text = "My property"
			_sum_value.text = Game.money(Game.props_value())
			_sum_line2.visible = true
			_sum_line2.text = "%d of %d owned" % [Game.props_owned(), Game.property_count()]
			_sum_line2.add_theme_color_override("font_color", UI.SUB)
			_sum_line3.visible = false
			_sum_right_sub.text = "Rent"
			_sum_right.text = Game.money_short(Game.rent_per_hour()) + " /h"
			_sum_right_note.visible = false
			_mood_box.visible = false
			var pmine: Array = []
			var prest: Array = []
			var powned := _props_owned()
			for i in range(Data.PROPERTIES.size()):
				if powned.has(i):
					pmine.append([str(i)])
				else:
					# The Market filter: All / Can buy / Locked.
					var can_buy := Game.cash >= Game.prop_price(i)
					if _prop_filter == 0 or (_prop_filter == 1 and can_buy) or (_prop_filter == 2 and not can_buy):
						prest.append([str(i)])
			_place("props", pmine, prest, _prop_rows_s, _my_props, _all_props, _my_props_l, _all_props_l)
			for i in range(Game.property_count()):
				var p: Array = Data.property(i)
				var r: Row = _prop_rows[i]
				if Game.prop_owned(i):
					r.set_texts(p[0], p[1], Game.money_short(Game.prop_rent(i)) + " /h")
					r.set_locked(false)
				else:
					var price := Game.prop_price(i)
					var can := Game.cash >= price
					# Not affordable yet: a lock and how far off it is, not a faded row.
					var sub: String = p[1] if can else "%s · %s to go" % [p[1], Game.money_short(price - Game.cash)]
					r.set_texts(p[0], sub, Game.money_short(price), "%s /h" % Game.money_short(Game.rent_quote(i)))
					r.set_locked(not can)
		2:
			var v := Game.book_value(Game.coins)
			_sum_sub.text = "My crypto"
			_sum_value.text = Game.money(v)
			_sum_lines(v, _today(Game.coins, true), v - Game.book_cost(Game.coins))
			var sph := Game.staking_per_hour()
			var mph := Game.mining_value_per_hour()
			_sum_right_sub.text = "Earns"
			_sum_right.text = Game.money_short(sph + mph) + " /h"
			_sum_right_note.visible = sph + mph > 0.0
			_sum_right_note.text = "locks and miners" if sph > 0.0 and mph > 0.0 else ("from locks" if sph > 0.0 else "from miners")
			_mood_box.visible = true
			_mood_value = Game.market_mood()
			_mood_label.text = "Mood · " + mood_name(_mood_value)
			_mood_bar.queue_redraw()
			_set_news(_news_rows[1], _latest_news("coin"))
			var cmine: Array = []
			var crest: Array = []
			var cowned := _owned_set("coins", Game.coins)
			for c in _ordered(Data.COINS, "coins"):
				if cowned.has(c[0]):
					cmine.append(c)
				else:
					crest.append(c)
			_place("coins", cmine, crest, _coin_rows, _my_coins, _all_coins, _my_coins_l, _all_coins_l)
			for c in cmine + crest:
				var r: Row = _coin_rows[c[0]]
				var held := Game.holding(Game.coins, c[0]) + Game.staked(c[0])
				var sub: String = "%s · %s risk" % [c[0], risk_name("coin", c[0])]
				if held > 0.0:
					sub = "%s %s · %s" % [qty_short(held), c[0], Game.money_short(held * Game.price(c[0]))]
				r.set_texts(c[1], sub, AssetDetail.price_text(Game.price(c[0])))
				r.set_change(Game.change_pct(c[0], 1440))
			_refresh_mining()


static func risk_name(kind: String, sym: String) -> String:
	## Low / Med / High from how much the price swings (Data volatility).
	## Shares and coins have their own scales: coins all swing more.
	if kind == "share":
		for s in Data.STOCKS:
			if s[0] == sym:
				var v: float = Data.SECTOR_VOL.get(s[4], 0.006)
				return "Low" if v <= 0.005 else ("Med" if v <= 0.007 else "High")
		return "Med"
	var c := Data.coin(sym)
	var cv := float(c[3]) if c.size() > 3 else 0.02
	return "Low" if cv <= 0.012 else ("Med" if cv <= 0.02 else "High")


func _sort_pill() -> Button:
	var b := Kit.drop_pill("")
	b.pressed.connect(func():
		var opts: Array = []
		for o in SORTS:
			opts.append([o[0], "Default order" if o[0] == "" else o[1]])
		Kit.pick("Sort", opts, String(Game.ui.get("sort", "")), func(v):
			Kit.haptic("selection")
			Game.ui["sort"] = String(v)
			_sorted.clear()
			_paint_sort()
			refresh()))
	Kit.press_fx(b)
	_sort_pills.append(b)
	_paint_sort.call_deferred()
	return b


func _paint_sort() -> void:
	var mode := String(Game.ui.get("sort", ""))
	for b in _sort_pills:
		var label := "Sort"
		for s in SORTS:
			if s[0] == mode and mode != "":
				label = s[1]
		b.text = label + "  ▾"


func _ordered(list: Array, key: String) -> Array:
	## The list in the chosen order. Kept until the player asks again, so a
	## row never jumps away just as it is tapped.
	var mode := String(Game.ui.get("sort", ""))
	var keep: Array = _sorted.get(key, [])
	if keep.size() == 2 and keep[0] == mode:
		return keep[1]
	var out := list.duplicate()
	match mode:
		"up":
			out.sort_custom(func(a, b): return Game.change_pct(a[0], 1440) > Game.change_pct(b[0], 1440))
		"down":
			out.sort_custom(func(a, b): return Game.change_pct(a[0], 1440) < Game.change_pct(b[0], 1440))
	_sorted[key] = [mode, out]
	return out


func _props_owned() -> Dictionary:
	## Owned properties. A home you just bought moves to "Yours" straight away
	## (rebuilt whenever the number owned changes, not only when the page opens).
	if _sorted.has("props_owned") and (_sorted["props_owned"] as Dictionary).size() == Game.props_owned():
		return _sorted["props_owned"]
	var out := {}
	for i in range(Data.PROPERTIES.size()):
		if Game.prop_owned(i):
			out[i] = true
	_sorted["props_owned"] = out
	return out


func _owned_set(key: String, book: Dictionary) -> Dictionary:
	## What counts as "Yours", worked out when the page is shown or a choice is
	## made, so a row never jumps between lists while you look (e.g. coins mined).
	var k := key + "_owned"
	if _sorted.has(k):
		return _sorted[k]
	var out := {}
	for sym in book.keys():
		if Game.holding(book, sym) + (Game.staked(sym) if key == "coins" else 0.0) > 0.0:
			out[sym] = true
	_sorted[k] = out
	return out


func _place(key: String, mine: Array, rest: Array, rows: Dictionary, my_v: VBoxContainer, all_v: VBoxContainer, my_l: Label, all_l: Label) -> void:
	## Puts rows into "Yours" and "Market"; only rebuilt when the split or order
	## changes. Every row stays in the tree: rows filtered out wait in a hidden list.
	var sig := ""
	for it in mine:
		sig += String(it[0]) + ","
	sig += "|"
	for it in rest:
		sig += String(it[0]) + ","
	var has_mine := not mine.is_empty()
	_counts[my_l].text = str(mine.size())
	my_l.get_parent().visible = has_mine
	my_v.get_parent().visible = has_mine
	all_l.get_parent().visible = has_mine   # "Market" title only needed when there are two lists
	if _order_key.get(key, "") == sig:
		return
	_order_key[key] = sig
	for v in [my_v, all_v]:
		for ch in v.get_children():
			if not (ch is Row):
				v.remove_child(ch)
				ch.queue_free()
	var placed := {}
	for pair in [[mine, my_v], [rest, all_v]]:
		var at := 0
		for it in pair[0]:
			var r: Row = rows[it[0]]
			placed[r] = true
			if r.get_parent() != pair[1]:
				r.get_parent().remove_child(r)
				pair[1].add_child(r)
			if at > 0:
				separator(pair[1])
				pair[1].move_child(pair[1].get_child(pair[1].get_child_count() - 1), at)
				at += 1
			pair[1].move_child(r, at)
			at += 1
	for r in rows.values():
		if not placed.has(r) and r.get_parent() != _park:
			r.get_parent().remove_child(r)
			_park.add_child(r)


func _mining_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var hh := HBoxContainer.new()
	box.add_child(hh)
	var hl := UI.label("Crypto miners", 17, UI.TEXT, true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hl)
	_mine_count = UI.label("", 13, UI.SUB)
	_mine_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(_mine_count)
	var mc := card(box)
	mc.add_child(MinerRack.new())   # the machines at work
	var sp := padded(mc, 16, 12)
	# Which coin they dig, what it makes, and a drop-down to switch coin.
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 12)
	sp.add_child(th)
	_mine_tile_box = Control.new()
	_mine_tile_box.custom_minimum_size = Vector2(40, 40)
	_mine_tile_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(_mine_tile_box)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tv)
	_mine_title = UI.label("", 17, UI.TEXT, true)
	_mine_title.clip_text = true
	_mine_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(_mine_title)
	_mine_sub = UI.label("", 13, UI.SUB)
	tv.add_child(_mine_sub)
	var chg := Kit.drop_pill("Change")
	chg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chg.custom_minimum_size.x = 112
	UI.paint(chg, UI.RAISED, UI.TEXT, 24)   # it sits on a card, so it needs its own fill
	chg.pressed.connect(_on_pick_target)
	Kit.press_fx(chg)
	th.add_child(chg)
	_rig_btn = UI.primary_btn("Buy miner")
	_rig_btn.pressed.connect(_on_buy_rig)
	Kit.press_fx(_rig_btn)
	sp.add_child(_rig_btn)
	_mine_note = UI.label("", 13, UI.SUB)
	_mine_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sp.add_child(_mine_note)
	# Miner upgrades (1.2): faster chips and better cooling.
	var uh := UI.label("Miner upgrades", 17, UI.TEXT, true)
	box.add_child(uh)
	var uc := card(box)
	var first := true
	for kind in ["speed", "cool"]:
		if not first:
			separator(uc, 50)
		first = false
		var r := Row.new("cpu" if kind == "speed" else "gauge", "", false)
		r.pressed.connect(_on_miner_up.bind(kind))
		uc.add_child(r)
		_mup_rows[kind] = r
	return box


func _on_miner_up(kind: String) -> void:
	Kit.tick()
	var r: Row = _mup_rows[kind]
	if Game.rigs_total() < Game.miner_up_need(kind):
		Kit.toast("Buy a miner first" if Game.rigs_total() == 0 else "Opens at %d miners" % Game.miner_up_need(kind))
		return
	if Game.miner_up_level(kind) >= Game.miner_up_max(kind):
		return
	var c := Game.miner_up_cost(kind)
	if Game.buy_miner_up(kind):
		Kit.haptic("success")
		Motion.pop(r, 1.03)
		Kit.toast("%s · level %d" % [String(Data.MINER_UPS[kind]["name"]), Game.miner_up_level(kind)], true)
		Game.flush_changes()
	else:
		Kit.haptic("error")
		Motion.shake(r)
		Kit.toast("Need %s more" % Game.money_short(c - Game.cash))


func _miner_up_after(kind: String) -> float:
	## Mining per hour if this upgrade were one level higher. Puts the level
	## back straight after, so nothing in the game changes.
	var keep := Game.miner_up_level(kind)
	Game.miners[kind] = keep + 1
	var v := Game.mining_value_per_hour()
	if keep == 0:
		Game.miners.erase(kind)
	else:
		Game.miners[kind] = keep
	return v


func _refresh_miner_ups() -> void:
	for kind in _mup_rows.keys():
		var r: Row = _mup_rows[kind]
		var u: Dictionary = Data.MINER_UPS[kind]
		var lvl := Game.miner_up_level(kind)
		var mx := Game.miner_up_max(kind)
		var sub := ""
		if kind == "speed":
			sub = "Mining +%d%% · level %d of %d" % [int(round(float(u["step"]) * 100.0 * lvl)), lvl, mx] if lvl > 0 else "+%d%% mining a level · %d levels" % [int(round(float(u["step"]) * 100.0)), mx]
		else:
			sub = "Cap %d%% of company income · level %d of %d" % [int(round(Game.mine_cap() * 100.0)), lvl, mx]
		if lvl >= mx:
			r.set_texts(String(u["name"]), sub)
			BusinessPage.plain_value(r, "Max", UI.SUB)
		else:
			var c := Game.miner_up_cost(kind)
			# With miners running: what the next level does to mining, before -> after.
			if Game.rigs_total() > 0:
				var now := Game.mining_value_per_hour()
				var after := _miner_up_after(kind)
				if after > now * 1.001:
					sub = "Mining " + BusinessPage.change_text(now, after)
				elif kind == "speed" and Game.mining_capped():
					sub = "At the cap: cooling first · level %d of %d" % [lvl, mx]
			r.set_texts(String(u["name"]), sub)
			if Game.rigs_total() < Game.miner_up_need(kind):
				BusinessPage.plain_value(r, "%d miners" % Game.miner_up_need(kind), UI.SUB)
			else:
				BusinessPage.price_pill(r, Game.money_short(c), Game.cash >= c)


func _refresh_mining() -> void:
	var n := Game.rigs_total()
	var tgt := Game.mine_target if Game.mine_target != "" else Game._first_coin_owned()
	var c := Data.coin(tgt)
	if _mine_target_sym != tgt:
		_mine_target_sym = tgt
		for ch in _mine_tile_box.get_children():
			ch.queue_free()
		_mine_tile_box.add_child(AssetTile.new(tgt))
	_mine_count.text = "%d / %d" % [n, Data.RIG_MAX]
	_mine_title.text = "Mining " + String(c[1])
	if n > 0:
		_mine_sub.text = "%s /h · %s %s /h" % [Game.money_short(Game.mining_value_per_hour()), qty_short(Game.mine_per_hour(tgt)), tgt]
	else:
		_mine_sub.text = "Miners dig up coins for you"
	var notes: Array = []
	if n >= Data.RIG_MAX:
		_rig_btn.text = "All miners bought"
		Page.set_enabled(_rig_btn, false)
	else:
		var gain := Game.miner_gain()
		var back_h := Game.rig_price() / maxf(gain, 0.001)
		_rig_btn.text = "Buy miner · " + Game.money_short(Game.rig_price())
		Page.set_enabled(_rig_btn, Game.cash >= Game.rig_price())
		if gain < 0.01 or back_h > 24.0 * 365.0:
			notes.append("Mining is at its cap: a new miner adds nothing until your companies earn more.")
		else:
			notes.append("Earns it back in ~%s." % Game.clock(back_h * 3600.0))
	notes.append("Mines while you're away (%d h max)." % int(Game.offline_cap_h()))
	if Game.mining_capped():
		notes.append("Mining pays at most %d%% of your company income." % int(round(Game.mine_cap() * 100.0)))
	_mine_note.text = "\n".join(notes)   # one fact a line
	_refresh_miner_ups()


func _on_buy_rig() -> void:
	## One tap buys one miner; it joins the others on the chosen coin.
	if Game.rigs_total() >= Data.RIG_MAX:
		return
	if Game.buy_miner():
		Kit.haptic("success")
		Motion.pop(_rig_btn, 1.04)
		Kit.toast("Miner %d · mining %s" % [Game.rigs_total(), Data.coin(Game.mine_target)[1]], true)
		Game.flush_changes()
	else:
		Kit.haptic("error")
		Motion.shake(_rig_btn)
		Kit.toast("Need %s more" % Game.money_short(Game.rig_price() - Game.cash))


static func coin_chip(sym: String, on: bool) -> Button:
	## A coin to pick in a grid: logo and ticker. Used by Mine and Convert.
	var b := UI.pill("", UI.TEXT if on else UI.RAISED, UI.INK if on else UI.TEXT, 15, 12)
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tile := AssetTile.new(sym, 26.0)
	tile.position = Vector2(8, 11)
	b.add_child(tile)
	var tl := UI.label(sym, 15, UI.INK if on else UI.TEXT, true)
	tl.position = Vector2(40, 13)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tl)
	Kit.press_fx(b)
	return b


func _on_pick_target() -> void:
	## The coin being mined on top, then the other 12 in a 3 x 4 grid: tap one
	## and every miner switches to it.
	Kit.tick()
	var cur := Game.mine_target if Game.mine_target != "" else Game._first_coin_owned()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var now := HBoxContainer.new()
	now.add_theme_constant_override("separation", 12)
	box.add_child(now)
	now.add_child(AssetTile.new(cur, 32.0))
	var nl := UI.label("Now mining " + String(Data.coin(cur)[1]), 15, UI.TEXT, true)
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	now.add_child(nl)
	var grid := GridContainer.new()
	grid.columns = 6 if Kit.landscape else 3   # landscape: two rows, so it fits the short screen
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	box.set_meta("wide_sheet", true)
	var relay := func(land: bool): grid.columns = 6 if land else 3
	Kit.layout_changed.connect(relay)
	grid.tree_exiting.connect(func(): Kit.layout_changed.disconnect(relay))
	for c in Data.COINS:
		var sym: String = c[0]
		if sym == cur:
			continue
		var b := coin_chip(sym, false)
		b.pressed.connect(func():
			Kit.close_top()
			if Game.set_mine_target(sym):
				Kit.haptic("selection")
				Kit.toast("Miners now mine " + String(c[1]), true)
				Game.flush_changes())
		grid.add_child(b)
	Kit.sheet("Mine which coin?", "All coins earn the same, unless news speeds one up.", [{"text": "Close", "style": "plain"}], true, box)


func _property(i: int) -> void:
	Kit.tick()
	if Game.prop_owned(i):
		push_page.emit(PropertyDetail.new(i))
		return
	var p: Array = Data.property(i)
	var price := Game.prop_price(i)
	var rent := Game.rent_quote(i)
	var can := Game.cash >= price
	var wait := Game.eta(price)
	var need := "Need " + Game.money_short(price - Game.cash) + (" · " + wait if wait != "" else "")
	Kit.sheet(p[0], "%s /h rent" % Game.money(rent), [
		{"text": ("Buy · " + Game.money_short(price)) if can else need, "style": "primary", "disabled": not can, "call": func():
			if Game.buy_property(i):
				Kit.toast("You own " + String(p[0]), true)},
		{"text": "Close", "style": "plain"},
	])
