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
	UI.paint(_more, UI.PANEL, UI.RED if _something_ready() else UI.TEXT, 24)
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


func _something_ready() -> bool:
	## Red "More" when an expansion or a merger is ready (same idea as the tab dot).
	if not Game.expandable().is_empty():
		return true
	for m in Data.MERGERS:
		if not Game.mergers.has(m["id"]) and Game.merger_ready(m) and Game.cash >= float(m["cost"]):
			return true
	return false


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
	Kit.pick("More", opts, "", _on_more_pick)


func _on_more_pick(v) -> void:
	if v == "fill":
		_on_fill()
	elif v == "expand":
		_on_expand_all()
	elif v == "mergers":
		push_page.emit(MergersPage.new())


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


class CardArt extends Art.Scene:
	## Narrow card art with a small sun, so the red isn't repeated loudly.
	func _draw() -> void:
		if size.x < 20.0 or size.y < 20.0:
			return
		Art.draw_scene(self, Rect2(Vector2.ZERO, size), kind, radius, size.x * 0.3, lit)


class BizCard extends Button:
	const ART_W := 90.0
	var id := ""
	var _scene: Art.Scene
	var _name: Label
	var _type: Label
	var _income: Label
	var _status: Label
	var _mark: ColorRect

	func _init(biz_id: String) -> void:
		id = biz_id
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 124)
		var bg := UI.box(UI.PANEL, 16)
		for st in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(st, bg)
		var b := Data.business(id)
		_scene = CardArt.new(b["kind"], 16.0)
		_scene.modulate.a = 0.5  # quiet, so the red sun isn't repeated loudly
		add_child(_scene)
		_name = UI.label("", 17, UI.TEXT, true)
		_type = UI.label("", 13, UI.SUB)
		_income = UI.label("", 22, UI.TEXT, true)
		_status = UI.label("", 13, UI.TEXT)
		_mark = ColorRect.new()
		_mark.color = UI.RED
		_mark.size = Vector2(8, 8)
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for n in [_name, _type, _income, _status, _mark]:
			add_child(n)
		resized.connect(_layout)

	func _layout() -> void:
		_scene.position = Vector2(size.x - ART_W, 0)
		_scene.size = Vector2(ART_W, size.y)
		_name.position = Vector2(16, 14)
		# Long names end in "..." instead of running under the art.
		_name.clip_text = true
		_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name.size = Vector2(maxf(40.0, size.x - ART_W - 28), 24)
		_type.position = Vector2(16, 36)
		_income.position = Vector2(16, size.y - 58)
		_mark.position = Vector2(16, size.y - 24)
		_status.position = Vector2(30, size.y - 31)

	func refresh() -> void:
		var s: Dictionary = Game.biz[id]
		_name.text = s["name"]
		_type.text = "Stage %d" % s["stage"]
		_income.text = Game.money_short(Game.biz_income(id)) + " /h"
		_scene.lit = 1 + int(s["stage"]) / 4
		_scene.queue_redraw()
		var cap := Game.capacity(id)
		var units := int(s["units"])
		if Game.expanding(id):
			_status.text = "Expanding " + Game.clock(Game.expansion_left(id))
			_mark.visible = false
		elif units >= cap and int(s["stage"]) < Data.MAX_STAGE:
			_status.text = "Full · Expand"
			_mark.visible = Game.can_expand(id)
		elif units >= cap:
			_status.text = "Full"
			_mark.visible = false
		else:
			_status.text = "%d/%d units" % [units, cap]
			_mark.visible = Game.cash >= Game.unit_price(id)
		_status.position.x = 30 if _mark.visible else 16
