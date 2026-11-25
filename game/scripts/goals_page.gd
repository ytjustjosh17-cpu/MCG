class_name GoalsPage
extends Page
## Today's and this week's goals. The reward shows once, in each header.

var _day_title: Label
var _day_note: Label
var _week_title: Label
var _week_note: Label
var _day_box: VBoxContainer
var _week_box: VBoxContainer
var _sig := ""


func _init() -> void:
	super("Goals", true)


func build() -> void:
	_day_note = section("Today")
	_day_title = _day_note.get_parent().get_child(0)
	_day_box = card()
	_week_note = section("This week")
	_week_title = _week_note.get_parent().get_child(0)
	_week_box = card()


func refresh() -> void:
	if _day_box == null:
		return
	var left := 86400.0 - fmod(Game.now(), 86400.0)
	_day_note.text = ("Day %d streak · " % Game.streak if Game.streak > 1 else "") + "Resets " + Game.clock(left)
	_week_note.text = "Resets " + Game.clock(Game.week_left())
	_day_title.text = "Today · +%s each" % Game.money_short(Game.daily_reward())
	_week_title.text = "This week · +%s each" % Game.money_short(Game.weekly_reward())
	# Rebuild rows only when something changed, so the page doesn't flicker.
	var sig := str(Game.daily_tasks()) + str(Game.weekly_tasks())
	if sig == _sig:
		return
	_sig = sig
	_fill(_day_box, Game.daily_tasks())
	_fill(_week_box, Game.weekly_tasks())


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
		m.custom_minimum_size = Vector2(0, 56)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		m.add_child(h)
		var ic := Icon.new("check", UI.TEXT, 22.0)
		ic.set_style(UI.TEXT, true)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l := UI.label("All done", 17, UI.TEXT, true)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		box.add_child(m)
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
		custom_minimum_size = Vector2(0, 64)
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
		ic.position = Vector2(16, 14)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		var l := UI.label(String(t["text"]), 15, UI.TEXT if not done else UI.SUB)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.position = Vector2(52, 12)
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
			cnt.size = Vector2(96, 20)
			cnt.position = Vector2(right - 96, 14)
			l.size = Vector2(maxf(0.0, right - 96 - 8 - 52), 22)
			if chev:
				chev.position = Vector2(size.x - 14 - 16, (size.y - 16.0) * 0.5)
			queue_redraw())

	static func _n(v: float, money: bool) -> String:
		return Game.money_short(v) if money else Game.group(int(v))

	func _draw() -> void:
		var g := float(t["goal"])
		var p := clampf(float(t["progress"]) / g, 0.0, 1.0) if g > 0.0 else 1.0
		var x0 := 52.0
		var x1 := size.x - (38.0 if not t["done"] else 16.0)
		var y := size.y - 16.0
		draw_line(Vector2(x0, y), Vector2(x1, y), UI.TRACK, 4.0, true)
		if p > 0.0:
			draw_line(Vector2(x0, y), Vector2(x0 + (x1 - x0) * p, y), UI.TEXT, 4.0, true)
