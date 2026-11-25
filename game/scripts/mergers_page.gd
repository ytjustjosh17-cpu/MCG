class_name MergersPage
extends Page
## Combine what you own into bigger groups for permanent income bonuses.

var _cards: Array = []


func _init() -> void:
	super("Mergers", true)


func build() -> void:
	for m in Data.MERGERS:
		var c := card()
		var p := padded(c, 16, 6)
		var h := HBoxContainer.new()
		p.add_child(h)
		var name := UI.label(m["name"], 22, UI.TEXT, true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name)
		var status := UI.label("", 13, UI.SUB)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(status)
		var rows: Array = []
		for n in m["needs"]:
			var r := HBoxContainer.new()
			r.custom_minimum_size = Vector2(0, 36)
			r.add_theme_constant_override("separation", 10)
			p.add_child(r)
			var box := ColorRect.new()
			box.custom_minimum_size = Vector2(14, 14)
			box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(box)
			var l := UI.label("", 15)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(l)
			var have := UI.label("", 13, UI.SUB)
			have.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(have)
			rows.append([n, box, l, have])
		var eff := UI.label(_effect(m), 13, UI.SUB)
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.add_child(eff)
		var id: String = m["id"]
		var btn := button("Merge", true, func(): _merge(id))
		p.add_child(btn)
		_cards.append([m, status, rows, btn])


func _effect(m: Dictionary) -> String:
	if m["boost"].is_empty():
		return "Income ×2 on everything"
	var names: Array = []
	for bid in m["boost"]:
		names.append(String(Data.business(bid)["name"]).to_lower())
	return "Income ×%s on %s" % [str(snappedf(float(m["mult"]), 0.1)), ", ".join(names)]


func refresh() -> void:
	for entry in _cards:
		var m: Dictionary = entry[0]
		var done := Game.mergers.has(m["id"])
		var ready := 0
		for r in entry[2]:
			var st: Array = Game.need_status(r[0])
			var ok: bool = st[0] or done
			(r[1] as ColorRect).color = UI.RED if ok else UI.TRACK
			(r[2] as Label).text = st[1]
			(r[2] as Label).add_theme_color_override("font_color", UI.TEXT if ok else UI.SUB)
			(r[3] as Label).text = st[2]
			if ok:
				ready += 1
		var btn: Button = entry[3]
		if done:
			(entry[1] as Label).text = "Merged"
			btn.text = "Merged"
			Page.set_enabled(btn, false)
		else:
			(entry[1] as Label).text = "%d / %d" % [ready, entry[2].size()]
			btn.text = "Merge · " + Game.money_short(m["cost"])
			Page.set_enabled(btn, Game.merger_ready(m) and Game.cash >= float(m["cost"]))


func _merge(id: String) -> void:
	if Game.merge(id):
		Kit.tick(40)
		Kit.toast("Merger complete", true)
		Game.flush_changes()
