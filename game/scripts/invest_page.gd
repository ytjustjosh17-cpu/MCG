class_name InvestPage
extends Page
## Invest tab: shares, property and crypto.

var _seg: Segmented
var _views: Array = []
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
var _share_seps := {}   # sym -> divider line above that row
var _news_rows: Array = []   # one news Row per tab that has one
var _mood_bar: Control
var _mood_label: Label
var _mood_value := 50.0


func _init() -> void:
	super("Invest")


func build() -> void:
	_seg = Segmented.new(["Shares", "Property", "Crypto"])
	_seg.changed.connect(func(_i):
		Kit.haptic("selection")
		refresh_view())
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

	# ---- shares ----
	var shares_box := VBoxContainer.new()
	shares_box.add_theme_constant_override("separation", 12)
	body.add_child(shares_box)
	shares_box.add_child(_news_card())
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	shares_box.add_child(flow)
	for sec in [""] + Data.SECTORS:
		var b := UI.pill("All" if sec == "" else sec, UI.PANEL, UI.SUB, 13, 16)
		b.custom_minimum_size = Vector2(0, 40)
		var ss: String = sec
		b.pressed.connect(func():
			Kit.haptic("selection")
			_sector = ss
			_paint_chips()
			refresh())
		Kit.press_fx(b)
		flow.add_child(b)
		_chips[sec] = b
	_paint_chips()
	var shares_v := card(shares_box)
	for i in range(Data.STOCKS.size()):
		var st: Array = Data.STOCKS[i]
		if i > 0:
			separator(shares_v)
			_share_seps[st[0]] = shares_v.get_child(shares_v.get_child_count() - 1)
		var r := Row.new()
		var sym: String = st[0]
		r.set_lead(AssetTile.new(sym))
		r.pressed.connect(func(): _open("share", sym))
		shares_v.add_child(r)
		_share_rows[sym] = r

	# ---- property ----
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

	# ---- crypto ----
	var coins_box := VBoxContainer.new()
	coins_box.add_theme_constant_override("separation", 12)
	body.add_child(coins_box)
	var mc := card(coins_box)
	var mp := padded(mc, 16, 8)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 8)
	mp.add_child(mh)
	var gi := Icon.new("gauge", UI.SUB, 18.0)
	gi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(gi)
	var ml := UI.label("Market mood", 13, UI.SUB)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(ml)
	_mood_label = UI.label("", 15, UI.TEXT, true)
	mh.add_child(_mood_label)
	_mood_bar = Control.new()
	_mood_bar.custom_minimum_size = Vector2(0, 14)
	_mood_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood_bar.draw.connect(_draw_mood)
	mp.add_child(_mood_bar)
	coins_box.add_child(_news_card())
	var coins_v := card(coins_box)
	for i in range(Data.COINS.size()):
		if i > 0:
			separator(coins_v)
		var c: Array = Data.COINS[i]
		var r := Row.new()
		var sym: String = c[0]
		r.set_lead(AssetTile.new(sym))
		r.pressed.connect(func(): _open("coin", sym))
		coins_v.add_child(r)
		_coin_rows[sym] = r
	_views = [shares_box, props_v.get_parent(), coins_box]
	refresh_view()


func _news_card() -> Control:
	## A single tappable row with the latest headline; opens the news feed.
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var r := Row.new("news")
	r.title_l.add_theme_font_size_override("font_size", 15)
	r.title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.pressed.connect(func():
		Kit.tick()
		push_page.emit(NewsPage.new()))
	pc.add_child(r)
	_news_rows.append(r)
	return pc


func _paint_chips() -> void:
	for k in _chips.keys():
		var on: bool = k == _sector
		var accent: Color = UI.SECTOR_COL.get(k, UI.TEXT)
		UI.paint(_chips[k], accent if on else UI.PANEL, UI.INK if on else UI.SUB, 16)


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
	_mood_bar.draw_rect(Rect2(x - 6.0, y - 3.0, 12.0, 12.0), UI.RED)


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
	for i in range(_views.size()):
		_views[i].visible = i == _seg.index
	refresh()


func _latest_news(kind: String) -> Dictionary:
	for i in range(Game.news.size() - 1, -1, -1):
		var it: Dictionary = Game.news[i]
		var is_coin := not Game._coin(String(it["sym"])).is_empty()
		if is_coin == (kind == "coin"):
			return it
	return {}


func _set_news(r: Row, it: Dictionary) -> void:
	if it.is_empty():
		r.set_texts("No news yet", "News moves prices")
		r.note_l.visible = false
	else:
		r.set_texts(String(it["text"]), NewsPage.ago(float(it["t"])))
		r.set_change(float(it["pct"]))


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
			_sum_right.add_theme_color_override("font_color", UI.TEXT)
			_sum_line2.text = "%s%s all time · %s paid out" % ["▲ +" if gain >= 0 else "▼ −", Game.money_short(absf(gain)), Game.money_short(float(Game.counters.get("dividends_earned", 0.0)))]
			_sum_line2.visible = v > 0.0 or float(Game.counters.get("dividends_earned", 0.0)) > 0.0
			_set_news(_news_rows[0], _latest_news("share"))
			var first := true
			for st in Data.STOCKS:
				var r: Row = _share_rows[st[0]]
				r.visible = _sector == "" or st[4] == _sector
				if _share_seps.has(st[0]):
					_share_seps[st[0]].visible = r.visible and not first
				if r.visible:
					first = false
				if not r.visible:
					continue
				var held := Game.holding(Game.shares, st[0])
				var sub: String = st[0] + (" · " + Game.money_short(held * Game.price(st[0])) if held > 0 else " · %.1f%%" % (float(st[3]) * 1000.0))
				r.set_texts(st[1], sub, AssetDetail.price_text(Game.price(st[0])))
				r.set_change(Game.change_pct(st[0], 1440))
				r.mark.visible = held > 0
		1:
			_sum_sub.text = "Property · %d of %d owned" % [Game.props_owned(), Data.PROPERTIES.size()]
			_sum_value.text = Game.money(Game.props_value())
			_sum_right_sub.text = "Rent"
			_sum_right.text = Game.money_short(Game.rent_per_hour()) + " /h"
			_sum_right.add_theme_color_override("font_color", UI.TEXT)
			_sum_line2.visible = false
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
			_sum_right.text = ("▲ +" if gain >= 0 else "▼ −") + Game.money_short(absf(gain))
			_sum_right.add_theme_color_override("font_color", UI.change_color(gain))
			var sph := Game.staking_per_hour()
			_sum_line2.text = "Staking earns %s /h" % Game.money_short(sph)
			_sum_line2.visible = sph > 0.0
			_mood_value = Game.market_mood()
			_mood_label.text = mood_name(_mood_value)
			_mood_label.add_theme_color_override("font_color", UI.DOWN if _mood_value < 40.0 else (UI.UP if _mood_value > 60.0 else UI.TEXT))
			_mood_bar.queue_redraw()
			_set_news(_news_rows[1], _latest_news("coin"))
			for c in Data.COINS:
				var r: Row = _coin_rows[c[0]]
				var held := Game.holding(Game.coins, c[0]) + Game.staked(c[0])
				r.set_texts(c[1], c[0] + (" · " + Game.money_short(held * Game.price(c[0])) if held > 0 else ""), AssetDetail.price_text(Game.price(c[0])))
				r.set_change(Game.change_pct(c[0], 1440))
				r.mark.visible = held > 0


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
