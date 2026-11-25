class_name ProfilePage
extends Page
## Profile: fortune, completion, breakdown, stats, achievements and settings.

var _fortune: CountLabel
var _pct: Label
var _bar: ProgressBar
var _rows := {}
var _stats: Array = []
var _ach_row: Row
var _vib_row: Row
var _upd_row: Row
var _report_row: Row
var _storage_row: Row
var _checking := false


func _init() -> void:
	super("Profile")


func build() -> void:
	body.add_child(UI.label("Fortune", 13, UI.SUB))
	_fortune = CountLabel.new(Game.money)
	_fortune.add_theme_font_size_override("font_size", 34)
	_fortune.add_theme_color_override("font_color", UI.TEXT)
	body.add_child(_fortune)
	var chart := NetChart.new()
	chart.custom_minimum_size = Vector2(0, 72)
	body.add_child(chart)
	Game.changed.connect(chart.queue_redraw)

	var cc := card()
	var cp := padded(cc, 16, 8)
	var ch := HBoxContainer.new()
	cp.add_child(ch)
	var cl := UI.label("Complete", 17, UI.TEXT, true)
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
		r.title_l.text = parts[i][1]
		bc.add_child(r)
		_rows[parts[i][0]] = r

	var sc := card()
	var sh := HBoxContainer.new()
	sh.custom_minimum_size = Vector2(0, 64)
	sc.add_child(sh)
	for k in ["Level", "Taps", "Playing"]:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		sh.add_child(v)
		var a := UI.label("", 17, UI.TEXT, true)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b := UI.label(k, 13, UI.SUB)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(a)
		v.add_child(b)
		_stats.append(a)

	var ac := card()
	_ach_row = Row.new("trophy")
	_ach_row.pressed.connect(func():
		Kit.tick()
		push_page.emit(AchievementsPage.new()))
	ac.add_child(_ach_row)

	var st := card()
	_vib_row = Row.new("vibrate", "", false)
	_vib_row.custom_minimum_size = Vector2(0, 52)
	_vib_row.pressed.connect(func():
		Game.vibrate = not Game.vibrate
		Kit.tick()
		Game.save_game()
		refresh())
	st.add_child(_vib_row)
	separator(st)
	_upd_row = Row.new("update", "", false)
	_upd_row.custom_minimum_size = Vector2(0, 52)
	_upd_row.pressed.connect(_check_updates)
	st.add_child(_upd_row)
	Updater.check_finished.connect(func(found: bool):
		if _checking and not found:
			Kit.toast("You're on the latest version")
		_checking = false)

	var hc := card()
	_report_row = Row.new("bug")
	_report_row.pressed.connect(_on_report)
	hc.add_child(_report_row)
	separator(hc, 50)
	_storage_row = Row.new("storage", "", false)
	_storage_row.custom_minimum_size = Vector2(0, 52)
	_storage_row.pressed.connect(func():
		Kit.toast("Saves and logs have fixed size limits"))
	hc.add_child(_storage_row)

	body.add_child(button("Start again", false, _on_reset))


func refresh() -> void:
	if _fortune == null:
		return
	var nw := Game.net_worth()
	_fortune.set_value(nw)
	var c := Game.completion()
	_pct.text = "%.1f%%" % (c * 100.0)
	_bar.value = c * 1000.0
	var vals := {
		"biz": Game.business_value(), "props": Game.props_value(), "shares": Game.book_value(Game.shares),
		"coins": Game.book_value(Game.coins), "items": Game.items_value(), "cash": Game.cash,
	}
	for k in vals.keys():
		var r: Row = _rows[k]
		r.value_l.text = Game.money_short(vals[k])
		r.note_l.text = "%.1f%%" % (float(vals[k]) / maxf(nw, 1.0) * 100.0)
		r.note_l.visible = true
	_stats[0].text = str(Game.level)
	_stats[1].text = Game.group(Game.taps)
	var days := int((Game.now() - Game.started_at) / 86400.0) + 1
	_stats[2].text = "%d day%s" % [days, "" if days == 1 else "s"]
	_ach_row.set_texts("Achievements", "", "%d / %d" % [Game.achieved.size(), Game.achievements().size()])
	_vib_row.set_texts("Vibration", "", "On" if Game.vibrate else "Off")
	_upd_row.set_texts("Updates", "", "v" + Updater.current_version())
	_report_row.set_texts("Copy problem report", "", "")
	if not _storage_timer_started:
		_storage_timer_started = true
		_update_storage()


var _storage_timer_started := false


func _update_storage() -> void:
	_storage_row.set_texts("Storage", "", GameLog.bytes(GameLog.storage_used()))


func _on_report() -> void:
	Kit.tick()
	var n := GameLog.copy_report()
	Kit.sheet("Report copied", "A problem report (%s) is on your clipboard.\n\nOpen the Claude app, paste it into the chat, and say what went wrong." % GameLog.bytes(n), [
		{"text": "Done", "style": "primary"},
	])
	_update_storage()


func _check_updates() -> void:
	Kit.tick()
	if not OS.has_feature("android"):
		Kit.toast("Updates are checked on your phone")
		return
	_checking = true
	Kit.toast("Checking for updates…")
	Updater.check(true)


func _on_reset() -> void:
	Kit.alert("Start again?", "This wipes your cash, companies and everything else. It can't be undone.", [
		{"text": "Keep my progress", "style": "primary"},
		{"text": "Wipe and start again", "style": "secondary", "call": func():
			Game.reset_game()
			Kit.toast("Fresh start")},
	])
