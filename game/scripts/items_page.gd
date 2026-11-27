class_name ItemsPage
extends Page
## Items tab: collections. Finishing one raises all income for good.

var _total: Label
var _casino_row: Row
var _casino_lock: Icon
var _relic_sep: Control
var _hint: Label
var _rows := {}
var _home_art: Control
var _home_kind := ""
var _home_name: Label
var _home_sub: Label
var _steps: Label
var _move: Button
var _next: Label
var _ladder: Array = []


func _init() -> void:
	super("Items")


func build() -> void:
	# Home: where you live, and the next step up.
	var hc := card()
	# The home picture is a button: tap it to look inside (1.2).
	var hb := Button.new()
	hb.focus_mode = Control.FOCUS_NONE
	hb.flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		hb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hb.custom_minimum_size = Vector2(0, 88)
	hb.clip_contents = true
	hb.pressed.connect(_look_inside)
	Kit.press_fx(hb)
	hc.add_child(hb)
	_home_art = Control.new()
	_home_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_child(_home_art)
	# Name and bonus, with "Look inside" as a clear row of its own (never
	# text over the art).
	var hp := padded(hc, 16, 4)
	var nh := HBoxContainer.new()
	hp.add_child(nh)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 2)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(nv)
	_home_name = UI.label("", 17, UI.TEXT, true)
	nv.add_child(_home_name)
	_home_sub = UI.label("", 13, UI.SUB)
	nv.add_child(_home_sub)
	var inside := UI.pill("Look inside", UI.RAISED, UI.TEXT, 15, 20)
	inside.custom_minimum_size = Vector2(0, UI.BTN_H)
	inside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inside.pressed.connect(_look_inside)
	Kit.press_fx(inside)
	nh.add_child(inside)
	# The ladder: one small step mark per home, lit up to where you are.
	var lad := HBoxContainer.new()
	lad.add_theme_constant_override("separation", 4)
	lad.custom_minimum_size = Vector2(0, 28)
	hp.add_child(lad)
	for i in range(1, Data.HOMES.size()):
		var sq := ColorRect.new()
		sq.custom_minimum_size = Vector2(0, 6)
		sq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lad.add_child(sq)
		_ladder.append(sq)
	_steps = UI.label("", 13, UI.SUB)
	_steps.custom_minimum_size = Vector2(40, 0)
	_steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lad.add_child(_steps)
	_move = button("", true, _on_move)
	_move.custom_minimum_size.y = UI.BTN_PRIMARY_H
	hp.add_child(_move)
	_next = UI.label("", 13, UI.SUB)
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_child(_next)

	# The casino lives with your lifestyle.
	var cc := card()
	_casino_row = Row.new()
	_casino_row.set_lead(CasinoPage.CasinoArt.new("roulette", 44.0))
	# Locked: a lock where the value goes, and the art dimmed.
	_casino_lock = Icon.new("lock", UI.SUB, 18.0)
	_casino_lock.size_flags_horizontal = Control.SIZE_SHRINK_END
	_casino_row.value_l.get_parent().add_child(_casino_lock)
	_casino_row.pressed.connect(func():
		Kit.tick()
		push_page.emit(CasinoPage.new()))
	cc.add_child(_casino_row)

	_total = section("Collections")   # right: "Complete 2 / 6"
	_hint = UI.label("Own a full set for bonus income", 13, UI.SUB)
	body.add_child(_hint)
	var list := card()
	var all_cols: Array = Data.COLLECTIONS + [Data.RELICS]   # relics show once unlocked in the tree
	for i in range(all_cols.size()):
		if i > 0:
			separator(list)
			if i == all_cols.size() - 1:
				_relic_sep = list.get_child(list.get_child_count() - 1)
		var col: Dictionary = all_cols[i]
		var r := Row.new()
		var cid: String = col["id"]
		r.set_lead(ItemArt.new(cid, 5, 44.0))   # each set shows its top item
		r.pressed.connect(func():
			Kit.tick()
			push_page.emit(CollectionPage.new(cid)))
		list.add_child(r)
		_rows[cid] = r


func refresh() -> void:
	if _total == null:
		return
	var open := Game.casino_open()
	if open:
		_casino_row.set_texts("Casino", "Slots and tables", "Chips " + Game.money_short(Game.chips()) if Game.chips() >= 0.01 else "")
	else:
		_casino_row.set_texts("Casino", "Unlocks in the Rebirth tree", "")
	_casino_row.lead.modulate.a = 1.0 if open else 0.4
	_casino_row.title_l.add_theme_color_override("font_color", UI.TEXT if open else UI.SUB)
	_casino_lock.visible = not open
	_casino_row.value_l.visible = open
	var h: Array = Data.HOMES[Game.home]
	if _home_kind != String(h[3]):
		_home_kind = h[3]
		for ch in _home_art.get_children():
			ch.queue_free()
		var sc := Art.Scene.new(h[3], 16.0)
		sc.seed_id = String(h[0])
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_home_art.add_child(sc)
	_home_name.text = h[0]
	var step := int(round(Data.HOME_BONUS * 100.0))
	_home_sub.text = ("+%d%% income each move" % step) if Game.home == 0 else ("+%d%% income" % (step * Game.home))
	for i in range(_ladder.size()):
		_ladder[i].color = UI.TEXT if i < Game.home else UI.TRACK
	_steps.text = "%d / %d" % [Game.home, _ladder.size()]
	var nc := Game.next_home_cost()
	_move.visible = nc > 0.0
	if nc > 0.0:
		var can := Game.cash >= nc
		var wait := Game.eta(nc)
		if can:
			_move.text = "Move up · " + Game.money_short(nc)
		else:
			_move.text = Game.money_short(nc) + ((" · " + wait) if wait != "" else "")
		Page.set_enabled(_move, can)
		_next.text = "Next: " + String(Data.HOMES[Game.home + 1][0])
	else:
		_next.text = "Top home"
	var done := 0
	var started := false
	var bonus := 0.0
	var relics := Game.rb("u_relics") > 0.0
	_rows["relics"].visible = relics
	if _relic_sep:
		_relic_sep.visible = relics
	for col in Game.collections():
		var cid: String = col["id"]
		var n := Game.collection_count(cid)
		var total: int = col["items"].size()
		if n > 0:
			started = true
		var sub := "Done"
		if n == total:
			done += 1
			bonus += float(col["bonus"])
		else:
			for i in range(total):
				if not Game.item_owned(cid, i):
					sub = "Next " + Game.money_short(col["items"][i][1])
					break
		var r: Row = _rows[cid]
		r.set_texts(col["name"], sub, "%d / %d" % [n, total])
	_total.text = "Complete %d / %d" % [done, Game.collections().size()]
	if bonus > 0.0:
		_total.text += " · +%d%%" % int(round(bonus * 100.0))
	_hint.visible = not started


