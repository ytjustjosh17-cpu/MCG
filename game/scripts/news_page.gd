class_name NewsPage
extends Page
## Market news: what moved prices, newest first.

var _list: VBoxContainer
var _count := -1
var _seg: Segmented
var _filter := 0   # 0 all, 1 shares, 2 crypto


func _init(start_filter := 0) -> void:
	super("News", true)
	_filter = start_filter


func build() -> void:
	_seg = Segmented.new(["All", "Shares", "Crypto"])
	_seg.changed.connect(func(i: int):
		_filter = i
		_count = -1
		refresh())
	body.add_child(_seg)
	_seg.select(_filter)
	_list = card()


func refresh() -> void:
	var n := int(Game.counters.get("news_total", 0))
	if _list == null or n == _count:
		return
	_count = n
	for ch in _list.get_children():
		ch.queue_free()
	var shown: Array = []
	for i in range(Game.news.size() - 1, -1, -1):
		var sym := String(Game.news[i].get("sym", ""))
		var is_coin := not Game._coin(sym).is_empty()
		if _filter == 0 or (_filter == 1 and not is_coin) or (_filter == 2 and is_coin):
			shown.append(Game.news[i])
	if shown.is_empty():
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.custom_minimum_size = Vector2(0, 56)
		_list.add_child(m)
		var l := UI.label("No news yet" if _filter == 0 else ("No share news yet" if _filter == 1 else "No crypto news yet"), 15, UI.SUB)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.add_child(l)
		return
	for i in range(shown.size()):
		if i > 0:
			separator(_list)
		var item: Dictionary = shown[i]
		var target := String(item.get("sym", ""))
		var opens := not Game._stock(target).is_empty() or not Game._coin(target).is_empty()
		var r := news_row(item, opens)
		r.pressed.connect(func():
			var k := "share" if not Game._stock(target).is_empty() else ("coin" if not Game._coin(target).is_empty() else "")
			if k != "":
				Kit.tick()
				push_page.emit(AssetDetail.new(k, target)))
		_list.add_child(r)


static func ago(t: float) -> String:
	var s := maxf(0.0, Game.now() - t)
	if s < 60.0:
		return "now"
	if s < 3600.0:
		return "%dm" % int(s / 60.0)
	if s < 86400.0:
		return "%dh" % int(s / 3600.0)
	return "%dd" % int(s / 86400.0)


static func news_row(item: Dictionary, chevron: bool) -> Row:
	var pct := float(item.get("pct", 0.0))
	var r := Row.new("news", "", chevron)
	r.custom_minimum_size = Vector2(0, 68)
	r.title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.title_l.add_theme_font_size_override("font_size", 15)
	r.set_texts(String(item.get("text", "")), "%s · %s" % [item.get("sym", ""), ago(float(item.get("t", 0.0)))])
	if item.has("mine"):
		# Mining news changes how fast coins are mined, not the price.
		r.value_l.text = "Mining ×%s" % str(snappedf(1.0 + pct / 100.0, 0.1))
	else:
		r.set_change(pct)
	if r.lead is Icon:
		(r.lead as Icon).set_style(UI.change_color(pct))
	if not chevron:
		# Read-only row: no press highlight.
		r.disabled = true
		r.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	return r
