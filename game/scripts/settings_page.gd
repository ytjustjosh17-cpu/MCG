class_name SettingsPage
extends Page
## Settings, pushed from Profile: feel, pop-ups, updates, help, backup and reset.

const VOLUMES := [[0.0, "Off"], [0.25, "Low"], [0.5, "Medium"], [1.0, "High"]]
const FORMATS := [["short", "Short"], ["sci", "Scientific"]]

var _vib: Switch
var _motion: Switch
var _news: Switch
var _awake: Switch
var _sound_row: Row
var _num_row: Row
var _upd_row: Row
var _report_row: Row
var _checking := false
var _storage := ""


func _init() -> void:
	super("Settings", true)


func build() -> void:
	# On/off settings use switches; rows with a chevron open a choice.
	var st := card()
	_sound_row = _row(st, "sound", true)
	_sound_row.pressed.connect(_on_sound)
	separator(st, 50)
	_num_row = _row(st, "hash", true)
	_num_row.pressed.connect(_on_numbers)
	separator(st, 50)
	_vib = _switch_row(st, "vibrate", "Vibration", Game.vibrate, func(on: bool):
		Game.vibrate = on)
	separator(st, 50)
	_motion = _switch_row(st, "sparkle", "Less motion", Game.reduce_motion, func(on: bool):
		Game.reduce_motion = on)
	separator(st, 50)
	# Deals never pop up (they wait on Business); only news can.
	_news = _switch_row(st, "news", "News pop-ups", not bool(Game.ui.get("news_quiet", false)), func(on: bool):
		Game.ui["news_quiet"] = not on)
	separator(st, 50)
	_awake = _switch_row(st, "clock", "Keep screen on", bool(Game.ui.get("keep_awake", false)), func(on: bool):
		Game.ui["keep_awake"] = on
		DisplayServer.screen_set_keep_on(on))

	var hc := card()
	_upd_row = _row(hc, "update", false)
	_upd_row.pressed.connect(_check_updates)
	separator(hc, 50)
	_report_row = _row(hc, "bug", false)
	_report_row.pressed.connect(_on_report)
	separator(hc, 50)
	var bk := _row(hc, "copy", true)
	bk.set_texts("Backup")
	bk.pressed.connect(_on_backup_menu)
	separator(hc, 50)
	var gd := _row(hc, "info", false)
	gd.set_texts("Replay guide")
	gd.pressed.connect(func():
		Kit.tick()
		Guide.replay()
		# Back to Earn, where the guide starts.
		var m: Node = self
		while m != null and m.get("_pages") == null:
			m = m.get_parent()
		if m != null:
			m.show_page(0)
			Guide.maybe_start(m))
	_storage = GameLog.bytes(GameLog.storage_used())
	Updater.state_changed.connect(_on_update_state)
	Updater.check_finished.connect(_on_check_finished)

	# Reset: a quiet row of its own, with a confirm. Never next to the rest.
	var rc := card()
	var reset := _row(rc, "trash", false)
	reset.set_texts("Reset game")
	reset.title_l.add_theme_color_override("font_color", UI.DOWN)
	(reset.lead as Icon).set_style(UI.DOWN)
	reset.pressed.connect(_on_reset)


func _row(parent: Control, icon: String, chevron: bool) -> Row:
	var r := Row.new(icon, "", chevron)
	parent.add_child(r)
	return r


func _switch_row(parent: Control, icon: String, title: String, start: bool, apply: Callable) -> Switch:
	## A row with a switch at the end; a tap anywhere on the row (switch
	## included) flips it.
	var r := _row(parent, icon, false)
	r.set_texts(title)
	var sw := Switch.new(start)   # built in its real state: no slide on open
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r._h.add_child(sw)
	# The row takes the tap (Kit lets button presses pass to parents, so a
	# live switch inside a live row would flip twice).
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.pressed.connect(func():
		sw.set_on(not sw.on)
		Kit.haptic("selection")
		apply.call(sw.on)
		Game.save_game())
	return sw


