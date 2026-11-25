extends SceneTree
## Headless smoke test: run with
##   godot --headless --path game -s res://tests/smoke_test.gd

var _fails := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("PASS  ", what)
	else:
		_fails += 1
		printerr("FAIL  ", what)


func _initialize() -> void:
	# Never hang CI: give up after 60 seconds.
	create_timer(150.0).timeout.connect(func():
		printerr("FAIL  timed out")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	game.reset_game()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if not main.has_method("show_page"):
		printerr("FAIL  main scene script did not load")
		quit(1)
		return
	await process_frame
	await process_frame

	# Formatting.
	_check(game.money(2.5) == "$2.50", "money small")
	_check(game.money(19284.4) == "$19,284", "money grouped")
	_check(game.money(62480190) == "$62,480,190", "money millions")
	_check(game.money(1.25e9) == "$1.25B", "money billions")
	_check(game.money(3.4e12) == "$3.4T" and game.money_short(32000.0) == "$32K" and game.money_short(1.2e6) == "$1.2M" and game.money_short(382800.0) == "$383K", "money short drops trailing zeros")
	_check(game.money_short(4658503.47) == "$4.66M", "money short")
	_check(game.clock(119) == "1:59", "clock")

	# Tapping through the tower card.
	var card = main.find_child("TowerCard", true, false)
	_check(card != null, "tower card exists")
	for i in 400:
		card._do_tap(Vector2(250, 100))
	_check(game.taps == 400, "tap count")
	_check(game.cash >= 1000.0, "400 taps earn at least $1,000 (got %s)" % game.cash)
	var before: float = game.cash
	_check(game.level_up(), "level up")
	_check(game.level == 2 and is_equal_approx(game.cash, before - 1000.0), "level 2, cost paid")

	# Boost.
	_check(game.start_boost(), "boost starts")
	var c0: float = game.cash
	card._do_tap(Vector2(250, 100))
	_check(is_equal_approx(game.cash - c0, game.tap_value() * 3.0), "boosted tap is x3")
	_check(not game.start_boost(), "boost on cooldown")

	# Businesses, using the simulator clock.
	game.sim_time = game.now()
	game.cash = 50000.0
	_check(game.open_business("shop", "Kettle & Co."), "open a shop")
	_check(not game.open_business("shop", "Again"), "can't open the same type twice")
	_check(game.income_per_hour > 0.0, "shop earns per hour")
	var units_before: int = game.biz["shop"]["units"]
	_check(game.buy_unit("shop"), "buy an outlet")
	_check(game.biz["shop"]["units"] == units_before + 1, "outlet added")
	for i in 10:
		game.buy_unit("shop")
	_check(game.biz["shop"]["units"] == game.capacity("shop"), "units stop at capacity")
	game.cash += 100000.0
	_check(game.start_expansion("shop"), "start expansion")
	_check(game.expanding("shop"), "expansion running")
	game.sim_time += game.expansion_seconds("shop") + 1.0
	game.advance(1.0)
	_check(game.biz["shop"]["stage"] == 2, "expansion finishes on time")
	_check(game.capacity("shop") == 10, "capacity grows with stage")

	# Shares, coins, property, collections.
	game.cash = 1.0e6
	_check(game.buy_asset("share", "NRV", 1000.0), "buy shares")
	_check(game.dividends_per_hour() > 0.0, "shares pay dividends")
	_check(game.sell_asset("share", "NRV", 1.0) > 0.0, "sell shares")
	_check(game.buy_asset("coin", "KRV", 500.0), "buy coins")
	_check(game.buy_property(0), "buy a property")
	_check(game.rent_per_hour() > 0.0, "property pays rent")
	_check(game.improve_property(0, 0), "improve a property")
	_check(is_equal_approx(game.sell_property_value(0), game.prop_value(0) * 0.88), "12% sales tax")
	_check(game.buy_item("watches", 0), "buy a watch")
	_check(game.collection_count("watches") == 1, "collection counts")
	game.advance(600.0)
	_check(game.price_hist["KRV"].size() > 60, "markets tick")
	# Week and day charts, news and market mood.
	_check(game.hist_h["NRV"].size() >= 160 and game.hist_q["NRV"].size() >= 90, "day and week charts filled")
	_check(game.series("KRV", "1W").size() > 100, "week series for coins")
	var mood: float = game.market_mood()
	_check(mood >= 0.0 and mood <= 100.0, "market mood in range")
	var n0 := int(game.counters.get("news_total", 0))
	for i in 40:
		game._news_event()
	_check(game.news.size() == 30 and int(game.counters.get("news_total", 0)) == n0 + 40, "news list capped, counter keeps rising")
	var bad := false
	for k in game.prices.keys():
		if not (game.prices[k] > 0.0) or is_nan(game.prices[k]) or is_inf(game.prices[k]):
			bad = true
	_check(not bad, "no broken prices after news")
	# Staking: lock, cannot unlock early, earns coins, unlocks after 24 h.
	game.cash += 1000.0
	game.buy_asset("coin", "LMN", 1000.0)
	var q0: float = game.holding(game.coins, "LMN")
	_check(game.stake("LMN", 1.0) and game.holding(game.coins, "LMN") == 0.0, "stake locks coins")
	_check(not game.unstake("LMN"), "cannot unlock early")
	_check(game.sell_asset("coin", "LMN", 1.0) == 0.0, "locked coins cannot be sold")
	game.sim_time += 25 * 3600.0
	game.advance(3600.0)
	_check(game.staked("LMN") > q0, "staking earns coins")
	_check(game.unstake("LMN") and game.holding(game.coins, "LMN") > q0, "unlock after 24 h")
	_check(float(game.counters.get("dividends_earned", 0.0)) >= 0.0, "dividends counter exists")
	# Selling part keeps the average price the same.
	game.cash += 2000.0
	game.buy_asset("share", "QSF", 2000.0)
	var avg0: float = game.avg_price(game.shares, "QSF")
	game.sell_asset("share", "QSF", 0.5)
	_check(absf(game.avg_price(game.shares, "QSF") - avg0) < avg0 * 1e-6, "average price stays after part sale")
	game.stake("LMN", 0.5)
	# Homes and the next goal.
	var h0: int = game.home
	var m0: float = game.global_mult()
	game.cash += game.next_home_cost()
	_check(game.move_home() and game.home == h0 + 1, "move up a home")
	_check(game.global_mult() > m0, "a new home raises income")
	game.cash = 0.0
	_check(not game.move_home(), "can't move without the money")
	var goal: Dictionary = game.next_goal()
	_check(not goal.is_empty() and float(goal["cost"]) > 0.0, "next goal: %s" % goal.get("text", "none"))
	# Weekly goals, deals, managers and rivals.
	_check(game.weekly_tasks().size() == 3, "three weekly goals")
	var gd := [0]
	game.goal_done.connect(func(_s, _t, _r): gd[0] += 1)
	for t in game.daily_tasks():
		if t["id"] == "taps" and not t["done"]:
			for i in int(t["goal"]):
				game.tap()
	_check(gd[0] >= 0, "goal_done fires without errors")
	game.cash += 1.0e7
	game.deal_wait = 0.0
	game.tick_deals(1.0)
	_check(not game.deal.is_empty(), "a deal arrives after its wait")
	var kind: String = game.deal["kind"]
	_check(game.accept_deal() and game.deal.is_empty(), "accept a %s deal" % kind)
	_check(float(game.counters.get("deals", 0)) >= 1.0, "deals are counted")
	game.deal_wait = 0.0
	game.tick_deals(1.0)
	game.decline_deal()
	_check(game.deal.is_empty(), "decline a deal")
	var bid: String = game.biz.keys()[0]
	var inc0: float = game.biz_income(bid)
	_check(game.hire_manager(bid) and game.has_manager(bid), "hire a manager")
	_check(game.biz_income(bid) < inc0 + 0.001, "manager takes a cut")
	game.cash = 1.0e9
	while game.buy_unit(bid):
		pass
	game.advance(1.0)
	_check(game.expanding(bid) or int(game.biz[bid]["stage"]) >= Data.MAX_STAGE, "manager starts the expansion")
	_check(game.rivals_beaten() >= 1, "beat at least one rival with $1B")
	# A version 2 save upgrades cleanly.
	var old: Dictionary = game._migrate({"version": 2, "cash": 5.0, "price_hist": {"KRV": [1.0]}})
	_check(int(old["version"]) == 5 and old["price_hist"].is_empty() and int(old["home"]) == 0, "v2 save upgrades")
	_check(game.completion() > 0.0 and game.completion() < 0.2, "completion is a small share")
	var st: Array = game.need_status(["biz", "shop", 5])
	_check(not st[0], "merger need not met yet")
	game.sim_time = -1.0

	# Every tab opens.
	for i in 5:
		main.show_page(i)
		await create_timer(0.4).timeout
	main.show_page(0)
	await process_frame

	# New invest screens build and their sheets open without errors.
	for spec in [["share", "NRV"], ["share", "QSF"], ["coin", "LMN"], ["coin", "DRF"]]:
		var pg = load("res://scripts/asset_detail.gd").new(spec[0], spec[1])
		main.push(pg)
		await create_timer(0.5).timeout
		for r in ["1H", "1D", "1W"]:
			pg._chart.set_range(r)
			await process_frame
		pg._on_buy()
		await create_timer(0.3).timeout
		root.get_node("Kit").close_top()
		pg._on_sell()
		await create_timer(0.3).timeout
		root.get_node("Kit").close_top()
		if spec[0] == "coin":
			pg._on_stake()
			await create_timer(0.3).timeout
			root.get_node("Kit").close_top()
		pg._on_scrub(1.0, 3, 10)
		pg._on_scrub(-1.0, -1, 0)
		_check(pg._price.text.begins_with("$"), "%s page shows a price" % spec[1])
		main.pop()
		await create_timer(0.5).timeout
	for path in ["res://scripts/goals_page.gd", "res://scripts/rivals_page.gd"]:
		var gp = load(path).new()
		main.push(gp)
		await create_timer(0.5).timeout
		_check(gp.body.get_child_count() > 2, "%s builds" % path.get_file())
		main.pop()
		await create_timer(0.5).timeout
	# Opening a page and backing out very fast must not leave a blank tab.
	main.show_page(2)
	await create_timer(0.5).timeout
	main._pages[2]._open("share", "OSB")
	await create_timer(0.1).timeout
	main._on_back()
	await create_timer(1.0).timeout
	_check(main._pages[2].visible and main._pages[2].modulate.a > 0.95, "fast back leaves the tab visible")
	main._pages[2]._open("share", "OSB")
	await create_timer(0.15).timeout
	main.show_page(2)
	await create_timer(1.0).timeout
	_check(main._pages[2].modulate.a > 0.95 and absf(main._pages[2].position.x) < 1.0, "tapping the same tab mid-slide leaves it clean")
	# Spam: fast tab switching, repeated pushes, back hammering.
	for k in 30:
		main.show_page(k % 3)
		await process_frame
	main.show_page(1)
	await create_timer(0.2).timeout
	main.show_page(0)
	await create_timer(0.8).timeout
	_check(main._pages[0].visible and main._pages[0].modulate.a > 0.95, "fast tab switching never leaves a blank screen")
	for k in 10:
		main.push(load("res://scripts/goals_page.gd").new())
		await process_frame
	await create_timer(0.6).timeout
	_check(main._stack.size() == 1, "hammering a button opens one page, not %d" % main._stack.size())
	await create_timer(0.5).timeout
	main.push(load("res://scripts/rivals_page.gd").new())
	await create_timer(0.6).timeout
	var top = main._stack.back()
	for k in 3:
		top.pop_page.emit()
	await create_timer(0.8).timeout
	_check(main._stack.size() == 1, "three quick back taps close only the top page")
	main.show_page(0)
	await create_timer(0.4).timeout
	var np = load("res://scripts/news_page.gd").new()
	main.push(np)
	await create_timer(0.5).timeout
	_check(np._list.get_child_count() >= 30, "news page lists headlines")
	main.pop()
	await create_timer(0.5).timeout
	main.show_page(2)
	await create_timer(0.4).timeout
	var inv = main._pages[2]
	for i in 3:
		inv._seg.select(i, true)
		await process_frame
	inv._seg.select(0, true)
	inv._sector = "Tech"
	inv.refresh()
	var shown := 0
	for k in inv._share_rows.keys():
		if inv._share_rows[k].visible:
			shown += 1
	_check(shown == 3, "sector filter shows Tech only")
	var lines := 0
	for k in inv._share_seps.keys():
		if inv._share_seps[k].visible:
			lines += 1
	_check(lines == 2, "sector filter hides extra divider lines")
	main.show_page(0)
	await process_frame

	# Save and load round trip.
	game.save_game()
	var saved_cash: float = game.cash
	game.cash = 0.0
	game.level = 1
	game.load_game()
	_check(game.cash >= saved_cash - 0.01, "save/load keeps cash")
	_check(game.level == 2, "save/load keeps level")
	_check(game.owns("shop") and game.biz["shop"]["stage"] == 2, "save/load keeps businesses")
	_check(game.props_owned() == 1, "save/load keeps property")
	_check(game.staked("LMN") > 0.0 and game.stake_left("LMN") > 0.0, "save/load keeps staking")
	_check(game.news.size() == 30 and game.hist_h["NRV"].size() >= 160, "save/load keeps news and charts")
	# Backup code: round trip, small, and bad codes are refused safely.
	var code: String = game.backup_code()
	_check(code.begins_with("SOL1:") and code.length() < 60000, "backup code is small (%d chars)" % code.length())
	var keep_cash: float = game.cash
	var keep_props: int = game.props_owned()
	var keep_staked: float = game.staked("LMN")
	game.cash = 1.0
	_check(not game.restore_code("hello"), "junk code refused")
	_check(not game.restore_code(code.substr(0, code.length() - 40)), "cut-off code refused")
	_check(not game.restore_code("SOL1:999999999:AAAA"), "fake size refused")
	_check(game.cash == 1.0, "failed restore changes nothing")
	_check(game.restore_code(code), "backup restores")
	_check(absf(game.cash - keep_cash) <= maxf(1.0, keep_cash * 1e-6) and game.props_owned() == keep_props and absf(game.staked("LMN") - keep_staked) <= keep_staked * 1e-6, "restore brings back cash, property and staking (%.2f/%.2f %d/%d %.6f/%.6f)" % [game.cash, keep_cash, game.props_owned(), keep_props, game.staked("LMN"), keep_staked])
	_check(game.hist_h["NRV"].size() >= 160, "charts rebuilt after restore")

	# Offline earnings are capped at 8 hours.
	var inc: float = game.income_per_hour
	var c1: float = game.cash
	game.apply_offline(24 * 3600)
	_check(game.cash - c1 <= inc * 8.0 * 1.2 + 1.0, "offline capped near 8 h")
	game.reset_game()

	# Storage stays bounded: logs rotate and the save file stays small.
	var gl = root.get_node("GameLog")
	for i in 6000:
		gl.info("test", "Filler line %d to check that log files rotate and never grow without limit." % i)
	_check(gl.logs_size() < 3 * 200000 + 300000, "logs stay capped (%s)" % gl.bytes(gl.logs_size()))
	var rep: String = gl.report()
	_check(rep.begins_with("=== Sol problem report") and rep.length() < 120000, "problem report builds and stays small")
	game.sim_time = game.now()
	game.cash = 1.0e13
	for b in Data.BUSINESSES:
		game.open_business(b["id"], b["names"][0])
	for i in range(Data.PROPERTIES.size()):
		game.buy_property(i)
	for i in 2200:
		game._record_history()
	game.advance(30.0 * 86400.0)
	game.sim_time = -1.0
	game.save_game()
	var save_size: int = gl.file_size("user://save.json")
	_check(save_size < 400000, "save stays small after a month of data (%s)" % gl.bytes(save_size))
	game.reset_game()

	# Update card on Profile, and old update files are cleaned up.
	var up = root.get_node("Updater")
	up.latest_version = "1.0.999"
	up._set_state(up.State.AVAILABLE)
	main.show_page(4)
	await create_timer(0.4).timeout
	var prof = main._pages[4]
	_check(prof._upd_card.visible and prof._upd_btn.text == "Update", "update card shows on Profile")
	_check(main._nav._badges[4].visible, "Profile tab shows a red dot")
	up.progress = 0.42
	up._set_state(up.State.DOWNLOADING)
	_check(prof._upd_btn.text == "Downloading 42%", "download progress shows")
	up._set_state(up.State.IDLE)
	_check(not prof._upd_card.visible, "card hides when up to date")
	var f := FileAccess.open("user://update.apk", FileAccess.WRITE)
	f.store_string("x")
	f.close()
	f = FileAccess.open("user://update.txt", FileAccess.WRITE)
	f.store_string("1.0.0")
	f.close()
	up._cleanup_old_download()
	_check(not FileAccess.file_exists("user://update.apk"), "old update file is deleted")
	main.show_page(0)

	# Exploit fixes from play-testing.
	game.reset_game()
	game.sim_time = 1.8e9
	game.cash = 1.0e6
	game.open_business("shop", "Test Shop")
	game.open_business("taxi", "Test Taxi")
	game.weekly = {"week": game._week(), "tasks": []}
	game.daily = {"day": game._today(), "tasks": []}
	game.recalc()
	var plain: float = game.income_per_hour
	if game.ibost_ready():
		game.start_ibost()
	game.recalc()
	var cash_ib: float = game.cash
	game.sim_time += 12 * 3600.0
	game.apply_offline(12 * 3600.0)
	var paid: float = game.away_earned  # achievements may also pay out here
	_check(paid <= plain * 12.0 * 1.02 + 10.0, "x2 boost isn't paid twice while away (%.1f h of income)" % (paid / maxf(plain, 1.0)))
	var bid2: String = game.biz.keys()[0]
	game.cash = 1.0e12
	while game.buy_unit(bid2):
		pass
	game.deal = {"kind": "buyer", "id": bid2, "value": game.unit_price(bid2) / Data.UNIT_PRICE_GROWTH * 1.15}
	var cash_b: float = game.cash
	game.accept_deal()
	game.buy_unit(bid2)
	_check(game.cash - cash_b < game.unit_price(bid2) * 0.2, "selling an outlet to a buyer and rebuying isn't a money loop")
	var code2: String = game.backup_code()
	var p1: float = game.price("DRF")
	game.sim_time += 8 * 3600.0
	game.restore_code(code2)
	_check(absf(game.price("DRF") - p1) < p1 * 0.001, "restoring a backup doesn't re-roll prices")
	game.sim_time = -1.0
	game.reset_game()
	print("Failures: ", _fails)
	quit(1 if _fails > 0 else 0)
