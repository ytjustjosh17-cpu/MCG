class_name ProfilePage
extends Page
## Profile: net worth, how much of the game is done, money breakdown, and links.

var _fortune: CountLabel
var _stats: Label
var _pct: Label
var _bar: ProgressBar
var _rows := {}
var _ach_row: Row
var _rival_row: Row
var _upd_card: PanelContainer
var _upd_title: Label
var _upd_btn: Button
var _upd_bar: ProgressBar


func _init() -> void:
	super("Profile")


func build() -> void:
	# Update card: only shown when a new version is out. One tap updates.
	_upd_card = PanelContainer.new()
	var sb := UI.box(UI.PANEL, 18)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = UI.RED
	_upd_card.add_theme_stylebox_override("panel", sb)
	body.add_child(_upd_card)
	var up := padded(_upd_card, 16, 10)
	var uh := HBoxContainer.new()
	uh.add_theme_constant_override("separation", 10)
	up.add_child(uh)
	var ui := Icon.new("update", UI.RED, 22.0)
	ui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	uh.add_child(ui)
	_upd_title = UI.label("", 17, UI.TEXT, true)
	uh.add_child(_upd_title)
	_upd_btn = UI.pill("Update", UI.RED, UI.INK, 17, 24)
	_upd_btn.custom_minimum_size = Vector2(0, 52)
	_upd_btn.pressed.connect(_on_update_pressed)
	Kit.press_fx(_upd_btn)
	up.add_child(_upd_btn)
	_upd_bar = ProgressBar.new()
	_upd_bar.show_percentage = false
	_upd_bar.custom_minimum_size = Vector2(0, 6)
	_upd_bar.max_value = 1.0
	_upd_bar.add_theme_stylebox_override("background", UI.box(UI.TRACK, 3))
	_upd_bar.add_theme_stylebox_override("fill", UI.box(UI.RED, 3))
	up.add_child(_upd_bar)
	Updater.state_changed.connect(_refresh_update)
	_refresh_update()

	body.add_child(UI.label("Net worth", 13, UI.SUB))
	_fortune = CountLabel.new(Game.money_short)
	_fortune.add_theme_font_size_override("font_size", 40)
	_fortune.add_theme_font_override("font", UI.DISPLAY)
	_fortune.add_theme_color_override("font_color", UI.TEXT)
	body.add_child(_fortune)
	_stats = UI.label("", 15, UI.SUB)
	body.add_child(_stats)
	var chart := NetChart.new()
	chart.custom_minimum_size = Vector2(0, 72)
	body.add_child(chart)
	Game.changed.connect(chart.queue_redraw)

	var cc := card()
	var cp := padded(cc, 16, 8)
	var ch := HBoxContainer.new()
	cp.add_child(ch)
	var cl := UI.label("Game done", 17, UI.TEXT, true)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(cl)
	_pct = UI.label("", 17, UI.TEXT, true)
	ch.add_child(_pct)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.max_value = 1000
	_bar.add_theme_stylebox_override("background", UI.box(UI.TRACK, 4))
	_bar.add_theme_stylebox_override("fill", UI.box(UI.RED, 4))
	cp.add_child(_bar)

	section("Money")
	var bc := card()
	var parts := [["biz", "Businesses"], ["props", "Property"], ["shares", "Shares"], ["coins", "Crypto"], ["items", "Items"], ["cash", "Cash"]]
	for i in range(parts.size()):
		if i > 0:
			separator(bc)
		var r := Row.new("", "", false)
		r.custom_minimum_size = Vector2(0, 48)
		r.set_texts(parts[i][1])
		bc.add_child(r)
		_rows[parts[i][0]] = r

	var ac := card()
	_ach_row = Row.new("trophy")
	_ach_row.pressed.connect(func():
		Kit.tick()
		push_page.emit(AchievementsPage.new()))
	ac.add_child(_ach_row)
	separator(ac, 50)
	_rival_row = Row.new("goal")
	_rival_row.pressed.connect(func():
		Kit.tick()
		push_page.emit(RivalsPage.new()))
	ac.add_child(_rival_row)
	separator(ac, 50)
	var stats_row := Row.new("stats")
	stats_row.set_texts("Stats")
	stats_row.pressed.connect(func():
		Kit.tick()
		push_page.emit(StatsPage.new()))
	ac.add_child(stats_row)
	separator(ac, 50)
	var set_row := Row.new("gear")
	set_row.set_texts("Settings")
	set_row.pressed.connect(func():
		Kit.tick()
		push_page.emit(SettingsPage.new()))
	ac.add_child(set_row)


func refresh() -> void:
	if _fortune == null:
		return
	var nw := Game.net_worth()
	_fortune.set_value(nw)
	var days := int((Game.now() - Game.started_at) / 86400.0) + 1
	_stats.text = "Lv %d · %s taps · %d day%s" % [Game.level, Game.group(Game.taps), days, "" if days == 1 else "s"]
	var c := clampf(Game.completion(), 0.0, 1.0)
	_pct.text = "%d%%" % int(c * 100.0)
	_bar.value = c * 1000.0
	var vals := {
		"biz": Game.business_value(), "props": Game.props_value(), "shares": Game.book_value(Game.shares),
		"coins": Game.book_value(Game.coins), "items": Game.items_value() + Game.home_value(), "cash": Game.cash,
	}
	for k in vals.keys():
		var r: Row = _rows[k]
		r.value_l.text = Game.money_short(vals[k])
	var na := Game.next_achievement()
	_ach_row.set_texts("Achievements", ("Next: %s · %d%%" % [na["title"], int(float(na["progress"]) * 100.0)]) if not na.is_empty() else "All done", "%d/%d" % [Game.achieved.size(), Game.achievements().size()])
	_rival_row.set_texts("Rivals", "", "%d/%d" % [Game.rivals_beaten(), Data.RIVALS.size()])


func _refresh_update() -> void:
	if _upd_card == null:
		return
	var show := Updater.has_update()
	_upd_card.visible = show
	if not show:
		return
	_upd_title.text = "Update ready"
	_upd_bar.visible = Updater.state == Updater.State.DOWNLOADING
	_upd_bar.value = Updater.progress
	match Updater.state:
		Updater.State.DOWNLOADING:
			_upd_btn.text = "Downloading %d%%" % int(Updater.progress * 100.0)
		Updater.State.INSTALLING:
			_upd_btn.text = "Opening installer…"
		Updater.State.READY:
			_upd_btn.text = "Install update"
		Updater.State.FAILED:
			_upd_btn.text = "Try again"
		_:
			_upd_btn.text = "Update"


func _on_update_pressed() -> void:
	Kit.haptic("medium")
	if Updater.state == Updater.State.FAILED:
		Updater.state = Updater.State.AVAILABLE
	Updater.start_update()
	_refresh_update()
