class_name ItemsPage
extends Page
## Items tab: collections. Finishing one raises all income for good.

var _summary: Label
var _bonus: Label
var _rows := {}


func _init() -> void:
	super("Items")


func build() -> void:
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
