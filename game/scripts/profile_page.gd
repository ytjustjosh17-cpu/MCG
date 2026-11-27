class_name ProfilePage
extends Page
## Profile: who you are (net worth, level), progress, the money breakdown and
## the app links. Red stays for the Update button only.

var _fortune: CountLabel
var _stats: Label
var _chart: NetChart
var _pct: Label
var _bar: ProgressBar
var _money: Array = []   # [part key, row, name label, value label, pct label]
var _money_box: VBoxContainer
var _mbar: MoneyBar
const PARTS := [["biz", "Businesses"], ["props", "Property"], ["shares", "Shares"], ["coins", "Crypto"], ["items", "Items"], ["cash", "Cash"]]
var _reb_row: Row
var _bank_row: Row
var _ach_row: Row
var _rival_row: Row
var _rec_row: Row
var _days_row: Row
var _rank_l: Label
var _rank_next: Label
var _rank_bar: ProgressBar
var _show_box: HBoxContainer
var _show_sig := "-"
var _upd_card: PanelContainer
var _upd_title: Label
var _upd_btn: Button
var _upd_bar: ProgressBar


func _init() -> void:
	super("Profile")


func build() -> void:
	# Identity first: net worth, then one quiet line under it.
	var id := VBoxContainer.new()
	id.add_theme_constant_override("separation", 0)
	body.add_child(id)
	id.add_child(UI.label("Net worth", 13, UI.SUB))
	_fortune = CountLabel.new(Game.money_short)
	_fortune.add_theme_font_size_override("font_size", 40)
	_fortune.add_theme_font_override("font", UI.DISPLAY)
	_fortune.add_theme_color_override("font_color", UI.TEXT)
	id.add_child(_fortune)
	_stats = UI.label("", 13, UI.SUB)
	id.add_child(_stats)
	# Rank title for your net worth, with a thin bar to the next one.
	var rk := VBoxContainer.new()
	rk.add_theme_constant_override("separation", 4)
	body.add_child(rk)
	_rank_l = UI.label("", 15, UI.TEXT, true)
	rk.add_child(_rank_l)
	_rank_bar = ProgressBar.new()
	_rank_bar.show_percentage = false
	_rank_bar.custom_minimum_size = Vector2(0, 4)
	_rank_bar.max_value = 1000
	_rank_bar.add_theme_stylebox_override("background", UI.box(UI.TRACK, 2))
	_rank_bar.add_theme_stylebox_override("fill", UI.box(UI.TEXT, 2))
	rk.add_child(_rank_bar)
	_rank_next = UI.label("", 13, UI.SUB)
	_rank_next.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rank_next.clip_text = true
	rk.add_child(_rank_next)
	# Past week, only once there is a week to show (2+ saved points).
	_chart = NetChart.new()
	_chart.custom_minimum_size = Vector2(0, 72)
	body.add_child(_chart)
	Game.changed.connect(_chart.refresh)

	# Update: a slim card row when a new version is out; red only on its button.
	_upd_card = PanelContainer.new()
	_upd_card.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	body.add_child(_upd_card)
	var up := padded(_upd_card, 16, 8)
	var uh := HBoxContainer.new()
	uh.add_theme_constant_override("separation", 12)
	up.add_child(uh)
	var ui := Icon.new("update", UI.TEXT, 22.0)
	ui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	uh.add_child(ui)
	_upd_title = UI.label("", 17, UI.TEXT, true)
	_upd_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upd_title.clip_text = true
	_upd_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	uh.add_child(_upd_title)
	_upd_btn = UI.pill("Update", UI.RED, UI.INK, 17, 24)
	_upd_btn.custom_minimum_size = Vector2(112, 48)
	_upd_btn.pressed.connect(_on_update_pressed)
	Kit.press_fx(_upd_btn)
	uh.add_child(_upd_btn)
	_upd_bar = ProgressBar.new()
	_upd_bar.show_percentage = false
	_upd_bar.custom_minimum_size = Vector2(0, 4)
	_upd_bar.max_value = 1.0
	_upd_bar.add_theme_stylebox_override("background", UI.box(UI.TRACK, 2))
	_upd_bar.add_theme_stylebox_override("fill", UI.box(UI.TEXT, 2))
	up.add_child(_upd_bar)
	Updater.state_changed.connect(_refresh_update)
	_refresh_update()

	var cc := card()
	var cp := padded(cc, 16, 10)
	var ch := HBoxContainer.new()
	cp.add_child(ch)
	var cl := UI.label("Game done", 17, UI.TEXT, true)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(cl)
	_pct = UI.label("", 17, UI.TEXT, true)
	ch.add_child(_pct)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 6)
	_bar.max_value = 1000
	_bar.add_theme_stylebox_override("background", UI.box(UI.TRACK, 3))
	_bar.add_theme_stylebox_override("fill", UI.box(UI.TEXT, 3))
	cp.add_child(_bar)

	# Showcase: four favourite items, picked from what you own.
	var shh := HBoxContainer.new()
	body.add_child(shh)
	var stl := UI.label("Showcase", 17, UI.TEXT, true)
	stl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shh.add_child(stl)
	var edit := UI.text_btn("Edit")
	edit.pressed.connect(_pick_showcase)
	Kit.press_fx(edit)
	shh.add_child(edit)
	var shc := card()
	var shp := padded(shc, 12, 0)
	_show_box = HBoxContainer.new()
	_show_box.add_theme_constant_override("separation", 8)
	shp.add_child(_show_box)

	var ac := card()
	_reb_row = _link(ac, "sparkle", func(): return RebirthPage.new())
	separator(ac, 50)
	_bank_row = _link(ac, "home", func(): return BankPage.new())
	separator(ac, 50)
	_ach_row = _link(ac, "trophy", func(): return AchievementsPage.new())
	separator(ac, 50)
	_rival_row = _link(ac, "goal", func(): return RivalsPage.new())
	separator(ac, 50)
	_rec_row = _link(ac, "star", func(): return RecordsPage.new())
	separator(ac, 50)
	_days_row = Row.new("clock", "", false)
	_days_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ac.add_child(_days_row)

	# Money: one stacked bar, then a list biggest first with each share.
	section("Money")
	var bc := card()
	var mp := padded(bc, 16, 12)
	_mbar = MoneyBar.new()
	mp.add_child(_mbar)
	_money_box = VBoxContainer.new()
	_money_box.add_theme_constant_override("separation", 8)
	mp.add_child(_money_box)
	for i in range(PARTS.size()):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UI.box(MoneyBar.COLS[i], 5))
		line.add_child(dot)
		var nl := UI.label(PARTS[i][1], 15, UI.TEXT)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nl)
		var vl := UI.label("", 15, UI.TEXT, true)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(vl)
		var pl := UI.label("", 13, UI.SUB)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pl.custom_minimum_size = Vector2(44, 0)
		line.add_child(pl)
		_money_box.add_child(line)
		_money.append([PARTS[i][0], line, vl, pl])

	section("App")
	var lc := card()
	var stats_row := _link(lc, "stats", func(): return StatsPage.new())
	stats_row.set_texts("Stats")
	separator(lc, 50)
	var new_row := Row.new("info")
	new_row.set_texts("What's new", "", "v" + Updater.current_version())
	new_row.pressed.connect(_show_whats_new)
	lc.add_child(new_row)
	separator(lc, 50)
	var set_row := _link(lc, "gear", func(): return SettingsPage.new())
	set_row.set_texts("Settings")


