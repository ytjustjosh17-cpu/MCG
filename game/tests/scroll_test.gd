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
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
