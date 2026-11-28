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
	_podium = Podium.new()
	body.add_child(_podium)
	_list = card()
	# Your own row, pinned above the tab bar while the real one is scrolled away.
	_pin = PanelContainer.new()
	_pin.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 16))
	_pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin.visible = false
	add_child(_pin)
	_pin_row = Row.new("", "", false)
	_pin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num := UI.display("", 22, UI.RED)
	num.custom_minimum_size = Vector2(28, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pin_row.set_lead(num)
	_pin_num = num
	_pin_row.title_l.add_theme_font_override("font", UI.SEMI)
	_pin.add_child(_pin_row)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): _place_pin())
	resized.connect(_place_pin)
	Kit.layout_changed.connect(func(_l): _place_pin.call_deferred())


var _podium: Podium
var _pin: PanelContainer
var _pin_row: Row
var _pin_num: Label


func _place_pin() -> void:
	## Shows the pinned row only while your real row is out of sight, in the
	## same column as the list, just above the tab bar (or the bottom in landscape).
	if _pin == null or _list == null:
		return
	var side := 16.0
	if Kit.landscape:
		side = maxf(16.0, (size.x - Kit.COLUMN_MAX) * 0.5)
	_pin.anchor_left = 0.0
	_pin.anchor_right = 1.0
	_pin.anchor_top = 1.0
	_pin.anchor_bottom = 1.0
	_pin.offset_left = side
	_pin.offset_right = -side
	_pin.offset_bottom = -(16.0 if Kit.landscape else 92.0)
	_pin.offset_top = _pin.offset_bottom - 60.0
	var show := false
	if is_instance_valid(_me) and _me.size.y > 0.0 and not _me.is_queued_for_deletion():
		var r := _me.get_global_rect()
		var view := scroll.get_global_rect()
		view.size.y -= (16.0 if Kit.landscape else 92.0) + 60.0   # the part the pin would cover
		show = not view.encloses(r)
	_pin.visible = show


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
	_podium.set_rows(rows.slice(0, 3))
	_pin_num.text = str(me + 1)
	_pin_row.set_texts("You", "", worth_text(nw))
	_place_pin.call_deferred()
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
	t._h.add_child(holder)   # in the row itself, so it centres on the text (not under an empty value line)
	return t


func _add_toggle(n: int) -> void:
	var t := _toggle("Hide passed rivals" if _open else "Passed (%d)" % n, _open)
	t.pressed.connect(func():
		Kit.tick()
		_open = not _open
		refresh())
	_list.add_child(t)


class Podium extends PanelContainer:
	## The three richest, flat: three blocks with #1 tallest in the middle,
	## name and fortune under each. No glow; the house teal with one TEXT accent.
	var _cols: Array = []   # [block, rank, name, worth] for places 2, 1, 3

	func _init() -> void:
		add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16, 12, 12))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
		for place in [2, 1, 3]:
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.alignment = BoxContainer.ALIGNMENT_END
			col.add_theme_constant_override("separation", 2)
			row.add_child(col)
			var nm := UI.label("", 13, UI.TEXT, true)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.clip_text = true
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			col.add_child(nm)
			var w := UI.label("", 13, UI.SUB)
			w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(w)
			var blk := PanelContainer.new()
			blk.add_theme_stylebox_override("panel", UI.box(UI.RAISED if place != 1 else UI.TEXT, 10))
			blk.custom_minimum_size = Vector2(0, [0, 64, 46, 34][place])
			col.add_child(blk)
			var rk := UI.display(str(place), 22, UI.INK if place == 1 else UI.TEXT)
			rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			blk.add_child(rk)
			_cols.append([blk, rk, nm, w])

	func set_rows(top: Array) -> void:
		var order := [1, 0, 2]   # columns show places 2, 1, 3
		for k in range(3):
			var c: Array = _cols[k]
			var i: int = order[k]
			if i >= top.size():
				(c[2] as Label).text = ""
				(c[3] as Label).text = ""
				continue
			var it: Dictionary = top[i]
			(c[2] as Label).text = String(it["name"])
			(c[3] as Label).text = Game.money_short(float(it["worth"]))
			(c[2] as Label).add_theme_color_override("font_color", UI.RED if it["me"] else UI.TEXT)


static func worth_text(v: float) -> String:
	## Exact to the pound while it fits a row (£1,353,325); short after that.
	if absf(v) < 1.0e12:
		return Game.CUR + Game.group(int(floor(v))) if v >= 1000.0 else Game.money(v)
	return Game.money_short(v)
