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
var _buff: Label
var _level_btn: IconButton
var _boost_btn: IconButton
var _auto_btn: IconButton
var _auto_cap: Label
var _hint: Label
var _level_cap: Label
var _boost_cap: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_tasks = IconButton.new("list", 48.0)
	_tasks.custom_minimum_size = Vector2(48, 48)
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

	# Big number is cash to the penny; net worth sits on the line below.
	_worth = CountLabel.new(Game.cash_text)
	_worth.fit_width = 358.0
	_worth.add_theme_font_size_override("font_size", 44)
	_worth.add_theme_font_override("font", UI.DISPLAY)
	_worth.add_theme_color_override("font_color", UI.TEXT)
	_worth.set_value(Game.cash, true)
	add_child(_worth)
	_rate = UI.label("", 15, UI.SUB)
	add_child(_rate)


	_card = TowerCard.new()
	_card.name = "TowerCard"
	add_child(_card)
	_per_tap = UI.label("", 15, UI.TEXT, true)
	_per_tap.position = Vector2(18, 16)
	_card.add_child(_per_tap)
	# Golden sun buffs (Frenzy or Rush) with time left.
	_buff = UI.label("", 13, UI.TEXT, true)
	_buff.position = Vector2(18, 40)
	_buff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_buff)
	# First-time hint, gone after a few taps.
	_hint = UI.label("Tap the tower", 15, UI.TEXT, true)
	_hint.position = Vector2(18, 42)
	_card.add_child(_hint)
	_level_btn = IconButton.new("level", 64.0)
	_level_btn.custom_minimum_size = Vector2(80, 86)
	_level_btn.pressed.connect(_on_level_up)
	_level_btn.mouse_filter = Control.MOUSE_FILTER_STOP  # don't also count as a tower tap
	_card.add_child(_level_btn)
	_boost_btn = IconButton.new("bolt", 64.0)
	_boost_btn.custom_minimum_size = Vector2(80, 86)
	_boost_btn.pressed.connect(_on_boost)
	_boost_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_child(_boost_btn)
	_auto_btn = IconButton.new("cpu", 64.0)
	_auto_btn.custom_minimum_size = Vector2(80, 86)
	_auto_btn.pressed.connect(_on_auto)
	_auto_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_child(_auto_btn)
	_level_cap = _caption("Level up")
	_boost_cap = _caption("Boost")
	_auto_cap = _caption("Auto")
	Game.auto_tapped.connect(func(_n: int, _v: float):
		if is_visible_in_tree() and not Motion.reduced():
			Motion.pop(_auto_btn, 1.06))

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
	_tasks.size = Vector2(48, 48)
	_pill.size = Vector2(112, 48)
	_pill.position = Vector2(w - 16 - 112, 4)
	for i in 5:
		_meter[i].position = Vector2(66 + i * 8, 18)
	_worth.position = Vector2(20, 58)
	_rate.position = Vector2(22, 112)
	var top := 148.0
	_card.position = Vector2(16, top)
	_card.size = Vector2(w - 32, maxf(260.0, h - NAV_SPACE - top))
	_level_btn.size = _level_btn.custom_minimum_size
	_boost_btn.size = _boost_btn.custom_minimum_size
	_auto_btn.size = _auto_btn.custom_minimum_size
	_auto_btn.position = Vector2(182, _card.size.y - 118)
	_auto_cap.position = Vector2(182, _card.size.y - 32)
	_level_btn.position = Vector2(10, _card.size.y - 118)
	_boost_btn.position = Vector2(96, _card.size.y - 118)
	_level_cap.position = Vector2(10, _card.size.y - 32)
	_boost_cap.position = Vector2(96, _card.size.y - 32)
	_refresh()


