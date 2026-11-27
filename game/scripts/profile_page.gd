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

	var ac := card()
	_reb_row = _link(ac, "sparkle", func(): return RebirthPage.new())
	separator(ac, 50)
	_bank_row = _link(ac, "home", func(): return BankPage.new())
	separator(ac, 50)
	_ach_row = _link(ac, "trophy", func(): return AchievementsPage.new())
	separator(ac, 50)
	_rival_row = _link(ac, "goal", func(): return RivalsPage.new())

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
