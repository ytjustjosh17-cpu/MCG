class_name AchievementsPage
extends Page
## All achievements with progress.

var _rows: Array = []


func _init() -> void:
	super("Achievements", true)


func build() -> void:
	var list := card()
	var all := Game.achievements()
	for i in range(all.size()):
		if i > 0:
			separator(list, 50)
		var r := Row.new("lock", "", false)
		r.custom_minimum_size = Vector2(0, 56)
		list.add_child(r)
		_rows.append([all[i], r])


func refresh() -> void:
	for e in _rows:
		var a: Dictionary = e[0]
		var r: Row = e[1]
		var got := Game.achieved.has(a["id"])
		var have := Game.metric(a["m"])
		var goal: float = a["goal"]
		var prog := ""
		if a["m"] in ["worth", "shares", "crypto_profit"]:
			prog = "%s of %s" % [Game.money_short(minf(have, goal)), Game.money_short(goal)]
		else:
			prog = "%s of %s" % [Game.group(int(minf(have, goal))), Game.group(int(goal))]
		r.set_texts(a["title"], "" if got else prog, "")
		var ic: Icon = r.lead
		ic.kind = "check" if got else "lock"
		ic.set_style(UI.RED if got else UI.DIM)
		r.title_l.add_theme_color_override("font_color", UI.TEXT if got else UI.SUB)
