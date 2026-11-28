extends SceneTree
## Sun Forge page: real taps (with wobble), money settled and saved before the
## grid moves, bets and the ante inside the table limit, Buy free spins
## charged 100x and paid as worked out, 48 px buttons, autoplay stops when
## you leave. Run with touch emulation and its own user folder:
##   printf '[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="sol-forge-test"\n\n[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > override.cfg
##   godot --headless --path . -s res://tests/forge_ui_test.gd ; rm override.cfg
## With a folder as the first argument (and a display, e.g. xvfb-run), it
## also saves screenshots there.

var fails := 0
var out := ""


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func():
		print("FAIL  timed out")
		quit(1))
	_run.call_deferred()


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


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
	await process_frame


func _forge() -> GDScript:
	## Loaded at run time: naming the class here would compile it before the
	## autoloads exist.
	return load("res://scripts/forge_page.gd")


func _disk_chips() -> float:
	var t := FileAccess.get_file_as_string("user://save.json")
	var d = JSON.parse_string(t)
	if typeof(d) != TYPE_DICTIONARY:
		return -1.0
	return float(d.get("casino", {}).get("chips", -1.0))


func _shot(name: String) -> void:
	if out == "":
		return
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("saved ", name)


func _small_buttons(page: Control) -> Array:
	var bad: Array = []
	var view := Rect2(Vector2.ZERO, Vector2(390, 844))
	for b in page.find_children("*", "BaseButton", true, false):
		var bb := b as BaseButton
		if not bb.is_visible_in_tree() or bb.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var r := bb.get_global_rect()
		if not view.intersects(r):
			continue
		if r.size.x < 47.5 or r.size.y < 47.5:
			bad.append("%s %dx%d" % [bb.text if bb.text != "" else bb.name, int(r.size.x), int(r.size.y)])
	return bad


