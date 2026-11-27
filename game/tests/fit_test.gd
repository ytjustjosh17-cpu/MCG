extends SceneTree
## Fit test: opens every screen (and the main pop-ups) in a rich late-game
## state with long numbers, and fails if any text is cut off ("...") or
## anything sits outside the 390 px wide screen.
##   godot --headless --path game -s res://tests/fit_test.gd

var fails := 0
var main
var g
var problems: Array = []
var checked := 0
var land := false   # `-- land`: the same checks with the phone held sideways (844 x 390)


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


func _audit(where: String) -> void:
	await create_timer(0.7).timeout
	var roots: Array = []
	if not main._stack.is_empty():
		roots.append(main._stack.back())
	else:
		roots.append(main._pages[main._current])
	var kit = root.get_node("Kit")
	if kit.has_open():
		roots = [kit._stack.back()["root"]]
	var view := root.get_visible_rect()
	var wide := view.size.x
	for rc in roots:
		for n in (rc as Node).find_children("*", "Label", true, false):
			var l := n as Label
			if not l.is_visible_in_tree() or l.text.strip_edges() == "" or l.modulate.a < 0.05:
				continue
			var r := l.get_global_rect()
			if r.size.x < 2.0:
				continue
			if not view.intersects(r):
				continue   # scrolled out of view vertically is fine
			if r.position.x < -1.0 or r.end.x > wide + 1.0:
				problems.append("%s: off screen '%s'" % [where, l.text.left(40)])
				continue
			if land and r.position.x < 84.0 - 1.0 and not kit.has_open():
				problems.append("%s: under the tab rail '%s'" % [where, l.text.left(40)])
				continue
			checked += 1
			if l.get_theme_font_size("font_size") < 13:
				problems.append("%s: text under 13 px (%d) '%s'" % [where, l.get_theme_font_size("font_size"), l.text.left(30)])
			if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
				continue
			var f: Font = l.get_theme_font("font")
			var fs := l.get_theme_font_size("font_size")
			var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if w > r.size.x + 1.5 and (l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
				problems.append("%s: cut off '%s'" % [where, l.text.left(40)])
			elif w > r.size.x + 1.5 and r.position.x + w > wide + 1.0:
				problems.append("%s: spills off '%s'" % [where, l.text.left(40)])


func _push(p: Control, where: String) -> void:
	main.push(p)
	await create_timer(0.9).timeout
	await _audit(where)
	main.pop()
	await create_timer(0.6).timeout


func _run() -> void:
	g = root.get_node("Game")
	land = OS.get_cmdline_user_args().has("land")
	root.size = Vector2i(844, 390) if land else Vector2i(390, 844)   # the phone's screen in game units
	g.reset_game(true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	g.ui["guide_done"] = true
	g.reduce_motion = true
	# A rich, late game: long names and big numbers everywhere.
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
	g.rebirth["earned"] = 123456
	g.cash = 4.56789e15
	g.buy_chips(9.87654e12)
	g.deposit(1.23456e13)
	g.take_loan(g.loan_limit())
	g.buy_miner()
	g.streak_unseen = []
	g.away_unseen = false
	g.recalc()
	while root.get_node("Kit").close_top():
		await create_timer(0.3).timeout
	for ti in 5:
		main.show_page(ti)
		await _audit("tab %d" % ti)
	var inv = main._pages[2]
	for seg in 3:
		main.show_page(2)
		inv._seg.select(seg, true)
		await _audit("invest %d" % seg)
	for path_arg in [["res://scripts/business_detail.gd", "shop"], ["res://scripts/business_detail.gd", "space"],
			["res://scripts/start_business_page.gd", ""], ["res://scripts/settings_page.gd", ""],
			["res://scripts/goals_page.gd", ""], ["res://scripts/rebirth_page.gd", ""], ["res://scripts/stats_page.gd", ""],
			["res://scripts/bank_page.gd", ""], ["res://scripts/casino_page.gd", ""], ["res://scripts/achievements_page.gd", ""],
			["res://scripts/rivals_page.gd", ""], ["res://scripts/records_page.gd", ""], ["res://scripts/mergers_page.gd", ""], ["res://scripts/head_office_page.gd", ""],
			["res://scripts/home_page.gd", ""], ["res://scripts/news_page.gd", ""],
			["res://scripts/slots_page.gd", "vault"], ["res://scripts/forge_page.gd", ""], ["res://scripts/roulette_page.gd", ""],
			["res://scripts/blackjack_page.gd", ""], ["res://scripts/video_poker_page.gd", ""], ["res://scripts/crash_page.gd", ""],
			["res://scripts/plinko_page.gd", ""], ["res://scripts/race_page.gd", ""], ["res://scripts/tower_page.gd", ""]]:
		if not ResourceLoader.exists(path_arg[0]):
			continue
		var pg = load(path_arg[0]).new(path_arg[1]) if path_arg[1] != "" else load(path_arg[0]).new()
		await _push(pg, path_arg[0].get_file().get_basename())
	await _push(AssetDetail.new("share", "QSF"), "share QSF")
	await _push(AssetDetail.new("coin", "SHIB"), "coin SHIB")
	await _push(load("res://scripts/property_detail.gd").new(0), "property")
	await _push(ItemsPage.CollectionPage.new("jets"), "collection")
	# Pop-ups with the longest texts.
	for m in [["share", "QSF", "buy"], ["share", "QSF", "sell"], ["coin", "SHIB", "convert"], ["coin", "SHIB", "lock"],
			["chips", "", "chips_in"], ["bank", "", "bank_in"], ["bank", "", "bank_out"]]:
		TradeSheet.open(m[0], m[1], m[2])
		await _audit("sheet %s" % m[2])
		root.get_node("Kit").close_top()
		await create_timer(0.5).timeout
	# Self-check: a label that is far too long must be caught.
	var probe := UI.label("This line is far too long to ever fit on a phone screen at this size", 17, UI.TEXT)
	probe.clip_text = true
	probe.custom_minimum_size = Vector2(120, 0)
	main._pages[0].add_child(probe)
	main.show_page(0)
	var before := problems.size()
	await _audit("probe")
	_ok(problems.size() > before, "the audit catches a cut-off line")
	problems.resize(before)
	probe.queue_free()
	_ok(checked > 300, "the audit looked at enough text (%d labels)" % checked)
	for p in problems:
		print("  ", p)
	_ok(problems.is_empty(), "nothing is cut off or off screen (%d problems)" % problems.size())
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
