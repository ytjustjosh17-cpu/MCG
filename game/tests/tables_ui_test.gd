extends SceneTree
## Roulette and blackjack, played with real (wobbly) taps:
##   printf '[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > override.cfg
##   $G --headless --path . -s res://tests/tables_ui_test.gd [-- <screenshot folder>]
##   rm override.cfg
## Checks money is exact, every stake is saved before the animation ends,
## the table limit holds, and leaving mid-hand settles the hand.

var fails := 0
var checked_n := 0
var out := ""
var main
var g


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func():
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
	await create_timer(0.3).timeout


func _tap(c: Control) -> void:
	await _wobble_tap(c.get_global_rect().get_center())


func _shot(name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("saved ", name)


func _saved_chips() -> float:
	var d = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	if typeof(d) != TYPE_DICTIONARY or not d.has("casino"):
		return -1.0
	return float(d["casino"].get("chips", -1.0))


func _won() -> float:
	return float(g.counters.get("casino_won", 0.0))


func _check_targets(root_c: Control, list_out: Array) -> void:
	if root_c == null:
		return
	var list: Array = root_c.find_children("*", "BaseButton", true, false)
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
			list_out.append("%s %dx%d [%s]" % [bb.name, int(r.size.x), int(r.size.y), bb.text])


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	g = root.get_node("Game")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.8).timeout
	# Set everything after the game has loaded, so nothing from the save file
	# (settings such as Less motion included) leaks in.
	g.reset_game(true)
	g.reduce_motion = false
	g.counters["rivals"] = 10
	g.cash = 5.0e6
	g.grant_node("u_casino")
	g.grant_node("u_tables")
	_ok(g.tables_open(), "casino and tables open")
	g.buy_chips(2.0e6)
	g.streak_unseen = []
	g.away_unseen = false
	var kit = root.get_node("Kit")
	while kit.close_top():
		await create_timer(0.3).timeout
	main.show_page(3)
	await create_timer(0.6).timeout
	await _roulette(kit)
	await _blackjack(kit)
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)


func _show_cell(rp, key: String) -> Button:
	var b: Button = rp._cells[key]
	var sc: ScrollContainer = rp._mat_scroll
	sc.scroll_vertical = int(maxf(0.0, b.position.y - 40.0))
	await process_frame
	await process_frame
	return b