func _settle(sp) -> void:
	var guard := 0
	while sp._busy and guard < 600:
		sp._on_spin_pressed()   # tap to hurry
		await create_timer(0.05).timeout
		guard += 1


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	var g = root.get_node("Game")
	g.reset_game(true)
	g.sim_time = -1.0
	var keep_motion: bool = g.reduce_motion
	g.reduce_motion = false   # a setting, so it survives resets: pin it for this test
	root.size = Vector2i(390, 844)   # the phone's screen in game units (as fit_test)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	g.streak_unseen = []
	g.away_unseen = false
	g.counters["rivals"] = 10
	var kit = root.get_node("Kit")
	while kit.close_top():
		await create_timer(0.3).timeout
	g.cash = 5.0e8
	g.open_business("shop", "Forge Test")
	g.biz["shop"]["units"] = 20
	g.recalc()
	g.grant_node("u_casino")
	_ok(g.casino_open(), "casino opens")
	_ok(g.buy_chips(4.0e5), "chips bought")
	main.show_page(3)
	await create_timer(0.6).timeout
	main.push(_forge().new("forge"))
	await create_timer(1.2).timeout
	var sp = main._stack.back()
	_ok(sp.get_script() == _forge(), "Sun Forge opens")
	await _shot("forge_idle")
	var bad: Array = _small_buttons(sp)
	_ok(bad.is_empty(), "every button is 48 px or more %s" % str(bad))
	_ok(sp._spin_b.get_global_rect().end.y < 844.0 - 100.0, "Spin sits above the bottom bar without scrolling (%.0f)" % sp._spin_b.get_global_rect().end.y)
	var vw: float = root.get_visible_rect().size.x
	var gr: Rect2 = sp._grid.get_global_rect()
	_ok(gr.position.x >= 0.0 and gr.end.x <= vw + 0.5 and gr.size.x >= sp._grid.CELL * 6.0 + sp._grid.PAD * 2.0, "the 6 x 5 grid fits the screen (%.0f of %.0f px)" % [gr.size.x, vw])
	# The ladder never offers more than the max bet, with or without ante.
	sp._bet_i = sp._ladder.size() - 1
	sp._refresh_bet()
	_ok(sp.stake() <= g.casino_max_bet() + 0.001, "top stake %s within max %s" % [g.money_short(sp.stake()), g.money_short(g.casino_max_bet())])
	sp._step_bet(1)
	_ok(sp.stake() <= g.casino_max_bet() + 0.001, "+ can't pass the table limit")
	sp.set_ante(true)
	_ok(sp.stake() <= g.casino_max_bet() + 0.001, "with the ante on, the stake still stays within the limit")
	sp.set_ante(false)
	sp._bet_i = maxi(0, sp._ladder.size() - 6)
	sp._refresh_bet()
	# Ante: +25% on the stake.
	var b0: float = sp.bet()
	sp.set_ante(true)
	_ok(sp.ante and absf(sp.stake() - sp.bet() * 1.25) < 1e-6 and absf(sp.bet() - b0) < 1e-6, "ante raises the stake by 25%% (%s to %s)" % [g.money_short(b0), g.money_short(sp.stake())])
	# A real tap on Spin with the ante on: the stake goes, the win comes.
	var before: float = g.chips()
	var st: float = sp.stake()
	var prev_last: Dictionary = sp._last
	await _wobble_tap(sp._spin_b.get_global_rect().get_center())
	await process_frame
	_ok(sp._last != prev_last, "a wobbly tap on Spin spins")
	var res: Dictionary = sp._last
	var paid := float(res.get("paid", 0.0))
	_ok(absf(g.chips() - (before - st + paid)) < 0.01, "chips change by exactly -stake + win (%s, %s)" % [g.money_short(st), g.money_short(paid)])
	_ok(bool(res.get("ante", false)) and absf(float(res["stake"]) - st) < 1e-6, "the round was played with the ante")
	await _settle(sp)
	sp.set_ante(false)
	# Saved before the grid moves: spin, then read the disk in the same frame.
	var started: bool = sp.spin()
	var busy: bool = sp._busy
	var disk := _disk_chips()
	_ok(started and busy and absf(disk - g.chips()) < 0.01, "the result is saved while the grid still moves (%.2f vs %.2f)" % [disk, g.chips()])
	_ok(float(sp._last.get("paid", 0.0)) <= g.casino_max_win() + 0.01 and float(sp._last["x"]) <= ForgeMath.MAX_WIN_X + 1e-6, "win within the caps")
	await _settle(sp)
	# Buy free spins: 100x the bet, the whole feature paid at once.
	sp._bet_i = maxi(0, sp._ladder.size() - 8)
	sp._refresh_bet()
	var bb: float = sp.bet()
	var c0: float = g.chips()
	var bought: bool = sp.buy_now()
	var br: Dictionary = sp._last
	_ok(bought and bool(br.get("bought", false)), "buy free spins goes through")
	var bpaid := float(br.get("paid", 0.0))
	_ok(absf(g.chips() - (c0 - bb * 100.0 + bpaid)) < 0.01, "it costs 100x the bet (%s) and pays the worked-out feature (%s) at once" % [g.money_short(bb * 100.0), g.money_short(bpaid)])
	_ok(absf(bpaid - minf(float(br["total"]) * (1.0 - Data.JP_SHARE), g.casino_max_win())) < 0.01 and (br["feature"]["spins"] as Array).size() >= ForgeMath.FREE_SPINS, "the feature has its %d+ spins and pays its total (less the jackpot share)" % ForgeMath.FREE_SPINS)
	_ok(absf(_disk_chips() - g.chips()) < 0.01, "the feature's pay is on disk before it plays")
	if out != "":
		await create_timer(2.6).timeout   # into the free spins
		await _shot("forge_free_spins")
	await _settle(sp)
	# The ante blocks the buy.
	sp.set_ante(true)
	_ok(not sp.buy_now(), "no buying free spins with the ante on")
	sp.set_ante(false)
	# Screenshots of a tumble win with orbs and of a big win banner.
	if out != "":
		var m = ForgeMath.new(31)
		var pick := {}
		for i in range(4000):
			var r: Dictionary = m.base_spin(1.0, false, true)
			if int(r["mult"]) > 0 and (r["spin"]["steps"] as Array).size() >= 3 and float(r["tumble_x"]) >= 1.0:
				pick = r
				break
		sp._grid._big_life = 0.0
		sp._grid._banner_life = 0.0
		sp._grid._labels = []
		if not pick.is_empty():
			var stp: Dictionary = (pick["spin"]["steps"] as Array)[0]
			await sp._grid.drop_in(stp, true)
			sp._grid.show_wins(stp["wins"], sp.bet(), false)
			sp._head.text = "TUMBLE WIN " + g.money_short(float(stp["x"]) * sp.bet())
			await create_timer(0.35).timeout
			await _shot("forge_tumble_win")
			await create_timer(1.4).timeout
		sp._grid.big_win("MEGA WIN", sp.bet() * 42.0, true)
		sp._win_l.text = g.money_short(sp.bet() * 42.0)
		await create_timer(0.2).timeout
		await _shot("forge_big_win")
		await create_timer(2.8).timeout
	# Autoplay stops when the page closes.
	sp._start_auto(25)
	await create_timer(0.3).timeout
	_ok(sp.is_auto(), "autoplay runs")
	main.pop()
	await create_timer(0.5).timeout
	_ok(not sp.is_auto() if is_instance_valid(sp) else true, "autoplay stops when you leave the machine")
	await create_timer(3.0).timeout
	var chips_b: float = g.chips()
	await create_timer(3.0).timeout
	_ok(absf(g.chips() - chips_b) < 0.01, "no more spins after leaving")
	# Less motion: a spin plays out almost at once.
	g.reduce_motion = true
	main.push(_forge().new("forge"))
	await create_timer(1.0).timeout
	var rp = main._stack.back()
	rp._bet_i = 0
	rp._refresh_bet()
	var tries := 0
	var quick := true
	while tries < 6:
		rp.spin()
		var waited := 0
		while rp._busy and waited < 200:
			await process_frame
			waited += 1
		if (rp._last.get("feature", {}) as Dictionary).is_empty() and waited > 150:
			quick = false
		tries += 1
	_ok(quick, "with Less motion a spin ends within a few frames")
	g.reduce_motion = false
	await _settle(rp)
	# Not enough chips: no spin, nothing taken.
	g.casino["chips"] = 0.0
	rp.refresh()
	var c_none: float = g.chips()
	_ok(not rp.spin() and g.chips() == c_none, "with no chips Spin does nothing")
	while kit.close_top():
		await create_timer(0.3).timeout
	main.pop()
	await create_timer(0.5).timeout
	g.reset_game(true)
	g.reduce_motion = keep_motion
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
