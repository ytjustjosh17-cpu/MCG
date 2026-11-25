class_name SettingsPage
extends Page
## Settings, pushed from Profile: feel, pop-ups, updates, help, backup and reset.

const POPUPS := [["all", "All"], ["deals", "Deals only"], ["none", "None"]]

var _vib_row: Row
var _motion_row: Row
var _pop_row: Row
var _awake_row: Row
var _upd_row: Row
var _report_row: Row
var _checking := false
var _storage := ""


func _init() -> void:
	super("Settings", true)


func build() -> void:
	var st := card()
	_vib_row = _row(st, "vibrate", false)
	_vib_row.pressed.connect(func():
		Game.vibrate = not Game.vibrate
		Kit.tick()
		Game.save_game()
		refresh())
	separator(st, 50)
	_motion_row = _row(st, "sparkle", false)
	_motion_row.pressed.connect(func():
		Game.reduce_motion = not Game.reduce_motion
		Kit.tick()
		Game.save_game()
		refresh())
	separator(st, 50)
	_pop_row = _row(st, "news", true)
	_pop_row.pressed.connect(_on_popups)
	separator(st, 50)
	_awake_row = _row(st, "clock", false)
	_awake_row.pressed.connect(func():
		Game.ui["keep_awake"] = not bool(Game.ui.get("keep_awake", false))
		Kit.tick()
		DisplayServer.screen_set_keep_on(bool(Game.ui["keep_awake"]))
		Game.save_game()
		refresh())

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
	_storage = GameLog.bytes(GameLog.storage_used())
	Updater.state_changed.connect(_on_update_state)
	Updater.check_finished.connect(_on_check_finished)

	var reset := UI.flat_button()
	reset.text = "Reset"
	reset.custom_minimum_size = Vector2(0, 48)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		reset.add_theme_color_override(k, UI.DOWN)
	reset.add_theme_font_size_override("font_size", 17)
	reset.pressed.connect(_on_reset)
	body.add_child(reset)


func _row(parent: Control, icon: String, chevron: bool) -> Row:
	var r := Row.new(icon, "", chevron)
	r.custom_minimum_size = Vector2(0, 52)
	parent.add_child(r)
	return r


func refresh() -> void:
	if _vib_row == null:
		return
	_vib_row.set_texts("Vibration", "", "On" if Game.vibrate else "Off")
	_motion_row.set_texts("Less motion", "", "On" if Game.reduce_motion else "Off")
	_pop_row.set_texts("Pop-ups", "", _popup_label(_popup_mode()))
	_awake_row.set_texts("Keep screen on", "", "On" if bool(Game.ui.get("keep_awake", false)) else "Off")
	_upd_row.set_texts("Updates", "", "Update ready" if Updater.has_update() else "Up to date")
	_report_row.set_texts("Report a problem", "", _storage)


static func _popup_mode() -> String:
	var deals_off := bool(Game.ui.get("deals_quiet", false))
	var news_off := bool(Game.ui.get("news_quiet", false))
	if not deals_off and not news_off:
		return "all"
	if not deals_off:
		return "deals"
	if news_off:
		return "none"
	return "news"  # older saves: deals off, news on


static func _popup_label(mode: String) -> String:
	for o in POPUPS:
		if o[0] == mode:
			return o[1]
	return "News only"


func _on_popups() -> void:
	Kit.tick()
	Kit.pick("Pop-ups", POPUPS, _popup_mode(), func(v):
		Game.ui["deals_quiet"] = v == "none"
		Game.ui["news_quiet"] = v != "all"
		Game.save_game()
		refresh())


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
			_on_restore())


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
				Kit.toast("That code didn't work")},
	])


func _on_reset() -> void:
	Kit.alert("Reset?", "Deletes all progress. Can't undo.", [
		{"text": "Keep", "style": "primary"},
		{"text": "Reset", "style": "secondary", "call": func():
			Game.reset_game()
			Kit.toast("Fresh start")},
	])