func _roulette(kit) -> void:
	main.push(load("res://scripts/roulette_page.gd").new())
	await create_timer(1.2).timeout
	var rp = main._stack.back()
	_ok(rp.get_script().resource_path.ends_with("roulette_page.gd"), "roulette opens")
	var chip: float = rp._chip
	var c17: Button = await _show_cell(rp, "straight:17")
	await _tap(c17)
	var cred: Button = await _show_cell(rp, "red")
	await _tap(cred)
	_ok(rp._bets.has("straight:17") and rp._bets.has("red") and absf(rp._table_total() - chip * 2.0) < 0.01, "wobbly taps put a chip on 17 and on Red (%s)" % str(rp._bets.keys()))
	# A drag on the mat scrolls it and places nothing.
	var sc: ScrollContainer = rp._mat_scroll
	sc.scroll_vertical = 0
	await process_frame
	var n_bets: int = rp._bets.size()
	var p0: Vector2 = sc.get_global_rect().get_center() + Vector2(0, 40)
	_ev_button(p0, true)
	await process_frame
	for k in range(1, 10):
		_ev_move(p0 - Vector2(0, k * 12), Vector2(0, -12))
		await process_frame
	_ev_button(p0 - Vector2(0, 108), false)
	await create_timer(0.4).timeout
	_ok(sc.scroll_vertical > 40 and rp._bets.size() == n_bets and absf(rp._table_total() - chip * 2.0) < 0.01, "dragging the mat scrolls it and places no chip (%d)" % sc.scroll_vertical)
	# The table limit holds, however many chips you tap.
	var mx: float = g.casino_max_bet()
	for i in 60:
		rp._place("straight:5", "straight", 5)
	_ok(rp._table_total() <= mx + 0.001, "the table never goes over the limit (%s of %s)" % [g.money(rp._table_total()), g.money(mx)])
	rp._on_undo()
	rp._on_clear()
	await process_frame
	await _tap(await _show_cell(rp, "straight:17"))
	await _tap(await _show_cell(rp, "red"))
	await _tap(await _show_cell(rp, "dozen:2"))
	sc.scroll_vertical = 0
	await process_frame
	await _shot("40_roulette_bets")
	var small: Array = []
	checked_n = 0
	_check_targets(rp, small)
	_ok(small.is_empty() and checked_n > 20, "every roulette button is at least 48 px (%d checked) %s" % [checked_n, str(small.slice(0, 6))])
	# Spin: the stake and the result are saved before the ball settles.
	var before: float = g.chips()
	var won0 := _won()
	var total: float = rp._table_total()
	# Read the file in the same frame as the press: the ball is still rolling.
	rp._spin_b.pressed.emit()
	var file_now := _saved_chips()
	var spinning: bool = rp._spinning
	var paid := _won() - won0
	var status_t: String = rp._status.text
	var saved_ok: bool = absf(file_now - (before - total + paid)) < 0.01
	_ok(spinning and saved_ok, "stake and result are saved before the ball settles (file %.2f)" % file_now)
	_ok(status_t.find(g.money(before - total)) >= 0, "the chips shown wait for the ball (%s vs %s)" % [status_t.replace("\n", " "), g.money(before - total)])
	await create_timer(5.4).timeout
	_ok(not rp._spinning and rp._history.size() == 1, "the ball settles and the number joins the history")
	_ok(absf(g.chips() - (before - total + paid)) < 0.01, "chips are exactly before - stake + paid (%s, paid %s)" % [g.money(g.chips()), g.money(paid)])
	await _shot("41_roulette_result")
	# Rebet puts the same bets back; Less motion spins at once.
	await _tap(rp._again_b)
	_ok(absf(rp._table_total() - total) < 0.01, "Rebet puts the last bets back")
	g.reduce_motion = true
	var b2: float = g.chips()
	var w2 := _won()
	rp._on_spin()
	await process_frame
	_ok(not rp._spinning and absf(g.chips() - (b2 - total + (_won() - w2))) < 0.01, "with Less motion the result shows at once")
	g.reduce_motion = false
	main.pop()
	await create_timer(0.6).timeout


func _play_by_strategy(bp) -> void:
	## Plays the hand on the table with basic strategy, through the buttons.
	var guard := 0
	while bp._bj.phase == "player" and guard < 12:
		guard += 1
		var h: Dictionary = bp._bj.current_hand()
		var mv := BlackjackMath.basic_strategy(h["cards"], bp._bj.dealer_up(), bp._bj.can_double(), bp._bj.can_split())
		var b: Button = {"hit": bp._hit_b, "stand": bp._stand_b, "double": bp._double_b, "split": bp._split_b}[mv]
		b.pressed.emit()
		await process_frame


