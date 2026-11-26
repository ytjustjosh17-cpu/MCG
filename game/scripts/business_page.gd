class_name BusinessPage
extends Page
## Business tab: income, the free double-income boost and your companies.

var _income: CountLabel
var _income_row: HBoxContainer
var _boost: Row
var _count: Label
var _list: VBoxContainer
var _cards := {}
var _empty: Control
var _actions: HBoxContainer
var _more: Button
var _deal_row: Row
var _deal_card: Control

signal deal_open
var _boost_card: Control


func _init() -> void:
	super("Business")


func build() -> void:
	# Income: big Tanker number, small "/h" in Switzer beside it.
	_income_row = HBoxContainer.new()
	_income_row.add_theme_constant_override("separation", 6)
	body.add_child(_income_row)
	_income = CountLabel.new(Game.money_short)
	_income.add_theme_font_size_override("font_size", 40)
	_income.add_theme_font_override("font", UI.DISPLAY)
	_income.add_theme_color_override("font_color", UI.TEXT)
	_income_row.add_child(_income)
	var ph := UI.label("/h", 17, UI.SUB)
	ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_income_row.add_child(ph)
	var c := card()
	_boost_card = c.get_parent()
	_boost = Row.new("bolt", "", false)
	(_boost.lead as Icon).set_style(UI.RED)
	_boost.pressed.connect(_on_boost)
	c.add_child(_boost)
	# One row of actions: New, and everything else in a drop-down.
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	body.add_child(_actions)
	_actions.add_child(button("+ New", true, func(): push_page.emit(StartBusinessPage.new())))
	_more = Kit.drop_pill("More")
	_more.add_theme_font_size_override("font_size", 17)
	_more.custom_minimum_size = Vector2(0, 48)
	_more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_more.pressed.connect(_on_more)
	Kit.press_fx(_more)
	_actions.add_child(_more)
	# A deal waiting quietly (when deal pop-ups are turned off).
	var dc := card()
	_deal_row = Row.new("sparkle")
	_deal_row.pressed.connect(func():
		Kit.tick()
		deal_open.emit())
	dc.add_child(_deal_row)
	_deal_card = dc.get_parent()
	_count = section("My companies")
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	body.add_child(_list)
	# Empty state: one clear way forward.
	var first: Dictionary = Data.BUSINESSES[0]
	var er := Row.new("business")
	er.custom_minimum_size = Vector2(0, 72)
	er.set_texts("Open a company", "Earns while you're away", Game.money_short(float(first["cost"])))
	er.pressed.connect(func():
		Kit.tick()
		push_page.emit(StartBusinessPage.new()))
	var ec := card(_list)
	ec.add_child(er)
	_empty = ec.get_parent()


func refresh() -> void:
	if _income == null:
		return
	_income.set_value(Game.business_per_hour())
	var has := Game.companies() > 0
	_boost_card.visible = has
	_income_row.visible = has
	_actions.visible = has
	_count.get_parent().visible = has
	if Game.ibost_active():
		_boost.set_texts("×2 on", "", Game.clock(Game.ibost_left()))
	elif Game.ibost_ready():
		_boost.set_texts("×2 income · 4 h", "", "Start")
	else:
		_boost.set_texts("×2 income", "", "Ready in " + Game.clock(Game.ibost_cooldown_left()))
	_boost.value_l.add_theme_color_override("font_color", UI.TEXT)
	_count.text = "%d of %d" % [Game.companies(), Data.BUSINESSES.size()]
	UI.paint(_more, UI.PANEL, UI.TEXT, 24)
	_deal_card.visible = not Game.deal.is_empty() and bool(Game.ui.get("deals_quiet", false))
	if _deal_card.visible:
		_deal_row.set_texts(String(Game.deal.get("title", "Deal")), String(Game.deal.get("text", "")))
	_empty.visible = not has
	for b in Data.BUSINESSES:
		var id: String = b["id"]
		if Game.owns(id) and not _cards.has(id):
			var bc := BizCard.new(id)
			bc.pressed.connect(func():
				Kit.tick()
				push_page.emit(BusinessDetail.new(id)))
			Kit.press_fx(bc)
			_list.add_child(bc)
			_cards[id] = bc
		if _cards.has(id):
			(_cards[id] as BizCard).refresh()



func _fill_plan() -> Array:
	## Dry run of Fill all (cheapest first): [units, total cost].
	var units := {}
	for id in Game.biz.keys():
		units[id] = int(Game.biz[id]["units"])
	var cash := Game.cash
	var n := 0
	var total := 0.0
	while n < 1000:
		var best := ""
		var best_p := INF
		for id in units.keys():
			if int(units[id]) < Game.capacity(id):
				var p := Data.unit_price(Data.business(id), int(units[id]) - 1)
				if p < best_p:
					best = id
					best_p = p
		if best == "" or cash < best_p:
			break
		cash -= best_p
		total += best_p
		units[best] = int(units[best]) + 1
		n += 1
	return [n, total]


func _expand_plan() -> Array:
	## Dry run of Expand all (cheapest first): [count, total cost].
	var ids := Game.expandable()
	ids.sort_custom(func(a, b): return Game.expansion_cost(a) < Game.expansion_cost(b))
	var cash := Game.cash
	var n := 0
	var total := 0.0
	for id in ids:
		var c := Game.expansion_cost(id)
		if cash < c:
			continue
		cash -= c
		total += c
		n += 1
	return [n, total]


