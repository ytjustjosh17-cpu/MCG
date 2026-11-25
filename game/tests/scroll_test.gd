extends SceneTree
## Checks that dragging on a list row scrolls and does not tap it, and that a tap still works.

var fails := 0


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(1))
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
	var pg = load("res://scripts/asset_detail.gd").new("share", "NRV")
	main.push(pg)
	await create_timer(0.8).timeout
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
	_ok(pg.scroll.scroll_vertical > 60, "dragging up on the chart scrolls (%d px)" % pg.scroll.scroll_vertical)
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
	for n in main._pages[1].find_children("*", "Button", true, false):
		if n.text == "New":
			newb = n
	await _wobble_tap(newb.get_global_rect().get_center())
	_ok(main._stack.size() == 1, "wobbly tap on New opens the page")
	var sb = main._stack[-1] if main._stack.size() > 0 else null
	if sb:
		var back: Button = sb.body.get_child(0)
		await _wobble_tap(back.get_global_rect().get_center())
		_ok(main._stack.size() == 0, "wobbly tap on the back button goes back")
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
	await _wobble_tap(earn._goal.get_global_rect().get_center())
	_ok(main._current != 0, "tapping the goal card opens its tab")
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
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