func _link(parent: Control, icon: String, make: Callable) -> Row:
	var r := Row.new(icon)
	r.pressed.connect(func():
		Kit.tick()
		push_page.emit(make.call()))
	parent.add_child(r)
	return r


func refresh() -> void:
	if _fortune == null:
		return
	_fortune.set_value(Game.net_worth())
	_stats.text = "Lv %d  ·  %s taps" % [Game.level, Game.group(Game.taps)]
	var rk: Dictionary = Game.rank_title()
	_rank_l.text = String(rk["title"])
	_rank_bar.value = float(rk["progress"]) * 1000.0
	_rank_bar.visible = String(rk["next_title"]) != ""
	_rank_next.text = ("Next: %s at %s" % [rk["next_title"], Game.money_short(float(rk["next_at"]))]) if String(rk["next_title"]) != "" else "The top rank"
	var nd := Game.next_days_milestone()
	_days_row.set_texts("Days played", ("Next reward on day %d" % nd) if nd > 0 else "Every milestone reached", Game.group(Game.days_played()))
	_fill_showcase()
	_chart.visible = NetChart.week_points() >= 2
	var c := clampf(Game.completion(), 0.0, 1.0)
	_pct.text = "%d%%" % int(c * 100.0)
	_bar.value = c * 1000.0
	var vals := {
		"biz": Game.business_value(), "props": Game.props_value(), "shares": Game.book_value(Game.shares),
		"coins": Game.book_value(Game.coins), "items": Game.items_value() + Game.home_value(), "cash": Game.cash,
	}
	var parts: Array = []
	var total := 0.0
	for p in PARTS:
		var v := maxf(0.0, float(vals[p[0]]))   # a loan can push cash below zero
		parts.append(v)
		total += v
	_mbar.set_parts(parts)
	# Biggest first; colours stay with their kind of money, not their place.
	var order: Array = _money.duplicate()
	order.sort_custom(func(x, y): return maxf(0.0, float(vals[x[0]])) > maxf(0.0, float(vals[y[0]])))
	for i in range(order.size()):
		var m: Array = order[i]
		var v := float(vals[m[0]])
		(m[2] as Label).text = Game.money_short(v)
		(m[3] as Label).text = ("%d%%" % roundi(maxf(0.0, v) / total * 100.0)) if total > 0.0 else "0%"
		if (m[1] as Control).get_index() != i:
			_money_box.move_child(m[1], i)
	var na := Game.next_achievement()
	var waiting := Game.unclaimed("ach")
	_ach_row.set_texts("Achievements", ("%d to claim" % waiting) if waiting > 0 else (("Next: %s · %d%%" % [na["title"], int(float(na["progress"]) * 100.0)]) if not na.is_empty() else "All done"), "%d/%d" % [Game.achieved.size(), Game.achievements().size()])
	var pend := Game.rebirth_pending()
	var free := Game.rbp_free()
	var sub := ("Ready: +%s RBP" % Game.group(pend)) if pend > 0 else ("Unlocks at %s net worth" % Game.money_short(Data.REBIRTH_MIN) if Game.rebirths() == 0 else "Next at %s net worth" % Game.money_short(Data.REBIRTH_MIN))
	var bank_sub := "Save and borrow"
	if not Game.loan().is_empty():
		bank_sub = "Loan: %s left" % Game.money_short(Game.loan_owed())
	elif Game.savings() > 0.0:
		bank_sub = "+%s an hour" % Game.money_short(Game.savings_per_hour())
	_bank_row.set_texts("Bank", bank_sub, Game.money_short(Game.savings()) if Game.savings() > 0.0 else "")
	_reb_row.set_texts("Rebirth", sub, ("%s RBP" % Game.group(free)) if free > 0 else "")
	_rival_row.set_texts("Rivals", "", "%d/%d" % [Game.rivals_beaten(), Data.RIVALS.size()])
	_rec_row.set_texts("Records", "Your all-time bests")


