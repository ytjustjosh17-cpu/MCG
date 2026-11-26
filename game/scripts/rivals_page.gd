class_name RivalsPage
extends Page
## Made-up rival tycoons ranked by fortune, with you placed among them.

var _list: VBoxContainer
var _rank: Label
var _of: Label
var _next: Label
var _me: Row
var _key := ""
var _open := false


var _top_open := false


func _init() -> void:
	super("Rivals", true)


func build() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	body.add_child(h)
	_rank = UI.display("", 44, UI.TEXT)
	h.add_child(_rank)
	_of = UI.label("", 15, UI.SUB)
	_of.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(_of)
	_next = UI.label("", 15, UI.SUB)
	_next.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(_next)
	_list = card()


func _sorted(nw: float) -> Array:
	## Richest first, you included. The rank and the rows both come from this.
	var rows: Array = []
	for r in Data.RIVALS:
		rows.append({"name": r[0], "sub": r[1], "worth": float(r[2]), "me": false})
	rows.append({"name": "You", "sub": "", "worth": nw, "me": true})
	rows.sort_custom(func(a, b):
		if float(a["worth"]) == float(b["worth"]):
			return bool(a["me"])  # a tie counts as passed
		return float(a["worth"]) > float(b["worth"]))
	return rows


func refresh() -> void:
	if _list == null:
		return
	var nw := Game.net_worth()
	var rows := _sorted(nw)
	var me := 0
	for i in range(rows.size()):
		if rows[i]["me"]:
			me = i
	_rank.text = "#%d" % (me + 1)
	_of.text = "of %d" % rows.size()
	if me > 0:
		var nx: Dictionary = rows[me - 1]
		_next.text = "Next: %s · %s to pass" % [nx["name"], Game.money_short(float(nx["worth"]) - nw)]
	else:
		_next.text = "Richest of all"
	# Rebuild only when your place changes; just update your money otherwise.
	var key := "%d:%s:%s" % [me, _open, _top_open]
	if key == _key and is_instance_valid(_me):
		_me.value_l.text = Game.money_short(nw)
		return
	_key = key
	_me = null
	for ch in _list.get_children():
		ch.queue_free()
	var passed := rows.size() - me - 1
	var first := true
	# Your row stays in view: only the two just above you, the rest folded.
	var start := 0 if _top_open else maxi(0, me - 2)
	if me > 2:
		var t := Row.new("", "", false)
		t.custom_minimum_size = Vector2(0, 48)
		t.set_texts("Richer rivals (%d)" % me, "", "▴" if _top_open else "▾")
		t.title_l.add_theme_color_override("font_color", UI.SUB)
		t.value_l.add_theme_color_override("font_color", UI.SUB)
		t.pressed.connect(func():
			Kit.tick()
			_top_open = not _top_open
			refresh())
		_list.add_child(t)
		first = false
	for i in range(start, rows.size()):
		if i > me and not _open:
			break
		if not first:
			separator(_list, 56)
		first = false
		_add_row(rows[i], i, i > me)
		if i == me and passed > 0:
			separator(_list, 56)
			_add_toggle(passed)


func _add_row(it: Dictionary, i: int, passed: bool) -> void:
	var r := Row.new("", "", false)
	r.custom_minimum_size = Vector2(0, 56)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num := UI.display(str(i + 1), 22, UI.RED if it["me"] else UI.DIM)
	num.custom_minimum_size = Vector2(28, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.set_lead(num)
	r.set_texts(it["name"], it["sub"], Game.money_short(it["worth"]))
	if it["me"]:
		_me = r
		r.title_l.add_theme_font_override("font", UI.SEMI)
		r.add_theme_stylebox_override("normal", UI.box(UI.RAISED, 0))
	elif passed:
		r.modulate.a = 0.55  # already passed
	_list.add_child(r)


func _add_toggle(n: int) -> void:
	var t := Row.new("", "", false)
	t.custom_minimum_size = Vector2(0, 48)
	t.set_texts("Passed (%d)" % n, "", "▴" if _open else "▾")
	t.title_l.add_theme_color_override("font_color", UI.SUB)
	t.value_l.add_theme_color_override("font_color", UI.SUB)
	t.pressed.connect(func():
		Kit.tick()
		_open = not _open
		refresh())
	_list.add_child(t)
