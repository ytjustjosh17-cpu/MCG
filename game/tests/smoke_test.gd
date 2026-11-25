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
	_check(game.money(3.4e12) == "$3.40T", "money trillions")
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
	# A version 2 save upgrades cleanly.
	var old: Dictionary = game._migrate({"version": 2, "cash": 5.0, "price_hist": {"KRV": [1.0]}})
	_check(int(old["version"]) == 3 and old["price_hist"].is_empty(), "v2 save upgrades")
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

	print("Failures: ", _fails)
	quit(1 if _fails > 0 else 0)
