class_name BusinessDetail
extends Page
## One company: units, expansion with a real-time timer, and its income.

var id := ""
var _scene: Art.Scene
var _type: Label
var _income: CountLabel
var _units_title: Label
var _units_value: Label
var _slots: GridContainer
var _buy: Button
var _buy_max: Button
var _unit_note: Label
var _exp_title: Label
var _exp_body: Label
var _exp_bar: ProgressBar
var _exp_btn: Button
var _boost_note: Label
var _hold: Timer
var _held := 0
var _buy_row: HBoxContainer
var _mgr: Row


func _init(biz_id := "") -> void:
	id = biz_id
	super(Game.biz[id]["name"] if Game.biz.has(id) else "Company", true)


func build() -> void:
	var b := Data.business(id)
	_type = UI.label("", 15, UI.SUB)
	body.add_child(_type)
	_scene = Art.Scene.new(b["kind"], 22.0)
	_scene.custom_minimum_size = Vector2(0, 190)
	body.add_child(_scene)
	var row := HBoxContainer.new()
	body.add_child(row)
	row.add_theme_constant_override("separation", 6)
	_income = CountLabel.new(Game.money_short)
	_income.add_theme_font_size_override("font_size", 28)
	_income.add_theme_font_override("font", UI.DISPLAY)
	_income.add_theme_color_override("font_color", UI.TEXT)
	row.add_child(_income)
	var ph := UI.label("/h", 15, UI.SUB)
	ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ph)
	_boost_note = UI.label("", 13, UI.SUB)
	body.add_child(_boost_note)

	# Units.
	var uc := card()
	var up := padded(uc, 16, 10)
	var uh := HBoxContainer.new()
	up.add_child(uh)
	_units_title = UI.label(String(b["units"]).capitalize(), 17, UI.TEXT, true)
	_units_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uh.add_child(_units_title)
	_units_value = UI.label("", 17)
	uh.add_child(_units_value)
	_slots = GridContainer.new()
	_slots.columns = 10
	_slots.add_theme_constant_override("h_separation", 4)
	_slots.add_theme_constant_override("v_separation", 4)
	up.add_child(_slots)
	for i in range(Data.MAX_STAGE * Data.UNITS_PER_STAGE):
		var sq := ColorRect.new()
		sq.custom_minimum_size = Vector2(22, 12)
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slots.add_child(sq)
	_unit_note = UI.label("", 13, UI.SUB)
	up.add_child(_unit_note)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	up.add_child(bh)
	_buy_row = bh
	_buy = button("+1", true, _on_buy)
	# Hold to keep buying, getting quicker the longer you hold.
	_hold = Timer.new()
	_hold.one_shot = true
	_hold.timeout.connect(_on_hold)
	add_child(_hold)
	_buy.button_down.connect(func():
		_held = 0
		_hold.start(0.45))
	_buy.button_up.connect(func(): _hold.stop())
	_buy_max = button("Max", false, _on_buy_max)
	_buy_max.size_flags_stretch_ratio = 0.6
	bh.add_child(_buy)
	bh.add_child(_buy_max)

	# Expansion.
	var ec := card()
	var ep := padded(ec, 16, 10)
	_exp_title = UI.label("", 17, UI.TEXT, true)
	ep.add_child(_exp_title)
	_exp_body = UI.label("", 15, UI.SUB)
	_exp_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ep.add_child(_exp_body)
	_exp_bar = ProgressBar.new()
	_exp_bar.show_percentage = false
	_exp_bar.custom_minimum_size = Vector2(0, 6)
	_exp_bar.add_theme_stylebox_override("background", UI.box(UI.TRACK, 3))
	_exp_bar.add_theme_stylebox_override("fill", UI.box(UI.TEXT, 3))
	ep.add_child(_exp_bar)
	_exp_btn = button("Expand", true, _on_expand)
	ep.add_child(_exp_btn)

	# Manager: expands for you when full, for a cut of the income.
	var mc := card()
	_mgr = Row.new("profile", "", false)
	_mgr.custom_minimum_size = Vector2(0, 64)
	_mgr.pressed.connect(_on_hire)
	mc.add_child(_mgr)
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(func():
		if is_visible_in_tree():
			refresh())
	add_child(t)


