class_name GoalsPage
extends Page
## Today's and this week's goals. The reward shows once, in each header.

var _day_title: Label
var _day_note: Label
var _week_title: Label
var _week_note: Label
var _day_box: VBoxContainer
var _week_box: VBoxContainer
var _day_chip: PanelContainer
var _day_chip_l: Label
var _day_done: Label
var _week_done: Label
var _sig := ""
var _season_bar: SeasonBar
var _season_title: Label
var _season_note: Label


func _init() -> void:
	super("Goals", true)


func build() -> void:
	# The weekly season bar first: goals, golden suns and the day's first tap fill it.
	var sc := card()
	var sp := padded(sc, 16, 6)
	var sh := HBoxContainer.new()
	sp.add_child(sh)
	_season_title = UI.label("Season", 17, UI.TEXT, true)
	_season_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(_season_title)
	_season_note = UI.label("", 13, UI.SUB)
	_season_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(_season_note)
	_season_bar = SeasonBar.new()
	sp.add_child(_season_bar)
	var hint := UI.label("Goals, golden suns and each day's first tap add points.", 13, UI.SUB)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sp.add_child(hint)
	# Finished goals, season rewards, day milestones and the daily gift wait here for a tap.
	body.add_child(ClaimList.new(["goal", "streak", "season", "days", "term"]))   # ended bank terms too, so none are missed
	var d := _header()
	_day_title = d[0]
	_day_note = d[1]
	_day_chip = d[2]
	_day_chip_l = d[3]
	_day_box = card()
	var w := _header()
	_week_title = w[0]
	_week_note = w[1]
	_week_box = card()


func _header() -> Array:
	## Section title with a small line under it (reward once, then when it resets).
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	body.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := UI.label("", 17, UI.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	# Small right-aligned chip (used for the streak); hidden until it has text.
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 12))
	chip.visible = false
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_left", 10)
	cm.add_theme_constant_override("margin_right", 10)
	chip.add_child(cm)
	var cl := UI.label("", 13, UI.TEXT)
	cm.add_child(cl)
	top.add_child(chip)
	var n := UI.label("", 13, UI.SUB)
	v.add_child(n)
	return [t, n, chip, cl]


func refresh() -> void:
	if _day_box == null:
		return
	_season_title.text = "Season · %d pts" % int(Game.season_pts())
	_season_note.text = "Resets in " + Game.clock(Game.season_week_left_s())
	_season_bar.refresh()
	var left := 86400.0 - fmod(Game.now(), 86400.0)
	_day_note.text = "Resets " + Game.clock(left)
	_day_chip.visible = Game.streak > 1
	_day_chip_l.text = "Day %d streak" % Game.streak
	_week_note.text = "Resets " + Game.clock(Game.week_left())
	_day_title.text = "Today · +%s each" % Game.money_short(Game.daily_reward())
	refresh_done_text()
	_week_title.text = "This week · +%s each" % Game.money_short(Game.weekly_reward())
	# Rebuild rows only when something changed, so the page doesn't flicker.
	var sig := str(Game.daily_tasks()) + str(Game.weekly_tasks())
	if sig == _sig:
		return
	_sig = sig
	_fill(_day_box, Game.daily_tasks())
	_fill(_week_box, Game.weekly_tasks())


func refresh_done_text() -> void:
	if is_instance_valid(_day_done):
		_day_done.text = "All done. New goals in %s." % Game.clock(86400.0 - fmod(Game.now(), 86400.0))
	if is_instance_valid(_week_done):
		_week_done.text = "All done. New goals in %s." % Game.clock(Game.week_left())


func _fill(box: VBoxContainer, tasks: Array) -> void:
	for ch in box.get_children():
		ch.queue_free()
	var all_done := true
	for t in tasks:
		if not t["done"]:
			all_done = false
	if all_done and not tasks.is_empty():
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.add_theme_constant_override("margin_right", 16)
		m.custom_minimum_size = Vector2(0, UI.ROW_H)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		m.add_child(h)
		var ic := Icon.new("check", UI.TEXT, 22.0)
		ic.set_style(UI.TEXT, true)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l := UI.label("", 15, UI.TEXT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(l)
		if box == _day_box:
			_day_done = l
		else:
			_week_done = l
		box.add_child(m)
		refresh_done_text()
		return
	for i in range(tasks.size()):
		if i > 0:
			separator(box, 52)
		box.add_child(GoalRow.new(tasks[i]))


class GoalRow extends Button:
	## Tap a goal to go where you can work on it.
	const TAB := {"taps": 0, "earn": 0, "units": 1, "expand": 1, "deal": 1, "invest": 2}
	var t: Dictionary

	func _init(task: Dictionary) -> void:
		t = task
		custom_minimum_size = Vector2(0, 56 if t["done"] else 64)
		focus_mode = Control.FOCUS_NONE
		flat = true
		for st in ["normal", "hover", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		add_theme_stylebox_override("pressed", UI.box(Color(UI.TEXT, 0.05), 0))
		pressed.connect(func():
			if t["done"]:
				return
			var main := get_tree().root.get_node_or_null("Main")
			if main and main.has_method("show_page"):
				Kit.tick()
				main.show_page(int(TAB.get(String(t["id"]), 0))))
		var done: bool = t["done"]
		var ic := Icon.new("check" if done else "goal", UI.TEXT if done else UI.SUB, 22.0)
		ic.set_style(UI.TEXT if done else UI.SUB, done)
		ic.position = Vector2(16, 17 if done else 14)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		var l := UI.label(String(t["text"]), 15, UI.TEXT if not done else UI.SUB)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.position = Vector2(52, 17 if done else 12)
		add_child(l)
		var g := float(t["goal"])
		var p := minf(float(t["progress"]), g)
		var money: bool = t.get("money", false)
		var cnt := UI.label("Done" if done else "%s/%s" % [_n(p, money), _n(g, money)], 13, UI.SUB)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.name = "Count"
		add_child(cnt)
		var chev: Icon = null
		if not done:
			chev = Icon.new("chevron", UI.DIM, 16.0)
			add_child(chev)
		resized.connect(func():
			var right := size.x - (38.0 if chev else 16.0)
			var cw := cnt.get_minimum_size().x + 2.0
			cnt.size = Vector2(cw, 20)
			cnt.position = Vector2(right - cw, 17 if done else 14)
			l.size = Vector2(maxf(0.0, right - cw - 12 - 52), 22)
			if chev:
				chev.position = Vector2(size.x - 14 - 16, 16.0)   # level with the count, not between the title and the bar
			queue_redraw())

	static func _n(v: float, money: bool) -> String:
		return Game.money_short(v) if money else Game.group(int(v))

	func _draw() -> void:
		var g := float(t["goal"])
		var p := clampf(float(t["progress"]) / g, 0.0, 1.0) if g > 0.0 else 1.0
		var x0 := 52.0
		var x1 := size.x - 16.0   # one right edge on every row
		var y := size.y - 16.0
		if t["done"]:
			return   # a finished goal has no bar
		draw_line(Vector2(x0, y), Vector2(x1, y), UI.TRACK, 4.0, true)
		if p > 0.0:
			draw_line(Vector2(x0, y), Vector2(x0 + (x1 - x0) * p, y), UI.TEXT, 4.0, true)