func _caption(text: String) -> Label:
	var l := UI.label(text, 13, UI.SUB)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(80, 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(l)
	return l


func _refresh() -> void:
	if _worth == null:
		return
	_worth.set_value(Game.cash)
	var parts: Array = []
	if Game.income_per_hour > 0.0:
		parts.append("+%s /h" % Game.money_short(Game.income_per_hour))
	parts.append("%s worth" % Game.money_short(Game.net_worth()))
	_rate.text = "  ·  ".join(parts)
	_level_pill.text = "Lv %d" % Game.level
	var prog := Game.level_progress()
	for i in 5:
		_meter[i].color = UI.RED if prog >= (i + 1) / 5.0 - 0.001 else UI.TRACK
	_hint.visible = Game.taps < 10 and not (Game.frenzy_active() or Game.rush_active())
	_per_tap.text = Game.money_short(Game.tap_value() * _tap_mult() * (Data.TAP_TIRED_MULT if Game.tap_tired() else 1.0)) + " /tap" + (" · tired, rest a bit" if Game.tap_tired() else "")
	var maxed := Game.level >= Data.MAX_LEVEL
	var can := Game.can_level_up()
	_level_btn.set_state(UI.TEXT if can else UI.SUB, prog if not maxed else 1.0, false, "MAX" if maxed else Game.money_short(Game.level_cost()))
	_tasks.set_state(UI.TEXT, -1.0, Game.unclaimed("goal") + Game.unclaimed("streak") > 0)   # a dot only when a reward waits
	_tick()


func _tap_mult() -> float:
	var m := Game.BOOST_MULT if Game.boost_active() else 1.0
	if Game.frenzy_active():
		m = maxf(m, Data.FRENZY_MULT)
	return m


func _tick() -> void:
	if _boost_btn == null:
		return
	var buffs: Array = []
	if Game.frenzy_active():
		buffs.append("Taps ×%d · %s" % [int(Data.FRENZY_MULT), Game.clock(Game.frenzy_until - Game.now())])
	if Game.rush_active():
		buffs.append("Income ×2 · %s" % Game.clock(Game.rush_until - Game.now()))
	_buff.text = "     ".join(buffs)
	_buff.visible = not buffs.is_empty()
	_per_tap.text = Game.money_short(Game.tap_value() * _tap_mult() * (Data.TAP_TIRED_MULT if Game.tap_tired() else 1.0)) + " /tap" + (" · tired, rest a bit" if Game.tap_tired() else "")
	if Game.boost_active():
		_boost_btn.set_state(UI.RED, Game.boost_left() / Game.BOOST_LEN_S, false, Game.clock(Game.boost_left()))
	elif Game.boost_ready():
		_boost_btn.set_state(UI.TEXT, 1.0, false, "×3")   # the full ring says ready
	else:
		var total := Game.BOOST_COOLDOWN_S
		_boost_btn.set_state(UI.SUB, 1.0 - Game.boost_cooldown_left() / total, false, Game.clock(Game.boost_cooldown_left()))
	# Auto clicker: ring fills towards the next auto tap; caption shows speed or price.
	if Game.auto_level == 0:
		_auto_btn.set_state(UI.TEXT if Game.cash >= Game.auto_cost() else UI.SUB, -1.0, false, Game.money_short(Game.auto_cost()))
	elif Game.auto_running():
		_auto_btn.set_state(UI.TEXT, clampf(Game._auto_acc / Game.auto_interval(), 0.0, 1.0), false, "%s s" % str(Game.auto_interval()))
	else:
		_auto_btn.set_state(UI.SUB, 0.0, false, "Paused")
	_card.queue_redraw()


func _show_tasks() -> void:
	Kit.tick()
	push_page.emit(GoalsPage.new())


func _on_level_up() -> void:
	if Game.level_up():
		Kit.haptic("success")
		Motion.pop(_pill, 1.12)
		_card.celebrate()
		Kit.toast("Lv %d · %s /tap" % [Game.level, Game.money_short(Game.tap_value())], true)
		Game.flush_changes()
	elif Game.level < Data.MAX_LEVEL:
		Motion.shake(_level_btn)
		var wait := Game.eta(Game.level_cost())
		Kit.toast("Lv up needs %s more%s" % [Game.money_short(Game.level_cost() - Game.cash), (" · " + wait) if wait != "" else ""])


func _on_auto() -> void:
	Kit.tick()
	var lv := Game.auto_level
	var maxed := Game.auto_cost() <= 0.0
	var body := "Taps for you while you play (half a tap each). Pauses after 2 min without a touch."
	if lv > 0:
		body += "\nNow: level %d, a tap every %s s." % [lv, str(Game.auto_interval())]
	var actions: Array = []
	if not maxed:
		var nxt: Array = Data.AUTO_LEVELS[lv]
		body += "\nNext: a tap every %s s." % str(nxt[1])
		var can := Game.cash >= float(nxt[0])
		actions.append({"text": ("Upgrade · " if lv > 0 else "Buy · ") + Game.money_short(float(nxt[0])) if can else "Need " + Game.money_short(float(nxt[0]) - Game.cash), "style": "primary", "disabled": not can, "call": func():
			if Game.buy_auto():
				Kit.haptic("success")
				Kit.sound("buy")
				Kit.toast("Auto clicker · level %d" % Game.auto_level, true)
				Game.flush_changes()
				_tick()})
	else:
		body += "\nFully upgraded."
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet("Auto clicker", body, actions)


func _on_boost() -> void:
	if Game.boost_ready() and Game.taps < 20:
		# Don't waste the boost before the player knows to tap.
		Motion.shake(_boost_btn)
		Kit.toast("Tap the tower first")
		return
	if Game.start_boost():
		Kit.haptic("medium")
		Motion.pop(_boost_btn, 1.1)
	else:
		Motion.shake(_boost_btn)
	_tick()
