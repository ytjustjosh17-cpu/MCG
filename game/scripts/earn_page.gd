class_name EarnPage
extends Control
## The Earn tab: net worth, stats, "Ready now" list and the tower tap card.

signal open_tab(index: int)

const MIN_H := 800.0
const CARD_H := 216.0
const NAV_SPACE := 92.0

var _scroll: ScrollContainer
var _canvas: Control
var _level_pill: Label
var _level_meter: Array = []
var _value: CountLabel
var _change_icon: Icon
var _change: Label
var _chart: NetChart
var _stat_cash: Label
var _stat_hour: Label
var _stat_comp: Label
var _away: Label
var _row_level_value: Label
var _row_level_mark: ColorRect
var _row_boost_value: Label
var _row_boost_mark: ColorRect
var _card: TowerCard
var _per_tap: Label
var _level_btn: Button
var _boost_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_canvas)
	_build()
	resized.connect(_layout)
	Game.changed.connect(_refresh)
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)
	_layout()
	_refresh()


func _build() -> void:
	# Top bar: level pill + more.
	var pill := UI.panel(UI.PANEL, 22)
	pill.name = "LevelPill"
	_canvas.add_child(pill)
	_level_pill = UI.label("Level 1", 17)
	UI.place(_level_pill, 16, 11)
	pill.add_child(_level_pill)
	for i in range(5):
		var sq := ColorRect.new()
		sq.size = Vector2(5, 10)
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(sq)
		_level_meter.append(sq)
	var more := UI.pill("", UI.PANEL, UI.TEXT, 17, 22)
	Kit.press_fx(more)
	more.name = "More"
	more.tooltip_text = "Profile"
	var dots := Icon.new("dots", UI.TEXT, 22.0)
	dots.position = Vector2(11, 11)
	more.add_child(dots)
	more.pressed.connect(func(): open_tab.emit(4))
	_canvas.add_child(more)

	# Title and net worth.
	_canvas.add_child(UI.place(UI.label("Net worth", 34, UI.TEXT, true), 20, 52))
	_value = CountLabel.new(Game.money)
	_value.add_theme_font_size_override("font_size", 34)
	_value.add_theme_color_override("font_color", UI.TEXT)
	_value.add_theme_font_override("font", UI.REG)
	_value.set_value(Game.net_worth(), true)
	_canvas.add_child(UI.place(_value, 20, 92))
	_change_icon = Icon.new("up", UI.TEXT, 10.0)
	_canvas.add_child(UI.place(_change_icon, 20, 141))
	_change = UI.label("", 13, UI.TEXT)
	_canvas.add_child(UI.place(_change, 34, 136))

	_chart = NetChart.new()
	_canvas.add_child(_chart)

	# Stats panel.
	var stats := UI.panel(UI.PANEL, 16)
	stats.name = "Stats"
	_canvas.add_child(stats)
	var cols := [["Cash"], ["Business / hr"], ["Companies"]]
	var vals: Array = []
	for i in range(3):
		var v := UI.label("", 17, UI.TEXT, true)
		var k := UI.label(cols[i][0], 13, UI.SUB)
		v.name = "V%d" % i
		k.name = "K%d" % i
		stats.add_child(v)
		stats.add_child(k)
		vals.append(v)
		if i > 0:
			var sep := ColorRect.new()
			sep.name = "S%d" % i
			sep.color = UI.RAISED
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats.add_child(sep)
	_stat_cash = vals[0]
	_stat_hour = vals[1]
	_stat_comp = vals[2]

	# Ready now.
	_canvas.add_child(UI.place(UI.label("Ready now", 17, UI.TEXT, true), 20, 314))
	_away = UI.label("", 13, UI.SUB)
	_away.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_away.name = "Away"
	_canvas.add_child(_away)
	var list := UI.panel(UI.PANEL, 16)
	list.name = "List"
	list.clip_contents = true
	_canvas.add_child(list)
	var r1 := _row(list, 0, "level", "Level up")
	_row_level_value = r1[0]
	_row_level_mark = r1[1]
	r1[2].pressed.connect(_on_level_up)
	var r2 := _row(list, 1, "bolt", "Boost ×3")
	_row_boost_value = r2[0]
	_row_boost_mark = r2[1]
	r2[2].pressed.connect(_on_boost)
	var r3 := _row(list, 2, "business", "Start a business")
	r3[0].text = "Next update"
	r3[1].visible = false
	r3[2].pressed.connect(func(): open_tab.emit(1))

	# Tap card.
	_card = TowerCard.new()
	_card.name = "TowerCard"
	_canvas.add_child(_card)
	_card.add_child(UI.place(UI.label("Tap your tower", 13, UI.SUB), 16, 16))
	_per_tap = UI.label("", 22, UI.TEXT, true)
	_card.add_child(UI.place(_per_tap, 16, 34))
	_level_btn = UI.pill("Level up", UI.TEXT, UI.INK, 17, 22)
	_level_btn.pressed.connect(_on_level_up)
	Kit.press_fx(_level_btn)
	_card.add_child(_level_btn)
	_boost_btn = UI.pill("Boost ×3", UI.PANEL, UI.TEXT, 17, 22)
	_boost_btn.pressed.connect(_on_boost)
	Kit.press_fx(_boost_btn)
	_boost_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boost_btn.add_theme_constant_override("h_separation", 0)
	var bolt := Icon.new("bolt", UI.RED, 14.0)
	bolt.name = "Bolt"
	_boost_btn.add_child(bolt)
	_card.add_child(_boost_btn)


