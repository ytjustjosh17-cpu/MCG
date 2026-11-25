class_name ItemsPage
extends Page
## Items tab: collections. Finishing one raises all income for good.

var _summary: Label
var _bonus: Label
var _rows := {}
var _home_art: Control
var _home_kind := ""
var _home_name: Label
var _home_sub: Label
var _move: Button
var _ladder: Array = []


func _init() -> void:
	super("Items")


func build() -> void:
	# Home: where you live, and the next step up.
	var hc := card()
	_home_art = Control.new()
	_home_art.custom_minimum_size = Vector2(0, 120)
	_home_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_art.clip_contents = true
	hc.add_child(_home_art)
	var hp := padded(hc, 16, 4)
	_home_name = UI.label("", 22, UI.TEXT, true)
	hp.add_child(_home_name)
	_home_sub = UI.label("", 13, UI.SUB)
	hp.add_child(_home_sub)
	# The ladder: one small step mark per home, lit up to where you are.
	var lad := HBoxContainer.new()
	lad.add_theme_constant_override("separation", 4)
	lad.custom_minimum_size = Vector2(0, 14)
	hp.add_child(lad)
	for i in range(1, Data.HOMES.size()):
		var sq := ColorRect.new()
		sq.custom_minimum_size = Vector2(0, 4)
		sq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lad.add_child(sq)
		_ladder.append(sq)
	_move = button("", true, _on_move)
	hp.add_child(_move)

	var c := card()
	var p := padded(c, 16, 2)
	_summary = UI.label("", 22, UI.TEXT, true)
	p.add_child(_summary)
	_bonus = UI.label("", 13, UI.SUB)
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(_bonus)
	section("Collections")
	var list := card()
	for i in range(Data.COLLECTIONS.size()):
		if i > 0:
			separator(list)
		var col: Dictionary = Data.COLLECTIONS[i]
		var r := Row.new("items")
		var cid: String = col["id"]
		r.pressed.connect(func():
			Kit.tick()
			push_page.emit(CollectionPage.new(cid)))
		list.add_child(r)
		_rows[cid] = r


func refresh() -> void:
	if _summary == null:
		return
	var h: Array = Data.HOMES[Game.home]
	if _home_kind != String(h[3]):
		_home_kind = h[3]
		for ch in _home_art.get_children():
			ch.queue_free()
		var sc := Art.Scene.new(h[3], 16.0)
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_home_art.add_child(sc)
	_home_name.text = h[0]
	_home_sub.text = h[1] if Game.home == 0 else "%s · +%d%% income" % [h[1], int(round(Data.HOME_BONUS * Game.home * 100.0))]
	for i in range(_ladder.size()):
		_ladder[i].color = UI.RED if i < Game.home else UI.TRACK
	var nc := Game.next_home_cost()
	_move.visible = nc > 0.0
	if nc > 0.0:
		var can := Game.cash >= nc
		_move.text = ("Move to %s · %s" % [Data.HOMES[Game.home + 1][0], Game.money_short(nc)]) if can else ("%s · %s to go" % [Data.HOMES[Game.home + 1][0], Game.money_short(nc - Game.cash)])
		Page.set_enabled(_move, can)
	var done := 0
	var bonus := 0.0
	for col in Data.COLLECTIONS:
		var cid: String = col["id"]
		var n := Game.collection_count(cid)
		var total: int = col["items"].size()
		if n == total:
			done += 1
			bonus += float(col["bonus"])
		var r: Row = _rows[cid]
		r.set_texts(col["name"], "+%d%% income" % int(float(col["bonus"]) * 100), "%d / %d" % [n, total])
		r.mark.visible = n == total
	_summary.text = "%d / %d complete" % [done, Data.COLLECTIONS.size()]
	_bonus.text = "+%d%% income" % int(bonus * 100)


class CollectionPage extends Page:
	var cid := ""
	var _rows: Array = []

	func _init(c := "") -> void:
		cid = c
		super(Game.collection(c)["name"], true)

	func build() -> void:
		var col := Game.collection(cid)
		var note := UI.label("All %d: +%d%% income" % [col["items"].size(), int(float(col["bonus"]) * 100)], 15, UI.SUB)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(note)
		var list := card()
		for i in range(col["items"].size()):
			if i > 0:
				separator(list)
			var r := Row.new("", "", false)
			var idx := i
			r.pressed.connect(func(): _tap(idx))
			list.add_child(r)
			_rows.append(r)

	func refresh() -> void:
		var col := Game.collection(cid)
		for i in range(_rows.size()):
			var it: Array = col["items"][i]
			var r: Row = _rows[i]
			if Game.item_owned(cid, i):
				r.set_texts(it[0], "", "Owned")
				r.value_l.add_theme_color_override("font_color", UI.SUB)
				r.mark.visible = true
			else:
				r.set_texts(it[0], "", Game.money_short(it[1]))
				r.value_l.add_theme_color_override("font_color", UI.TEXT if Game.cash >= float(it[1]) else UI.SUB)
				r.mark.visible = false

	func _tap(i: int) -> void:
		var it: Array = Game.collection(cid)["items"][i]
		if Game.item_owned(cid, i):
			Kit.alert("Sell %s?" % it[0], "You get %s back (80%%)." % Game.money(float(it[1]) * Data.ITEM_RESALE), [
				{"text": "Keep it", "style": "primary"},
				{"text": "Sell", "style": "secondary", "call": func():
					Game.sell_item(cid, i)
					Kit.toast("Sold")},
			])
		elif Game.buy_item(cid, i):
			Kit.tick(20)
			Kit.toast(String(it[0]) + " added", true)
			if Game.collection_done(cid):
				Kit.toast("Collection complete · income up for good", true)
		else:
			Kit.toast("You need " + Game.money_short(float(it[1]) - Game.cash) + " more")


func _on_move() -> void:
	var nc := Game.next_home_cost()
	if nc <= 0.0:
		return
	var nh: Array = Data.HOMES[Game.home + 1]
	Kit.sheet(nh[0], "%s · %s\nAll income +%d%% for good." % [nh[1], Game.money(nc), int(round(Data.HOME_BONUS * 100.0))], [
		{"text": "Move for " + Game.money_short(nc), "style": "primary", "call": func():
			if Game.move_home():
				Kit.haptic("success")
				Motion.pop(_home_name, 1.08)
				Kit.toast("Welcome home · " + String(nh[0]), true)},
		{"text": "Not yet", "style": "plain"},
	])
