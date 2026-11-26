class_name StartBusinessPage
extends Page
## Pick a kind of company to open. Names are picked for you (no keyboard needed).

var _cash: Label
var _grid: GridContainer
var _owned_row: Row
var _owned_list: Label
var _owned_open := false
var _tiles := {}
var _name_index := {}


func _init() -> void:
	super("New company", true)


func build() -> void:
	# Cash is in the pill at the top; this line only shows when nothing is left.
	_cash = UI.label("You own every kind of company.", 15, UI.SUB)
	body.add_child(_cash)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(_grid)
	for b in Game.businesses():
		var id: String = b["id"]
		var t := Button.new()
		t.focus_mode = Control.FOCUS_NONE
		t.custom_minimum_size = Vector2(0, 132)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc := Art.Scene.new(b["kind"], 12.0)
		sc.seed_id = String(b["id"])
		sc.position = Vector2(8, 8)
		t.add_child(sc)
		var n := UI.label(b["name"], 17)
		var c := UI.label(Game.money_short(float(b["cost"])), 13, UI.SUB)
		t.add_child(n)
		t.add_child(c)
		t.resized.connect(func():
			sc.size = Vector2(t.size.x - 16, 62)
			n.position = Vector2(12, 78)
			c.position = Vector2(12, 102))
		t.pressed.connect(func(): _pick(id))
		Kit.press_fx(t)
		_grid.add_child(t)
		_tiles[id] = [t, n, c, sc]
		_name_index[id] = 0
	# Owned kinds fold into one line, so the grid only shows what's left to open.
	var oc := card()
	_owned_row = Row.new("check", "", false)
	_owned_row.pressed.connect(func():
		Kit.tick()
		_owned_open = not _owned_open
		refresh())
	oc.add_child(_owned_row)
	var om := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		om.add_theme_constant_override("margin_" + side, 16)
	oc.add_child(om)
	_owned_list = UI.label("", 13, UI.SUB)
	_owned_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	om.add_child(_owned_list)


func refresh() -> void:
	if _cash == null:
		return
	# Affordable first, then the rest by price, owned ones last.
	var order: Array = Game.businesses().duplicate()
	order.sort_custom(func(a, b):
		var ka := _rank(a)
		var kb := _rank(b)
		return ka < kb if ka != kb else float(a["cost"]) < float(b["cost"]))
	for i in range(order.size()):
		_grid.move_child(_tiles[order[i]["id"]][0], i)
	var owned_names: Array = []
	for b in Game.businesses():
		if Game.owns(b["id"]):
			owned_names.append(String(b["name"]))
	_cash.visible = owned_names.size() == Game.businesses().size()
	_owned_row.get_parent().get_parent().visible = not owned_names.is_empty()
	_owned_row.set_texts("Owned · %d" % owned_names.size(), "", "Hide" if _owned_open else "Show")
	_owned_list.text = ", ".join(owned_names)
	_owned_list.get_parent().visible = _owned_open
	for b in Game.businesses():
		var id: String = b["id"]
		var parts: Array = _tiles[id]
		var t: Button = parts[0]
		var owned := Game.owns(id)
		t.visible = not owned
		var can := Game.cash >= float(b["cost"])
		var bg := UI.box(UI.RAISED if can and not owned else UI.PANEL, 16)
		for st in ["normal", "hover", "pressed", "focus"]:
			t.add_theme_stylebox_override(st, bg)
		(parts[1] as Label).add_theme_color_override("font_color", UI.TEXT if (can or owned) else UI.SUB)
		if owned:
			(parts[2] as Label).text = "Owned"
		elif can:
			(parts[2] as Label).text = Game.money_short(float(b["cost"]))
		else:
			var wait := Game.eta(float(b["cost"]))
			if wait.ends_with("days") and int(wait.trim_prefix("~").get_slice(" ", 0)) > 30:
				wait = ""  # too far off to be useful
			(parts[2] as Label).text = Game.money_short(float(b["cost"])) + ("" if wait == "" else " · " + wait)
		(parts[3] as Control).modulate.a = 1.0 if (can or owned) else 0.45


func _pick(id: String) -> void:
	var b := Data.business(id)
	if Game.owns(id):
		Kit.toast("Already owned")
		return
	if Game.cash < float(b["cost"]):
		Kit.toast("Need %s more" % Game.money_short(float(b["cost"]) - Game.cash))
		return
	var names: Array = b["names"]
	var nm: String = names[int(_name_index[id]) % names.size()]
	var per_h: float = float(b["unit_income"]) * Game.global_mult()
	Kit.sheet(
		"Open %s?" % nm,
		"1 unit · %s /h\nEarns while you're away" % Game.money_short(per_h),
		[
			{"text": "Open · " + Game.money_short(float(b["cost"])), "style": "primary", "call": func(): _open(id, nm)},
			{"text": "New name", "style": "secondary", "call": func():
				_name_index[id] = int(_name_index[id]) + 1
				_pick(id)},
		])


func _open(id: String, nm: String) -> void:
	if Game.open_business(id, nm):
		Kit.tick(30)
		Kit.toast("Opened", true)
		pop_page.emit()
	else:
		Kit.toast("Need %s more" % Game.money_short(float(Data.business(id)["cost"]) - Game.cash))


func _rank(b: Dictionary) -> int:
	if Game.owns(b["id"]):
		return 2
	return 0 if Game.cash >= float(b["cost"]) else 1