func _row(list: Panel, i: int, icon: String, title: String) -> Array:
	var b := UI.flat_button()
	b.position = Vector2(0, i * 48.5)
	b.custom_minimum_size = Vector2(0, 48)
	b.name = "Row%d" % i
	list.add_child(b)
	b.add_child(UI.place(Icon.new(icon, UI.TEXT, 22.0), 16, 13))
	b.add_child(UI.place(UI.label(title, 17), 50, 13))
	var mark := ColorRect.new()
	mark.color = UI.RED
	mark.size = Vector2(8, 8)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.name = "Mark"
	b.add_child(mark)
	var value := UI.label("", 17, UI.SUB)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.name = "Value"
	b.add_child(value)
	var chev := Icon.new("chevron", UI.DIM, 16.0)
	chev.name = "Chevron"
	b.add_child(chev)
	if i > 0:
		var sep := ColorRect.new()
		sep.color = UI.RAISED
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sep.name = "Sep"
		b.add_child(sep)
	return [value, mark, b]


func _layout() -> void:
	var w := size.x
	var h := maxf(size.y, MIN_H)
	_canvas.custom_minimum_size = Vector2(w, h)
	_canvas.size = Vector2(w, h)

	var pill: Panel = _canvas.get_node("LevelPill")
	var more: Button = _canvas.get_node("More")
	more.size = Vector2(44, 44)
	more.position = Vector2(w - 16 - 44, 4)
	pill.size = Vector2(128, 44)
	pill.position = Vector2(more.position.x - 8 - 128, 4)
	for i in range(5):
		_level_meter[i].position = Vector2(84 + i * 7, 17)

	_chart.position = Vector2(20, 160)
	_chart.size = Vector2(w - 40, 64)

	var stats: Panel = _canvas.get_node("Stats")
	stats.position = Vector2(16, 236)
	stats.size = Vector2(w - 32, 64)
	var cw := (w - 32) / 3.0
	for i in range(3):
		stats.get_node("V%d" % i).position = Vector2(i * cw + 16, 10)
		stats.get_node("K%d" % i).position = Vector2(i * cw + 16, 34)
		if i > 0:
			var sep: ColorRect = stats.get_node("S%d" % i)
			sep.position = Vector2(i * cw, 0)
			sep.size = Vector2(1, 64)

	_away.position = Vector2(w - 20 - 220, 318)
	_away.size = Vector2(220, 20)
	var list: Panel = _canvas.get_node("List")
	list.position = Vector2(16, 342)
	list.size = Vector2(w - 32, 146)
	for i in range(3):
		var b: Button = list.get_node("Row%d" % i)
		b.size = Vector2(w - 32, 48)
		b.get_node("Chevron").position = Vector2(w - 32 - 16 - 16, 16)
		var v: Label = b.get_node("Value")
		v.size = Vector2(160, 24)
		v.position = Vector2(w - 32 - 40 - 160, 12)
		if b.has_node("Sep"):
			var sep: ColorRect = b.get_node("Sep")
			sep.position = Vector2(50, -1)
			sep.size = Vector2(w - 32 - 50, 1)

	_card.position = Vector2(16, h - NAV_SPACE - CARD_H)
	_card.size = Vector2(w - 32, CARD_H)
	_level_btn.position = Vector2(16, CARD_H - 16 - 44 - 8 - 44)
	_level_btn.size = Vector2(0, 44)
	_boost_btn.position = Vector2(16, CARD_H - 16 - 44)
	_boost_btn.size = Vector2(0, 44)
	_refresh()


