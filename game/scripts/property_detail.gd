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
	var sc := Art.Scene.new(p[3], 16.0)
	sc.seed_id = String(p[0])
	sc.custom_minimum_size = Vector2(0, 140)   # compact, so Sell sits above the bottom bar
	body.add_child(sc)
	# Rent and worth on one line: the big value left, worth on the right.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)
	_rent = UI.display("", 28)
	row.add_child(_rent)
	var ph := UI.label("/h", 15, UI.SUB)
	ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ph)
	_value = UI.label("", 13, UI.SUB)
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_value)
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
				Game.flush_changes()
			elif not Game.props[str(index)]["imps"][kk]:
				var need := Game.prop_price(index) * float(Data.IMPROVEMENTS[kk][1]) - Game.cash
				if need > 0.0:
					Kit.toast("Need %s more" % Game.money_short(need))
					Motion.shake(r))
		c.add_child(r)
		_imps.append(r)
	# Selling is quiet and last (it asks first).
	var sell := UI.text_btn("Sell property")
	sell.pressed.connect(_on_sell)
	Kit.press_fx(sell)
	body.add_child(sell)


func refresh() -> void:
	if _rent == null or not Game.prop_owned(index):
		return
	_rent.text = Game.money_short(Game.prop_rent(index))
	_value.text = "Worth " + Game.money_short(Game.prop_value(index))
	var imps: Array = Game.props[str(index)]["imps"]
	for k in range(_imps.size()):
		var imp: Array = Data.IMPROVEMENTS[k]
		var r: Row = _imps[k]
		var cost := Game.prop_price(index) * float(imp[1])
		# Every row keeps its sub-line, so done rows don't shrink the rhythm.
		r.set_texts(imp[0], "+%d%% rent" % int(float(imp[2]) * 100))
		if imps[k]:
			BusinessPage.plain_value(r, "Done")
		else:
			BusinessPage.price_pill(r, Game.money_short(cost), Game.cash >= cost)


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
