class_name EarnPage
extends Control
## Earn tab, tower first: cash, the big tower to tap, and an action strip
## under it (Level up, Boost, Auto). The tower card is pure art: only small
## chips sit on it, never buttons or captions.
## Landscape (1.2): side by side. Cash, level and the three actions (as a
## column of rows) on the left; the tower fills the height on the right.
## The same nodes are moved, never rebuilt, so a combo survives a turn.

signal push_page(page: Control)

const NAV_SPACE := 92.0
const STRIP_H := 72.0
const LAND_COL := 340.0     # landscape: width of the cash and actions column
const LAND_ROW_H := 56.0    # landscape: each action is one row of the strip

var _worth: CountLabel
var _rate: Label
var _level_pill: Label
var _lv_track: ColorRect
var _lv_fill: ColorRect
var _pill: Panel
var _tasks: IconButton
var _card: TowerCard
var _chips: VBoxContainer
var _per_tap: Label
var _buff_row: HBoxContainer
var _frenzy: Label
var _rush: Label
var _hint: Control
var _strip: Panel
var _level_btn: IconButton
var _boost_btn: IconButton
var _auto_btn: IconButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_tasks = IconButton.new("list", 48.0)
	_tasks.fill = UI.PANEL
	_tasks.pressed.connect(_show_tasks)
	add_child(_tasks)

	# Level: "Lv 6" and a thin bar towards the next level (no coloured pips).
	_pill = UI.panel(UI.PANEL, 24)
	add_child(_pill)
	_level_pill = UI.label("", 15, UI.TEXT, true)
	_level_pill.position = Vector2(16, 13)
	_pill.add_child(_level_pill)
	_lv_track = ColorRect.new()
	_lv_track.color = UI.TRACK
	_lv_track.size = Vector2(36, 4)
	_lv_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(_lv_track)
	_lv_fill = ColorRect.new()
	_lv_fill.color = UI.TEXT
	_lv_fill.size = Vector2(0, 4)
	_lv_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lv_track.add_child(_lv_fill)

	# Big number is cash to the penny; net worth sits on the line below.
	_worth = CountLabel.new(Game.cash_text)
	_worth.name = "CashLabel"   # claimed money flies here (Kit.fly_money)
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
	# Chips at the top of the art: per tap, golden sun buffs, first-time hint.
	# They ignore the mouse, so a tap on them still taps the tower.
	_chips = VBoxContainer.new()
	_chips.add_theme_constant_override("separation", 6)
	_chips.position = Vector2(12, 12)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_chips)
	_per_tap = _chip(_chips, 15)
	_buff_row = HBoxContainer.new()
	_buff_row.add_theme_constant_override("separation", 6)
	_buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.add_child(_buff_row)
	_frenzy = _chip(_buff_row, 13)
	_rush = _chip(_buff_row, 13)
	var hl := _chip(_chips, 15)
	hl.text = "Tap the tower"
	_hint = hl.get_parent()

	# The action strip: a solid panel under the art, three equal tiles.
	_strip = UI.panel(UI.PANEL, 16)
	add_child(_strip)
	_level_btn = _action("level", "Level up", _on_level_up)
	_boost_btn = _action("bolt", "Boost", _on_boost)
	_auto_btn = _action("cpu", "Auto", _on_auto)
	Game.auto_tapped.connect(func(_n: int, _v: float):
		if is_visible_in_tree() and not Motion.reduced():
			Motion.pop(_auto_btn, 1.04))

	resized.connect(_layout)
	Kit.layout_changed.connect(func(_l: bool): _layout())
	Game.changed.connect(_refresh)
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)
	_layout()
	_refresh()


