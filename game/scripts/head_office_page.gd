class_name HeadOfficePage
extends Page
## Head office: one-off upgrades that change how the game works, in four
## small groups so the list never reads as a wall.

var _rows := {}
const ICONS := {"tap": "earn", "deals": "coins", "away1": "clock", "fast1": "level", "sun": "star",
	"lock": "lock", "mine": "cpu", "away2": "home", "fast2": "gauge", "mgr": "profile"}
const GROUPS := [
	["Taps and luck", ["tap", "deals", "sun"]],
	["While away", ["away1", "away2"]],
	["Companies", ["fast1", "fast2", "mgr"]],
	["Crypto", ["lock", "mine"]],
]


func _init() -> void:
	super("Head office", true)


func build() -> void:
	var hint := UI.label("Pay once. Each upgrade lasts for good.", 15, UI.SUB)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var placed := {}
	for g in GROUPS:
		section(g[0])
		var c := card()
		var first := true
		for uid in g[1]:
			if Game.upgrade(uid).is_empty():
				continue
			if not first:
				separator(c, 50)
			first = false
			_add_row(c, uid)
			placed[uid] = true
	# Anything added later without a group still shows, at the end.
	var others: Array = []
	for u in Data.UPGRADES:
		if not placed.has(u[0]):
			others.append(u[0])
	if not others.is_empty():
		section("More")
		var c2 := card()
		for i in range(others.size()):
			if i > 0:
				separator(c2, 50)
			_add_row(c2, others[i])


func _add_row(c: Control, uid: String) -> void:
	var r := Row.new(ICONS.get(uid, "sparkle"), "", false)
	r.pressed.connect(func(): _on_tap(uid))
	c.add_child(r)
	_rows[uid] = r


func refresh() -> void:
	for u in Data.UPGRADES:
		var r: Row = _rows.get(u[0])
		if r == null:
			continue
		var cost := float(u[3])
		r.set_texts(u[1], u[2])
		if Game.has_up(u[0]):
			BusinessPage.plain_value(r, "Owned")
		else:
			BusinessPage.price_pill(r, Game.money_short(cost), Game.cash >= cost)


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
