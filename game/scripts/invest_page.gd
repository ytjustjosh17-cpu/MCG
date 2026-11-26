class_name InvestPage
extends Page
## Invest tab: shares, property and crypto.

var _seg: Segmented
var _views: Array = []
var _isles_l: Label
var _isles_card: Control
var _sum_value: Label
var _sum_sub: Label
var _sum_right: Label
var _sum_right_sub: Label
var _sum_line2: Label
var _share_rows := {}
var _prop_rows := {}
var _coin_rows := {}
var _sector := ""
var _chips := {}
var _sector_pill: Button
var _my_shares: VBoxContainer
var _all_shares: VBoxContainer
var _my_shares_l: Label
var _all_shares_l: Label
var _my_coins: VBoxContainer
var _all_coins: VBoxContainer
var _my_coins_l: Label
var _all_coins_l: Label
var _mine_sum: Row
var _mine_note: Label
var _mine_target: Row
var _mine_target_sym := ""
var _rig_btn: Button
var _mine_sig := ""
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
	body.add_child(_seg)
	var sc := card()
	var sp := padded(sc, 16, 4)
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
	_sum_line2 = UI.label("", 13, UI.SUB)
	sp.add_child(_sum_line2)
	# For someone who owns nothing yet: what this tab is for, in one line.
	_hint = UI.label("", 13, UI.SUB)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sp.add_child(_hint)
	# Crypto only: market mood as one line with a bar under it.
	var mb := VBoxContainer.new()
	mb.add_theme_constant_override("separation", 2)
	sp.add_child(mb)
	_mood_box = mb
	_mood_label = UI.label("", 13, UI.SUB)
	mb.add_child(_mood_label)
	_mood_bar = Control.new()
	_mood_bar.custom_minimum_size = Vector2(0, 14)
	_mood_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood_bar.draw.connect(_draw_mood)
	mb.add_child(_mood_bar)

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
	_my_shares_l = UI.label("Yours", 17, UI.TEXT, true)
	shares_box.add_child(_my_shares_l)
	_my_shares = card(shares_box)
	_all_shares_l = UI.label("Market", 17, UI.TEXT, true)
	shares_box.add_child(_all_shares_l)
	_all_shares = card(shares_box)
	for st in Data.STOCKS:
		var r := Row.new()
		var sym: String = st[0]
		r.set_lead(AssetTile.new(sym))
		r.pressed.connect(func(): _open("share", sym))
		_share_rows[sym] = r

	# ---- property ----
	var props_box := VBoxContainer.new()
	props_box.add_theme_constant_override("separation", 12)
	body.add_child(props_box)
	var props_v := card(props_box)
	for i in range(Data.PROPERTIES.size()):
		if i > 0:
			separator(props_v, 50)
		var r := Row.new("", String(Data.PROPERTIES[i][3]))   # its own little scene
		(r.lead as Art.Scene).seed_id = String(Data.PROPERTIES[i][0])
		var idx := i
		r.pressed.connect(func(): _property(idx))
		props_v.add_child(r)
		_prop_rows[i] = r
	# Island estates: a tree unlock, shown once you own the node.
	_isles_l = UI.label("Island estates", 17, UI.TEXT, true)
	props_box.add_child(_isles_l)
	var isles_v := card(props_box)
	_isles_card = isles_v.get_parent()
	for k in range(Data.ISLES.size()):
		var i := Data.PROPERTIES.size() + k
		if k > 0:
			separator(isles_v, 50)
		var r := Row.new("", String(Data.ISLES[k][3]))
		(r.lead as Art.Scene).seed_id = String(Data.ISLES[k][0])
		var idx := i
		r.pressed.connect(func(): _property(idx))
		isles_v.add_child(r)
		_prop_rows[i] = r

	# ---- crypto ----
	var coins_box := VBoxContainer.new()
	coins_box.add_theme_constant_override("separation", 12)
	body.add_child(coins_box)
	coins_box.add_child(_news_card())
	# One-line header: "Coins" on the left, the sort drop-down on the right.
	var sort_row := HBoxContainer.new()
	var cl := UI.label("", 15, UI.SUB)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort_row.add_child(cl)
	var csp := _sort_pill()
	csp.custom_minimum_size.x = 150
	sort_row.add_child(csp)
	coins_box.add_child(sort_row)
	_my_coins_l = UI.label("Yours", 17, UI.TEXT, true)
	coins_box.add_child(_my_coins_l)
	_my_coins = card(coins_box)
	# Mining has its own section: one place for all rigs.
	coins_box.add_child(_mining_section())
	_all_coins_l = UI.label("Market", 17, UI.TEXT, true)
	coins_box.add_child(_all_coins_l)
	_all_coins = card(coins_box)
	for c in Data.COINS:
		var r := Row.new()
		var sym: String = c[0]
		r.set_lead(AssetTile.new(sym))
		r.pressed.connect(func(): _open("coin", sym))
		_coin_rows[sym] = r
	_views = [shares_box, props_box, coins_box]
	refresh_view()


