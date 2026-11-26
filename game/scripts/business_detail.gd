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
var _mult_seg: Segmented
const MULTS := [1, 10, 100, 0]   # 0 = Max
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
var _mile: Label
var _syn_rows := {}


func _init(biz_id := "") -> void:
	id = biz_id
	super(Game.biz[id]["name"] if Game.biz.has(id) else "Company", true)


func build() -> void:
	var b := Data.business(id)
	_type = UI.label("", 15, UI.SUB)
	body.add_child(_type)
	_scene = Art.Scene.new(b["kind"], 22.0)
	_scene.seed_id = id
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
	_mile = UI.label("", 13, UI.TEXT)
	up.add_child(_mile)
	# How many to buy at once: 1, 10, 100 or as many as you can afford.
	_mult_seg = Segmented.new(["×1", "×10", "×100", "Max"])
	_mult_seg.select(MULTS.find(int(Game.ui.get("buy_mult", 1))) if MULTS.has(int(Game.ui.get("buy_mult", 1))) else 0)
	_mult_seg.changed.connect(func(i: int):
		Game.ui["buy_mult"] = MULTS[i]
		refresh())
	up.add_child(_mult_seg)
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
	bh.add_child(_buy)

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

	# Synergies: another company you own can boost this one.
	var syns := Game.synergies_for(id)
	if not syns.is_empty():
		section("Synergies")
		var sc := card()
		for i in range(syns.size()):
			if i > 0:
				separator(sc, 50)
			var sy: Array = syns[i]
			var r := Row.new("sparkle", "", false)
			r.custom_minimum_size = Vector2(0, 64)
			var sid: String = sy[0]
			r.pressed.connect(func(): _on_synergy(sid, r))
			sc.add_child(r)
			_syn_rows[sid] = r
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
	var per_unit := Game.biz_income(id) / float(maxi(1, units))
	var nm := Game.next_milestone(id)
	_mile.visible = not nm.is_empty()
	if not nm.is_empty():
		_mile.text = "%d %s: income ×%s" % [int(nm[0]), b.get("units", "units"), str(nm[1])]
	_refresh_synergies()
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
		_mult_seg.visible = false
		_unit_note.visible = false
	else:
		var p := Game.unit_price(id)
		_units_value.text = "%d / %d" % [units, cap]
		_buy_row.visible = true
		_mult_seg.visible = true
		_unit_note.visible = true
		_unit_note.text = "+%s /h each" % Game.money_short(per_unit)
		var n := _buy_n()
		var shown := maxi(n, 1)
		var cost := Game.bulk_cost(id, shown)
		_buy.text = "+%d · %s" % [shown, Game.money_short(cost)]
		Page.set_enabled(_buy, n > 0 and Game.cash >= cost)
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


func _refresh_synergies() -> void:
	for sid in _syn_rows.keys():
		var sy := Data.synergy(sid)
		var r: Row = _syn_rows[sid]
		var src := Data.business(sy[2])
		var pct := "+%d%% income" % int(round((float(sy[5]) - 1.0) * 100.0))
		if Game.synergies.has(sid):
			r.set_texts(sy[1], pct, "Owned")
			r.value_l.add_theme_color_override("font_color", UI.SUB)
		elif not Game.owns(sy[2]):
			r.set_texts(sy[1], "Needs %s" % src["name"], Game.money_short(float(sy[6])))
			r.value_l.add_theme_color_override("font_color", UI.SUB)
		elif not Game.synergy_ready(sid):
			r.set_texts(sy[1], "Needs %s stage %d" % [Game.biz[sy[2]]["name"], int(sy[3])], Game.money_short(float(sy[6])))
			r.value_l.add_theme_color_override("font_color", UI.SUB)
		else:
			r.set_texts(sy[1], pct, Game.money_short(float(sy[6])))
			r.value_l.add_theme_color_override("font_color", UI.TEXT if Game.cash >= float(sy[6]) else UI.SUB)


func _on_synergy(sid: String, r: Row) -> void:
	if Game.synergies.has(sid):
		return
	if Game.buy_synergy(sid):
		Kit.haptic("success")
		Motion.pop(r, 1.04)
		Kit.toast("%s · income up" % Data.synergy(sid)[1], true)
		Game.flush_changes()
	else:
		Kit.haptic("error")
		Motion.shake(r)
		var sy := Data.synergy(sid)
		if Game.synergy_ready(sid):
			Kit.toast("Need %s more" % Game.money_short(float(sy[6]) - Game.cash))
		else:
			Kit.toast("Not ready yet")


func _milestone_check(before: float) -> void:
	## A milestone just reached: a burst, a sound and a short note.
	if Game.milestone_mult(id) <= before + 0.0001:
		return
	var b := Data.business(id)
	Kit.sound("fanfare")
	Kit.haptic("success")
	Kit.toast("Milestone · %d %s · income ×%.2f" % [int(Game.biz[id]["units"]), b.get("units", "units"), Game.milestone_mult(id) / before], true)
	if not Motion.reduced():
		add_child(Confetti.new(_units_value.global_position - global_position + Vector2(20, 0), 50))


func _buy_n() -> int:
	## Units the buy button gets right now, for the chosen ×1/×10/×100/Max.
	return Game.bulk_count(id, int(Game.ui.get("buy_mult", 1)))


func _on_hold() -> void:
	if not _buy.is_pressed() or Kit.dragged:
		return
	var hm0 := Game.milestone_mult(id)
	if Game.buy_units(id, _buy_n()) > 0:
		_milestone_check(hm0)
		_held += 1
		Kit.haptic("selection")
		Motion.pop(_units_value, 1.08)
		Game.flush_changes()
		_hold.start(maxf(0.06, 0.18 - 0.012 * _held))


func _on_buy() -> void:
	if _held > 0:
		_held = 0  # the hold already bought; releasing shouldn't buy one more
		return
	var want := _buy_n()
	var m0 := Game.milestone_mult(id)
	var got := Game.buy_units(id, want)
	if got > 0:
		_milestone_check(m0)
		Kit.haptic("light" if got == 1 else "success")
		Motion.pop(_units_value, 1.15)
		if got > 1:
			Kit.toast("Bought %d" % got, true)
		Game.flush_changes()
	else:
		Kit.haptic("error")
		Motion.shake(_buy)


func _on_expand() -> void:
	if Game.start_expansion(id):
		Kit.haptic("success")
		Motion.pop(_exp_title, 1.06)
		Game.flush_changes()
