class_name MergersPage
extends Page
## Join companies into bigger groups for lasting income bonuses.
## Only the next one is open; the rest fold into one row each.

var _cards: Array = []  # [m, row, panel, need_rows, button, chip]
var _open = null  # merger id shown open; null = the next one not merged


func _init() -> void:
	super("Mergers", true)


func build() -> void:
	body.add_child(UI.label("Join companies for bonus income", 15, UI.SUB))
	for m in Data.MERGERS:
		var id: String = m["id"]
		var c := card()
		var row := Row.new("check")   # the chevron says it opens
		row.pressed.connect(func():
			Kit.tick()
			_open = "" if _current_open() == id else id
			refresh())
		c.add_child(row)
		row.title_l.add_theme_font_override("font", UI.SEMI)
		# The bonus as a small chip beside the name; the price is the one value.
		row.title_l.size_flags_horizontal = Control.SIZE_FILL
		var chip := UI.label("", 13, UI.TEXT, true)
		chip.add_theme_stylebox_override("normal", UI.box(UI.RAISED, 10, 8, 2))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.title_l.get_parent().add_child(chip)
		var p := padded(c, 16, 6)
		p.get_parent().add_theme_constant_override("margin_top", 0)
		var rows: Array = []
		for n in m["needs"]:
			var r := HBoxContainer.new()
			r.custom_minimum_size = Vector2(0, 36)
			r.add_theme_constant_override("separation", 10)
			p.add_child(r)
			var tick := Tick.new()
			tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(tick)
			var l := UI.label("", 15)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(l)
			var have := UI.label("", 15, UI.SUB)
			have.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(have)
			rows.append([n, tick, l, have])
		var btn := button("Merge", true, func(): _merge(id))
		p.add_child(btn)
		_cards.append([m, row, p.get_parent(), rows, btn, chip])


func _effect(m: Dictionary) -> String:
	if m["boost"].is_empty():
		return "Lifts everything"
	var names: Array = []
	for bid in m["boost"]:
		names.append(String(Data.business(bid)["name"]))
	# Short enough for one line: one name, then how many more.
	if names.size() == 1:
		return "Lifts " + names[0]
	return "Lifts %s and %d more" % [names[0], names.size() - 1]


func _need(n: Array) -> Array:
	## Short label and "have / need" text for one requirement.
	var st: Array = Game.need_status(n)
	match n[0]:
		"biz":
			var stg := int(Game.biz[n[1]]["stage"]) if Game.biz.has(n[1]) else 0
			return [String(Data.business(n[1])["name"]), "Stage %d / %d" % [stg, n[2]]]
		"props":
			return ["Properties", "%d / %d" % [Game.props_owned(), n[1]]]
		"shares":
			return ["Shares", "%s / %s" % [st[2], Game.money_short(float(n[1]))]]
		"crypto":
			return ["Crypto", "%s / %s" % [st[2], Game.money_short(float(n[1]))]]
		"collection":
			return [String(Game.collection(n[1])["name"]), String(st[2]).replace(" of ", " / ")]
		"mergers":
			return ["Other mergers", "%d / %d" % [mini(Game.mergers.size(), int(n[1])), n[1]]]
	return [String(st[1]), String(st[2])]


func _current_open() -> String:
	if _open != null:
		return _open
	for m in Data.MERGERS:
		if not Game.mergers.has(m["id"]):
			return m["id"]
	return ""


func refresh() -> void:
	var open := _current_open()
	for entry in _cards:
		var m: Dictionary = entry[0]
		var row: Row = entry[1]
		var done := Game.mergers.has(m["id"])
		(row.lead as Icon).visible = done
		(entry[5] as Label).text = "×" + str(snappedf(float(m["mult"]), 0.1))
		row.set_texts(m["name"], _effect(m), "Merged" if done else Game.money_short(float(m["cost"])))
		row.title_l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING   # short names; the chip sits right after
		row.value_l.add_theme_color_override("font_color", UI.SUB if done else UI.TEXT)
		(entry[2] as Control).visible = m["id"] == open
		for r in entry[3]:
			var ok: bool = Game.need_status(r[0])[0] or done
			var txt := _need(r[0])
			(r[1] as Tick).set_done(ok)
			(r[2] as Label).text = txt[0]
			(r[2] as Label).add_theme_color_override("font_color", UI.TEXT if ok else UI.SUB)
			(r[3] as Label).text = "Done" if done else txt[1]
		var btn: Button = entry[4]
		btn.visible = not done
		btn.text = "Merge · " + Game.money_short(float(m["cost"]))
		Page.set_enabled(btn, Game.merger_ready(m) and Game.cash >= float(m["cost"]))


func _merge(id: String) -> void:
	if Game.merge(id):
		Kit.tick(40)
		Kit.toast("Merged", true)
		_open = null
		Game.flush_changes()
	else:
		var m: Dictionary = {}
		for x in Data.MERGERS:
			if x["id"] == id:
				m = x
		if Game.merger_ready(m):
			Kit.toast("Need %s more" % Game.money_short(float(m["cost"]) - Game.cash))


class Tick extends Control:
	## Done: a filled TEXT check. Not yet: an empty ring. Easy to tell apart.
	var done := false

	func _init() -> void:
		custom_minimum_size = Vector2(20, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_done(d: bool) -> void:
		if d != done:
			done = d
			queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		if done:
			draw_circle(c, 10.0, UI.TEXT)
			draw_polyline(PackedVector2Array([c + Vector2(-4.5, 0.5), c + Vector2(-1.2, 3.8), c + Vector2(5.0, -3.2)]), UI.INK, 2.2, true)
		else:
			draw_arc(c, 9.0, 0.0, TAU, 40, UI.SUB, 1.5, true)
