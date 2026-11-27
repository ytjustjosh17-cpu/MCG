extends SceneTree
## 1.2 casino games: payback and limits for video poker, crash, plinko and
## races, plus a wobbly tap on each new page and the daily wheel. Also the
## shared layout: every game has the i, the status row, and one 56 px primary
## ending at the same height above the nav bar.
##   $G --headless --path . -s res://tests/casino12_test.gd
## (The touch part needs pointing/emulate_touch_from_mouse=true in override.cfg;
## tools/check_all.sh runs it that way.)

var fails := 0


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func():
		print("FAIL  test timed out")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	_poker()
	_crash()
	_plinko()
	_races()
	await _pages()
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)


# ---- maths -------------------------------------------------------------------

func _poker() -> void:
	var pm := PokerMath.new(1234)
	# Hand ranks.
	var h := func(s: String) -> Array:
		var out: Array = []
		for t in s.split(" "):
			var suit: String = {"h": "hearts", "d": "diamonds", "c": "clubs", "s": "spades"}[t.right(1)]
			out.append({"rank": t.left(t.length() - 1), "suit": suit})
		return out
	_ok(PokerMath.evaluate(h.call("10h Jh Qh Kh Ah")) == "royal", "poker: royal flush")
	_ok(PokerMath.evaluate(h.call("Ah 2d 3c 4s 5h")) == "straight", "poker: ace-low straight")
	_ok(PokerMath.evaluate(h.call("Jh Jd 3c 4s 9h")) == "jacks", "poker: jacks or better")
	_ok(PokerMath.evaluate(h.call("10h 10d 3c 4s 9h")) == "", "poker: a low pair pays nothing")
	_ok(PokerMath.evaluate(h.call("Kh Kd Kc 4s 4h")) == "full", "poker: full house")
	var n := 200000
	var ret := 0.0
	for i in n:
		var cards := pm.deal()
		var hold := PokerMath.auto_hold(cards)
		pm.draw(hold)
		ret += PokerMath.pays(PokerMath.evaluate(pm.hand))
	var r := ret / float(n)
	print("  video poker (simple strategy, %d hands): %.2f%%" % [n, r * 100.0])
	_ok(r > 0.96 and r < 1.0, "poker: payback with the simple strategy is just under 100%% (%.2f%%)" % (r * 100.0))
	pm.deal()
	_ok(pm.deck.size() == 47, "poker: a fresh 52-card deck every hand")


func _crash() -> void:
	var cm := CrashMath.new(99)
	var n := 400000
	var maxx := 0.0
	var res := {}
	for t in [1.5, 2.0, 10.0, 100.0]:
		res[t] = 0.0
	var instant := 0
	for i in n:
		var x := cm.roll()
		maxx = maxf(maxx, x)
		if x < 1.01:
			instant += 1
		for t in res.keys():
			if x >= float(t):
				res[t] = float(res[t]) + float(t)
	for t in res.keys():
		var r := float(res[t]) / float(n)
		print("  crash, cash out at %sx: %.2f%%" % [str(t), r * 100.0])
		var tol := 0.02 if float(t) <= 10.0 else 0.15
		_ok(r < 1.0 + tol and absf(r - CrashMath.EDGE) < tol, "crash: target %sx pays back about 97%% (%.2f%%)" % [str(t), r * 100.0])
	_ok(maxx <= CrashMath.MAX_X, "crash: never above %dx" % int(CrashMath.MAX_X))
	_ok(instant > 0, "crash: sometimes crashes at once (the house edge)")


func _plinko() -> void:
	for risk in ["low", "medium", "high"]:
		var exact := PlinkoMath.rtp(risk)
		var pm := PlinkoMath.new(7)
		var n := 200000
		var t := 0.0
		for i in n:
			var d := pm.drop()
			t += PlinkoMath.mult(risk, int(d["slot"]))
		var sim := t / float(n)
		print("  plinko %s: exact %.2f%%, played %.2f%%" % [risk, exact * 100.0, sim * 100.0])
		_ok(exact > 0.96 and exact < 0.99, "plinko %s pays back 96 to 99%% (%.2f%%)" % [risk, exact * 100.0])
		_ok(absf(sim - exact) < 0.03, "plinko %s: the played rate matches the table" % risk)
	var pm2 := PlinkoMath.new(3)
	var d2 := pm2.drop()
	var s := 0
	for v in d2["path"]:
		s += int(v)
	_ok(d2["path"].size() == PlinkoMath.ROWS and s == int(d2["slot"]), "plinko: the path leads to the slot")