func _news_card() -> Control:
	## A single tappable row with the latest headline; opens the news feed.
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var r := Row.new("news")
	r.title_l.add_theme_font_size_override("font_size", 15)
	r.title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Headlines get two lines instead of being cut off.
	r.title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.title_l.max_lines_visible = 2
	r.custom_minimum_size = Vector2(0, 64)
	r.title_l.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.value_l.add_theme_font_size_override("font_size", 15)
	r.pressed.connect(func():
		Kit.tick()
		push_page.emit(NewsPage.new()))
	pc.add_child(r)
	_news_rows.append(r)
	return pc


func _paint_chips() -> void:
	if _sector_pill:
		_sector_pill.text = ("All sectors" if _sector == "" else _sector) + "  ▾"

func _draw_mood() -> void:
	var w := _mood_bar.size.x
	var hgt := 6.0
	var y := (_mood_bar.size.y - hgt) * 0.5
	# Fear (coral) to calm (sand) to greed (mint).
	var n := 40
	for i in n:
		var t := float(i) / float(n - 1)
		var c := UI.DOWN.lerp(UI.SECTOR_COL["Finance"], t * 2.0) if t < 0.5 else UI.SECTOR_COL["Finance"].lerp(UI.UP, t * 2.0 - 1.0)
		c.a = 1.0 if t * 100.0 <= _mood_value else 0.25
		_mood_bar.draw_rect(Rect2(w * i / n, y, w / n - 1.0, hgt), c)
	var x := clampf(w * _mood_value / 100.0, 6.0, w - 6.0)
	_mood_bar.draw_rect(Rect2(x - 6.0, y - 3.0, 12.0, 12.0), UI.TEXT)


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
	## One line: the headline, then the move it caused.
	if it.is_empty():
		r.set_texts("No news")
		r.title_l.add_theme_color_override("font_color", UI.SUB)
	else:
		var pct := float(it["pct"])
		var move := "%s%.1f%%" % ["▲ +" if pct >= 0.0 else "▼ −", absf(pct)]
		if it.has("mine"):
			move = "Mining ×%s" % str(snappedf(1.0 + pct / 100.0, 0.1))
		r.set_texts(String(it["text"]), "", move)
		r.title_l.add_theme_color_override("font_color", UI.TEXT)
		r.value_l.add_theme_color_override("font_color", UI.change_color(pct))