func refresh() -> void:
	if _type == null or not Game.biz.has(id):
		return
	var b := Data.business(id)
	var s: Dictionary = Game.biz[id]
	var stage := int(s["stage"])
	var units := int(s["units"])
	var cap := Game.capacity(id)
	_type.text = "Stage %d / %d" % [stage, Data.MAX_STAGE]
	_scene.lit = 1 + stage / 4
	_scene.queue_redraw()
	_income.set_value(Game.biz_income(id))
	var notes: Array = []
	if Game.merger_mult(id) > 1.0:
		notes.append("Merger ×%.1f" % Game.merger_mult(id))
	if Game.ibost_active():
		notes.append("×2 on")
	_boost_note.text = " · ".join(notes)
	_boost_note.visible = not notes.is_empty()
	for i in range(_slots.get_child_count()):
		var sq: ColorRect = _slots.get_child(i)
		sq.visible = i < cap
		sq.color = UI.RED if i < units else UI.TRACK
	var per_unit := float(b["unit_income"]) * pow(float(b["stage_mult"]), stage - 1) * Game.merger_mult(id) * Game.global_mult()
	if Game.has_manager(id):
		per_unit *= 1.0 - Data.MANAGER_CUT
	var cut := int(Data.MANAGER_CUT * 100.0)
	if Game.has_manager(id):
		_mgr.set_texts("Manager hired", "Expands for you · takes %d%%" % cut, "")
		if not _mgr.has_meta("hired"):
			_mgr.set_meta("hired", true)
			_mgr.set_lead(Icon.new("check", UI.TEXT, 22.0))
	else:
		var mc := Game.manager_cost(id)
		_mgr.set_texts("Manager", "Expands for you · takes %d%%" % cut, Game.money_short(mc))
		_mgr.value_l.add_theme_color_override("font_color", UI.TEXT if Game.cash >= mc else UI.SUB)
	if units >= cap:
		_units_value.text = "%d / %d · Full" % [units, cap]
		_buy_row.visible = false
		_unit_note.visible = false
	else:
		var p := Game.unit_price(id)
		_units_value.text = "%d / %d" % [units, cap]
		_buy_row.visible = true
		_unit_note.visible = true
		_unit_note.text = "+%s /h each" % Game.money_short(per_unit)
		_buy.text = "+1 · " + Game.money_short(p)
		Page.set_enabled(_buy, Game.cash >= p)
		Page.set_enabled(_buy_max, Game.cash >= p, false)
	if stage >= Data.MAX_STAGE:
		_exp_title.text = "Fully expanded"
		_exp_body.visible = false
		_exp_bar.visible = false
		_exp_btn.visible = false
	elif Game.expanding(id):
		var total := Game.expansion_seconds(id)
		var left := Game.expansion_left(id)
		_exp_title.text = "Expanding to Stage %d" % (stage + 1)
		_exp_body.visible = true
		_exp_body.text = Game.clock(left)
		_exp_bar.visible = true
		_exp_bar.max_value = total
		_exp_bar.value = total - left
		_exp_btn.visible = false
	else:
		_exp_title.text = "Expand to Stage %d" % (stage + 1)
		_exp_body.visible = true
		_exp_body.text = "+%d units · ×%.1f · %s" % [Data.UNITS_PER_STAGE, b["stage_mult"], _span(Game.expansion_seconds(id))]
		_exp_bar.visible = false
		_exp_btn.visible = true
		var cost := Game.expansion_cost(id)
		_exp_btn.text = "Expand · " + Game.money_short(cost)
		var wait := Game.eta(cost)
		if wait != "" and not Game.can_expand(id):
			_exp_btn.text += " · " + wait
		Page.set_enabled(_exp_btn, Game.can_expand(id))


static func _span(sec: float) -> String:
	## Short length of time: "4 h", "45 min", "2 h 30 min".
	var m := int(round(sec / 60.0))
	if m < 60:
		return "%d min" % m
	if m % 60 == 0:
		return "%d h" % (m / 60)
	return "%d h %d min" % [m / 60, m % 60]


func _on_hire() -> void:
	if Game.has_manager(id):
		return
	Kit.tick()
	if Game.hire_manager(id):
		Kit.haptic("success")
		Kit.toast("Manager hired", true)
		Game.flush_changes()
	else:
		Kit.toast("Need %s more" % Game.money_short(Game.manager_cost(id) - Game.cash))
		Motion.shake(_mgr)


func _on_hold() -> void:
	if not _buy.is_pressed() or Kit.dragged:
		return
	if Game.buy_unit(id):
		_held += 1
		Kit.haptic("selection")
		Motion.pop(_units_value, 1.08)
		Game.flush_changes()
		_hold.start(maxf(0.06, 0.18 - 0.012 * _held))


func _on_buy() -> void:
	if _held > 0:
		_held = 0  # the hold already bought; releasing shouldn't buy one more
		return
	if Game.buy_unit(id):
		Kit.haptic("light")
		Motion.pop(_units_value, 1.15)
		Game.flush_changes()


func _on_buy_max() -> void:
	var n := 0
	while Game.buy_unit(id):
		n += 1
	if n > 0:
		Kit.tick(20)
		Kit.toast("Bought %d unit%s" % [n, "" if n == 1 else "s"], true)
		Game.flush_changes()


func _on_expand() -> void:
	if Game.start_expansion(id):
		Kit.haptic("success")
		Motion.pop(_exp_title, 1.06)
		Game.flush_changes()
