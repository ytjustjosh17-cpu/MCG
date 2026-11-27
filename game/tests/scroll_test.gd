extends SceneTree
## Checks that dragging on a list row scrolls and does not tap it, and that a tap still works.

var fails := 0
var checked_n := 0


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func():
		print("FAIL  test timed out")
		quit(1))
	_run.call_deferred()


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


func _wobble_tap(p: Vector2) -> void:
	_ev_button(p, true)
	await process_frame
	for d in [Vector2(2, 1), Vector2(4, 3), Vector2(3, 5)]:
		_ev_move(p + d, Vector2(1, 1))
		await process_frame
	_ev_button(p + Vector2(3, 5), false)
	await create_timer(0.7).timeout


func _run() -> void:
	var g = root.get_node("Game")
	g.reset_game()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.show_page(2)
	await create_timer(0.5).timeout
	var inv = main._pages[2]
	var row: Control = inv._share_rows["QLM"]
	var taps := [0]
	row.pressed.connect(func(): taps[0] += 1)
	var start := row.get_global_rect().get_center()
	_ok(inv.scroll.scroll_vertical == 0, "starts at the top")
	# Drag up by 300 px starting on the row.
	_ev_button(start, true)
	await process_frame
	var p := start
	for i in 15:
		p += Vector2(0, -20)
		_ev_move(p, Vector2(0, -20))
		await process_frame
	_ev_button(p, false)
	await create_timer(0.3).timeout
	_ok(inv.scroll.scroll_vertical > 100, "dragging on a row scrolls (%d px)" % inv.scroll.scroll_vertical)
	_ok(taps[0] == 0, "dragging does not tap the row")
	_ok(not row.disabled, "row usable again after the drag")
	# A plain tap still works.
	await create_timer(1.0).timeout
	inv.scroll.scroll_vertical = 0
	await create_timer(0.3).timeout
	var c := row.get_global_rect().get_center()
	_ev_button(c, true)
	await process_frame
	_ev_button(c, false)
	await create_timer(0.2).timeout
	_ok(taps[0] == 1, "a tap still presses the row")
	# On a share page, an up/down drag on the chart scrolls; a sideways drag reads prices.
	await create_timer(0.6).timeout  # pushes within 450 ms are ignored on purpose (spam guard)
	g.cash = maxf(g.cash, 1.0e6)
	g.buy_asset("share", "NRV", 1.0e5)   # owning some makes the page long enough to scroll
	var pg = load("res://scripts/asset_detail.gd").new("share", "NRV")
	main.push(pg)
	await create_timer(0.8).timeout
	# The page is short now; add room below so there is something to scroll.
	var room_pad := Control.new()
	room_pad.custom_minimum_size = Vector2(0, 700)
	pg.body.add_child(room_pad)
	await create_timer(0.2).timeout
	var ch: Control = pg._chart
	var cs: Vector2 = ch.get_global_rect().get_center()
	_ev_button(cs, true)
	await process_frame
	var q := cs
	for i in 12:
		q += Vector2(0, -20)
		_ev_move(q, Vector2(0, -20))
		await process_frame
	_ev_button(q, false)
	await create_timer(0.3).timeout
	var room: float = pg.scroll.get_v_scroll_bar().max_value - pg.scroll.size.y   # how far this page can scroll
	_ok(room > 20.0 and pg.scroll.scroll_vertical >= minf(60.0, room - 2.0), "dragging up on the chart scrolls (%d of %d px)" % [pg.scroll.scroll_vertical, int(room)])
	pg.scroll.scroll_vertical = 0
	await create_timer(0.5).timeout
	cs = ch.get_global_rect().get_center()
	var seen := [false]
	ch.scrub.connect(func(price: float, _i: int, _n: int):
		if price > 0.0:
			seen[0] = true)
	_ev_button(cs, true)
	await process_frame
	q = cs
	for i in 8:
		q += Vector2(-15, 0)
		_ev_move(q, Vector2(-15, 0))
		await process_frame
	_ok(seen[0] and pg._scrubbing, "sideways drag reads old prices")
	_ok(pg.scroll.scroll_vertical == 0, "sideways drag does not scroll")
	_ev_button(q, false)
	await create_timer(0.2).timeout
	_ok(not pg._scrubbing, "price returns after letting go")
	# A real finger wobbles a few pixels on a tap. That must still count as a tap
	# (this was broken on the phone: buttons on pages did nothing).
	main.pop()
	await create_timer(0.6).timeout
	main.show_page(1)
	await create_timer(0.6).timeout
	var newb: Button = null
	# No companies yet, so the tab shows one "Open a company" row.
	for n in main._pages[1].find_children("*", "Row", true, false):
		if n.title_l.text == "Open a company" and n.is_visible_in_tree():
			newb = n
	await _wobble_tap(newb.get_global_rect().get_center())
	_ok(main._stack.size() == 1, "wobbly tap on Open a company opens the page")
	var sb = main._stack[-1] if main._stack.size() > 0 else null
	if sb:
		var back: Button = main.back_btn
		_ok(back.visible and back.get_global_rect().position.x > 300.0, "back button sits bottom right")
		await _wobble_tap(back.get_global_rect().get_center())
		_ok(main._stack.size() == 0 and not back.visible, "wobbly tap on the back button goes back")
	# Items tab: wobbly tap on Move, then on the sheet's Move button.
	g.counters["rivals"] = float(Data.RIVALS.size())  # no "rival beaten" pop-ups mid-test
	g.cash = 1.0e6
	g.recalc()
	main.show_page(3)
	await create_timer(0.8).timeout
	var items = main._pages[3]
	items.refresh()
	await process_frame
	await _wobble_tap(items._move.get_global_rect().get_center())
	var kit = root.get_node("Kit")
	var sheet_btn: Button = null
	for n in kit.find_children("*", "Button", true, false):
		if n.is_visible_in_tree() and String(n.text).begins_with("Move for"):
			sheet_btn = n
	_ok(sheet_btn != null, "wobbly tap on Move opens the sheet")
	if sheet_btn:
		await _wobble_tap(sheet_btn.get_global_rect().get_center())
	_ok(g.home == 1, "wobbly tap on the sheet button moves home")
	# Collection: a quick double tap on an item buys it once and does not offer to sell.
	g.cash = 1.0e6
	await create_timer(0.6).timeout
	var cp = load("res://scripts/items_page.gd").CollectionPage.new("watches")
	main.push(cp)
	await create_timer(0.8).timeout
	var ip: Vector2 = cp._rows[0].get_global_rect().get_center()
	for k in 2:
		_ev_button(ip, true)
		await process_frame
		_ev_button(ip, false)
		await create_timer(0.1).timeout
	await create_timer(0.3).timeout
	var sell_btn := false
	for n in kit.find_children("*", "Button", true, false):
		if n.is_visible_in_tree() and String(n.text) == "Sell":
			sell_btn = true
	_ok(g.item_owned("watches", 0), "tapping an item buys it")
	_ok(not sell_btn, "a quick second tap does not offer to sell")
	main.pop()
	await create_timer(0.6).timeout
	# Earn: the goal card opens a tab.
	main.show_page(0)
	await create_timer(0.8).timeout
	var earn = main._pages[0]
	# Tapping the round Level-up button must not also tap the tower.
	g.cash = 0.0
	var lv_pressed := [0]
	earn._level_btn.pressed.connect(func(): lv_pressed[0] += 1)
	var taps0: int = g.taps
	var lp: Vector2 = earn._level_btn.get_global_rect().get_center()
	_ev_button(lp, true)
	await process_frame
	_ev_button(lp, false)
	await create_timer(0.3).timeout
	_ok(lv_pressed[0] == 1, "tapping Level up presses it")
	_ok(g.taps == taps0, "tapping Level up is not a tower tap")
	var tp: Vector2 = earn._card.get_global_rect().position + Vector2(earn._card.size.x * 0.6, earn._card.size.y * 0.4)
	_ev_button(tp, true)
	await process_frame
	_ev_button(tp, false)
	await create_timer(0.3).timeout
	_ok(g.taps == taps0 + 1, "tapping the tower still earns")
	_ok(earn.get("_goal") == null, "the Earn screen has no next-goal card (owner removed it)")
	# Hold +1 on a company to keep buying outlets.
	g.cash = 1.0e9
	g.open_business("shop", "Hold Test")
	main.show_page(1)
	await create_timer(0.8).timeout
	main.push(load("res://scripts/business_detail.gd").new("shop"))
	await create_timer(0.9).timeout
	var bd = main._stack.back()
	var u0: int = int(g.biz["shop"]["units"])
	var bp: Vector2 = bd._buy.get_global_rect().get_center()
	_ev_button(bp, true)
	await create_timer(1.5).timeout
	_ev_button(bp, false)
	await create_timer(0.3).timeout
	var bought: int = int(g.biz["shop"]["units"]) - u0
	_ok(bought >= 3 and bought <= 4, "holding +1 keeps buying (%d bought)" % bought)
	# Golden sun: it appears on Earn and a tap on it pays out.
	main.show_page(0)
	await create_timer(0.8).timeout
	var sun_card = main._pages[0].find_child("TowerCard", true, false)
	sun_card.spawn_sun()
	await create_timer(1.5).timeout
	var sun: Control = null
	for sun_ch in sun_card.get_children():
		if sun_ch.has_method("_catch"):
			sun = sun_ch
	var found := sun != null
	var suns_s: int = int(g.counters.get("suns", 0))
	var taps_s: int = g.taps
	if found:
		await _wobble_tap(sun.get_global_rect().get_center())
	_ok(found and int(g.counters.get("suns", 0)) > suns_s and g.taps == taps_s, "tapping a golden sun catches it and isn't a tower tap")
	# Trade sheet: dragging the slider (with wobble) changes the amount, and
	# the Sell button sells that much.
	g.cash = maxf(g.cash, 1.0e6)
	g.buy_asset("coin", "DOGE", 1.0e5)
	main.show_page(2)
	await create_timer(0.5).timeout
	TradeSheet.open("coin", "DOGE", "sell")
	await create_timer(0.8).timeout
	var ts = null
	for n in root.get_node("Kit").find_children("*", "TradeSheet", true, false):
		ts = n
	var q0: float = g.holding(g.coins, "DOGE")
	var ts_found: bool = ts != null
	if ts:
		var sr: Rect2 = ts._slider.get_global_rect()
		var from_p := Vector2(sr.position.x + sr.size.x * 0.5, sr.get_center().y)
		_ev_button(from_p, true)
		await process_frame
		var to_p := Vector2(sr.position.x + sr.size.x * 0.27, sr.get_center().y + 3.0)
		_ev_move(to_p, to_p - from_p)
		await process_frame
		_ev_button(to_p, false)
		await create_timer(0.2).timeout
		await _wobble_tap(ts._go.get_global_rect().get_center())
		await create_timer(0.5).timeout
	var sold: float = 1.0 - g.holding(g.coins, "DOGE") / maxf(q0, 1e-9)
	_ok(ts_found and sold > 0.15 and sold < 0.35, "dragging the slider to about a quarter sells about a quarter (%.2f)" % sold)
	# Typing an amount: a tap selects the old amount, typing £500 buys £500
	# even while cash keeps arriving.
	g.cash = 10000.0
	TradeSheet.open("coin", "DOGE", "buy")
	await create_timer(0.8).timeout
	var tb = null
	for n in root.get_node("Kit").find_children("*", "TradeSheet", true, false):
		if n.mode == "buy":
			tb = n
	var tb_found: bool = tb != null
	var spent := 0.0
	if tb:
		_ok(tb._field.select_all_on_focus, "the amount box selects its old amount on tap")
		await _wobble_tap(tb._type_btn.get_global_rect().get_center())
		_ok(tb._field.visible and tb._field.has_focus(), "tapping Type an amount opens the box")
		tb._field.text = "500"
		tb._field.text_changed.emit("500")
		g.cash += 2000.0
		g.changed.emit()
		await process_frame
		_ok(tb._field.text == "500", "live updates don't rewrite the box while typing")
		tb._field.release_focus()
		var c0: float = g.cash
		tb._confirm()
		spent = c0 - g.cash
		await create_timer(0.5).timeout
	_ok(tb_found and absf(spent - 500.0) < 0.01, "typing £500 buys exactly £500 (%.2f)" % spent)
	# Lock uses the same sheet: Max locks everything free.
	TradeSheet.open("coin", "DOGE", "lock")
	await create_timer(0.8).timeout
	var tl = null
	for n in root.get_node("Kit").find_children("*", "TradeSheet", true, false):
		if n.mode == "lock":
			tl = n
	var free0: float = g.holding(g.coins, "DOGE")
	var tl_found: bool = tl != null
	if tl:
		tl._confirm()
		await create_timer(0.5).timeout
	_ok(tl_found and g.holding(g.coins, "DOGE") < 1e-6 and absf(g.staked("DOGE") - free0) < free0 * 1e-4, "Lock sheet locks the amount shown (%s, free %.3f, staked %.3f of %.3f)" % [tl_found, g.holding(g.coins, "DOGE"), g.staked("DOGE"), free0])
	# First-time guide: starts for a new player, lets the tower be tapped,
	# moves on when the player does the thing, and Skip ends it.
	var gd_taps: int = g.taps
	var gd_biz: Dictionary = g.biz.duplicate(true)
	g.taps = 0
	g.biz = {}
	g.ui["guide_done"] = false
	g.ui["guide_step"] = 0
	main.show_page(0)
	await create_timer(0.5).timeout
	Guide.maybe_start(main)
	await create_timer(0.5).timeout
	var gd = main.find_children("*", "Guide", false, false)
	_ok(gd.size() == 1, "the guide starts for a new player")
	var gd_card: Control = main._pages[0]._card
	for k in 6:
		await _wobble_tap(gd_card.get_global_rect().get_center() + Vector2(k * 3, 0))
	await create_timer(0.3).timeout
	_ok(g.taps >= 5 and int(g.ui.get("guide_step", 0)) == 1, "taps go through the guide and it moves on (%d taps, step %d)" % [g.taps, int(g.ui.get("guide_step", 0))])
	var gd_skip: Button = null
	if gd.size() == 1:
		for bb in gd[0].find_children("*", "Button", true, false):
			gd_skip = bb
	_ok(gd_skip != null and gd_skip.size.y >= 48.0, "Skip is easy to tap")
	if gd_skip:
		await _wobble_tap(gd_skip.get_global_rect().get_center())
	await create_timer(0.6).timeout
	_ok(bool(g.ui.get("guide_done", false)) and main.find_children("*", "Guide", false, false).is_empty(), "Skip ends the guide")
	Guide.maybe_start(main)
	await process_frame
	_ok(main.find_children("*", "Guide", false, false).is_empty(), "a finished guide doesn't come back")
	g.taps = gd_taps
	g.biz = gd_biz
	g.recalc()
	# Dots: only for a reward waiting, round, and opening the tab clears it.
	g.rewards = []
	g.ui["dots_seen"] = {}
	main.show_page(1)
	await create_timer(0.5).timeout
	main._update_badges()
	_ok(not main._nav._badges[1].visible and not main._nav._badges[2].visible, "no dots for things you can merely afford")
	g.add_reward("test_goal", "goal", "Test goal", 10.0)
	main._update_badges()
	_ok(main._nav._badges[0].visible, "a reward to claim shows a dot on Earn")
	_ok(main._nav._badges[0] is Panel, "the dot is round (a rounded panel, not a square)")
	main.show_page(0)
	await create_timer(0.5).timeout
	main._update_badges()
	main.show_page(1)
	await create_timer(0.5).timeout
	main._update_badges()
	_ok(not main._nav._badges[0].visible, "opening Earn clears its dot until something new arrives")
	g.add_reward("test_goal2", "goal", "Test goal 2", 10.0)
	main._update_badges()
	_ok(main._nav._badges[0].visible, "a new reward brings the dot back")
	g.rewards = []
	main._update_badges()
	main.show_page(0)
	await create_timer(0.5).timeout
	# The RBP tree: a wobbly tap on a node opens it; a drag moves the map and
	# opens nothing.
	g.rebirth = {"count": 1, "earned": 50, "nodes": {}}
	g._rb_cache = {}
	main.show_page(4)
	await create_timer(0.5).timeout
	main.push(RebirthPage.new())
	await create_timer(1.2).timeout
	var tr_rp = main._stack.back()
	var tr_tv = tr_rp._view
	var tr_gate: Vector2 = tr_tv.global_position + tr_tv.to_screen(RebirthTree.node("emp_g"))
	await _wobble_tap(tr_gate)
	var tr_kit = root.get_node("Kit")
	var tr_opened_title := ""
	if tr_kit.has_open():
		tr_opened_title = tr_kit._stack.back().get("title", "")
	_ok(tr_opened_title == "Empire gate", "a wobbly tap on a tree node opens it (%s)" % tr_opened_title)
	while tr_kit.close_top():
		await create_timer(0.3).timeout
	await create_timer(0.4).timeout
	var tr_pan0: Vector2 = tr_tv.pan
	var tr_c0: Vector2 = tr_tv.global_position + tr_tv.size * 0.5 + Vector2(40, 60)
	_ev_button(tr_c0, true)
	await process_frame
	for k in range(1, 9):
		_ev_move(tr_c0 + Vector2(k * 10, k * 6), Vector2(10, 6))
		await process_frame
	_ev_button(tr_c0 + Vector2(80, 48), false)
	await create_timer(0.6).timeout
	_ok(tr_tv.pan.distance_to(tr_pan0) > 60.0 and not tr_kit.has_open(), "dragging moves the tree and opens nothing")
	# The +, - and centre buttons: a tap there never opens the node behind.
	var tr_bad := 0
	for tr_b in tr_tv._btns.get_children():
		var tr_bc: Vector2 = (tr_b as Control).get_global_rect().get_center()
		tr_tv.pan = (tr_bc - tr_tv.global_position) - tr_tv.size * 0.5 - Vector2(float(RebirthTree.node("emp_g")["x"]), float(RebirthTree.node("emp_g")["y"])) * tr_tv.zoom
		tr_tv.queue_redraw()
		await create_timer(0.2).timeout
		await _wobble_tap(tr_bc)
		await create_timer(0.5).timeout
		if tr_kit.has_open():
			tr_bad += 1
			while tr_kit.close_top():
				await create_timer(0.3).timeout
	_ok(tr_bad == 0, "the tree's zoom and centre buttons never open the node behind them (%d did)" % tr_bad)
	g.rebirth = {"count": 0, "earned": 0, "nodes": {}}
	g._rb_cache = {}
	main.pop()
	await create_timer(0.5).timeout
	# Tap targets: every visible button on every tab and main detail page is
	# at least 44 px each way (mobile rule). Lists the offenders.
	var small: Array = []
	checked_n = 0
	var screens: Array = []
	for ti in 5:
		main.show_page(ti)
		await create_timer(0.6).timeout
		_check_targets(main._pages[ti], small)
	for path in ["res://scripts/business_detail.gd", "res://scripts/start_business_page.gd", "res://scripts/settings_page.gd", "res://scripts/goals_page.gd", "res://scripts/rebirth_page.gd", "res://scripts/stats_page.gd"]:
		main.show_page(1)
		await create_timer(0.3).timeout
		var pg2 = load(path).new("shop") if path.ends_with("business_detail.gd") else load(path).new()
		main.push(pg2)
		await create_timer(0.8).timeout
		_check_targets(main._stack.back() if not main._stack.is_empty() else null, small)
		main.pop()
		await create_timer(0.5).timeout
	_check_targets(main.back_btn, small)
	_ok(small.is_empty(), "every button is at least 48 px (%d checked) %s" % [checked_n, ", ".join(small.slice(0, 8))])
	_ok(checked_n > 40, "the size check saw the buttons")
	# Landscape (1.2): the phone held sideways. Earn's actions and the rebirth
	# tree stay fully on screen, and the tower still pays on a tap.
	root.size = Vector2i(844, 390)
	await create_timer(0.6).timeout
	_ok(root.get_node("Kit").landscape, "a wide window switches to landscape")
	main.show_page(0)
	await create_timer(0.6).timeout
	var ls_vr := root.get_visible_rect()
	var ls_ep = main._pages[0]
	_ok(ls_vr.encloses(ls_ep._strip.get_global_rect()), "landscape: the Earn actions are fully on screen")
	var ls_c0: float = g.cash
	await _wobble_tap(ls_ep._card.get_global_rect().get_center())
	_ok(g.cash > ls_c0, "landscape: a tap on the tower earns money")
	main.push(load("res://scripts/rebirth_page.gd").new())
	await create_timer(1.0).timeout
	_ok(ls_vr.encloses(main._stack.back()._view.get_global_rect()), "landscape: the rebirth tree is fully on screen")
	main.pop()
	await create_timer(0.5).timeout
	root.size = Vector2i(390, 844)
	await create_timer(0.5).timeout
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)


func _check_targets(root_c: Control, out: Array) -> void:
	if root_c == null:
		return
	var list: Array = root_c.find_children("*", "BaseButton", true, false)
	if root_c is BaseButton:
		list.append(root_c)
	var view := Rect2(Vector2.ZERO, Vector2(390, 844))
	for b in list:
		var bb := b as BaseButton
		if not bb.is_visible_in_tree() or bb.disabled or bb.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var r := bb.get_global_rect()
		if not view.intersects(r):
			continue
		checked_n += 1
		if r.size.x < 47.5 or r.size.y < 47.5:
			var lbl := ""
			for l in bb.find_children("*", "Label", true, false):
				lbl += (l as Label).text + " "
			out.append("%s/%s %dx%d [%s%s]" % [root_c.name, bb.name, int(r.size.x), int(r.size.y), bb.text, lbl.strip_edges()])