func refresh() -> void:
	if _seg == null:
		return
	var hints := ["Shares pay you every hour. Tap one to buy.", "Homes and offices pay rent every hour.", "Coins go up and down. Miners dig up more for you."]
	var none: bool = [Game.shares.is_empty(), Game.props.is_empty(), Game.coins.is_empty() and Game.rigs_total() == 0][_seg.index]
	_hint.text = hints[_seg.index]
	_hint.visible = none
	match _seg.index:
		0:
			var v := Game.book_value(Game.shares)
			var gain := v - Game.book_cost(Game.shares)
			_sum_sub.text = "My shares"
			_sum_value.text = Game.money(v)
			_sum_right_sub.text = "Dividends · next in %d min" % int(ceil(Game.next_dividend_in() / 60.0))
			_sum_right.text = Game.money_short(Game.dividends_per_hour()) + " /h"
			_sum_right.add_theme_color_override("font_color", UI.TEXT)
			var paid_out := float(Game.counters.get("dividends_earned", 0.0))
			_sum_line2.text = "%s%s" % ["▲ +" if gain >= 0 else "▼ −", Game.money_short(absf(gain))]
			if paid_out > 0.0:
				_sum_line2.text += " · %s paid" % Game.money_short(paid_out)
			_sum_line2.visible = v > 0.0 or paid_out > 0.0
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
				var sub: String = st[0] + (" · " + Game.money_short(held * Game.price(st[0])) if held > 0 else "")
				r.set_texts(st[1], sub, AssetDetail.price_text(Game.price(st[0])))
				r.set_change(Game.change_pct(st[0], 1440))
				r.mark.visible = false
		1:
			_sum_sub.text = "Property · %d / %d" % [Game.props_owned(), Game.property_count()]
			var isles := Game.rb("u_isles") > 0.0
			_isles_l.visible = isles
			_isles_card.visible = isles
			_sum_value.text = Game.money(Game.props_value())
			_sum_right_sub.text = "Rent"
			_sum_right.text = Game.money_short(Game.rent_per_hour()) + " /h"
			_sum_right.add_theme_color_override("font_color", UI.TEXT)
			_sum_line2.visible = false
			_mood_box.visible = false
			for i in range(Game.property_count()):
				var p: Array = Data.property(i)
				var r: Row = _prop_rows[i]
				if Game.prop_owned(i):
					r.set_texts(p[0], p[1], Game.money_short(Game.prop_rent(i)) + " /h")
				else:
					r.set_texts(p[0], p[1], Game.money_short(Game.prop_price(i)), "%s /h" % Game.money_short(Game.prop_price(i) * Data.RENT_PER_H * Game.global_mult()))
				r.mark.visible = Game.prop_owned(i)
				r.modulate.a = 1.0 if (Game.prop_owned(i) or Game.cash >= Game.prop_price(i)) else 0.6
		2:
			var v := Game.book_value(Game.coins)
			var gain := v - Game.book_cost(Game.coins)
			_sum_sub.text = "My crypto"
			_sum_value.text = Game.money(v)
			_sum_right_sub.text = "Profit"
			_sum_right.text = ("▲ +" if gain >= 0 else "▼ −") + Game.money_short(absf(gain))
			_sum_right.add_theme_color_override("font_color", UI.change_color(gain))
			var sph := Game.staking_per_hour()
			_sum_line2.text = "Locked coins %s /h" % Game.money_short(sph)
			_sum_line2.visible = sph > 0.0
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
				r.set_texts(c[1], c[0] + (" · " + Game.money_short(held * Game.price(c[0])) if held > 0 else ""), AssetDetail.price_text(Game.price(c[0])))
				r.set_change(Game.change_pct(c[0], 1440))
				r.mark.visible = false
			_refresh_mining()


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
	## Puts rows into "Yours" and "Market"; only rebuilt when the split or order changes.
	var sig := ""
	for it in mine:
		sig += String(it[0]) + ","
	sig += "|"
	for it in rest:
		sig += String(it[0]) + ","
	var has_mine := not mine.is_empty()
	my_l.text = "Yours · %d" % mine.size()
	my_l.visible = has_mine
	my_v.get_parent().visible = has_mine
	all_l.visible = has_mine   # "Market" label only needed when there are two lists
	if _order_key.get(key, "") == sig:
		return
	_order_key[key] = sig
	for v in [my_v, all_v]:
		for ch in v.get_children():
			v.remove_child(ch)
			if not (ch is Row):
				ch.queue_free()
	for pair in [[mine, my_v], [rest, all_v]]:
		var first := true
		for it in pair[0]:
			if not first:
				separator(pair[1])
			first = false
			pair[1].add_child(rows[it[0]])


