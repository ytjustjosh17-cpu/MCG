extends SceneTree
## Landscape test: the phone held sideways (844 x 390 game units). Opens the
## Business, Invest, Items and Profile tabs, their pushed pages and every
## trade sheet in a rich late game, and fails if:
##   - a button sits off screen and no scroll view can bring it into view,
##   - anything on a page sits under the tab rail on the left (x < 84),
##   - a trade sheet's confirm button is not fully on screen.
## Then turns the phone back upright and checks the amount in an open sheet
## survived both turns.
##   godot --headless --path game -s res://tests/landscape_test.gd

const W := 844.0
const H := 390.0
const RAIL_END := 84.0   # Kit.RAIL_W + 12 px gap: page content starts here

var fails := 0
var main
var g
var problems: Array = []
var checked := 0


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func():
		print("FAIL  timed out")
		print("Failures: ", fails + 1)
		quit(1))
	_run.call_deferred()


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _in_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _audit(where: String) -> void:
	await create_timer(0.7).timeout
	var root_c: Control = main._stack.back() if not main._stack.is_empty() else main._pages[main._current]
	for n in root_c.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 2.0 or c.size.y < 2.0:
			continue
		if not (c is BaseButton or c is Label):
			continue
		if c is Label and (c as Label).text.strip_edges() == "":
			continue
		var r := c.get_global_rect()
		checked += 1
		if r.position.x < RAIL_END - 1.0:
			problems.append("%s: under the rail '%s' (x %d)" % [where, _name(c), int(r.position.x)])
		elif r.end.x > W + 1.0:
			problems.append("%s: off the right '%s' (end %d)" % [where, _name(c), int(r.end.x)])
		elif c is BaseButton and (r.position.y < -1.0 or r.end.y > H + 1.0) and not _in_scroll(c):
			problems.append("%s: button off screen, can't scroll to it '%s'" % [where, _name(c)])


static func _name(c: Control) -> String:
	if c is Label:
		return (c as Label).text.left(30)
	if c is Button and (c as Button).text != "":
		return (c as Button).text.left(30)
	return c.name


func _push(p: Control, where: String) -> void:
	main.push(p)
	await create_timer(0.9).timeout
	await _audit(where)
	main.pop()
	await create_timer(0.6).timeout


func _sheet_check(k: String, s: String, m: String) -> void:
	var kit = root.get_node("Kit")
	TradeSheet.open(k, s, m)
	await create_timer(0.8).timeout
	var ts: TradeSheet = null
	if kit.has_open():
		var found: Array = kit._stack.back()["root"].find_children("*", "TradeSheet", true, false)
		if not found.is_empty():
			ts = found[0]
	if ts == null:
		_ok(false, "sheet %s %s opens" % [m, s])
		return
	var r := ts._go.get_global_rect()
	var inside := r.position.x >= -1.0 and r.position.y >= -1.0 and r.end.x <= W + 1.0 and r.end.y <= H + 1.0
	# Inside a scrolling card the button must also be within the visible part.
	var p := ts._go.get_parent()
	while p != null:
		if p is ScrollContainer:
			var sr := (p as ScrollContainer).get_global_rect()
			inside = inside and r.position.y >= sr.position.y - 1.0 and r.end.y <= sr.end.y + 1.0
		p = p.get_parent()
	_ok(ts._go.is_visible_in_tree() and inside, "%s %s: confirm button fully on screen (%d,%d to %d,%d)" % [m, s, int(r.position.x), int(r.position.y), int(r.end.x), int(r.end.y)])
	kit.close_top()
	await create_timer(0.5).timeout


