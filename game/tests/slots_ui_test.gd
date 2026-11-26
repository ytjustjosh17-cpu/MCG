extends SceneTree
## Slots page: real taps (with wobble), money settled and saved before the
## reels stop, bets inside the table limit, 48 px buttons, autospin stops
## when you leave. Run with touch emulation, like scroll_test.gd, and its own
## user folder (it reads the save file, so another run must not share it):
##   printf '[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="sol-slots-test"\n\n[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > override.cfg
##   godot --headless --path . -s res://tests/slots_ui_test.gd ; rm override.cfg
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


func _slots() -> GDScript:
	## Loaded at run time: naming the class here would compile it before the
	## autoloads exist.
	return load("res://scripts/slots_page.gd")


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


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	var g = root.get_node("Game")
	g.reset_game(true)
	g.sim_time = -1.0
	var keep_motion: bool = g.reduce_motion
	g.reduce_motion = false   # a setting, so it survives resets: pin it for this test
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
	g.open_business("shop", "Slot Test")
	g.biz["shop"]["units"] = 20
	g.recalc()
	g.grant_node("u_casino")
	_ok(g.casino_open(), "casino opens")
	_ok(g.buy_chips(2.0e5), "chips bought")
	main.show_page(3)
	await create_timer(0.6).timeout
	for th in ["classic", "neon", "vault"]:
		main.push(_slots().new(th))
		await create_timer(1.2).timeout
		var sp = main._stack.back()
		_ok(sp.get_script() == _slots() and sp.theme_id == th, "%s machine opens" % th)
		_ok(sp.total_bet() <= g.casino_max_bet() + 0.001, "%s: starting bet within the limit" % th)
		# The ladder never offers more than the max bet.
		sp._bet_i = sp._ladder.size() - 1
		sp._refresh_bet()
		_ok(sp.total_bet() <= g.casino_max_bet() + 0.001, "%s: top bet %s within max %s" % [th, g.money_short(sp.total_bet()), g.money_short(g.casino_max_bet())])
		sp._step_bet(1)
		_ok(sp.total_bet() <= g.casino_max_bet() + 0.001, "%s: + can't pass the table limit" % th)
		sp._bet_i = maxi(0, sp._ladder.size() - 4)
		sp._refresh_bet()
		var bad: Array = _small_buttons(sp)
		_ok(bad.is_empty(), "%s: every button is 48 px or more %s" % [th, str(bad)])
		_ok(sp._spin_b.get_global_rect().end.y < 844.0 - 100.0, "%s: Spin sits above the bottom bar without scrolling" % th)
		# A real tap on Spin: the bet goes, the win comes, and it's on disk
		# before the reels stop.
		var before: float = g.chips()
		var bet: float = sp.total_bet()
		var prev_last: Dictionary = sp._last
		await _wobble_tap(sp._spin_b.get_global_rect().get_center())
		await process_frame
		_ok(sp._last != prev_last, "%s: a wobbly tap on Spin spins" % th)
		var res: Dictionary = sp._last
		var paid := float(res.get("paid", 0.0))
		_ok(absf(g.chips() - (before - bet + paid)) < 0.01, "%s: chips change by exactly -bet + win (%s, %s)" % [th, g.money_short(bet), g.money_short(paid)])
		# Saved before the reels stop: spin, then read the disk in the same frame.
		while sp._busy or sp._free_left > 0:
			await create_timer(0.1).timeout
		var started: bool = sp.spin()
		var spinning: bool = sp._machine._spinning.has(true)
		var disk := _disk_chips()
		var waits := 0
		while disk < 0.0 and waits < 20:   # caught mid-rename (another run may share user://)
			await process_frame
			disk = _disk_chips()
			waits += 1
		_ok(started and spinning and absf(disk - g.chips()) < 0.01, "%s: the result is saved while the reels still spin (%s %s %.2f %.2f)" % [th, started, spinning, disk, g.chips()])
		_ok(paid <= g.casino_max_win() + 0.01 and float(res.get("total", 0.0)) <= bet * SlotMath.MAX_WIN_X + 0.01, "%s: win within the caps" % th)
		if th == "classic" and out != "":
			await _shot("slots_%s_spinning" % th)
		# Find a winning spin for the screenshot / line display.
		var tries := 0
		while tries < 40:
			while sp._busy:
				await create_timer(0.1).timeout
			if float(sp._last.get("paid", 0.0)) > 0.0 and int(sp._last.get("free_spins_awarded", 0)) == 0 and sp._free_left == 0:
				break
			if sp._free_left > 0:
				await create_timer(0.3).timeout
				continue
			sp.spin()
			sp._machine.slam()
			tries += 1
		await create_timer(0.3).timeout
		await _shot("slots_%s_win" % th)
		# Slam stop: tapping Spin while the reels move stops them at once.
		while sp._busy or sp._free_left > 0:
			await create_timer(0.1).timeout
		if sp.spin():
			await process_frame
			sp._on_spin_pressed()
			await process_frame
			_ok(not sp._machine._spinning.has(true), "%s: tapping again stops the reels" % th)
		while sp._busy or sp._free_left > 0:
			await create_timer(0.1).timeout
		await _shot("slots_%s_idle" % th)
		main.pop()
		await create_timer(0.7).timeout
	# Autospin stops when the page closes.
	main.push(_slots().new("neon"))
	await create_timer(1.0).timeout
	var ap = main._stack.back()
	ap._start_auto(25)
	await create_timer(0.3).timeout
	_ok(ap.is_auto(), "autospin runs")
	var chips_a: float = g.chips()
	main.pop()
	await create_timer(0.5).timeout
	_ok(not ap.is_auto() if is_instance_valid(ap) else true, "autospin stops when you leave the machine")
	await create_timer(2.5).timeout
	var chips_b: float = g.chips()
	await create_timer(2.5).timeout
	_ok(absf(g.chips() - chips_b) < 0.01, "no more spins after leaving (%s then %s)" % [g.money_short(chips_a), g.money_short(chips_b)])
	# Bonus buy: costs the shown price, gives free spins; free spins cost nothing.
	main.push(_slots().new("classic"))
	await create_timer(1.0).timeout
	var bp = main._stack.back()
	bp._bet_i = 0
	bp._refresh_bet()
	var cost: float = bp.math.bonus_buy_cost(bp.line_bet())
	var c0: float = g.chips()
	var bought: bool = await bp.buy_bonus()
	_ok(bought, "bonus buy goes through")
	await create_timer(0.2).timeout
	var after_first: float = g.chips()
	_ok(after_first <= c0 - cost + float(bp._free_won) + 0.01 and after_first >= c0 - cost - 0.01, "bonus buy costs %s and free spins take no stake" % g.money_short(cost))
	_ok(g.ui.has("slots_free") or bp._free_left == 0, "free spins left are kept in the save")
	if out != "":
		bp._machine.banner("10 FREE SPINS", "Wins pay ×2", 3.0)
		await create_timer(0.3).timeout
		await _shot("slots_free_banner")
	var guard := 0
	while (bp._busy or bp._free_left > 0) and guard < 400:
		bp._machine.slam()
		await create_timer(0.1).timeout
		guard += 1
	_ok(bp._free_left == 0 and not g.ui.has("slots_free"), "the feature ends and clears its saved count")
	main.pop()
	await create_timer(0.6).timeout
	# Less motion: the reels show the result at once.
	g.reduce_motion = true
	main.push(_slots().new("classic"))
	await create_timer(1.0).timeout
	var rp = main._stack.back()
	rp._bet_i = 0
	rp._refresh_bet()
	rp.spin()
	_ok(not rp._machine._spinning.has(true), "with Less motion the reels stop at once")
	g.reduce_motion = false
	while rp._busy or rp._free_left > 0:
		rp._machine.slam()
		await create_timer(0.1).timeout
	main.pop()
	await create_timer(0.6).timeout
	# Not enough chips: no spin, nothing taken.
	main.push(_slots().new("vault"))
	await create_timer(1.0).timeout
	var np = main._stack.back()
	g.casino["chips"] = 0.0
	np.refresh()
	var c_none: float = g.chips()
	_ok(not np.spin() and g.chips() == c_none, "with no chips Spin does nothing")
	while kit.close_top():
		await create_timer(0.3).timeout
	main.pop()
	await create_timer(0.5).timeout
	g.reset_game(true)
	g.reduce_motion = keep_motion
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