func _on_more() -> void:
	Kit.tick()
	var opts: Array = []
	var fill := _fill_plan()
	if int(fill[0]) > 0:
		opts.append(["fill", "Fill all · " + Game.money_short(float(fill[1]))])
	var ex := _expand_plan()
	if int(ex[0]) > 0:
		opts.append(["expand", "Expand %d · %s" % [ex[0], Game.money_short(float(ex[1]))]])
	opts.append(["mergers", "Mergers"])
	opts.append(["office", "Head office · %d/%d" % [Game.upgrades.size(), Data.UPGRADES.size()]])
	Kit.pick("More", opts, "", _on_more_pick)


func _on_more_pick(v) -> void:
	if v == "fill":
		_on_fill()
	elif v == "expand":
		_on_expand_all()
	elif v == "mergers":
		push_page.emit(MergersPage.new())
	elif v == "office":
		push_page.emit(HeadOfficePage.new())


func _on_fill() -> void:
	var n := Game.fill_all()
	if n > 0:
		Kit.haptic("success")
		Kit.toast("Bought %d unit%s" % [n, "" if n == 1 else "s"], true)
		Game.flush_changes()


func _on_expand_all() -> void:
	var n := Game.expand_all()
	if n > 0:
		Kit.haptic("success")
		Kit.toast("%d expanding" % n, true)
		Game.flush_changes()


func _on_boost() -> void:
	if Game.start_ibost():
		Kit.tick(20)
		Kit.toast("×2 income for 4 h", true)
	elif Game.companies() == 0:
		Kit.toast("Open a company first")
	elif not Game.ibost_active():
		Kit.toast("Ready in " + Game.clock(Game.ibost_cooldown_left()))


class BizCard extends Button:
	## One compact row: picture, name and status, income, and a thin bar
	## (units filled, or time left on an expansion).
	const ART_W := 76.0
	var id := ""
	var _scene: Art.Scene
	var _name: Label
	var _status: Label
	var _income: Label
	var _mark: ColorRect
	var _track: ColorRect
	var _fill: ColorRect
	var _bar_tw: Tween

	func _init(biz_id: String) -> void:
		id = biz_id
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 84)
		var bg := UI.box(UI.PANEL, 16)
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, bg)
		var b := Data.business(id)
		_scene = Art.Scene.new(b["kind"], 12.0)
		_scene.seed_id = id
		add_child(_scene)
		_name = UI.label("", 17, UI.TEXT, true)
		_name.clip_text = true
		_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_status = UI.label("", 13, UI.SUB)
		_income = UI.label("", 17, UI.TEXT, true)
		_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_mark = ColorRect.new()
		_mark.color = UI.RED
		_mark.size = Vector2(8, 8)
		_track = ColorRect.new()
		_track.color = UI.TRACK
		_fill = ColorRect.new()
		_fill.color = UI.TEXT
		for n in [_name, _status, _income, _mark, _track, _fill]:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(n)
		resized.connect(_layout)

	func _layout() -> void:
		_scene.position = Vector2(10, 10)
		_scene.size = Vector2(ART_W, size.y - 20)
		var x := ART_W + 24.0
		var right := size.x - 16.0
		_income.size = Vector2(110, 24)
		_income.position = Vector2(right - 110, 16)
		_name.position = Vector2(x, 16)
		_name.size = Vector2(maxf(40.0, right - 116 - x), 24)
		_status.position = Vector2(x, 42)
		_mark.position = Vector2(right - 8, 48)
		_track.position = Vector2(x, size.y - 16)
		_track.size = Vector2(right - x, 3)
		_fill.position = _track.position
		refresh()

	func refresh() -> void:
		if not Game.biz.has(id):
			return
		var s: Dictionary = Game.biz[id]
		_name.text = s["name"]
		_income.text = Game.money_short(Game.biz_income(id)) + " /h"
		_scene.lit = 1 + int(s["stage"]) / 4
		var cap := Game.capacity(id)
		var units := int(s["units"])
		var frac := float(units) / float(maxi(1, cap))
		var unit_word: String = Data.business(id).get("units", "units")
		if Game.expanding(id):
			_status.text = "Stage %d · expanding %s" % [s["stage"], Game.clock(Game.expansion_left(id))]
			frac = 1.0 - Game.expansion_left(id) / maxf(1.0, Game.expansion_seconds(id))
			_mark.visible = false
		elif units >= cap and int(s["stage"]) < Data.MAX_STAGE:
			_status.text = "Stage %d · full, expand" % s["stage"]
			_mark.visible = Game.can_expand(id)
		elif units >= cap:
			_status.text = "Stage %d · max" % s["stage"]
			_mark.visible = false
		else:
			_status.text = "Stage %d · %d/%d %s" % [s["stage"], units, cap, unit_word]
			_mark.visible = Game.cash >= Game.unit_price(id)
		# The bar glides to its new length instead of jumping.
		var want := _track.size.x * clampf(frac, 0.0, 1.0)
		_fill.size.y = 3
		if absf(_fill.size.x - want) > 1.5 and is_visible_in_tree():
			if _bar_tw != null and _bar_tw.is_valid():
				_bar_tw.kill()
			_bar_tw = create_tween()
			_bar_tw.tween_property(_fill, "size:x", want, Motion.d(0.35)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_fill.size.x = want
		# Name gets all the room the income doesn't need.
		var iw := _income.get_theme_font("font").get_string_size(_income.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		_name.size.x = maxf(40.0, size.x - 16.0 - iw - 12.0 - _name.position.x)