func _run() -> void:
	g = root.get_node("Game")
	root.size = Vector2i(int(W), int(H))   # the phone held sideways
	g.reset_game(true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	var kit = root.get_node("Kit")
	_ok(kit.landscape, "an 844 x 390 window counts as landscape")
	_ok(absf(root.get_visible_rect().size.x - W) < 2.0 and absf(root.get_visible_rect().size.y - H) < 2.0, "the visible area is 844 x 390 game units")
	g.ui["guide_done"] = true
	g.reduce_motion = true
	# A rich, late game: long names and big numbers everywhere (like fit_test).
	g.cash = 4.56789e15
	for b in Data.BUSINESSES:
		g.open_business(b["id"], Data.business(b["id"])["names"][0])
		g.biz[b["id"]]["units"] = g.capacity(b["id"]) - 3
		g.biz[b["id"]]["stage"] = 6
	g.hire_manager("shop")
	for s in Data.STOCKS:
		g.buy_asset("share", s[0], 3.3e11)
	for c in Data.COINS:
		g.buy_asset("coin", c[0], 3.3e11)
	for i in Data.PROPERTIES.size():
		g.buy_property(i)
	for nid in ["u_casino", "u_tables", "u_frontier", "u_isles", "u_relics"]:
		g.grant_node(nid)
	g.cash = 4.56789e15
	g.buy_chips(9.87654e12)
	g.deposit(1.23456e13)
	g.buy_miner()
	g.streak_unseen = []
	g.away_unseen = false
	g.recalc()
	while kit.close_top():
		await create_timer(0.3).timeout
	for ti in [1, 2, 3, 4]:
		main.show_page(ti)
		await _audit("tab %d" % ti)
	var inv = main._pages[2]
	for seg in 3:
		main.show_page(2)
		inv._seg.select(seg, true)
		await _audit("invest %d" % seg)
	for path_arg in [["res://scripts/business_detail.gd", "shop"], ["res://scripts/start_business_page.gd", ""],
			["res://scripts/settings_page.gd", ""], ["res://scripts/goals_page.gd", ""], ["res://scripts/stats_page.gd", ""],
			["res://scripts/bank_page.gd", ""], ["res://scripts/achievements_page.gd", ""], ["res://scripts/rivals_page.gd", ""],
			["res://scripts/records_page.gd", ""], ["res://scripts/mergers_page.gd", ""], ["res://scripts/head_office_page.gd", ""],
			["res://scripts/news_page.gd", ""]]:
		var pg = load(path_arg[0]).new(path_arg[1]) if path_arg[1] != "" else load(path_arg[0]).new()
		await _push(pg, path_arg[0].get_file().get_basename())
	await _push(AssetDetail.new("share", "QSF"), "share QSF")
	await _push(AssetDetail.new("coin", "SHIB"), "coin SHIB")
	await _push(load("res://scripts/property_detail.gd").new(0), "property")
	await _push(ItemsPage.CollectionPage.new("jets"), "collection")
	# Every trade sheet: its confirm button must be fully on screen.
	for m in [["coin", "SHIB", "buy"], ["coin", "SHIB", "sell"], ["coin", "SHIB", "convert"], ["coin", "SHIB", "lock"],
			["share", "QSF", "buy"], ["share", "QSF", "sell"], ["chips", "", "chips_in"], ["chips", "", "chips_out"],
			["bank", "", "bank_in"], ["bank", "", "bank_out"]]:
		await _sheet_check(m[0], m[1], m[2])
	# Turning the phone with a sheet open keeps what you chose.
	TradeSheet.open("coin", "SHIB", "sell")
	await create_timer(0.8).timeout
	var ts: TradeSheet = kit._stack.back()["root"].find_children("*", "TradeSheet", true, false)[0]
	ts.frac = 0.25
	ts._slider.set_value(0.25)
	ts._update()
	var before: float = ts._amount
	root.size = Vector2i(390, 844)
	await create_timer(0.6).timeout
	_ok(not kit.landscape and is_instance_valid(ts) and ts._go.is_visible_in_tree(), "turned upright: the same sheet is still open")
	root.size = Vector2i(int(W), int(H))
	await create_timer(0.6).timeout
	_ok(is_instance_valid(ts) and absf(ts._amount - before) <= maxf(1.0, before * 0.02), "turned twice: the amount is kept (%.0f vs %.0f)" % [ts._amount, before])
	kit.close_top()
	await create_timer(0.4).timeout
	_ok(checked > 300, "the audit looked at enough buttons and text (%d)" % checked)
	for p in problems:
		print("  ", p)
	_ok(problems.is_empty(), "landscape: nothing under the rail or off screen (%d problems)" % problems.size())
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