func _races() -> void:
	var rm := RaceMath.new(5)
	for i in rm.chances.size():
		_ok(rm.rtp(i) <= RaceMath.EDGE + 0.001, "races: runner %d pays back at most 95%%" % i)
	var n := 200000
	var bet := 0
	var won := 0.0
	for i in n:
		if i % 50 == 0:
			rm.new_form()
		var order := rm.run()
		bet = i % 6
		if order[0] == bet:
			won += float(rm.odds[bet])
	var r := won / float(n)
	print("  races (backing each car in turn): %.2f%%" % (r * 100.0))
	_ok(r > 0.9 and r < 0.99, "races: played payback about 95%% (%.2f%%)" % (r * 100.0))
	var order2 := rm.run()
	var seen := {}
	for v in order2:
		seen[v] = true
	_ok(order2.size() == 6 and seen.size() == 6, "races: every car finishes once")


# ---- pages (touch) -------------------------------------------------------------

func _ev_button(pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(e, true)


func _ev_move(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)


func _tap(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	_ev_button(p, true)
	await process_frame
	for d in [Vector2(2, 1), Vector2(4, 3), Vector2(3, 5)]:
		_ev_move(p + d, Vector2(1, 1))
		await process_frame
	_ev_button(p + Vector2(3, 5), false)
	await create_timer(0.3).timeout


func _small(page: Control) -> Array:
	var out: Array = []
	for b in page.find_children("*", "BaseButton", true, false):
		var bb := b as BaseButton
		if not bb.is_visible_in_tree() or bb.disabled or bb.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var r := bb.get_global_rect()
		if r.size.x < 47.5 or r.size.y < 47.5:
			out.append("%s %dx%d" % [bb.name, int(r.size.x), int(r.size.y)])
	return out


func _pages() -> void:
	var g = root.get_node("Game")
	g.reset_game(true)
	root.size = Vector2i(390, 844)   # the phone's screen in game units (as fit_test)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	g.reduce_motion = true   # results show at once, so the test stays quick
	g.cash = 1.0e9
	g.grant_node("u_casino")
	g.grant_node("u_tables")
	g.buy_chips(5.0e5)
	g.recalc()
	main.show_page(3)
	await create_timer(0.5).timeout
	# One layout on every game (design pass): the "i", the status row, and one
	# primary button whose bottom sits at the same height, just above the nav bar.
	# Also with the phone's status bar and gesture bar taking room (main.gd's safe area).
	for inset in [[0.0, 0.0], [44.0, 24.0]]:
		main._content.offset_top = inset[0]
		main._content.offset_bottom = -inset[1]
		await create_timer(0.3).timeout
		var screen_h := int(844.0 - inset[0] - inset[1])
		var bottom: float = root.get_visible_rect().size.y - inset[1] - 104.0
		for pa in [["res://scripts/slots_page.gd", "classic"], ["res://scripts/forge_page.gd", ""], ["res://scripts/roulette_page.gd", ""],
				["res://scripts/blackjack_page.gd", ""], ["res://scripts/video_poker_page.gd", ""], ["res://scripts/crash_page.gd", ""],
				["res://scripts/plinko_page.gd", ""], ["res://scripts/race_page.gd", ""]]:
			var lp = load(pa[0]).new(pa[1]) if pa[1] != "" else load(pa[0]).new()
			main.push(lp)
			await create_timer(0.8).timeout
			var name: String = pa[0].get_file().get_basename()
			var last: Control = lp.dock.get_child(lp.dock.get_child_count() - 1)
			var end_y: float = last.get_global_rect().end.y
			_ok(absf(end_y - bottom) <= 1.0 and last.size.y >= 55.5, "%s at %d: the primary is 56 px and ends at y %.0f (%.0f)" % [name, screen_h, bottom, end_y])
			_ok(lp.info_b != null and lp.info_b.is_visible_in_tree() and lp.status.is_visible_in_tree(), "%s: has the i button and the status row" % name)
			var wide: float = root.get_visible_rect().size.x
			_ok(lp.body.get_global_rect().end.x <= wide - 15.5, "%s: nothing pushes the page wider than the screen (%.0f)" % [name, lp.body.get_global_rect().end.x])
			var small := _small(lp)
			_ok(small.is_empty(), "%s: every button is at least 48 px %s" % [name, str(small)])
			lp.show_info()
			await create_timer(0.3).timeout
			_ok(root.get_node("Kit").has_open(), "%s: i opens the rules" % name)
			while root.get_node("Kit").close_top():
				await create_timer(0.3).timeout
			main.pop()
			await create_timer(0.5).timeout
	main._content.offset_top = 0.0
	main._content.offset_bottom = 0.0
	await create_timer(0.3).timeout
	# No chips: a tap on SPIN still answers (it offers chips), it is not swallowed.
	var chips_keep: float = g.casino["chips"]
	g.casino["chips"] = 0.0
	var zp = load("res://scripts/slots_page.gd").new("classic")
	main.push(zp)
	await create_timer(0.8).timeout
	await _tap(zp._spin_b)
	await create_timer(0.4).timeout
	_ok(root.get_node("Kit").has_open(), "slots: SPIN with no chips offers chips")
	while root.get_node("Kit").close_top():
		await create_timer(0.3).timeout
	main.pop()
	await create_timer(0.5).timeout
	g.casino["chips"] = chips_keep
	for path in ["res://scripts/video_poker_page.gd", "res://scripts/crash_page.gd", "res://scripts/plinko_page.gd", "res://scripts/race_page.gd"]:
		var pg = load(path).new()
		main.push(pg)
		await create_timer(1.0).timeout
		var small := _small(pg)
		_ok(small.is_empty(), "%s: every button is at least 48 px %s" % [path.get_file(), str(small)])
		var c0: float = g.chips()
		var b0: float = float(g.counters.get("casino_bet", 0.0))
		var w0: float = float(g.counters.get("casino_won", 0.0))
		await _tap(pg.play_button())
		if pg.has_method("finish_for_test"):
			await pg.finish_for_test()
		await create_timer(0.8).timeout
		var bet: float = float(g.counters.get("casino_bet", 0.0)) - b0
		var won: float = float(g.counters.get("casino_won", 0.0)) - w0
		_ok(bet > 0.0, "%s: a wobbly tap on the play button bets" % path.get_file())
		_ok(absf(g.chips() - (c0 - bet + won)) < 0.01, "%s: chips are exact (bet %s, won %s)" % [path.get_file(), g.money_short(bet), g.money_short(won)])
		var sv = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
		_ok(typeof(sv) == TYPE_DICTIONARY and absf(float(sv["casino"]["chips"]) - g.chips()) < 0.01, "%s: the result is saved" % path.get_file())
		main.pop()
		await create_timer(0.6).timeout
	# Crash: an unfinished round with no auto target is lost on restart.
	g.ui["crash_round"] = {"crash": 3.0, "stake": 100.0, "target": 0.0, "paid": false}
	var cp = load("res://scripts/crash_page.gd").new()
	var cc0: float = g.chips()
	main.push(cp)
	await create_timer(0.8).timeout
	_ok(not g.ui.has("crash_round") and absf(g.chips() - cc0) < 0.01, "crash: a round left open by closing the app is lost, never refunded")
	main.pop()
	await create_timer(0.6).timeout
	# The daily wheel: once a day.
	g.casino["wheel_day"] = -1
	_ok(g.wheel_ready(), "wheel: a free spin is ready")
	var cash0: float = g.cash + g.chips()
	var got: Dictionary = g.spin_wheel()
	_ok(not got.is_empty() and absf(g.cash + g.chips() - cash0 - float(got["amount"])) < 0.01, "wheel: the prize is paid")
	_ok(not g.wheel_ready() and g.spin_wheel().is_empty(), "wheel: only once a day")
	g.reduce_motion = false
	g.reset_game(true)

	# Landscape (1.2): the phone on its side. Every game: the main button fully
	# on screen and right of the tab rail, the table at least 300 px wide.
	g.grant_node("u_casino")   # earlier parts of this test start new games
	g.grant_node("u_tables")
	g.casino["chips"] = 5.0e5
	root.size = Vector2i(844, 390)
	await create_timer(0.6).timeout
	var lkit = root.get_node("Kit")
	_ok(lkit.landscape, "landscape: the frame switches when the screen is wider than tall")
	var lrail: float = main._nav.get_global_rect().end.x
	var lvr: Rect2 = root.get_visible_rect()
	for pa in [["res://scripts/slots_page.gd", "classic"], ["res://scripts/forge_page.gd", ""], ["res://scripts/roulette_page.gd", ""],
			["res://scripts/blackjack_page.gd", ""], ["res://scripts/video_poker_page.gd", ""], ["res://scripts/crash_page.gd", ""],
			["res://scripts/plinko_page.gd", ""], ["res://scripts/race_page.gd", ""]]:
		var llp = load(pa[0]).new(pa[1]) if pa[1] != "" else load(pa[0]).new()
		main.push(llp)
		await create_timer(0.8).timeout
		var lname: String = pa[0].get_file().get_basename()
		var llast: Control = llp.dock.get_child(llp.dock.get_child_count() - 1)
		var lr: Rect2 = llast.get_global_rect()
		_ok(lr.end.y <= lvr.size.y + 0.5 and lr.position.y >= 0.0 and lr.end.x <= lvr.size.x + 0.5 and lr.position.x >= lrail, "landscape %s: the main button is on screen, right of the rail (%s)" % [lname, str(lr)])
		_ok(llast.size.y >= 55.5, "landscape %s: the main button is 56 px" % lname)
		_ok(llp.area.size.x >= 300.0, "landscape %s: the table is at least 300 px wide (%.0f)" % [lname, llp.area.size.x])
		_ok(llp.info_b.is_visible_in_tree() and llp.info_b.get_global_rect().end.y <= lvr.size.y, "landscape %s: the i button shows" % lname)
		var lsmall := _small(llp)
		_ok(lsmall.is_empty(), "landscape %s: every button is at least 48 px %s" % [lname, str(lsmall)])
		main.pop()
		await create_timer(0.5).timeout
	# Turning the phone mid-round never touches the stake or the pay.
	var lcp = load("res://scripts/crash_page.gd").new()
	main.push(lcp)
	await create_timer(0.8).timeout
	var lc0: float = g.chips()
	var lb0: float = float(g.counters.get("casino_bet", 0.0))
	var lw0: float = float(g.counters.get("casino_won", 0.0))
	lcp.play_button().pressed.emit()   # start a round (the tap itself is tested above)
	await create_timer(0.2).timeout
	root.size = Vector2i(390, 844)
	await create_timer(0.3).timeout
	root.size = Vector2i(844, 390)
	await create_timer(0.3).timeout
	if lcp.has_method("finish_for_test"):
		await lcp.finish_for_test()
	await create_timer(0.8).timeout
	var lbet: float = float(g.counters.get("casino_bet", 0.0)) - lb0
	var lwon: float = float(g.counters.get("casino_won", 0.0)) - lw0
	_ok(lbet > 0.0 and absf(g.chips() - (lc0 - lbet + lwon)) < 0.01, "rotating mid-round: one bet, chips exact (bet %s, won %s)" % [g.money_short(lbet), g.money_short(lwon)])
	_ok(lcp.dock.get_parent() == lcp.side, "after turning back to landscape the dock is in the side column again")
	main.pop()
	await create_timer(0.5).timeout
	root.size = Vector2i(390, 844)
	await create_timer(0.5).timeout
	_ok(not lkit.landscape, "portrait again after turning back")
