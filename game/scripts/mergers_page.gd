class_name MergersPage
extends Page
## Join companies into bigger groups for lasting income bonuses.
## Only the next one is open; the rest fold into one row each.

var _cards: Array = []  # [m, row, panel, need_rows, button]
var _open = null  # merger id shown open; null = the next one not merged


func _init() -> void:
	super("Mergers", true)


func build() -> void:
	body.add_child(UI.label("Join companies for bonus income", 15, UI.SUB))
	for m in Data.MERGERS:
		var id: String = m["id"]
		var c := card()
		var row := Row.new("check", "", false)
		row.pressed.connect(func():
			Kit.tick()
			_open = "" if _current_open() == id else id
			refresh())
		c.add_child(row)
		var p := padded(c, 16, 6)
		p.get_parent().add_theme_constant_override("margin_top", 0)
		var eff := UI.label(_effect(m), 15, UI.SUB)
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(eff)
		var rows: Array = []
		for n in m["needs"]:
			var r := HBoxContainer.new()
			r.custom_minimum_size = Vector2(0, 36)
			r.add_theme_constant_override("separation", 10)
			p.add_child(r)
			var tick := Icon.new("check", UI.DIM, 18.0)
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
		_cards.append([m, row, p.get_parent(), rows, btn])


func _effect(m: Dictionary) -> String:
	if m["boost"].is_empty():
		return "×2 income on everything"
	var names: Array = []
	for bid in m["boost"]:
		names.append(String(Data.business(bid)["name"]))
	return "×%s income: %s" % [str(snappedf(float(m["mult"]), 0.1)), ", ".join(names)]


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
		var mult := "×" + str(snappedf(float(m["mult"]), 0.1))
		(row.lead as Icon).visible = done
		if done:
			row.set_texts(m["name"], "", "Merged")
		else:
			row.set_texts(m["name"], "", "%s · %s" % [mult, Game.money_short(float(m["cost"]))])
		row.title_l.add_theme_font_override("font", UI.SEMI)
		(entry[2] as Control).visible = m["id"] == open
		for r in entry[3]:
			var ok: bool = Game.need_status(r[0])[0] or done
			var txt := _need(r[0])
			(r[1] as Icon).set_style(UI.TEXT if ok else UI.DIM, ok)
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
