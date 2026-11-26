class_name HeadOfficePage
extends Page
## Head office: one-off upgrades that change how the game works.

var _rows := {}
const ICONS := {"tap": "earn", "deals": "coins", "away1": "clock", "fast1": "level", "sun": "star",
	"lock": "lock", "mine": "cpu", "away2": "clock", "fast2": "level", "mgr": "profile"}


func _init() -> void:
	super("Head office", true)


func build() -> void:
	var hint := UI.label("Pay once. Each upgrade lasts for good.", 15, UI.SUB)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var c := card()
	for i in range(Data.UPGRADES.size()):
		if i > 0:
			separator(c, 50)
		var u: Array = Data.UPGRADES[i]
		var r := Row.new(ICONS.get(u[0], "sparkle"), "", false)
		r.custom_minimum_size = Vector2(0, 64)
		var id: String = u[0]
		r.pressed.connect(func(): _on_tap(id))
		c.add_child(r)
		_rows[id] = r


func refresh() -> void:
	for u in Data.UPGRADES:
		var r: Row = _rows.get(u[0])
		if r == null:
			continue
		var cost := float(u[3])
		if Game.has_up(u[0]):
			r.set_texts(u[1], u[2], "Owned")
			r.value_l.add_theme_color_override("font_color", UI.SUB)
		else:
			r.set_texts(u[1], u[2], "Buy · " + Game.money_short(cost))
			r.value_l.add_theme_color_override("font_color", UI.TEXT if Game.cash >= cost else UI.SUB)


func _on_tap(id: String) -> void:
	Kit.tick()
	if Game.has_up(id):
		return
	var u := Game.upgrade(id)
	var cost := float(u[3])
	var can := Game.cash >= cost
	var wait := Game.eta(cost)
	Kit.sheet(u[1], String(u[2]) + ". For good.", [
		{"text": ("Buy · " + Game.money_short(cost)) if can else ("Need %s more" % Game.money_short(cost - Game.cash)) + (" · " + wait if wait != "" else ""), "style": "primary", "disabled": not can, "call": func():
			if Game.buy_upgrade(id):
				Kit.haptic("success")
				Kit.toast(String(u[1]) + " · done", true)
				Game.flush_changes()},
		{"text": "Close", "style": "plain"},
	])