func _refresh() -> void:
	if _value == null:
		return
	_level_pill.text = "Level %d" % Game.level
	var prog := Game.level_progress()
	for i in range(5):
		_level_meter[i].color = UI.RED if prog >= (i + 1) / 5.0 - 0.001 else UI.TRACK
	_value.set_value(Game.net_worth())

	var wc := Game.week_change()
	if wc.is_empty() or absf(wc[1] - wc[0]) < 0.005:
		_change_icon.visible = false
		_change.position.x = 20
		_change.text = "Tap your tower to start earning" if Game.taps == 0 else "No change yet this week"
		_change.add_theme_color_override("font_color", UI.SUB)
	else:
		var diff: float = wc[1] - wc[0]
		var pct := diff / maxf(absf(wc[0]), 1.0) * 100.0
		var up := diff >= 0.0
		_change_icon.visible = true
		_change_icon.kind = "up" if up else "down"
		_change_icon.set_style(UI.TEXT if up else UI.SUB)
		_change.position.x = 34
		if absf(wc[0]) < 100.0:
			_change.text = "%s%s past week" % ["+" if up else "−", Game.money(absf(diff))]
		else:
			_change.text = "%s%s (%s%.1f%%) past week" % ["+" if up else "−", Game.money(absf(diff)), "+" if up else "−", absf(pct)]
		_change.add_theme_color_override("font_color", UI.TEXT if up else UI.SUB)
	_chart.queue_redraw()

	_stat_cash.text = Game.money(Game.cash)
	_stat_hour.text = Game.money_short(Game.income_per_hour)
	_stat_comp.text = "%d / 10" % Game.companies()
	_away.text = ("Earned while away +" + Game.money_short(Game.away_earned)) if Game.away_earned > 0.0 else ""

	var cost := Game.level_cost()
	var can := Game.can_level_up()
	_row_level_mark.visible = can
	_row_level_value.text = "Ready" if can else Game.money_short(cost - Game.cash) + " to go"
	_row_level_value.add_theme_color_override("font_color", UI.TEXT if can else UI.SUB)
	_row_level_mark.position = Vector2(_row_level_value.position.x + 160 - _row_level_value.get_minimum_size().x - 14, 20)

	_per_tap.text = Game.money(Game.tap_value() * (Game.BOOST_MULT if Game.boost_active() else 1.0)) + " per tap"
	_level_btn.text = "Level up  " + (Game.money(cost) if cost < 1e6 else Game.money_short(cost))
	_level_btn.disabled = not can
	if can:
		UI.paint(_level_btn, UI.TEXT, UI.INK)
	else:
		UI.paint(_level_btn, UI.RAISED, UI.SUB)
	_tick()


func _tick() -> void:
	if _boost_btn == null:
		return
	var bolt: Icon = _boost_btn.get_node("Bolt")
	if Game.boost_active():
		_boost_btn.text = "      On · " + Game.clock(Game.boost_left())
		_boost_btn.disabled = true
		UI.paint(_boost_btn, UI.PANEL, UI.TEXT)
		_row_boost_value.text = "On · " + Game.clock(Game.boost_left())
		_row_boost_mark.visible = false
	elif Game.boost_ready():
		_boost_btn.text = "      Boost ×3"
		_boost_btn.disabled = false
		UI.paint(_boost_btn, UI.PANEL, UI.TEXT)
		_row_boost_value.text = "Ready"
		_row_boost_mark.visible = true
	else:
		_boost_btn.text = "      " + Game.clock(Game.boost_cooldown_left())
		_boost_btn.disabled = true
		UI.paint(_boost_btn, UI.PANEL, UI.SUB)
		_row_boost_value.text = "In " + Game.clock(Game.boost_cooldown_left())
		_row_boost_mark.visible = false
	_row_boost_value.add_theme_color_override("font_color", UI.TEXT if _row_boost_mark.visible else UI.SUB)
	_row_boost_mark.position = Vector2(_row_boost_value.position.x + 160 - _row_boost_value.get_minimum_size().x - 14, 20)
	bolt.position = Vector2(16, 15)
	_boost_btn.size = Vector2(0, 44)
	_card.queue_redraw()


func _on_level_up() -> void:
	if Game.level_up():
		Kit.tick(30)
		Kit.toast("Level %d · %s per tap" % [Game.level, Game.money(Game.tap_value())], true)
		Game.flush_changes()
	else:
		Kit.toast(Game.money(Game.level_cost() - Game.cash) + " more to level up")


func _on_boost() -> void:
	if Game.start_boost():
		Kit.tick(20)
		Kit.toast("Boost on · ×3 for 60 seconds", true)
	else:
		Kit.toast("Boost ready in " + Game.clock(Game.boost_cooldown_left()))
	_tick()