func _mining_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UI.label("Crypto miners", 17, UI.TEXT, true))
	var mc := card(box)
	mc.add_child(MinerRack.new())   # the machines at work
	_mine_sum = Row.new("cpu", "", false)
	_mine_sum.disabled = true
	_mine_sum.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	mc.add_child(_mine_sum)
	separator(mc, 50)
	# Which coin every miner digs: tap to switch, free, any time.
	_mine_target = Row.new()
	_mine_target.pressed.connect(_on_pick_target)
	mc.add_child(_mine_target)
	_mine_note = UI.label("", 13, UI.SUB)
	_mine_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mine_note)
	_rig_btn = UI.pill("Buy miner", UI.TEXT, UI.INK, 17, 24)
	_rig_btn.custom_minimum_size = Vector2(0, 48)
	_rig_btn.pressed.connect(_on_buy_rig)
	Kit.press_fx(_rig_btn)
	box.add_child(_rig_btn)
	return box


func _refresh_mining() -> void:
	var n := Game.rigs_total()
	_mine_sum.set_texts("Miners · %d of %d" % [n, Data.RIG_MAX], "" if n > 0 else "They dig up coins for you", (Game.money_short(Game.mining_value_per_hour()) + " /h") if n > 0 else "")
	var tgt := Game.mine_target if Game.mine_target != "" else Game._first_coin_owned()
	var c := Data.coin(tgt)
	if _mine_target_sym != tgt:
		_mine_target_sym = tgt
		_mine_target.set_lead(AssetTile.new(tgt))
	var mph := Game.mine_per_hour(tgt)
	_mine_target.set_texts("Mining " + String(c[1]), ("%s %s /h" % [AssetDetail.qty_text(mph), tgt]) if n > 0 else "Tap to choose the coin", "Change")
	var notes: Array = ["They keep mining while you're away (%d h max)." % int(Game.offline_cap_h())]
	if Game.mining_capped():
		notes.append("Capped at %.1f%% of your income; each new miner lifts the cap." % (Game.mine_cap() * 100.0))
	_mine_note.text = " ".join(notes)
	if n >= Data.RIG_MAX:
		_rig_btn.text = "All miners bought"
		Page.set_enabled(_rig_btn, false)
	else:
		var gain := Game.miner_gain()
		var back_h := Game.rig_price() / maxf(gain, 0.001)
		_rig_btn.text = "Buy miner · %s · +%s /h" % [Game.money_short(Game.rig_price()), Game.money_short(gain)]
		_mine_note.text += "  Next miner pays for itself in about %s." % Game.clock(back_h * 3600.0)
		Page.set_enabled(_rig_btn, Game.cash >= Game.rig_price(), false)


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


func _on_pick_target() -> void:
	## A compact grid of coins (3 across): tap one and every miner switches to it.
	Kit.tick()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for c in Data.COINS:
		var sym: String = c[0]
		var on := sym == Game.mine_target
		var b := UI.pill(sym, UI.TEXT if on else UI.RAISED, UI.INK if on else UI.TEXT, 15, 14)
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Kit.close_top()
			if Game.set_mine_target(sym):
				Kit.haptic("selection")
				Kit.toast("Miners now mine " + String(c[1]), true)
				Game.flush_changes())
		Kit.press_fx(b)
		grid.add_child(b)
	Kit.sheet("Mine which coin?", "All coins earn the same, unless news speeds one up.", [{"text": "Close", "style": "plain"}], true, grid)


func _property(i: int) -> void:
	Kit.tick()
	if Game.prop_owned(i):
		push_page.emit(PropertyDetail.new(i))
		return
	var p: Array = Data.property(i)
	var price := Game.prop_price(i)
	var rent := price * Data.RENT_PER_H * Game.global_mult()
	var can := Game.cash >= price
	var wait := Game.eta(price)
	var need := "Need " + Game.money_short(price - Game.cash) + (" · " + wait if wait != "" else "")
	Kit.sheet(p[0], "%s /h rent" % Game.money(rent), [
		{"text": ("Buy · " + Game.money_short(price)) if can else need, "style": "primary", "disabled": not can, "call": func():
			if Game.buy_property(i):
				Kit.toast("You own " + String(p[0]), true)},
		{"text": "Close", "style": "plain"},
	])


func _exit_tree() -> void:
	# Rows not in a list right now (filtered out) aren't in the tree; free them too.
	for d in [_share_rows, _coin_rows]:
		for r in d.values():
			if is_instance_valid(r) and r.get_parent() == null:
				r.queue_free()