class CollectionPage extends Page:
	var cid := ""
	var _note: Label
	var _bar: ProgressBar
	var _rows: Array = []
	var _bought_at := {}  # row index -> ms; a quick second tap must not offer to sell

	func _init(c := "") -> void:
		cid = c
		super(Game.collection(c)["name"], true)

	func build() -> void:
		_note = UI.label("", 15, UI.SUB)
		_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(_note)
		var col := Game.collection(cid)
		# How far through the set you are.
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.max_value = col["items"].size()
		_bar.custom_minimum_size = Vector2(0, 6)
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.add_theme_stylebox_override("background", UI.box(UI.TRACK, 3))
		_bar.add_theme_stylebox_override("fill", UI.box(UI.TEXT, 3))
		body.add_child(_bar)
		var list := card()
		for i in range(col["items"].size()):
			if i > 0:
				separator(list)
			var r := Row.new("", "", false)
			var idx := i
			r.set_lead(ItemArt.new(cid, i, 48.0))   # each item has its own picture
			r.pressed.connect(func(): _tap(idx))
			list.add_child(r)
			_rows.append(r)

	func _bonus_text() -> String:
		return "+%d%% income" % int(round(float(Game.collection(cid)["bonus"]) * 100.0))

	func refresh() -> void:
		var col := Game.collection(cid)
		var have := Game.collection_count(cid)
		_bar.value = have
		if Game.collection_done(cid):
			_note.text = "Done · " + _bonus_text()
		else:
			_note.text = "%d of %d owned · all for %s" % [have, col["items"].size(), _bonus_text()]
		var next := -1
		for i in range(_rows.size()):
			var it: Array = col["items"][i]
			var r: Row = _rows[i]
			(r.lead as ItemArt).set_owned(Game.item_owned(cid, i))
			var price := float(it[1])
			if Game.item_owned(cid, i):
				r.set_texts(it[0], "Owned")
				BusinessPage.plain_value(r, "Sell " + Game.money_short(price * Data.ITEM_RESALE))
				continue
			var can := Game.cash >= price
			var sub := ""
			if next < 0:
				next = i
				var wait := Game.eta(price)
				sub = ("Afford in " + wait) if wait != "" else ""
			r.set_texts(it[0], sub)
			BusinessPage.price_pill(r, Game.money_short(price), can)

	func _tap(i: int) -> void:
		var it: Array = Game.collection(cid)["items"][i]
		if Game.item_owned(cid, i):
			if Time.get_ticks_msec() - int(_bought_at.get(i, -100000)) < 600:
				return  # double tap after buying: ignore, don't offer to sell
			Kit.alert("Sell for %s (%d%%)?" % [Game.money_short(float(it[1]) * Data.ITEM_RESALE), int(round(Data.ITEM_RESALE * 100.0))], "", [
				{"text": "Keep", "style": "primary"},
				{"text": "Sell", "style": "secondary", "call": func():
					Game.sell_item(cid, i)
					Kit.toast("Sold")},
			])
		elif Game.buy_item(cid, i):
			_bought_at[i] = Time.get_ticks_msec()
			Kit.tick(20)
			if Game.collection_done(cid):
				Kit.toast("Set done · " + _bonus_text(), true)
			else:
				Kit.toast("Bought " + String(it[0]), true)
		else:
			Kit.toast("Need " + Game.money_short(float(it[1]) - Game.cash) + " more")


func _look_inside() -> void:
	Kit.tick()
	push_page.emit(HomePage.new())


func _on_move() -> void:
	var nc := Game.next_home_cost()
	if nc <= 0.0:
		return
	var nh: Array = Data.HOMES[Game.home + 1]
	Kit.sheet(nh[0], "+%d%% income for good" % int(round(Data.HOME_BONUS * 100.0)), [
		{"text": "Move for " + Game.money_short(nc), "style": "primary", "call": func():
			if Game.move_home():
				Kit.haptic("success")
				Motion.pop(_home_name, 1.08)
				Kit.toast("Moved to " + String(nh[0]), true)},
		{"text": "Not yet", "style": "plain"},
	])
