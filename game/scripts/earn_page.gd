class_name EarnPage
extends Control
## Earn tab, tower first: net worth, the big tower to tap, and three icon buttons.

signal open_tab(index: int)
signal push_page(page: Control)

const NAV_SPACE := 92.0

var _worth: CountLabel
var _rate: Label
var _level_pill: Label
var _meter: Array = []
var _pill: Panel
var _tasks: IconButton
var _card: TowerCard
var _per_tap: Label
var _level_btn: IconButton
var _boost_btn: IconButton
var _goal: GoalCard


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_tasks = IconButton.new("list", 44.0)
	_tasks.custom_minimum_size = Vector2(44, 44)
	_tasks.fill = UI.PANEL
	_tasks.pressed.connect(_show_tasks)
	add_child(_tasks)

	_pill = UI.panel(UI.PANEL, 22)
	add_child(_pill)
	_level_pill = UI.label("", 15, UI.TEXT, true)
	_level_pill.position = Vector2(16, 12)
	_pill.add_child(_level_pill)
	for i in 5:
		var sq := ColorRect.new()
		sq.size = Vector2(5, 12)
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pill.add_child(sq)
		_meter.append(sq)

	_worth = CountLabel.new(Game.money_short)
	_worth.add_theme_font_size_override("font_size", 44)
	_worth.add_theme_font_override("font", UI.DISPLAY)
	_worth.add_theme_color_override("font_color", UI.TEXT)
	_worth.set_value(Game.net_worth(), true)
	add_child(_worth)
	_rate = UI.label("", 15, UI.SUB)
	add_child(_rate)

	_goal = GoalCard.new()
	_goal.pressed.connect(func():
		if not _goal.goal.is_empty():
			Kit.tick()
			open_tab.emit(int(_goal.goal["tab"])))
	add_child(_goal)

	_card = TowerCard.new()
	_card.name = "TowerCard"
	add_child(_card)
	_per_tap = UI.label("", 15, UI.TEXT, true)
	_per_tap.position = Vector2(18, 16)
	_card.add_child(_per_tap)
	_level_btn = IconButton.new("level", 64.0)
	_level_btn.custom_minimum_size = Vector2(80, 86)
	_level_btn.pressed.connect(_on_level_up)
	_card.add_child(_level_btn)
	_boost_btn = IconButton.new("bolt", 64.0)
	_boost_btn.custom_minimum_size = Vector2(80, 86)
	_boost_btn.pressed.connect(_on_boost)
	_card.add_child(_boost_btn)

	resized.connect(_layout)
	Game.changed.connect(_refresh)
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)
	_layout()
	_refresh()


func _layout() -> void:
	var w := size.x
	var h := size.y
	_tasks.position = Vector2(16, 4)
	_tasks.size = Vector2(44, 44)
	_pill.size = Vector2(112, 44)
	_pill.position = Vector2(w - 16 - 112, 4)
	for i in 5:
		_meter[i].position = Vector2(66 + i * 8, 16)
	_worth.position = Vector2(20, 58)
	_rate.position = Vector2(22, 112)
	_goal.position = Vector2(16, 140)
	_goal.size = Vector2(w - 32, 52)
	var top := 204.0 if _goal.visible else 148.0
	_card.position = Vector2(16, top)
	_card.size = Vector2(w - 32, maxf(260.0, h - NAV_SPACE - top))
	_level_btn.size = _level_btn.custom_minimum_size
	_boost_btn.size = _boost_btn.custom_minimum_size
	_level_btn.position = Vector2(10, _card.size.y - 100)
	_boost_btn.position = Vector2(96, _card.size.y - 100)
	_refresh()


func _refresh() -> void:
	if _worth == null:
		return
	_worth.set_value(Game.net_worth())
	_rate.text = ("+%s /h" % Game.money_short(Game.income_per_hour)) if Game.income_per_hour > 0.0 else ""
	_level_pill.text = "Lv %d" % Game.level
	var prog := Game.level_progress()
	for i in 5:
		_meter[i].color = UI.RED if prog >= (i + 1) / 5.0 - 0.001 else UI.TRACK
	var had := _goal.visible
	_goal.set_goal(Game.next_goal())
	if had != _goal.visible:
		_layout.call_deferred()
	_per_tap.text = Game.money_short(Game.tap_value() * (Game.BOOST_MULT if Game.boost_active() else 1.0)) + " /tap"
	var maxed := Game.level >= Data.MAX_LEVEL
	var can := Game.can_level_up()
	_level_btn.set_state(UI.TEXT if can else UI.SUB, prog if not maxed else 1.0, can, "MAX" if maxed else Game.money_short(Game.level_cost()))
	_tasks.set_state(UI.TEXT, -1.0, Game.goals_open() > 0 and Game.taps > 0)
	_tick()


func _tick() -> void:
	if _boost_btn == null:
		return
	if Game.boost_active():
		_boost_btn.set_state(UI.RED, Game.boost_left() / Game.BOOST_LEN_S, false, Game.clock(Game.boost_left()))
	elif Game.boost_ready():
		_boost_btn.set_state(UI.TEXT, 1.0, true, "×3")
	else:
		var total := Game.BOOST_COOLDOWN_S
		_boost_btn.set_state(UI.SUB, 1.0 - Game.boost_cooldown_left() / total, false, Game.clock(Game.boost_cooldown_left()))
	_card.queue_redraw()


func _show_tasks() -> void:
	Kit.tick()
	push_page.emit(GoalsPage.new())


func _on_level_up() -> void:
	if Game.level_up():
		Kit.haptic("success")
		Motion.pop(_pill, 1.12)
		_card.celebrate()
		Kit.toast("Level %d · %s /tap" % [Game.level, Game.money_short(Game.tap_value())], true)
		Game.flush_changes()
	elif Game.level < Data.MAX_LEVEL:
		Motion.shake(_level_btn)


func _on_boost() -> void:
	if Game.start_boost():
		Kit.haptic("medium")
		Motion.pop(_boost_btn, 1.1)
	else:
		Motion.shake(_boost_btn)
	_tick()
