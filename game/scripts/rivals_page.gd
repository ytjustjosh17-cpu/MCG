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
		_me.value_l.text = worth_text(nw)
		return
	_key = key
	_me = null
	for ch in _list.get_children():
		ch.queue_free()
	var passed := rows.size() - me - 1
	var first := true
	# Your row stays in view: the three richest rivals above you, the rest folded.
	var start := 0 if _top_open else maxi(0, me - 3)
	if me > 3:
		var t := _toggle("Hide richer rivals" if _top_open else "Show %d more" % (me - 3), _top_open)
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
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num := UI.display(str(i + 1), 22, UI.RED if it["me"] else UI.DIM)
	num.custom_minimum_size = Vector2(28, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.set_lead(num)
	r.set_texts(it["name"], it["sub"], worth_text(it["worth"]))
	if it["me"]:
		_me = r
		r.title_l.add_theme_font_override("font", UI.SEMI)
		r.add_theme_stylebox_override("normal", UI.box(UI.RAISED, 0))
	elif passed:
		r.modulate.a = 0.55  # already passed
	_list.add_child(r)


func _toggle(text: String, open: bool) -> Row:
	## A quiet row that folds or unfolds a group; the chevron turns when open.
	var t := Row.new("", "", false)
	t.set_texts(text)
	t.title_l.add_theme_color_override("font_color", UI.SUB)
	var chev := Icon.new("chevron", UI.DIM, 16.0)
	chev.custom_minimum_size = Vector2(16, 16)
	chev.pivot_offset = Vector2(8, 8)
	chev.rotation = -PI / 2.0 if open else PI / 2.0
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A plain holder: containers reset a child's rotation, so turn it inside.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(16, 16)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(chev)
	t.value_l.get_parent().get_parent().add_child(holder)
	return t


func _add_toggle(n: int) -> void:
	var t := _toggle("Hide passed rivals" if _open else "Passed (%d)" % n, _open)
	t.pressed.connect(func():
		Kit.tick()
		_open = not _open
		refresh())
	_list.add_child(t)


static func worth_text(v: float) -> String:
	## Exact to the pound while it fits a row (£1,353,325); short after that.
	if absf(v) < 1.0e12:
		return Game.CUR + Game.group(int(floor(v))) if v >= 1000.0 else Game.money(v)
	return Game.money_short(v)