func _chip(parent: Control, fs: int) -> Label:
	## A small solid pill on the art, so its text never sits on lit windows.
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 14, 10, 4))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(pc)
	var l := UI.label("", fs, UI.TEXT, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(l)
	return l


func _action(icon: String, title: String, call: Callable) -> IconButton:
	var b := IconButton.new(icon, 40.0, title)
	b.pressed.connect(call)
	_strip.add_child(b)
	return b


func _refit_cash(w: float) -> void:
	## The big number shrinks to fit its column; a new width needs a refit.
	if is_equal_approx(_worth.fit_width, w):
		return
	_worth.fit_width = w
	_worth.text = ""
	_worth.set_value(Game.cash, true)


func _layout() -> void:
	if Kit.landscape:
		_layout_land()
		return
	var w := size.x
	var h := size.y
	_refit_cash(358.0)
	_tasks.position = Vector2(16, 4)
	_tasks.size = Vector2(48, 48)
	_pill.size = Vector2(112, 48)
	_pill.position = Vector2(w - 16 - 112, 4)
	_lv_track.position = Vector2(62, 22)
	_worth.position = Vector2(20, 58)
	_rate.position = Vector2(22, 112)
	var top := 148.0
	var strip_y := maxf(top + 260.0 + 12.0, h - NAV_SPACE - STRIP_H)
	_strip.position = Vector2(16, strip_y)
	_strip.size = Vector2(w - 32, STRIP_H)
	_card.position = Vector2(16, top)
	_card.size = Vector2(w - 32, strip_y - 12.0 - top)
	var tw := (_strip.size.x - 16.0) / 3.0
	for i in 3:
		var b: IconButton = [_level_btn, _boost_btn, _auto_btn][i]
		b.position = Vector2(8.0 + tw * i, 8.0)
		b.size = Vector2(tw, STRIP_H - 16.0)
	_refresh()


func _layout_land() -> void:
	## 844 x 390 minus the rail: the column on the left, the tower on the right.
	var w := size.x
	var h := size.y
	var col := minf(LAND_COL, w * 0.45)
	_refit_cash(col - 8.0)
	_tasks.position = Vector2(4, 8)
	_tasks.size = Vector2(48, 48)
	_pill.size = Vector2(112, 48)
	_pill.position = Vector2(col - 112.0, 8)
	_lv_track.position = Vector2(62, 22)
	_worth.position = Vector2(8, 62)
	_rate.position = Vector2(10, 116)
	# The three actions stacked as rows at the foot of the column.
	var strip_h := LAND_ROW_H * 3.0 + 16.0
	_strip.position = Vector2(0, maxf(148.0, h - 16.0 - strip_h))
	_strip.size = Vector2(col, strip_h)
	for i in 3:
		var b: IconButton = [_level_btn, _boost_btn, _auto_btn][i]
		b.position = Vector2(8.0, 8.0 + LAND_ROW_H * i)
		b.size = Vector2(col - 16.0, LAND_ROW_H)
	var cx := col + 16.0
	_card.position = Vector2(cx, 8)
	_card.size = Vector2(maxf(160.0, w - cx - 16.0), h - 8.0 - 16.0)
	_refresh()


func _refresh() -> void:
	if _worth == null or not is_visible_in_tree():
		return   # nothing to update while another tab is showing
	_worth.set_value(Game.cash)
	var parts: Array = []
	if Game.income_per_hour > 0.0:
		parts.append("+%s /h" % Game.money_short(Game.income_per_hour))
	parts.append("%s worth" % Game.money_short(Game.net_worth()))
	_rate.text = "  ·  ".join(parts)
	_level_pill.text = "Lv %d" % Game.level
	var maxed := Game.level >= Data.MAX_LEVEL
	var prog := 1.0 if maxed else clampf(Game.level_progress(), 0.0, 1.0)
	_lv_fill.size = Vector2(_lv_track.size.x * prog, 4)
	# The guide says it already while it runs, so the chip waits for it to end.
	_hint.visible = Game.taps < 10 and bool(Game.ui.get("guide_done", false)) and not (Game.frenzy_active() or Game.rush_active())
	_tasks.set_state(UI.TEXT, -1.0, Game.unclaimed("goal") + Game.unclaimed("streak") > 0)   # a dot only when a reward waits
	_tick()


func _best() -> String:
	## The one action worth taking now gets the red ring (one red per screen):
	## Level up first, then a ready Boost, then a first Auto clicker.
	if Game.level < Data.MAX_LEVEL and Game.can_level_up():
		return "level"
	if Game.boost_ready() and not Game.boost_active() and Game.taps >= 20:
		return "boost"
	if Game.auto_level == 0 and Game.auto_cost() > 0.0 and Game.cash >= Game.auto_cost():
		return "auto"
	return ""


func _tap_mult() -> float:
	var m := Game.BOOST_MULT if Game.boost_active() else 1.0
	if Game.frenzy_active():
		m = maxf(m, Data.FRENZY_MULT)
	return m


func _tick() -> void:
	if _boost_btn == null or not is_visible_in_tree():
		return
	var tired := Game.tap_tired()
	_per_tap.text = Game.money_short(Game.tap_value() * _tap_mult() * (Data.TAP_TIRED_MULT if tired else 1.0)) + " /tap" + ("  ·  tired, rest a bit" if tired else "")
	_frenzy.get_parent().visible = Game.frenzy_active()
	if Game.frenzy_active():
		_frenzy.text = "Taps ×%d  %s" % [int(Data.FRENZY_MULT), Game.clock(Game.frenzy_until - Game.now())]
	_rush.get_parent().visible = Game.rush_active()
	if Game.rush_active():
		_rush.text = "Income ×2  %s" % Game.clock(Game.rush_until - Game.now())
	_buff_row.visible = Game.frenzy_active() or Game.rush_active()
	var best := _best()
	var maxed := Game.level >= Data.MAX_LEVEL
	var can := Game.can_level_up()
	_level_btn.set_state(UI.TEXT if can or maxed else UI.SUB, 1.0 if maxed else Game.level_progress(), false,
		"Max" if maxed else Game.money_short(Game.level_cost()), UI.RED if best == "level" else UI.TEXT)
	if Game.boost_active():
		_boost_btn.set_state(UI.TEXT, Game.boost_left() / Game.BOOST_LEN_S, false, Game.clock(Game.boost_left()))
	elif Game.boost_ready():
		_boost_btn.set_state(UI.TEXT, 1.0, false, "×3", UI.RED if best == "boost" else UI.TEXT)
	else:
		_boost_btn.set_state(UI.SUB, 1.0 - Game.boost_cooldown_left() / Game.BOOST_COOLDOWN_S, false, Game.clock(Game.boost_cooldown_left()))
	# Auto clicker: the ring fills towards the next auto tap.
	if Game.auto_level == 0:
		_auto_btn.set_state(UI.TEXT if Game.cash >= Game.auto_cost() else UI.SUB, 1.0 if best == "auto" else -1.0, false,
			Game.money_short(Game.auto_cost()), UI.RED)
	elif Game.auto_running():
		_auto_btn.set_state(UI.TEXT, clampf(Game._auto_acc / Game.auto_interval(), 0.0, 1.0), false, "%s s" % str(Game.auto_interval()))
	else:
		_auto_btn.set_state(UI.SUB, 0.0, false, "Paused")


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
