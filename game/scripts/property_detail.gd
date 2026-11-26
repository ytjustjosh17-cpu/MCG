class_name PropertyDetail
extends Page
## An owned property: rent, upgrades and selling (12% tax).

var index := 0
var _place: Label
var _rent: Label
var _value: Label
var _imps: Array = []


func _init(i := 0) -> void:
	index = i
	super(Data.property(i)[0], true)


func build() -> void:
	var p: Array = Data.property(index)
	_place = UI.label(p[1], 15, UI.SUB)
	body.add_child(_place)
	var sc := Art.Scene.new(p[3], 22.0)
	sc.seed_id = String(p[0])
	sc.custom_minimum_size = Vector2(0, 190)
	body.add_child(sc)
	_rent = UI.label("", 22, UI.TEXT, true)
	body.add_child(_rent)
	_value = UI.label("", 13, UI.SUB)
	body.add_child(_value)
	section("Upgrades")
	var c := card()
	for k in range(Data.IMPROVEMENTS.size()):
		if k > 0:
			separator(c)
		var r := Row.new("", "", false)
		var kk := k
		r.pressed.connect(func():
			if Game.improve_property(index, kk):
				Kit.tick(20)
				Kit.toast(String(Data.IMPROVEMENTS[kk][0]) + " done", true)
				Game.flush_changes())
		c.add_child(r)
		_imps.append(r)
	body.add_child(button("Sell", false, _on_sell))


func refresh() -> void:
	if _rent == null or not Game.prop_owned(index):
		return
	_rent.text = Game.money_short(Game.prop_rent(index)) + " /h"
	_value.text = "Worth " + Game.money_short(Game.prop_value(index))
	var imps: Array = Game.props[str(index)]["imps"]
	for k in range(_imps.size()):
		var imp: Array = Data.IMPROVEMENTS[k]
		var r: Row = _imps[k]
		var cost := Game.prop_price(index) * float(imp[1])
		if imps[k]:
			r.set_texts(imp[0], "", "Done")
			r.value_l.add_theme_color_override("font_color", UI.SUB)
			r.mark.visible = false
		else:
			r.set_texts(imp[0], "+%d%% rent" % int(float(imp[2]) * 100), Game.money_short(cost))
			r.value_l.add_theme_color_override("font_color", UI.TEXT if Game.cash >= cost else UI.SUB)
			r.mark.visible = false


func _on_sell() -> void:
	var v := Game.prop_value(index)
	var you_get := Game.money_short(v - v * Data.SELL_TAX)
	Kit.alert("Sell %s?" % Data.property(index)[0],
		"You get %s. Tax %d%%." % [you_get, int(round(Data.SELL_TAX * 100.0))],
		[
			{"text": "Keep", "style": "primary"},
			{"text": "Sell · " + you_get, "style": "secondary", "call": func():
				Game.sell_property(index)
				Kit.toast("Sold")
				pop_page.emit()},
		])
