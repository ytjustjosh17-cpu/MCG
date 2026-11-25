class_name RivalsPage
extends Page
## Made-up rival tycoons ranked by fortune, with you placed among them.

var _list: VBoxContainer
var _rank: Label
var _key := ""


func _init() -> void:
	super("Rivals", true)


func build() -> void:
	_rank = UI.label("", 15, UI.SUB)
	body.add_child(_rank)
	_list = card()


func refresh() -> void:
	if _list == null:
		return
	var nw := Game.net_worth()
	var beaten := Game.rivals_beaten()
	var rank := Data.RIVALS.size() - beaten + 1
	_rank.text = "You're number %d of %d" % [rank, Data.RIVALS.size() + 1]
	# Rebuild only when your place changes; just update your money otherwise.
	var key := str(beaten)
	if key == _key:
		var me := _list.find_child("Me", true, false) as Row
		if me:
			me.value_l.text = Game.money_short(nw)
		return
	_key = key
	for ch in _list.get_children():
		ch.queue_free()
	# Richest first.
	var rows: Array = []
	for r in Data.RIVALS:
		rows.append({"name": r[0], "sub": r[1], "worth": float(r[2]), "me": false})
	rows.append({"name": "You", "sub": "Sol", "worth": nw, "me": true})
	rows.sort_custom(func(a, b): return float(a["worth"]) > float(b["worth"]))
	for i in range(rows.size()):
		if i > 0:
			separator(_list, 56)
		var it: Dictionary = rows[i]
		var r := Row.new("", "", false)
		r.custom_minimum_size = Vector2(0, 56)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := UI.display(str(i + 1), 22, UI.RED if it["me"] else UI.DIM)
		num.custom_minimum_size = Vector2(28, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.set_lead(num)
		r.set_texts(it["name"], it["sub"], Game.money_short(it["worth"]))
		if it["me"]:
			r.name = "Me"
			r.title_l.add_theme_font_override("font", UI.SEMI)
			r.add_theme_stylebox_override("normal", UI.box(UI.RAISED, 0))
		elif float(it["worth"]) <= nw:
			r.modulate.a = 0.55  # already beaten
		_list.add_child(r)
