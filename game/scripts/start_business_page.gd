class_name StartBusinessPage
extends Page
## Pick a business type to open. Names are picked for you (no keyboard needed).

var _cash: Label
var _grid: GridContainer
var _tiles := {}
var _name_index := {}


func _init() -> void:
	super("New business", true)


func build() -> void:
	_cash = UI.label("", 15, UI.SUB)
	body.add_child(_cash)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(_grid)
	for b in Data.BUSINESSES:
		var id: String = b["id"]
		var t := Button.new()
		t.focus_mode = Control.FOCUS_NONE
		t.custom_minimum_size = Vector2(0, 132)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc := Art.Scene.new(b["kind"], 12.0)
		sc.position = Vector2(8, 8)
		t.add_child(sc)
		var n := UI.label(b["name"], 17)
		var c := UI.label(Game.money(b["cost"]), 13, UI.SUB)
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


func refresh() -> void:
	if _cash == null:
		return
	# Affordable first, then the rest by price, owned ones last.
	var order: Array = Data.BUSINESSES.duplicate()
	order.sort_custom(func(a, b):
		var ka := _rank(a)
		var kb := _rank(b)
		return ka < kb if ka != kb else float(a["cost"]) < float(b["cost"]))
	for i in range(order.size()):
		_grid.move_child(_tiles[order[i]["id"]][0], i)
	_cash.text = "Cash " + Game.money(Game.cash)
	for b in Data.BUSINESSES:
		var id: String = b["id"]
		var parts: Array = _tiles[id]
		var t: Button = parts[0]
		var owned := Game.owns(id)
		var can := Game.cash >= float(b["cost"])
		var bg := UI.box(UI.RAISED if can and not owned else UI.PANEL, 16)
		for st in ["normal", "hover", "pressed", "focus"]:
			t.add_theme_stylebox_override(st, bg)
		(parts[1] as Label).add_theme_color_override("font_color", UI.TEXT if (can or owned) else UI.SUB)
		if owned:
			(parts[2] as Label).text = "Owned"
		elif can:
			(parts[2] as Label).text = Game.money(b["cost"])
		else:
			(parts[2] as Label).text = Game.money_short(float(b["cost"])) + " · need " + Game.money_short(float(b["cost"]) - Game.cash)
		(parts[3] as Control).modulate.a = 1.0 if (can or owned) else 0.45


func _pick(id: String) -> void:
	var b := Data.business(id)
	if Game.owns(id):
		Kit.toast("You already own a " + String(b["name"]).to_lower())
		return
	if Game.cash < float(b["cost"]):
		Kit.toast("You need " + Game.money(float(b["cost"]) - Game.cash) + " more")
		return
	var names: Array = b["names"]
	var nm: String = names[int(_name_index[id]) % names.size()]
	var per_h: float = float(b["unit_income"]) * Game.global_mult()
	Kit.sheet(
		"Open %s?" % nm,
		"%s for %s. It starts with 1 %s earning %s an hour, and keeps earning while you're away." % [b["name"], Game.money(b["cost"]), b["unit"], Game.money(per_h)],
		[
			{"text": "Open for " + Game.money(b["cost"]), "style": "primary", "call": func(): _open(id, nm)},
			{"text": "Choose another name", "style": "secondary", "call": func():
				_name_index[id] = int(_name_index[id]) + 1
				_pick(id)},
			{"text": "Cancel", "style": "plain"},
		])


func _open(id: String, nm: String) -> void:
	if Game.open_business(id, nm):
		Kit.tick(30)
		Kit.toast(nm + " is open", true)
		pop_page.emit()
	else:
		Kit.toast("Not enough cash")


func _rank(b: Dictionary) -> int:
	if Game.owns(b["id"]):
		return 2
	return 0 if Game.cash >= float(b["cost"]) else 1