func _refresh_update() -> void:
	if _upd_card == null:
		return
	var show := Updater.has_update()
	_upd_card.visible = show
	if not show:
		return
	_upd_bar.visible = Updater.state == Updater.State.DOWNLOADING
	_upd_bar.value = Updater.progress
	# Short words: the button is compact, the title says what is happening.
	match Updater.state:
		Updater.State.DOWNLOADING:
			_upd_title.text = "Update"
			_upd_btn.text = "Downloading %d%%" % int(Updater.progress * 100.0)
		Updater.State.INSTALLING:
			_upd_title.text = "Opening installer"
			_upd_btn.text = "Wait"
		Updater.State.READY:
			_upd_title.text = "Update downloaded"
			_upd_btn.text = "Install"
		Updater.State.FAILED:
			_upd_title.text = "Update failed"
			_upd_btn.text = "Try again"
		_:
			_upd_title.text = "Update ready"
			_upd_btn.text = "Update"


func _on_update_pressed() -> void:
	Kit.haptic("medium")
	if Updater.state == Updater.State.FAILED:
		Updater.state = Updater.State.AVAILABLE
	Updater.start_update()
	_refresh_update()


static func _show_whats_new() -> void:
	Kit.tick()
	Game.ui["seen_new"] = Data.RELEASE
	# One short line each with a gap between, no bullets (easier to read).
	Kit.sheet("What's new in %s" % Data.RELEASE, "\n\n".join(Data.WHATS_NEW), [{"text": "Nice", "style": "primary"}])