func refresh() -> void:
	if _vib == null:
		return
	_sound_row.set_texts("Sound", "", _vol_label())
	_num_row.set_texts("Numbers", "", "Scientific" if Game.sci else "Short")
	_sync(_vib, Game.vibrate)
	_sync(_motion, Game.reduce_motion)
	_sync(_news, not bool(Game.ui.get("news_quiet", false)))
	_sync(_awake, bool(Game.ui.get("keep_awake", false)))
	_upd_row.set_texts("Updates", "", "Update ready" if Updater.has_update() else "Up to date")
	_report_row.set_texts("Report a problem", "", _storage)


static func _sync(sw: Switch, v: bool) -> void:
	if sw.on != v:
		sw.set_on(v)


static func _vol_label() -> String:
	var v := float(Game.ui.get("vol", 0.5))
	var best: Array = VOLUMES[0]
	for o in VOLUMES:
		if absf(float(o[0]) - v) < absf(float(best[0]) - v):
			best = o
	return best[1]


func _on_sound() -> void:
	Kit.tick()
	var cur := 0
	for i in range(VOLUMES.size()):
		if VOLUMES[i][1] == _vol_label():
			cur = i
	_seg_sheet("Sound", VOLUMES, cur, func(v):
		Game.ui["vol"] = float(v)
		Kit.sound("buy"))


func _on_numbers() -> void:
	Kit.tick()
	_seg_sheet("Numbers", FORMATS, 1 if Game.sci else 0, func(v):
		Game.sci = v == "sci"
		Game.ui["sci"] = Game.sci
		Game.flush_changes())


func _seg_sheet(title: String, options: Array, cur: int, apply: Callable) -> void:
	## A short choice (2 to 4 options) as one segmented control; it applies
	## at once, so the sheet only needs Done.
	var labels: Array = []
	for o in options:
		labels.append(String(o[1]))
	var seg := Segmented.new(labels)
	seg.select(cur)
	seg.changed.connect(func(i: int):
		apply.call(options[i][0])
		Game.save_game()
		refresh())
	Kit.sheet(title, "", [{"text": "Done", "style": "primary"}], true, seg)


func _on_update_state() -> void:
	if is_inside_tree():
		refresh()


func _on_check_finished(found: bool) -> void:
	if _checking and not found:
		Kit.toast("Up to date")
	_checking = false
	if is_inside_tree():
		refresh()


func _check_updates() -> void:
	Kit.tick()
	if not OS.has_feature("android"):
		Kit.toast("Updates are checked on your phone")
		return
	_checking = true
	Kit.toast("Checking…")
	Updater.check(true)


func _on_report() -> void:
	Kit.tick()
	GameLog.copy_report()
	_storage = GameLog.bytes(GameLog.storage_used())
	Kit.sheet("Report a problem", "Copied. Open Claude, paste it, say what went wrong.", [
		{"text": "Done", "style": "primary"},
	])
	refresh()


func _on_backup_menu() -> void:
	Kit.tick()
	Kit.pick("Backup", [["copy", "Copy code"], ["paste", "Paste code"]], "", func(v):
		if v == "copy":
			_on_backup()
		else:
			_on_restore(), "Your whole game in one code.")


func _on_backup() -> void:
	Game.save_game()
	DisplayServer.clipboard_set(Game.backup_code())
	Kit.haptic("success")
	Kit.sheet("Backup", "Copied. Paste it into Notes to keep it safe.", [
		{"text": "Done", "style": "primary"},
	])


func _on_restore() -> void:
	var code := DisplayServer.clipboard_get().strip_edges()
	if not code.begins_with(Game.BACKUP_PREFIX):
		Kit.haptic("error")
		Kit.sheet("No code found", "Copy your code first. It starts with SOL1.", [
			{"text": "OK", "style": "primary"},
		])
		return
	Kit.alert("Restore?", "Replaces your progress.", [
		{"text": "Cancel", "style": "secondary"},
		{"text": "Restore", "style": "primary", "call": func():
			if Game.restore_code(code):
				Kit.haptic("success")
				Kit.toast("Progress restored", true)
			else:
				Kit.haptic("error")
				Kit.toast(Game.restore_error if Game.restore_error != "" else "That code didn't work")},
	])


func _on_reset() -> void:
	Kit.alert("Reset?", "Deletes all progress. Can't undo.", [
		{"text": "Keep", "style": "primary"},
		{"text": "Reset", "style": "secondary", "call": func():
			Game.reset_game()
			Kit.toast("Fresh start")},
	])
