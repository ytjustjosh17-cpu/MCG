class_name GoalsPage
extends Page
## Today's and this week's goals, each with a progress line and its reward.

var _day_note: Label
var _week_note: Label
var _day_box: VBoxContainer
var _week_box: VBoxContainer
var _sig := ""


func _init() -> void:
	super("Goals", true)


func build() -> void:
	_day_note = section("Today")
	_day_box = card()
	_week_note = section("This week")
	_week_box = card()


func refresh() -> void:
	if _day_box == null:
		return
	var left := 86400.0 - fmod(Game.now(), 86400.0)
	_day_note.text = ("Day %d in a row · " % Game.streak if Game.streak > 1 else "") + "New in " + Game.clock(left)
	_week_note.text = "New in " + Game.clock(Game.week_left())
	# Rebuild rows only when something changed, so the page doesn't flicker.
	var sig := str(Game.daily_tasks()) + str(Game.weekly_tasks())
	if sig == _sig:
		return
	_sig = sig
	_fill(_day_box, Game.daily_tasks(), Game.daily_reward())
	var all_done := true
	for t in Game.daily_tasks():
		if not t["done"]:
			all_done = false
	if all_done:
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 16)
		m.custom_minimum_size = Vector2(0, 48)
		var l := UI.label("All done for today. Nice work.", 15, UI.UP)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.add_child(l)
		_day_box.add_child(m)
	_fill(_week_box, Game.weekly_tasks(), Game.weekly_reward())


func _fill(box: VBoxContainer, tasks: Array, reward: float) -> void:
	for ch in box.get_children():
		ch.queue_free()
	for i in range(tasks.size()):
		if i > 0:
			separator(box, 52)
		box.add_child(GoalRow.new(tasks[i], reward))


class GoalRow extends Button:
	## Tap a goal to go where you can work on it.
	const TAB := {"taps": 0, "earn": 0, "units": 1, "expand": 1, "deal": 1, "invest": 2}
	var t: Dictionary
	var reward := 0.0

	func _init(task: Dictionary, r: float) -> void:
		t = task
		reward = r
		custom_minimum_size = Vector2(0, 72)
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
		var ic := Icon.new("check" if done else "goal", UI.RED if done else UI.SUB, 22.0)
		ic.set_style(UI.RED if done else UI.SUB, done)
		ic.position = Vector2(16, 16)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		var l := UI.label(String(t["text"]), 15, UI.TEXT if not done else UI.SUB)
		l.position = Vector2(52, 12)
		add_child(l)
		var g := float(t["goal"])
		var p := minf(float(t["progress"]), g)
		var money: bool = t.get("money", false)
		var sub := "Done" if done else ("%s / %s" % [_n(p, money), _n(g, money)])
		var s := UI.label(sub, 13, UI.SUB)
		s.position = Vector2(52, 36)
		add_child(s)
		var rw := UI.label(("+" + Game.money_short(reward)) if not done else "", 15, UI.TEXT, true)
		rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rw.name = "Reward"
		add_child(rw)
		resized.connect(func():
			rw.size = Vector2(110, 22)
			rw.position = Vector2(size.x - 16 - 110, 12)
			queue_redraw())

	static func _n(v: float, money: bool) -> String:
		return Game.money_short(v) if money else Game.group(int(v))

	func _draw() -> void:
		var g := float(t["goal"])
		var p := clampf(float(t["progress"]) / g, 0.0, 1.0) if g > 0.0 else 1.0
		var x0 := 52.0
		var x1 := size.x - 16.0
		var y := size.y - 12.0
		draw_line(Vector2(x0, y), Vector2(x1, y), UI.TRACK, 4.0, true)
		if p > 0.0:
			draw_line(Vector2(x0, y), Vector2(x0 + (x1 - x0) * p, y), UI.RED if t["done"] else UI.TEXT, 4.0, true)
