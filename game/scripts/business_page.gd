class_name BusinessPage
extends Page
## Business tab: income, the free double-income boost and your companies.

var _income: CountLabel
var _boost: Row
var _count: Label
var _list: VBoxContainer
var _cards := {}
var _empty: Control


func _init() -> void:
	super("Business")


func build() -> void:
	_income = CountLabel.new(func(v): return Game.money_short(v) + " /h")
	_income.add_theme_font_size_override("font_size", 40)
	_income.add_theme_font_override("font", UI.DISPLAY)
	_income.add_theme_color_override("font_color", UI.TEXT)
	body.add_child(_income)
	var c := card()
	_boost = Row.new("bolt", "", false)
	(_boost.lead as Icon).set_style(UI.RED)
	_boost.pressed.connect(_on_boost)
	c.add_child(_boost)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	body.add_child(h)
	h.add_child(button("New", true, func(): push_page.emit(StartBusinessPage.new())))
	h.add_child(button("Mergers", false, func(): push_page.emit(MergersPage.new())))
	_count = section("My companies")
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	body.add_child(_list)
	_empty = UI.panel(UI.PANEL, 16)
	_empty.custom_minimum_size = Vector2(0, 96)
	var el := UI.label("Open a company to earn every hour.", 15, UI.SUB)
	el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	el.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	el.offset_left = 16
	el.offset_right = -16
	el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.add_child(el)
	_list.add_child(_empty)


func refresh() -> void:
	if _income == null:
		return
	_income.set_value(Game.business_per_hour())
	if Game.ibost_active():
		_boost.set_texts("×2 income", "", Game.clock(Game.ibost_left()))
	elif Game.ibost_ready():
		_boost.set_texts("×2 income · 4 h", "", "Start" if Game.companies() > 0 else "")
	else:
		_boost.set_texts("×2 income", "", Game.clock(Game.ibost_cooldown_left()))
	_count.text = "%d of %d" % [Game.companies(), Data.BUSINESSES.size()]
	_empty.visible = Game.companies() == 0
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


func _on_boost() -> void:
	if Game.start_ibost():
		Kit.tick(20)
		Kit.toast("Double income for 4 hours", true)
	elif Game.companies() == 0:
		Kit.toast("Open a company first")
	elif not Game.ibost_active():
		Kit.toast("Ready again in " + Game.clock(Game.ibost_cooldown_left()))


class BizCard extends Button:
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
		_scene = Art.Scene.new(b["kind"], 16.0)
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
		_scene.position = Vector2(size.x - 150, 0)
		_scene.size = Vector2(150, size.y)
		_name.position = Vector2(16, 14)
		_type.position = Vector2(16, 36)
		_income.position = Vector2(16, size.y - 58)
		_mark.position = Vector2(16, size.y - 24)
		_status.position = Vector2(30, size.y - 31)

	func refresh() -> void:
		var b := Data.business(id)
		var s: Dictionary = Game.biz[id]
		_name.text = s["name"]
		_type.text = "%s · Stage %d" % [b["name"], s["stage"]]
		_income.text = Game.money_short(Game.biz_income(id)) + " /h"
		_scene.lit = 1 + int(s["stage"]) / 4
		_scene.queue_redraw()
		var cap := Game.capacity(id)
		if Game.expanding(id):
			_status.text = Game.clock(Game.expansion_left(id))
			_mark.visible = false
			_status.position.x = 16
		elif int(s["units"]) >= cap and int(s["stage"]) < Data.MAX_STAGE:
			_status.text = "Expand"
			_mark.visible = true
			_status.position.x = 30
		else:
			_status.text = "%d / %d" % [s["units"], cap]
			_mark.visible = Game.cash >= Game.unit_price(id) and int(s["units"]) < cap
			_status.position.x = 30 if _mark.visible else 16