class MoneyBar extends Control:
	## One bar split by where your money is.
	const COLS := [UI.TEXT, UI.SUB, UI.HAZE, UI.DIM, UI.FLASH, UI.TRACK]
	var parts: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(0, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_parts(p: Array) -> void:
		parts = p
		queue_redraw()

	func _draw() -> void:
		var total := 0.0
		for v in parts:
			total += float(v)
		draw_rect(Rect2(Vector2.ZERO, size), UI.WINDOW)
		if total <= 0.0:
			return
		var x := 0.0
		for i in range(parts.size()):
			var w := size.x * float(parts[i]) / total
			if w > 0.5:
				draw_rect(Rect2(x, 0, maxf(1.0, w - 1.0), size.y), COLS[i % COLS.size()])
			x += w


# ---- showcase ----------------------------------------------------------------

static func item_name(key: String) -> String:
	var parts := key.split(":")
	if parts.size() != 2:
		return key
	for c in Game.collections():
		if String(c["id"]) == parts[0]:
			var list: Array = c["items"]
			var i := int(parts[1])
			return String(list[i][0]) if i >= 0 and i < list.size() else key
	return key


func _fill_showcase() -> void:
	var keys: Array = Game.showcase()
	var sig := ",".join(keys)
	if sig == _show_sig:
		return
	_show_sig = sig
	for ch in _show_box.get_children():
		ch.queue_free()
	for i in range(Data.SHOWCASE_MAX):
		var slot := Button.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.custom_minimum_size = Vector2(0, 76)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			slot.add_theme_stylebox_override(st, UI.box(UI.RAISED, 12))
		slot.pressed.connect(_pick_showcase)
		Kit.press_fx(slot)
		_show_box.add_child(slot)
		if i < keys.size():
			var p := String(keys[i]).split(":")
			var art := ItemArt.new(p[0], int(p[1]), 52.0)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.offset_left = 8
			art.offset_right = -8
			art.offset_top = 8
			art.offset_bottom = -8
			slot.add_child(art)
		else:
			var plus := Icon.new("plus", UI.SUB, 20.0)
			plus.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			plus.offset_left = -10
			plus.offset_top = -10
			plus.offset_right = 10
			plus.offset_bottom = 10
			slot.add_child(plus)


func _pick_showcase() -> void:
	## A sheet of everything you own; tap up to four, then Done.
	Kit.tick()
	var owned: Array = []
	for c in Game.collections():
		for i in range((c["items"] as Array).size()):
			var key := "%s:%d" % [c["id"], i]
			if Game.items.has(key):
				owned.append(key)
	if owned.is_empty():
		Kit.toast("Buy an item first (Items tab)")
		return
	var sel: Array = Game.showcase().duplicate()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var tiles := {}
	var paint := func():
		for k in tiles.keys():
			var on: bool = sel.has(k)
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				(tiles[k] as Button).add_theme_stylebox_override(st, _ring_box() if on else UI.box(UI.RAISED, 12))
	for key in owned:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(72, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = item_name(key)
		var p := String(key).split(":")
		var art := ItemArt.new(p[0], int(p[1]), 48.0)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 10
		art.offset_right = -10
		art.offset_top = 10
		art.offset_bottom = -10
		b.add_child(art)
		b.pressed.connect(func():
			Kit.tick()
			if sel.has(key):
				sel.erase(key)
			elif sel.size() >= Data.SHOWCASE_MAX:
				Kit.toast("Four at most: tap one to take it off")
				return
			else:
				sel.append(key)
			paint.call())
		grid.add_child(b)
		tiles[key] = b
	paint.call()
	Kit.sheet("Showcase", "Pick up to four items to show on your profile.", [
		{"text": "Done", "style": "primary", "call": func():
			Game.set_showcase(sel)
			_show_sig = "-"
			refresh()},
		{"text": "Close", "style": "plain"},
	], true, grid)


static func _ring_box() -> StyleBoxFlat:
	var sb := UI.box(UI.RAISED, 12)
	sb.border_color = UI.TEXT
	sb.set_border_width_all(2)
	return sb