func _blackjack(kit) -> void:
	main.show_page(3)
	await create_timer(0.4).timeout
	main.push(load("res://scripts/blackjack_page.gd").new())
	await create_timer(1.2).timeout
	var bp = main._stack.back()
	_ok(bp.get_script().resource_path.ends_with("blackjack_page.gd"), "blackjack opens")
	# Bet with a real tap on a chip, then deal with a real tap.
	var bet0: float = bp._bet
	var chip_b: Control = bp._chip_row.get_child(0)
	await _tap(chip_b)
	_ok(bp._bet > bet0, "tapping a chip adds to the bet")
	var before: float = g.chips()
	var won0 := _won()
	bp._deal_b.pressed.emit()
	var deal_file := _saved_chips()
	var bet: float = bp._staked
	var deal_saved: bool = absf(deal_file - (before - bet + (_won() - won0))) < 0.01
	_ok(bet > 0.0 and deal_saved, "the bet is taken and saved at the deal")
	await create_timer(1.0).timeout
	if bp._bj.phase == "player":
		await _shot("42_blackjack_hand")
		var small: Array = []
		checked_n = 0
		_check_targets(bp, small)
		_ok(small.is_empty() and checked_n >= 5, "every blackjack button is at least 48 px (%d checked) %s" % [checked_n, str(small.slice(0, 6))])
		# One real tap on the strategy's move, then the rest by strategy.
		var h: Dictionary = bp._bj.current_hand()
		var mv := BlackjackMath.basic_strategy(h["cards"], bp._bj.dealer_up(), bp._bj.can_double(), bp._bj.can_split())
		await _tap({"hit": bp._hit_b, "stand": bp._stand_b, "double": bp._double_b, "split": bp._split_b}[mv])
		await _play_by_strategy(bp)
	await create_timer(2.0).timeout
	_ok(bp._bj.is_over() and bp._settled, "the hand plays out through the buttons")
	_ok(absf(g.chips() - (before - bp._staked + bp._paid)) < 0.01, "money is exact: before - stakes + payout (staked %s, paid %s)" % [g.money(bp._staked), g.money(bp._paid)])
	await create_timer(3.0).timeout   # let any toast leave the picture
	await _shot("43_blackjack_result")
	# Many hands by strategy (Less motion, quick): money exact every hand, and
	# doubles and splits charge their extra stake at the tap.
	g.reduce_motion = true
	var doubles := 0
	var splits := 0
	var exact := true
	var extra_ok := true
	for i in 400:
		if doubles > 0 and splits > 0 and i > 60:
			break
		var b0: float = g.chips()
		bp._on_deal()
		var s0: float = g.chips()
		var guard := 0
		while bp._bj.phase == "player" and guard < 12:
			guard += 1
			var hh: Dictionary = bp._bj.current_hand()
			var m := BlackjackMath.basic_strategy(hh["cards"], bp._bj.dealer_up(), bp._bj.can_double(), bp._bj.can_split())
			var c_before: float = g.chips()
			var hand_bet := float(hh["bet"])
			var was_last: bool = bp._bj.hands.size() == 1 or bp._bj.active == bp._bj.hands.size() - 1
			match m:
				"double":
					bp._double_b.pressed.emit()
					doubles += 1
					# Unless the double ended the hand (then the payout lands too).
					if not bp._bj.is_over() and absf(c_before - g.chips() - hand_bet) > 0.01:
						extra_ok = false
				"split":
					bp._split_b.pressed.emit()
					splits += 1
					if not bp._bj.is_over() and absf(c_before - g.chips() - hand_bet) > 0.01:
						extra_ok = false
				"hit":
					bp._hit_b.pressed.emit()
				_:
					bp._stand_b.pressed.emit()
			var _unused = was_last
		await process_frame
		if absf(g.chips() - (b0 - bp._staked + bp._paid)) > 0.01 or (s0 > b0 and not bp._bj.is_over()):
			if exact:
				print("  first mismatch: before %.2f after %.2f staked %.2f paid %.2f phase %s over %s" % [b0, g.chips(), bp._staked, bp._paid, bp._bj.phase, bp._settled])
			exact = false
	_ok(exact, "money exact over many hands")
	_ok(doubles > 0 and splits > 0 and extra_ok, "doubles (%d) and splits (%d) take their extra stake at the tap" % [doubles, splits])
	# Leaving mid-hand stands on what's left and pays it out.
	var left := false
	for i in 40:
		var bl: float = g.chips()
		bp._on_deal()
		if bp._bj.phase != "player":
			continue
		var bj_obj = bp._bj
		var after_deal: float = g.chips()
		var w0 := _won()
		main.pop()
		await create_timer(0.8).timeout
		var expect: float = minf(float(bj_obj.result()["payout_total"]), g.casino_max_win())
		_ok(bj_obj.is_over() and absf(_won() - w0 - expect) < 0.01 and absf(g.chips() - (after_deal + expect)) < 0.01 and after_deal < bl, "leaving mid-hand stands and pays it out (%s)" % g.money(expect))
		left = true
		break
	_ok(left, "found a hand to leave in the middle of")
	g.reduce_motion = false
