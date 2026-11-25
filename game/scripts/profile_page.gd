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
var _motion_row: Row
var _report_row: Row
var _rival_row: Row
var _toggles: Array = []
var _storage_row: Row
var _checking := false
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

	body.add_child(UI.label("Fortune", 13, UI.SUB))
	_fortune = CountLabel.new(Game.money)
	_fortune.add_theme_font_size_override("font_size", 40)
	_fortune.add_theme_font_override("font", UI.DISPLAY)
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
	var parts := [["biz", "Businesses"], ["props", "Property"], ["shares", "Shares"], ["coins", "Crypto"], ["items", "Items & home"], ["cash", "Cash"]]
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
	separator(ac, 50)
	_rival_row = Row.new("trophy")
	_rival_row.pressed.connect(func():
		Kit.tick()
		push_page.emit(RivalsPage.new()))
	ac.add_child(_rival_row)

	var st := card()
	_vib_row = Row.new("vibrate", "", false)
	_vib_row.custom_minimum_size = Vector2(0, 52)
	_vib_row.pressed.connect(func():
		Game.vibrate = not Game.vibrate
		Kit.tick()
		Game.save_game()
		refresh())
	st.add_child(_vib_row)
	separator(st, 50)
	_motion_row = Row.new("sparkle", "", false)
	_motion_row.custom_minimum_size = Vector2(0, 52)
	_motion_row.pressed.connect(func():
		Game.reduce_motion = not Game.reduce_motion
		Kit.tick()
		Game.save_game()
		refresh())
	st.add_child(_motion_row)
	separator(st, 50)
	_toggles = []
	for spec in [["deals_quiet", "sparkle", "Deal pop-ups", true], ["news_quiet", "news", "News messages", true], ["keep_awake", "clock", "Keep screen on", false]]:
		var key: String = spec[0]
		var inverted: bool = spec[3]  # "quiet" keys are shown as the opposite (pop-ups on/off)
		var tr := Row.new(spec[1], "", false)
		tr.custom_minimum_size = Vector2(0, 52)
		tr.pressed.connect(func():
			Game.ui[key] = not bool(Game.ui.get(key, false))
			Kit.tick()
			if key == "keep_awake":
				DisplayServer.screen_set_keep_on(bool(Game.ui[key]))
			Game.save_game()
			refresh())
		st.add_child(tr)
		separator(st, 50)
		_toggles.append([tr, key, spec[2], inverted])
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

	# Backup: the save as a code on the clipboard, to keep in Notes.
	var bk := card()
	var b1 := Row.new("copy")
	b1.set_texts("Back up progress", "Copies a code to paste in Notes")
	b1.pressed.connect(_on_backup)
	bk.add_child(b1)
	separator(bk, 50)
	var b2 := Row.new("download")
	b2.set_texts("Restore progress", "From a copied code")
	b2.pressed.connect(_on_restore)
	bk.add_child(b2)

	var reset := UI.flat_button()
	reset.text = "Start again"
	reset.custom_minimum_size = Vector2(0, 48)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		reset.add_theme_color_override(k, UI.DOWN)
	reset.add_theme_font_size_override("font_size", 15)
	reset.pressed.connect(_on_reset)
	body.add_child(reset)


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
		"coins": Game.book_value(Game.coins), "items": Game.items_value() + Game.home_value(), "cash": Game.cash,
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
	var na := Game.next_achievement()
	_ach_row.set_texts("Achievements", ("Next: %s · %d%%" % [na["title"], int(float(na["progress"]) * 100.0)]) if not na.is_empty() else "All done", "%d / %d" % [Game.achieved.size(), Game.achievements().size()])
	for t in _toggles:
		var on: bool = bool(Game.ui.get(t[1], false))
		if t[3]:
			on = not on
		(t[0] as Row).set_texts(t[2], "", "On" if on else "Off")
	_rival_row.set_texts("Rivals", "", "%d / %d beaten" % [Game.rivals_beaten(), Data.RIVALS.size()])
	_vib_row.set_texts("Vibration", "", "On" if Game.vibrate else "Off")
	_motion_row.set_texts("Reduce motion", "", "On" if Game.reduce_motion else "Off")
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


func _refresh_update() -> void:
	if _upd_card == null:
		return
	var show := Updater.has_update()
	_upd_card.visible = show
	if not show:
		return
	_upd_title.text = "Version %s is ready" % Updater.latest_version
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


func _on_backup() -> void:
	Kit.tick()
	Game.save_game()
	var code := Game.backup_code()
	DisplayServer.clipboard_set(code)
	Kit.haptic("success")
	Kit.sheet("Backup copied", "Your progress is now a code on the clipboard (%s).\n\nPaste it into Notes or Keep so it's safe." % GameLog.bytes(code.length()), [
		{"text": "Done", "style": "primary"},
	])


func _on_restore() -> void:
	Kit.tick()
	var code := DisplayServer.clipboard_get().strip_edges()
	if not code.begins_with(Game.BACKUP_PREFIX):
		Kit.haptic("error")
		Kit.sheet("No backup code found", "Copy your backup code first (it starts with SOL1), then tap Restore again.", [
			{"text": "OK", "style": "primary"},
		])
		return
	Kit.alert("Restore this backup?", "Your current progress will be replaced by the backup.", [
		{"text": "Cancel", "style": "secondary"},
		{"text": "Restore", "style": "primary", "call": func():
			if Game.restore_code(code):
				Kit.haptic("success")
				Kit.toast("Progress restored", true)
			else:
				Kit.haptic("error")
				Kit.toast("That code didn't work")},
	])
