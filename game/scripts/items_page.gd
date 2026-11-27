class_name ItemsPage
extends Page
## Items tab: your home and the collections. What they do, in plain words:
## a full set (every item in it) adds its bonus to all income for good, each
## move up the home ladder adds +1%, and any item sells back for 80%.

var _sum_pct: Label
var _sum_cash: Label
var _total: Label
var _casino_row: Row
var _casino_lock: Icon
var _relic_sep: Control
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


static func gain_h(delta: float) -> float:
	## Extra income an hour if `delta` were added to the income bonus (full
	## sets and the home add to the same bonus, which the Holding doubles).
	var k := 2.0 if Game.mergers.has("holding") else 1.0
	return Game.base_income() * delta * k / maxf(Game.global_mult(), 0.01)


static func bonus_now() -> float:
	## Income bonus from your home and full sets together.
	var b := Data.HOME_BONUS * float(Game.home)
	for c in Game.collections():
		if Game.collection_done(String(c["id"])):
			b += float(c["bonus"])
	return b


static func pct(v: float) -> String:
	return "+%d%%" % int(round(v * 100.0))


func build() -> void:
	# What all of this does for you, before anything asks for money.
	var sc := card()
	var sp := padded(sc, 16, 14)
	sp.add_theme_constant_override("separation", 4)
	sp.add_child(UI.label("Income bonus from items", 13, UI.SUB))
	var sh := HBoxContainer.new()
	sp.add_child(sh)
	_sum_pct = UI.display("+0%", 28)
	_sum_pct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(_sum_pct)
	_sum_cash = UI.label("", 15, UI.TEXT, true)
	_sum_cash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(_sum_cash)
	var how := UI.label("Own a whole set to add its bonus to all income for good. Items sell back for 80%.", 13, UI.SUB)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sp.add_child(how)

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
	var now := bonus_now()
	_sum_pct.text = pct(now)
	_sum_cash.text = ("+" + Game.money_short(gain_h(now)) + " /h") if now > 0.0 and Game.base_income() > 0.0 else ""
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
	_home_sub.text = ("Each move up: +%d%% income" % step) if Game.home == 0 else ("Home bonus +%d%% income" % (step * Game.home))
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
		var g := gain_h(Data.HOME_BONUS)
		_next.text = String(Data.HOMES[Game.home + 1][0]) + ": +%d%% income" % step + ((" (+" + Game.money_short(g) + " /h)") if g >= 1.0 else "")
	else:
		_next.text = "Top home"
	var done := 0
	var relics := Game.rb("u_relics") > 0.0
	_rows["relics"].visible = relics
	if _relic_sep:
		_relic_sep.visible = relics
	for col in Game.collections():
		var cid: String = col["id"]
		var n := Game.collection_count(cid)
		var total: int = col["items"].size()
		var b := float(col["bonus"])
		var sub := ""
		if n == total:
			done += 1
			sub = "Done · %s income" % pct(b)
		else:
			var g := gain_h(b)
			sub = "Full set %s" % pct(b) + ((" · +" + Game.money_short(g) + " /h") if g >= 1.0 else " income")
		var r: Row = _rows[cid]
		r.set_texts(col["name"], sub, "%d / %d" % [n, total])
	_total.text = "Complete %d / %d" % [done, Game.collections().size()]


class CollectionPage extends Page:
	## One set: what finishing it gives, how far you are, and each item with
	## what buying it does.
	var cid := ""
	var _hero_art: ItemArt
	var _bonus: Label
	var _gain: Label
	var _bar: ProgressBar
	var _have: Label
	var _left: Label
	var _rows: Array = []
	var _bought_at := {}  # row index -> ms; a quick second tap must not offer to sell

	func _init(c := "") -> void:
		cid = c
		super(Game.collection(c)["name"], true)

	func build() -> void:
		var col := Game.collection(cid)
		# The reward, first and big.
		var hc := card()
		var hp := padded(hc, 16, 14)
		hp.add_theme_constant_override("separation", 10)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 14)
		hp.add_child(top)
		_hero_art = ItemArt.new(cid, col["items"].size() - 1, 72.0)
		_hero_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(_hero_art)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(tv)
		tv.add_child(UI.label("Full set bonus", 13, UI.SUB))
		_bonus = UI.display("", 28)
		tv.add_child(_bonus)
		_gain = UI.label("", 13, UI.SUB)
		tv.add_child(_gain)
		# How far through the set you are, and what's left to pay.
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.max_value = col["items"].size()
		_bar.custom_minimum_size = Vector2(0, 6)
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.add_theme_stylebox_override("background", UI.box(UI.TRACK, 3))
		_bar.add_theme_stylebox_override("fill", UI.box(UI.TEXT, 3))
		hp.add_child(_bar)
		var lh := HBoxContainer.new()
		hp.add_child(lh)
		_have = UI.label("", 13, UI.SUB)
		_have.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.add_child(_have)
		_left = UI.label("", 13, UI.SUB)
		lh.add_child(_left)
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
		var foot := UI.label("Items count only as a whole set. Sell any item back for %d%%." % int(round(Data.ITEM_RESALE * 100.0)), 13, UI.SUB)
		foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(foot)

	func _bonus_text() -> String:
		return ItemsPage.pct(float(Game.collection(cid)["bonus"])) + " income"

	func refresh() -> void:
		var col := Game.collection(cid)
		var total: int = col["items"].size()
		var have := Game.collection_count(cid)
		var done := Game.collection_done(cid)
		var b := float(col["bonus"])
		_hero_art.set_owned(done)
		_bonus.text = _bonus_text()
		var g := ItemsPage.gain_h(b)
		if done:
			_gain.text = "On for good" + ((" · +" + Game.money_short(g) + " /h") if g >= 1.0 else "")
		else:
			_gain.text = ("+" + Game.money_short(g) + " /h at your income now") if g >= 1.0 else "Adds to all your income"
		_bar.value = have
		_have.text = "%d of %d owned" % [have, total]
		var cost_left := 0.0
		for i in range(total):
			if not Game.item_owned(cid, i):
				cost_left += float(col["items"][i][1])
		_left.text = "" if done else Game.money_short(cost_left) + " to finish"
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
			# Only the next one to buy says what it does (repeating it on
			# every row was noise); the last missing one says it finishes.
			var sub := "Completes the set" if have == total - 1 else ""
			if next < 0:
				next = i
				var wait := Game.eta(price)
				if sub == "":
					sub = "Next · %d of %d" % [have + 1, total]
				if not can and wait != "":
					sub += " · afford in " + wait
			r.set_texts(it[0], sub)
			BusinessPage.price_pill(r, Game.money_short(price), can)

	func _tap(i: int) -> void:
		var it: Array = Game.collection(cid)["items"][i]
		if Game.item_owned(cid, i):
			if Time.get_ticks_msec() - int(_bought_at.get(i, -100000)) < 600:
				return  # double tap after buying: ignore, don't offer to sell
			var note := "The set bonus stops until you buy it back." if Game.collection_done(cid) else ""
			Kit.alert("Sell for %s (%d%%)?" % [Game.money_short(float(it[1]) * Data.ITEM_RESALE), int(round(Data.ITEM_RESALE * 100.0))], note, [
				{"text": "Keep", "style": "primary"},
				{"text": "Sell", "style": "secondary", "call": func():
					Game.sell_item(cid, i)
					Kit.toast("Sold")},
			])
		elif Game.buy_item(cid, i):
			_bought_at[i] = Time.get_ticks_msec()
			Kit.tick(20)
			if Game.collection_done(cid):
				Kit.haptic("success")
				Kit.toast("Set done · " + _bonus_text() + " for good", true)
			else:
				Kit.toast("Bought %s · %d of %d" % [String(it[0]), Game.collection_count(cid), Game.collection(cid)["items"].size()], true)
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
