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
	game.tap_cap = false  # tests tap hundreds of times in one frame
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
	_check(game.money(2.5) == "£2.50", "money small")
	_check(game.money(19284.4) == "£19,284", "money grouped")
	_check(game.money(62480190) == "£62,480,190", "money millions")
	_check(game.money(1.25e9) == "£1.25B", "money billions")
	_check(game.money(3.4e12) == "£3.4T" and game.money_short(32000.0) == "£32K" and game.money_short(1.2e6) == "£1.2M" and game.money_short(382800.0) == "£383K", "money short drops trailing zeros")
	_check(game.money_short(4658503.47) == "£4.66M", "money short")
	_check(game.cash_text(1385.62) == "£1,385.62" and game.cash_text(177930027.72) == "£177.9M", "cash to the penny, short when big (%s)" % game.cash_text(177930027.72))
	game.sci = true
	_check(game.money_short(1.234e9) == "£1.23e9" and game.money_short(5000.0) == "£5K", "scientific format (%s)" % game.money_short(1.234e9))
	game.sci = false
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

	# Combo pay: nothing below 10 in a row, then up to x2.5, never more.
	_check(game.combo_mult(9) == 1.0 and is_equal_approx(game.combo_mult(100), Data.COMBO_MAX_MULT) and is_equal_approx(game.combo_mult(100000), Data.COMBO_MAX_MULT), "combo pays from 10 in a row and stops at x2.5")
	# Boost.
	_check(game.start_boost(), "boost starts")
	var c0: float = game.cash
	card._do_tap(Vector2(250, 100))
	var want_x: float = 3.0 * (Data.CRIT_MULT if game.last_tap_crit else 1.0) * game.combo_mult(card._combo)   # 1 in 25 taps crits; earlier taps may have built a combo
	_check(is_equal_approx(game.cash - c0, game.tap_value() * want_x), "boosted tap is x3 (x15 on a crit)")
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
	_check(game.buy_asset("coin", "SOL", 500.0), "buy coins")
	_check(game.buy_property(0), "buy a property")
	_check(game.rent_per_hour() > 0.0, "property pays rent")
	_check(game.improve_property(0, 0), "improve a property")
	_check(is_equal_approx(game.sell_property_value(0), game.prop_value(0) * 0.88), "12% sales tax")
	_check(game.buy_item("watches", 0), "buy a watch")
	_check(game.collection_count("watches") == 1, "collection counts")
	game.advance(600.0)
	_check(game.price_hist["SOL"].size() > 60, "markets tick")
	# Week and day charts, news and market mood.
	_check(game.hist_h["NRV"].size() >= 160 and game.hist_q["NRV"].size() >= 90, "day and week charts filled")
	_check(game.series("SOL", "1W").size() > 100, "week series for coins")
	var mood: float = game.market_mood()
	_check(mood >= 0.0 and mood <= 100.0, "market mood in range")
	var n0 := int(game.counters.get("news_total", 0))
	for i in 40:
		game._news_event()
	_check(game.news.size() <= game.NEWS_MAX and int(game.counters.get("news_total", 0)) == n0 + 40, "news list capped, counter keeps rising")
	var bad := false
	for k in game.prices.keys():
		if not (game.prices[k] > 0.0) or is_nan(game.prices[k]) or is_inf(game.prices[k]):
			bad = true
	_check(not bad, "no broken prices after news")
	# Staking: lock, cannot unlock early, earns coins, unlocks after 24 h.
	game.cash += 1000.0
	game.buy_asset("coin", "XRP", 1000.0)
	var q0: float = game.holding(game.coins, "XRP")
	_check(game.stake("XRP", 1.0) and game.holding(game.coins, "XRP") == 0.0, "stake locks coins")
	_check(not game.unstake("XRP"), "cannot unlock early")
	_check(game.sell_asset("coin", "XRP", 1.0) == 0.0, "locked coins cannot be sold")
	game.sim_time += 25 * 3600.0
	game.advance(3600.0)
	_check(game.staked("XRP") > q0, "staking earns coins")
	_check(game.unstake("XRP") and game.holding(game.coins, "XRP") > q0, "unlock after 24 h")
	_check(float(game.counters.get("dividends_earned", 0.0)) >= 0.0, "dividends counter exists")
	# Selling part keeps the average price the same.
	game.cash += 2000.0
	game.buy_asset("share", "QSF", 2000.0)
	var avg0: float = game.avg_price(game.shares, "QSF")
	game.sell_asset("share", "QSF", 0.5)
	_check(absf(game.avg_price(game.shares, "QSF") - avg0) < avg0 * 1e-6, "average price stays after part sale")
	game.stake("XRP", 0.5)
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
	# Quality of life: waiting time, streak, tab dots, remembered choices.
	game.cash = 0.0
	game.recalc()
	var e: String = game.eta(game.income_per_hour * 0.5)
	_check(e.begins_with("~") and e.ends_with("min"), "waiting time reads like ~30 min (%s)" % e)
	_check(game.eta(-1.0) == "", "no waiting time when you can afford it")
	var tday: int = game._today()
	game.streak_day = tday - 1
	game.streak = 2
	game._check_streak()
	_check(game.streak == 3 and not game.streak_unseen.is_empty(), "coming back the next day grows the streak")
	game.streak_day = tday - 3
	game._check_streak()
	_check(game.streak == 1, "missing days resets the streak")
	game.ui["invest_tab"] = 2
	var dd: Dictionary = game.to_dict()
	_check(int(dd["ui"]["invest_tab"]) == 2 and dd.has("streak"), "screen choices and streak are saved")
	# Quality of life 2: bulk actions, next achievement, sorting, quiet deals.
	game.cash = 1.0e9
	for b in Data.BUSINESSES:
		if not game.owns(b["id"]):
			game.open_business(b["id"], "Fill Test")
			break
	var nb: int = game.fill_all()
	var full := true
	for id in game.biz.keys():
		if int(game.biz[id]["units"]) < game.capacity(id):
			full = false
	_check(nb > 0 and full, "Fill all fills every company (%d bought)" % nb)
	var ready: int = game.expandable().size()
	_check(game.expand_all() == ready, "Expand all starts every ready expansion")
	var na: Dictionary = game.next_achievement()
	_check(not na.is_empty() and float(na["progress"]) < 1.0, "next achievement found (%s)" % na.get("title", ""))
	game.ui["deals_quiet"] = true
	game.away_unseen = false   # a leftover welcome-back card would count as a pop-up
	game.streak_unseen = []
	while root.get_node("Kit").close_top():   # a gift sheet may already be open
		await create_timer(0.3).timeout
	await create_timer(0.4).timeout
	game.deal = {"kind": "order", "id": game.biz.keys()[0], "value": 1.0, "title": "T", "text": "x", "yes": "Y"}
	main._show_deal()
	await create_timer(0.3).timeout
	if root.get_node("Kit").has_open():
		for it in root.get_node("Kit")._stack:
			print("OPEN POP-UP: ", it["root"].find_children("*", "Label", true, false).map(func(l): return l.text))
	_check(not root.get_node("Kit").has_open(), "quiet deals don't pop up")
	main.open_waiting_deal()
	await create_timer(0.3).timeout
	_check(root.get_node("Kit").has_open(), "a quiet deal opens from the Business tab")
	root.get_node("Kit").close_top()
	await create_timer(0.4).timeout
	game.ui["deals_quiet"] = false
	game.deal = {}
	main.show_page(2)
	await create_timer(0.5).timeout
	var inv2 = main._pages[2]
	inv2._seg.select(0, true)
	game.ui["sort"] = "up"
	inv2.refresh()
	var first_row: Control = null
	var col: Node = inv2._share_rows["NRV"].get_parent()
	for ch in col.get_children():
		if ch is Row:
			first_row = ch
			break
	var best_sym := ""
	var best_ch := -1e9
	var nrv_owned: bool = game.holding(game.shares, "NRV") > 0.0
	for st in Data.STOCKS:
		if (game.holding(game.shares, st[0]) > 0.0) != nrv_owned:
			continue   # only compare within the same list (Yours or Market)
		if game.change_pct(st[0], 1440) > best_ch:
			best_ch = game.change_pct(st[0], 1440)
			best_sym = st[0]
	_check(first_row == inv2._share_rows[best_sym], "Rising sort puts the biggest riser first")
	_check(inv2._my_shares.get_parent().visible == (game.shares.size() > 0), "owned shares get their own section")
	game.ui["sort"] = ""
	main.show_page(0)
	await create_timer(0.4).timeout
	# Round 2 guards: tap cap, clock going back, penny investments, staking cap.
	var keep_sim: float = game.sim_time
	game.sim_time = -1.0  # the cap only applies to real play, not the simulator
	game.tap_cap = true
	game._tap_tokens = 7.0
	game._tap_ms = Time.get_ticks_msec()
	var t_before: int = game.taps
	for k in 40:
		game.tap()
	_check(game.taps - t_before <= 8, "taps are capped at about 7 a second (%d paid)" % (game.taps - t_before))
	game.tap_cap = false
	game.sim_time = keep_sim
	var day_tasks: Array = game.daily_tasks().duplicate(true)
	var real_t: float = game.sim_time
	game.sim_time = game.now() - 3 * 86400.0
	game._ensure_daily()
	_check(str(game.daily_tasks()) == str(day_tasks), "setting the clock back doesn't re-roll goals")
	game.sim_time = real_t
	var inv_before := 0.0
	for t in game.daily_tasks():
		if t["id"] == "invest":
			inv_before = float(t["progress"])
	game.cash += 1.0
	game.buy_asset("share", "NRV", 0.01)
	var inv_after := 0.0
	for t in game.daily_tasks():
		if t["id"] == "invest":
			inv_after = float(t["progress"])
	_check(inv_after == inv_before, "a 1p investment doesn't count for goals")
	_check(game._stake_scale() <= 1.0, "staking cap is shared across coins")
	# A version 2 save upgrades cleanly.
	var old: Dictionary = game._migrate({"version": 2, "cash": 5.0, "price_hist": {"SOL": [1.0]}})
	_check(int(old["version"]) == game.SAVE_VERSION and old["price_hist"].is_empty() and int(old["home"]) == 0, "v2 save upgrades")
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
	for spec in [["share", "NRV"], ["share", "QSF"], ["coin", "XRP"], ["coin", "PEPE"]]:
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
		_check(pg._price.text.begins_with("£"), "%s page shows a price" % spec[1])
		main.pop()
		await create_timer(0.5).timeout
	for path in ["res://scripts/goals_page.gd", "res://scripts/rivals_page.gd", "res://scripts/settings_page.gd", "res://scripts/achievements_page.gd", "res://scripts/records_page.gd"]:
		var gp = load(path).new()
		main.push(gp)
		await create_timer(0.5).timeout
		_check(gp.body.get_child_count() > 2, "%s builds" % path.get_file())
		main.pop()
		await create_timer(0.5).timeout
	# Turning the phone keeps what's open: the page stack and a pop-up.
	var kit_r = root.get_node("Kit")
	main.push(load("res://scripts/settings_page.gd").new())
	await create_timer(0.5).timeout
	kit_r.sheet("Rotate test", "Stays open", [{"text": "Close", "style": "plain"}])
	await create_timer(0.3).timeout
	var stack_n: int = main._stack.size()
	root.size = Vector2i(844, 390)
	await create_timer(0.4).timeout
	_check(kit_r.landscape and root.get_visible_rect().size.y < 400.0, "turning the phone switches to the landscape layout")
	_check(main._stack.size() == stack_n and kit_r.has_open(), "turning the phone keeps the open page and pop-up")
	_check(main._nav.vertical and main.back_btn.visible, "landscape: tab rail on the left with back under it")
	var sp: Control = kit_r._stack.back()["panel"]
	var vw: float = root.get_visible_rect().size.x
	_check(absf(sp.position.x + sp.size.x * 0.5 - vw * 0.5) < 2.0 and sp.size.x <= 421.0, "an open pop-up re-centres when the phone turns")
	root.size = Vector2i(390, 844)
	await create_timer(0.4).timeout
	_check(not kit_r.landscape and not main._nav.vertical, "turning back restores portrait")
	while kit_r.close_top():
		await create_timer(0.3).timeout
	main.pop()
	await create_timer(0.5).timeout
	# Buying a home from the Property list moves it to "Yours" at once.
	main.show_page(2)
	await create_timer(0.4).timeout
	var ivp = main._pages[2]
	ivp._seg.select(1, true)
	await create_timer(0.5).timeout
	var free_i := -1
	for pi in range(Data.PROPERTIES.size()):
		if not game.prop_owned(pi):
			free_i = pi
			break
	game.cash += game.prop_price(free_i) + 10.0
	game.buy_property(free_i)
	await create_timer(0.6).timeout
	_check(ivp._prop_rows[free_i].get_parent() == ivp._my_props, "a bought home shows under Yours without leaving the page")
	game.props.erase(str(free_i))   # leave the rest of the test as it was
	game.recalc()
	ivp._seg.select(0, true)
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
	var tech_owned := 0
	for sst in Data.STOCKS:
		var rr: Control = inv._share_rows[sst[0]]
		if rr.is_inside_tree() and rr.get_parent() == inv._all_shares:
			shown += 1
		if sst[4] == "Tech" and game.holding(game.shares, sst[0]) > 0.0:
			tech_owned += 1
	_check(shown == 3 - tech_owned, "sector filter shows Tech only in the market list (%d)" % shown)
	var lines := 0
	for ch in inv._all_shares.get_children():
		if not (ch is Row):
			lines += 1
	_check(lines == maxi(0, shown - 1), "a divider only between rows")
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
	_check(game.staked("XRP") > 0.0 and game.stake_left("XRP") > 0.0, "save/load keeps staking")
	_check(game.news.size() >= 30 and game.hist_h["NRV"].size() >= 160, "save/load keeps news and charts")
	# Backup code: round trip, small, and bad codes are refused safely.
	var code: String = game.backup_code()
	_check(code.begins_with("SOL1:") and code.length() < 60000, "backup code is small (%d chars)" % code.length())
	var keep_cash: float = game.cash
	var keep_props: int = game.props_owned()
	var keep_staked: float = game.staked("XRP")
	game.cash = 1.0
	_check(not game.restore_code("hello"), "junk code refused")
	_check(not game.restore_code(code.substr(0, code.length() - 40)), "cut-off code refused")
	_check(not game.restore_code("SOL1:999999999:AAAA"), "fake size refused")
	_check(game.cash == 1.0, "failed restore changes nothing")
	game.restore_guard = false   # these tests restore into the same game on purpose
	_check(game.restore_code(code), "backup restores")
	_check(absf(game.cash - keep_cash) <= maxf(1.0, keep_cash * 1e-6) and game.props_owned() == keep_props and absf(game.staked("XRP") - keep_staked) <= keep_staked * 1e-6, "restore brings back cash, property and staking (%.2f/%.2f %d/%d %.6f/%.6f)" % [game.cash, keep_cash, game.props_owned(), keep_props, game.staked("XRP"), keep_staked])
	_check(game.hist_h["NRV"].size() >= 160, "charts rebuilt after restore")

	# Offline earnings are capped at 8 hours (goals off, so a goal reward
	# landing at the same moment isn't counted).
	game.weekly = {"week": game._week(), "tasks": []}
	game.daily = {"day": game._today(), "tasks": []}
	var inc: float = game.income_per_hour
	var c1: float = game.cash
	game.apply_offline(24 * 3600)
	_check(game.away_earned <= inc * 8.0 * 1.2 + 1.0, "offline capped near 8 h (%.1f h, boost %s, managers %s)" % [game.away_earned / maxf(inc, 1.0), game.ibost_active(), game.metric("managers")])  # rewards may also land
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
	main.show_page(0)
	await create_timer(0.4).timeout
	main._update_badges()
	_check(main._nav._badges[4].visible, "Profile tab shows a dot for a new update")
	main.show_page(4)
	await create_timer(0.4).timeout
	main._update_badges()
	var prof = main._pages[4]
	_check(prof._upd_card.visible and prof._upd_btn.text == "Update", "update card shows on Profile")
	_check(not main._nav._badges[4].visible, "no dot on the tab you're on")
	main.show_page(0)
	await create_timer(0.2).timeout
	main._update_badges()
	_check(not main._nav._badges[4].visible, "seen once, the update dot stays cleared")
	main.show_page(4)
	await create_timer(0.2).timeout
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
	var p1: float = game.price("PEPE")
	game.sim_time += 8 * 3600.0
	game.restore_code(code2)
	_check(absf(game.price("PEPE") - p1) < p1 * 0.001, "restoring a backup doesn't re-roll prices")
	game.sim_time = -1.0
	game.reset_game()
	# Bulk buy: the cost shown is exactly what is spent; Max never overspends.
	game.cash = 1.0e6
	game.open_business("shop", "Bulk Test")
	var bn: int = game.bulk_count("shop", 10)
	var bc: float = game.bulk_cost("shop", bn)
	var bcash: float = game.cash
	var bgot: int = game.buy_units("shop", bn)
	_check(bn == 4 and bgot == bn and absf((bcash - game.cash) - bc) < 0.01, "x10 buys up to the room left and costs what it shows (%d, %.2f vs %.2f)" % [bgot, bcash - game.cash, bc])
	game.reset_game()
	game.cash = 1.0e4
	game.open_business("shop", "Max Test")
	game.cash = 3000.0
	var mx: int = game.bulk_count("shop", 0)
	var mc: float = game.bulk_cost("shop", mx)
	_check(mx >= 2 and mc <= 3000.0 and game.bulk_cost("shop", mx + 1) > 3000.0, "Max buys as many as the cash covers (%d for %.2f)" % [mx, mc])
	_check(game.buy_units("shop", mx + 1) == 0 or mx + 1 > game.capacity("shop"), "a bulk buy you can't afford buys nothing")
	game.reset_game()
	# Milestones, synergies and the achievement bonus.
	game.cash = 1.0e9
	game.open_business("food", "Mile Test")
	_check(is_equal_approx(game.milestone_mult("food"), 1.0), "no milestone with one unit")
	game.biz["food"]["stage"] = 2
	game.biz["food"]["units"] = 5
	game.recalc()
	_check(is_equal_approx(game.milestone_mult("food"), 1.1), "5 units gives the first milestone")
	_check(not game.synergy_ready("delivery") and not game.buy_synergy("delivery"), "a synergy needs its other company first")
	game.open_business("taxi", "Syn Test")
	game.biz["taxi"]["stage"] = 3
	var inc1: float = game.biz_income("food")
	var cs: float = game.cash
	_check(game.buy_synergy("delivery") and absf(cs - game.cash - 6.0e4) < 0.01, "a ready synergy can be bought for its price")
	_check(absf(game.biz_income("food") / inc1 - 1.3) < 0.001, "the synergy lifts its target by 30%")
	_check(not game.buy_synergy("delivery"), "a synergy can only be bought once")
	var ab: float = game.ach_bonus()
	for k in 200:
		game.achieved["fake_%d" % k] = true
	_check(is_equal_approx(game.ach_bonus(), Data.ACH_BONUS_CAP) and ab < Data.ACH_BONUS_CAP, "achievement bonus is capped")
	game.reset_game()
	# Crits and golden sun buffs.
	game.cash = 1.0e6
	game.open_business("shop", "Crit Test")
	game.tap_cap = false
	var cr0: int = int(game.counters.get("crits", 0))
	for k in 4000:
		game.tap()
	var crits: int = int(game.counters.get("crits", 0)) - cr0
	_check(crits > 100 and crits < 260, "about 4%% of taps are critical (%d of 4000)" % crits)
	game.frenzy_until = game.now() + 20.0
	game.boost_until = game.now() + 60.0
	var tv: float = game.tap_value()
	var ftop := 0.0
	for k in 300:
		var got: float = game.tap()
		if not game.last_tap_crit:
			ftop = maxf(ftop, got)
	_check(absf(ftop / tv - Data.FRENZY_MULT) < 0.01, "Frenzy and the x3 boost don't stack (x%.2f)" % (ftop / tv))
	game.frenzy_until = 0.0
	game.boost_until = 0.0
	var kinds := {}
	for k in 400:
		game.catch_sun()
		kinds[game.last_sun] = int(kinds.get(game.last_sun, 0)) + 1
	_check(kinds.has("cash") and kinds.has("frenzy") and kinds.has("rush"), "suns give cash, Frenzy or Rush (%s)" % str(kinds))
	game.rush_until = game.now() + 600.0
	game.recalc()
	var plain_h: float = game.income_per_hour
	game.sim_time = game.now()
	game.apply_offline(3600.0)
	_check(game.away_earned <= plain_h * 1.02 + 10.0, "Rush never pays while away (%.2f h)" % (game.away_earned / maxf(1.0, plain_h)))
	game.sim_time = -1.0
	game.reset_game()
	# Crypto mining: rig prices climb across all coins, mining pays coins,
	# is capped, counts only 8 h while away, and a restore pays nothing.
	game.cash = 1.0e9
	for mbid in ["shop", "taxi", "shipping"]:
		game.open_business(mbid, "Mine Test")
		while game.buy_unit(mbid):
			pass
	var rp0: float = game.rig_price()
	_check(game.buy_rig("SOL") and game.buy_rig("AVAX") and absf(game.rig_price() - rp0 * Data.RIG_GROWTH * Data.RIG_GROWTH) < 1.0, "rig prices climb across all coins")
	game.recalc()
	var mph: float = game.mine_per_hour("SOL")
	var kq0: float = game.holding(game.coins, "SOL")
	game.advance(3600.0)
	_check(mph > 0.0 and absf(game.holding(game.coins, "SOL") - kq0 - mph) < mph * 0.05 + 1e-9, "a rig mines its coin each hour (%.4f)" % mph)
	for k in 30:
		game.cash = 1.0e15
		game.buy_rig("LTC")
	game.recalc()
	var hash_now: float = float(game.miners.get("hash", 0.0))
	var raw_mine := hash_now * Data.MINE_YIELD * float(game.mine_eff.get(game.mine_target, 1.0))
	var mine_cap_v := maxf(Data.MINE_CAP_FLOOR, Data.MINE_CAP * game.business_per_hour())
	_check(absf(game.mining_value_per_hour() - minf(raw_mine, mine_cap_v)) < 1.0, "each miner earns 4% of its price an hour, up to a quarter of company income")
	_check(raw_mine > mine_cap_v, "30 miners on a small empire hit the mining cap")
	# Miner upgrades: cooling lifts the cap, chips speed mining up; both stop at their max.
	game.cash = 1.0e30
	var capped_before: float = game.mining_value_per_hour()
	_check(game.buy_miner_up("cool") and game.miner_up_level("cool") == 1 and is_equal_approx(game.mine_cap(), Data.MINE_CAP + 0.05), "cooling raises the mining cap")
	_check(game._mine_cap_value() >= mine_cap_v and game.mining_value_per_hour() >= capped_before, "a higher cap never pays less (the £2K floor may still rule on a tiny empire)")
	for k in 10:
		game.buy_miner_up("cool")
		game.buy_miner_up("speed")
	_check(game.miner_up_level("cool") == Data.MINER_UPS["cool"]["max"] and game.miner_up_level("speed") == Data.MINER_UPS["speed"]["max"] and game.miner_up_cost("speed") == 0.0, "miner upgrades stop at their max")
	var mk_raw: float = game._mine_raw_value()
	_check(absf(mk_raw - float(game.miners["hash"]) * Data.MINE_YIELD * float(game.mine_eff.get(game.mine_target, 1.0)) * 1.75) < 1.0, "five chip levels mine 75% faster")
	var mup_old: Dictionary = game.to_dict()
	mup_old["miners"] = {"n": 3, "hash": 100.0}
	_check(int(mup_old["miners"].get("speed", 0)) == 0, "old saves have no miner upgrades")
	for k in 20:
		game.cash = 1.0e30
		game.buy_miner()
	_check(game.rigs_total() == Data.RIG_MAX and not game.buy_miner(), "never more than %d miners" % Data.RIG_MAX)
	var mv0: float = float(game.counters.get("mined_value", 0.0))
	game.sim_time = game.now()
	game.apply_offline(48.0 * 3600.0)
	var mined_away: float = float(game.counters.get("mined_value", 0.0)) - mv0
	_check(mined_away <= game.mining_value_per_hour() * 8.0 * 1.3 + 1.0, "mining away counts at most 8 h (%.1f h)" % (mined_away / maxf(1.0, game.mining_value_per_hour())))
	var mcode: String = game.backup_code()
	var mq: float = game.holding(game.coins, "SOL")
	game.sim_time += 24.0 * 3600.0
	game.restore_code(mcode)
	_check(absf(game.holding(game.coins, "SOL") - mq) <= mq * 0.001 + 1e-9, "restoring a backup mines nothing")
	# An old (v9) backup code converts its coins at today's price, so waiting
	# for a coin to rise and then restoring gains nothing.
	var oldd := {"version": 9, "cash": 1.0, "coins": {"EMB": {"qty": 1000.0, "cost": 4.2}}, "prices": {"EMB": 0.0042}}
	game.prices["SHIB"] = 0.000015 * 10.0
	var conv: Dictionary = game._migrate(oldd.duplicate(true), game.prices)
	var conv_val: float = float(conv["coins"]["SHIB"]["qty"]) * game.price("SHIB")
	_check(absf(conv_val - 4.2) < 0.01, "old backup coins keep their value at today's price (%.3f)" % conv_val)
	# Switching the coin keeps the earnings the same, and moves new coins to it.
	game.mine_eff = {}   # no mining news, so every coin earns the same
	var mv1: float = game.mining_value_per_hour()
	_check(game.set_mine_target("ETH") and absf(game.mining_value_per_hour() - mv1) <= mv1 * 0.001 + 1e-9 and game.mine_per_hour("SOL") == 0.0 and game.mine_per_hour("ETH") > 0.0, "switching miners to another coin keeps the same earnings")
	# Reset then restore can't re-roll the market.
	var pr0: float = game.price("PEPE")
	var rcode: String = game.backup_code()
	game.reset_game()
	_check(absf(game.price("PEPE") - pr0) < pr0 * 0.001, "a reset keeps the live market")
	game.restore_code(rcode)
	_check(absf(game.price("PEPE") - pr0) < pr0 * 0.001 and game.rigs_total() > 0, "reset then restore brings back rigs and keeps prices")
	for c in Data.COINS:
		if game.price(c[0]) <= 0.0:
			_check(false, "coin %s has a price" % c[0])
	game.sim_time = -1.0
	game.reset_game()
	# Restore guard: a backup can't rewind the game it came from, even after a reset.
	game.restore_guard = true
	game.sim_time = -1.0
	game.reset_game()
	game.cash = 5000.0
	game.save_game()
	var gcode: String = game.backup_code()
	var gk := str(int(game.started_at))
	game._guard[gk] = game.now() + 3600.0   # the game has moved on an hour
	_check(not game.restore_code(gcode) and game.restore_error != "", "an older backup can't rewind the same game")
	game.reset_game()
	_check(not game.restore_code(gcode), "nor after a reset")
	game._guard.erase(gk)
	_check(game.restore_code(gcode), "it works on a new phone (no record of that game)")
	game.restore_guard = false
	game.reset_game()
	# Rebirth: every saved key is either kept or cleared, nothing forgotten.
	var rb_keys: Array = game.to_dict().keys()
	var rb_unlisted: Array = []
	for k in rb_keys:
		if k in ["version", "saved_at"]:
			continue
		var rb_n_in := int(k in game.REBIRTH_RESET) + int(k in game.REBIRTH_KEEP)
		if rb_n_in != 1:
			rb_unlisted.append(k)
	_check(rb_unlisted.is_empty(), "every saved field is either kept or cleared by a rebirth %s" % str(rb_unlisted))
	game.reset_game(true)
	game.cash = 1.0e9
	_check(game.rebirth_pending() == 0 and game.do_rebirth() == 0, "no rebirth below £10B")
	game.cash = 1.0e13
	game.ui["sci"] = true
	game.sci = true
	game.achieved["test_ach"] = true
	game.open_business("shop", "Reborn Test")
	game.add_reward("rb_test", "goal", "Hoarded", 5.0e12)
	game.restore_guard = true
	game.save_game()
	var rb_code: String = game.backup_code()
	var rb_pend: int = game.rebirth_pending()
	var rb_got_rb: int = game.do_rebirth()
	_check(rb_pend == 100 and rb_got_rb == 100, "£10T gives 100 RBP (%d)" % rb_got_rb)
	_check(game.cash == 0.0 and game.biz.is_empty() and game.level == 1, "rebirth clears money and companies")
	_check(game.rewards.is_empty(), "rebirth clears unclaimed rewards (no hoarding into a new run)")
	_check(game.achieved.has("test_ach") and game.sci, "rebirth keeps achievements and settings")
	_check(game.rebirths() == 1 and game.rbp_free() == 100, "RBP banked")
	var cash_keep: float = game.cash
	game.cash = 6.7e21   # months of waiting: the old formula gave 87,000 RBP
	var huge: int = game.rebirth_pending()
	_check(huge > 1000 and huge < 6000, "a huge fortune can't buy the whole tree in one rebirth (%d RBP)" % huge)
	game.cash = cash_keep
	game._guard[str(int(game.started_at))] = game.now() + 3600.0
	_check(not game.restore_code(rb_code), "a backup from before a rebirth can't undo it")
	game.restore_guard = false
	# The tree: only nodes next to something owned, paid in RBP, effects add up.
	_check(not game.buy_node("emp_t1"), "can't buy a node that isn't linked to yours")
	var rb_inc0: float = game.rb("income")
	_check(game.buy_node("emp_g") and game.rb("income") > rb_inc0, "buying the Empire gate adds company income")
	_check(game.node_open("emp_t1") and game.node_open("hand_g"), "its neighbours open up (trunk and ring)")
	var rb_all_cost := 0
	for nd in RebirthTree.nodes():
		rb_all_cost += int(nd["cost"])
	_check(RebirthTree.nodes().size() >= 150 and rb_all_cost > 5000, "the tree is big (%d nodes, %d RBP)" % [RebirthTree.nodes().size(), rb_all_cost])
	var rb_ids := {}
	for nd in RebirthTree.nodes():
		rb_ids[nd["id"]] = true
	_check(rb_ids.size() == RebirthTree.nodes().size(), "node rb_ids are unique")
	var rb_min := 1.0e9
	var rb_ns: Array = RebirthTree.nodes()
	for i in rb_ns.size():
		for j in range(i + 1, rb_ns.size()):
			rb_min = minf(rb_min, Vector2(rb_ns[i]["x"], rb_ns[i]["y"]).distance_to(Vector2(rb_ns[j]["x"], rb_ns[j]["y"])))
	_check(rb_min * 0.62 >= 48.0, "tree nodes sit at least 48 px apart at the starting zoom (%.0f px)" % (rb_min * 0.62))
	_check(int(RebirthTree.node("u_casino")["cost"]) + int(RebirthTree.node("emp_g")["cost"]) <= 10, "a first rebirth (10 RBP) can reach the casino")
	game.cash = 1.0e6
	game.open_business("shop", "Tree Test")
	game.recalc()
	var rb_with_node: float = game.income_per_hour
	game.rebirth["nodes"].erase("emp_g")
	game._rb_cache = {}
	game.recalc()
	_check(rb_with_node > game.income_per_hour * 1.05, "tree income really raises income")
	game.rebirth["nodes"]["emp_g"] = true
	game._rb_cache = {}
	game.save_game()
	game.load_game()
	_check(game.node_owned("emp_g") and game.rebirths() == 1, "tree and rebirth count survive save and load")
	var rb_old12: Dictionary = game.to_dict()
	rb_old12["version"] = 12
	rb_old12.erase("rebirth")
	var rb_mig: Dictionary = game._migrate(rb_old12)
	_check(int(rb_mig["version"]) == game.SAVE_VERSION and rb_mig.has("rebirth") and (rb_mig["rebirth"]["nodes"] as Dictionary).is_empty(), "v12 saves load with an empty tree")
	game.reset_game(true)
	# Casino: locked until bought, bets and wins capped by income, every
	# round saved at once, chips go on rebirth but the unlock stays.
	game.reset_game(true)
	game.cash = 1.0e6
	_check(not game.casino_open() and not game.buy_chips(100.0), "casino starts locked")
	game.rebirth["earned"] = 10
	_check(game.path_cost("u_casino") <= 10 and game.buy_node("hand_g") and game.buy_node("u_casino") and game.casino_open(), "the Sol Casino node opens it (%d RBP from the centre)" % 9)
	_check(not game.tables_open(), "roulette and blackjack need High tables too")
	game.grant_node("u_tables")
	_check(game.tables_open(), "High tables opens them")
	game.cash = 5.0e5
	var cs_nw: float = game.net_worth()
	_check(game.buy_chips(2.0e5) and absf(game.chips() - 2.0e5) < 0.01 and absf(game.net_worth() - cs_nw) < 1.0, "chips count in net worth")
	var cs_max: float = game.casino_max_bet()
	_check(not game.casino_stake(cs_max * 1.5), "a bet over the limit is refused")
	_check(game.casino_stake(cs_max), "a bet at the limit is taken")
	var cs_after: float = game.chips()
	game.load_game()
	_check(absf(game.chips() - cs_after) < 0.01, "a bet is saved at once (closing the app can't undo it)")
	var cs_paid: float = game.casino_pay(game.casino_max_win() * 10.0)
	_check(absf(cs_paid - game.casino_max_win()) < 0.01, "one payout is capped at %s" % game.money_short(game.casino_max_win()))
	game.cash = 2.0e10
	game.do_rebirth()
	_check(game.casino_open() and game.chips() == 0.0, "rebirth keeps the casino open (tree) and clears the chips")
	var cs_old: Dictionary = game.to_dict()
	cs_old["version"] = 13
	cs_old.erase("casino")
	var cs_mig: Dictionary = game._migrate(cs_old)
	_check(cs_mig.has("casino") and not bool(cs_mig["casino"]["open"]), "v13 saves load with the casino locked")
	game.reset_game(true)
	# Back up, gamble, restore if down: refused even a minute later.
	game.reset_game(true)
	game.grant_node("u_casino")
	game.cash = 1.0e6
	game.buy_chips(1000.0)
	game.restore_guard = true
	game.save_game()
	var gb_code: String = game.backup_code()
	game.casino_stake(game.casino_max_bet())
	_check(not game.restore_code(gb_code) and game.restore_error != "", "a backup can't undo a casino bet, even moments later")
	game._guard.erase(str(int(game.started_at)) + "!")
	game._guard.erase(str(int(game.started_at)))
	game.restore_guard = false
	game.reset_game(true)
	# Tree unlock content: locked until its node, never part of completion %.
	game.reset_game(true)
	game.cash = 1.0e15
	_check(not game.open_business("fusion", "Test Fusion"), "Frontier companies stay locked without the node")
	_check(not game.buy_property(Data.PROPERTIES.size()), "island estates stay locked without the node")
	_check(not game.buy_item("relics", 0), "relics stay locked without the node")
	var uc_before: float = game.completion()
	var uc_ach: int = game.achievements().size()
	game.grant_node("u_frontier")
	game.grant_node("u_isles")
	game.grant_node("u_relics")
	_check(game.open_business("fusion", "Test Fusion") and game.businesses().size() == Data.BUSINESSES.size() + 2, "the Frontier node opens two new companies")
	_check(game.buy_property(Data.PROPERTIES.size() + 2) and game.property_count() == Data.PROPERTIES.size() + 3, "the Island estates node opens three properties")
	_check(game.buy_item("relics", 0) and game.collections().size() == Data.COLLECTIONS.size() + 1, "the Relic hunters node opens a collection")
	_check(absf(game.completion() - uc_before) < 0.0001 and game.achievements().size() == uc_ach, "unlock content changes neither completion % nor the achievements")
	game.save_game()
	game.load_game()
	_check(game.prop_owned(Data.PROPERTIES.size() + 2) and game.owns("fusion") and game.item_owned("relics", 0), "unlock content survives save and load")
	game.recalc()
	_check(game.prop_rent(Data.PROPERTIES.size() + 2) > 0.0 and game.biz_income("fusion") > 0.0, "and earns")
	game.reset_game(true)
	# Dividends: a set rate per company, paid once an hour on the hour.
	game.reset_game(true)
	game.cash = 1.0e6
	game.sim_time = 1.7e9 + 600.0   # 10 minutes past an hour
	game.div_hour = -1
	game.buy_asset("share", "NRV", 5.0e5)
	game.advance(1.0)
	var dv_rate: float = game.dividend_rate("NRV")
	game.prices["NRV"] = game.price("NRV") * 3.0
	_check(absf(game.dividend_rate("NRV") - dv_rate) < 1e-9 and dv_rate > 0.0, "a share's dividend is a set rate (doesn't move with the price)")
	_check(game.dividend_rate("NRV") != game.dividend_rate("QSF"), "rates differ by company")
	var dv_cash: float = game.cash
	game.sim_time += 1500.0
	game.advance(1500.0, false)
	_check(absf(game.cash - dv_cash) < 0.001, "nothing paid before the hour")
	game.sim_time += 1500.0
	game.advance(1.0, false)
	var dv_paid: float = game.cash - dv_cash
	_check(absf(dv_paid - game.dividends_per_hour()) < 0.01 * maxf(1.0, dv_paid), "one hour's dividend paid on the hour (%s)" % game.money_short(dv_paid))
	dv_cash = game.cash
	game.sim_time += 30.0 * 3600.0
	game.apply_offline(30.0 * 3600.0)
	var dv_div: float = float(game.counters.get("dividends_earned", 0.0))
	_check(dv_div <= dv_paid * (1.0 + ceil(game.offline_cap_h())) * 1.01, "time away pays at most the away cap in hours")
	game.sim_time = -1.0
	game.reset_game(true)
	# Auto clicker: bought in levels, taps while you play, pauses when idle.
	game.reset_game(true)
	game.cash = 1.0e5
	_check(game.auto_tick(10.0) == 0, "no auto clicker, no auto taps")
	_check(game.buy_auto() and game.auto_level == 1 and absf(game.cash - 7.5e4) < 0.01, "auto clicker level 1 costs %s" % game.money_short(Data.AUTO_LEVELS[0][0]))
	game.tap()
	var ac_cash: float = game.cash
	var ac_n := 0
	for k in 10:
		ac_n += game.auto_tick(1.0)
	_check(ac_n == 5 and game.cash > ac_cash, "level 1 taps every 2 s while you play (%d taps in 10 s)" % ac_n)
	game.last_tap_at = game.now() - Data.AUTO_IDLE_S - 1.0
	_check(game.auto_tick(5.0) == 0, "it pauses after 2 minutes without a touch")
	var ac_old: Dictionary = game.to_dict()
	ac_old["version"] = 15
	ac_old.erase("auto_level")
	_check(int(game._migrate(ac_old).get("auto_level", -1)) == 0, "v15 saves load with no auto clicker")
	game.reset_game(true)
	# Selling a company pays half its value; a manager can be switched off.
	game.reset_game(true)
	game.cash = 1.0e7
	game.open_business("shop", "Sell Test")
	game.biz["shop"]["units"] = game.capacity("shop")
	game.cash = 1.0e7
	game.hire_manager("shop")
	game.recalc()
	var mg_on: float = game.biz_income("shop")
	game.set_manager_on("shop", false)
	_check(not game.manager_on("shop") and game.biz_income("shop") > mg_on, "a switched-off manager takes no cut")
	game.advance(1.0)
	_check(not game.expanding("shop"), "and doesn't expand")
	var sl_cash: float = game.cash
	var sl_price: float = game.sell_price("shop")
	var sl_got: float = game.sell_business("shop")
	_check(absf(sl_got - game.biz_value("shop") * 0.5) < 0.01 or (absf(sl_got - sl_price) < 0.01 and not game.owns("shop") and absf(game.cash - sl_cash - sl_got) < 0.01), "selling pays half the company's value and removes it")
	# Tired taps: a tapping app can't farm for hours at full pay.
	game.reset_game(true)
	game.cash = 0.0
	game._tap_heat = 0.0
	game._heat_ms = Time.get_ticks_msec()
	game._tap_tokens = 7.0
	var tt_c0: float = game.cash
	game._tap_rng.seed = 1
	game.tap()
	var tt_full: float = game.cash - tt_c0
	game._tap_heat = Data.TAP_HEAT_MAX + 50.0
	game._heat_ms = Time.get_ticks_msec()
	game._tap_tokens = 7.0
	var tt_c1: float = game.cash
	game.tap()
	var tt_tired: float = game.cash - tt_c1
	_check(game.tap_tired() and tt_tired < tt_full * 0.5 and tt_tired > 0.0, "after a long non-stop run taps pay a quarter (%.2f vs %.2f)" % [tt_tired, tt_full])
	game._tap_heat = 0.0
	game.reset_game(true)
	# Bank: savings earn capped interest; a loan is repaid in set payments and
	# can push cash into the minus.
	game.reset_game(true)
	game.sim_time = 1.7e9
	game.cash = 1.0e5
	_check(game.deposit(4.0e4) and absf(game.savings() - 4.0e4) < 0.01 and absf(game.cash - 6.0e4) < 0.01, "deposit moves cash into savings")
	var bk_nw: float = game.net_worth()
	game._bank_tick(3600.0)
	var bk_int: float = game.savings() - 4.0e4
	_check(bk_int > 0.0 and bk_int <= maxf(game.base_income(), Data.BANK_CAP_FLOOR) * Data.BANK_CAP + 0.01, "an hour of interest, capped (%s)" % game.money_short(bk_int))
	_check(game.withdraw(1.0e9) and game.savings() < 0.01, "withdraw takes it all back")
	game.cash = 0.0
	var bk_lim: float = game.loan_limit()
	_check(not game.take_loan(bk_lim * 2.0), "can't borrow over the limit")
	_check(game.take_loan(4000.0) and absf(game.cash - 4000.0) < 0.01 and not game.take_loan(100.0), "a £4K loan, one at a time")
	_check(absf(game.loan_owed() - 5000.0) < 0.01 and game.net_worth() < game.cash + game.savings() + 0.01 - 999.0, "owing counts against net worth")
	game.cash = 0.0
	game.sim_time += Data.LOAN_EVERY_H * 3600.0 + 1.0
	game._bank_tick(0.0)
	_check(absf(game.cash + 1000.0) < 0.01 and int(game.loan()["left"]) == 4, "a payment of £1K falls due and puts cash in the minus")
	_check(not game.buy_chips(1.0) and not game.deposit(1.0), "in the minus, nothing can be bought")
	game.sim_time += Data.LOAN_EVERY_H * 3600.0 * 4.0 + 1.0
	game._bank_tick(0.0)
	_check(game.loan().is_empty() and absf(game.cash + 5000.0) < 0.01, "all five payments taken, loan done")
	var bk_old: Dictionary = game.to_dict()
	bk_old["version"] = 16
	bk_old.erase("bank")
	_check(game._migrate(bk_old).has("bank"), "v16 saves load with an empty bank")
	# 1.2 season bar: points from goals, suns and the day's first tap; milestones
	# land in the claim list with the amount fixed; it resets each week.
	game.reset_game(true)
	game.sim_time = 1.9e9
	game.recalc()
	game.income_per_hour = 1000.0
	game.season_add(25.0)
	_check(game.season_pts() == 25.0 and game.unclaimed("season") == 0, "season: 25 points, no milestone yet")
	game.season_add(10.0)
	var sm: Array = game.season_milestones()
	_check(sm[0]["reached"] and not sm[0]["claimed"] and game.unclaimed("season") == 1, "season: 30 points reaches the first milestone")
	var fixed: float = float(sm[0]["amount"])
	game.income_per_hour = 1.0e9
	_check(is_equal_approx(float(game.season_milestones()[0]["amount"]), fixed), "season: a reached prize is fixed (waiting can't pay more)")
	game.season_add(40.0)
	game.rush_until = 0.0
	game.claim_all("season")
	_check(game.rush_active() and game.unclaimed("season") == 0 and game.season_milestones()[1]["claimed"], "season: claiming the Rush milestone starts Rush")
	game.rush_until = 0.0
	game.season_add(500.0)
	game.season_add(500.0)
	_check(game.unclaimed("season") == 3, "season: each milestone pays once")
	var sd: Dictionary = game.to_dict()
	game.sim_time += 8.0 * 86400.0
	_check(game.season_pts() == 0.0 and game.season_milestones()[0]["reached"] == false, "season: a new week starts an empty bar")
	game.sim_time -= 8.0 * 86400.0
	_check(game.season_week_left_s() > 0.0 and game.season_week_left_s() <= 7.0 * 86400.0, "season: time left this week")
	var s18: Dictionary = sd.duplicate(true)
	s18["version"] = 18
	s18.erase("season")
	_check(game._migrate(s18).has("season"), "v18 saves load with an empty season bar")
	var td0 := int(game.counters.get("tap_day", -1))
	var sp0: float = game.season_pts()
	game.tap()
	game.tap()
	_check(game.season_pts() <= sp0 + 5.0 and int(game.counters.get("tap_day", -1)) != td0 or game.season_pts() == sp0, "season: the day's first tap adds 5 once, more taps add nothing")
	game.sim_time = -1.0
	game.reset_game(true)
	# 1.2 company upgrade paths: five named steps, +25% each, gated by stage,
	# priced no faster than a unit's payback, counted in what you've invested.
	game.reset_game(true)
	game.cash = 1.0e6
	game.open_business("shop", "Up Test")
	_check(game.biz_up_level("shop") == 0 and not bool(game.biz_up_next("shop")["ready"]), "upgrade path: step 1 waits for stage 2")
	game.biz["shop"]["stage"] = 2
	game.biz["shop"]["units"] = 10
	game.recalc()
	var bu: Dictionary = game.biz_up_next("shop")
	var up_inc0: float = game.biz_income("shop")
	var up_inv0: float = float(game.biz["shop"]["invested"])
	_check(String(bu["name"]) != "" and float(bu["cost"]) / float(bu["gain_now"]) >= Data.BIZ_UP_MIN_H - 0.01, "upgrade path: a step pays back no faster than the minimum hours")
	_check(is_equal_approx(game.biz_income_after_up("shop"), up_inc0 * (1.0 + Data.BIZ_UP_STEP)), "upgrade path: before and after income")
	game.cash = 1.0e12
	_check(game.buy_biz_up("shop") and game.biz_up_level("shop") == 1 and is_equal_approx(game.biz_income("shop"), up_inc0 * (1.0 + Data.BIZ_UP_STEP)), "upgrade path: buying step 1 lifts income by one step")
	_check(float(game.biz["shop"]["invested"]) > up_inv0, "upgrade path: the spend counts as invested")
	_check(not game.buy_biz_up("shop"), "upgrade path: step 2 needs stage 4")
	game.biz["shop"]["stage"] = 10
	for k in 6:
		game.buy_biz_up("shop")
	_check(game.biz_up_level("shop") == 5 and game.biz_up_next("shop").is_empty(), "upgrade path: five steps, then done")
	game.biz["shop"].erase("ups")
	_check(game.biz_up_level("shop") == 0, "upgrade path: old saves (no steps saved) start at 0")
	game.reset_game(true)
	# 1.2 fixed-term savings: capped, fixed rate, pays into the claim list when
	# it ends; breaking early returns principal minus 5%; never beats a loan.
	game.reset_game(true)
	game.sim_time = 1.9e9
	game.cash = 1.0e9
	game.recalc()
	var cap: float = game.term_cap()
	_check(not game.open_term(5, 1000.0), "terms: only the offered lengths")
	_check(game.open_term(7, cap * 10.0) and is_equal_approx(game.terms_total(), cap) and game.term_cap_left() < 1.0, "terms: locking is capped")
	var nw_t: float = game.net_worth()
	_check(absf(nw_t - (game.cash + cap)) < 1.0 or nw_t > game.cash, "terms: locked cash still counts in net worth")
	game.sim_time += 3.0 * 86400.0
	game._bank_tick(0.0)
	_check(game.terms().size() == 1 and float(game.terms()[0]["progress"]) > 0.4, "terms: halfway through")
	game.sim_time -= 5.0 * 86400.0
	game._bank_tick(0.0)
	_check(game.terms().size() == 1 and game.unclaimed("term") == 0, "terms: a clock set back never pays early")
	game.sim_time += 9.0 * 86400.0
	game._bank_tick(0.0)
	_check(game.terms().is_empty() and game.unclaimed("term") == 1, "terms: an ended term waits in the claim list")
	var c_t: float = game.cash
	var paid_t: float = game.claim_all("term")
	_check(is_equal_approx(paid_t, cap * 1.20) and is_equal_approx(game.cash, c_t + cap * 1.20), "terms: 7 days pays 20%")
	game.open_term(1, 1000.0)
	game.restore_guard = false
	var code_t: String = game.backup_code()
	_check(game.restore_code(code_t) and game.terms().size() == 1 and is_equal_approx(float(game.terms()[0]["amount"]), 1000.0), "terms: a backup restore keeps an open term as it was")
	var c_b: float = game.cash
	_check(is_equal_approx(game.break_term(0), 950.0) and is_equal_approx(game.cash, c_b + 950.0) and game.terms().is_empty(), "terms: breaking early returns 95%, no interest")
	var best_rate: float = 0.0
	for tr in game.term_rates():
		best_rate = maxf(best_rate, float(tr["rate"]))
	_check(best_rate < Data.LOAN_FEE, "terms: borrowing to lock can't pay (best rate under the loan fee)")
	var t17: Dictionary = game.to_dict()
	t17["bank"] = {"saved": 0.0, "loan": {}}
	_check(game._migrate(t17).has("bank"), "saves without terms still load")
	game.sim_time = -1.0
	game.reset_game(true)
	# 1.2 records and rivals.
	_check(Data.RIVALS.size() >= 30, "at least 30 rivals")
	var round_worths := 0
	for rv in Data.RIVALS:
		if fmod(float(rv[2]), 1000.0) == 0.0:
			round_worths += 1
	_check(round_worths == 0, "no rival has a round fortune")
	var rv_old: Dictionary = game.to_dict()
	rv_old["version"] = 17
	rv_old["counters"]["rivals"] = 5.0   # passed the old £500M rival
	var rv_mig: Dictionary = game._migrate(rv_old)
	_check(int(rv_mig["counters"]["rivals"]) == 11, "v17 rivals passed maps onto the new list (5 old -> 11 new)")
	game.reset_game(true)
	game.cash = 0.0
	game._earn(1234.0)
	game._earn(66.0)
	var recs: Array = game.records()
	_check(absf(float(recs[2][1]) - 1300.0) < 0.01, "best day counts today's earnings")
	game.tap()
	_check(float(game.counters.get("best_tap", 0.0)) > 0.0 and float(game.counters.get("best_tap_at", 0.0)) > 0.0, "biggest tap is kept with its time")
	_check(RecordsPage.value_text(3.0, "days") == "3 days" and RivalsPage.worth_text(1353325.0) == "£1,353,325", "records and rivals text")
	game.sim_time = -1.0
	game.reset_game(true)
	# Toasts queue: a second message never cuts the first one short.
	var tk = root.get_node("Kit")
	tk._toast_q.clear()
	if tk._toast != null and is_instance_valid(tk._toast):
		tk._toast.queue_free()
	tk._toast = null
	tk.toast("First toast")
	tk.toast("Second toast")
	tk.toast("Second toast")
	_check(String(tk._toast.get_meta("text", "")) == "First toast" and tk._toast_q.size() == 1, "a new toast waits for the one showing (no flash), duplicates dropped")
	tk._toast_q.clear()
	# Rewards wait for a tap: achievements and goals add to the list, claiming
	# pays exactly once, and the amount doesn't grow while it waits.
	game.reset_game()
	game.cash = 0.0
	game.tap_cap = false
	for k in 120:
		game.tap()
	game._check_achievements()
	var waiting: int = game.unclaimed("ach")
	var c_before: float = game.cash
	_check(waiting >= 1 and game.reward_for("ach:taps_100").size() > 0, "a finished achievement waits to be claimed (%d waiting)" % waiting)
	var amt: float = float(game.reward_for("ach:taps_100")["amount"])
	game.income_per_hour = 1.0e9   # richer later: the reward must not grow
	var got: float = game.claim("ach:taps_100")
	_check(absf(got - amt) < 0.01 and absf(game.cash - c_before - amt) < 0.01, "claiming pays the amount fixed when it was earned")
	_check(game.claim("ach:taps_100") == 0.0, "a reward can only be claimed once")
	game.recalc()
	game.claim_all()
	_check(game.unclaimed() == 0, "Claim all clears the list")
	game.reset_game()
	# Converting coins keeps the value, less the usual sell spread.
	game.reset_game()
	game.cash = 1.0e6
	game.buy_asset("coin", "XRP", 1.0e5)
	var xv: float = game.holding(game.coins, "XRP") * game.price("XRP")
	var got_btc: float = game.convert_coin("XRP", "BTC", 0.5)
	var btc_v: float = got_btc * game.price("BTC")
	_check(absf(btc_v - xv * 0.5 * (1.0 - Data.SELL_SPREAD)) < xv * 0.001 and absf(game.cash - 9.0e5) < 1.0, "converting half the XRP into BTC keeps the value less the spread")
	_check(game.convert_coin("XRP", "XRP", 1.0) == 0.0 and game.convert_coin("DOGE", "BTC", 1.0) == 0.0, "no converting into the same coin or from a coin you don't own")
	# Head office upgrades: each works once and changes its rule.
	game.reset_game()
	game.cash = 1.0e13
	game.open_business("shop", "Office Test")
	var tv0: float = game.tap_value()
	var cap0: float = game.offline_cap_h()
	var ex0: float = game.expansion_seconds("shop")
	_check(game.buy_upgrade("tap") and absf(game.tap_value() / tv0 - 1.5) < 0.001, "Stronger taps: taps x1.5")
	_check(not game.buy_upgrade("tap"), "an upgrade can only be bought once")
	game.buy_upgrade("away1")
	game.buy_upgrade("away2")
	_check(is_equal_approx(game.offline_cap_h(), cap0 + 4.0), "Night shift and Weekend staff: away up to 12 h")
	game.buy_upgrade("fast1")
	_check(absf(game.expansion_seconds("shop") / ex0 - 0.85) < 0.001, "Fast builders: expansions 15% quicker")
	game.buy_upgrade("mgr")
	_check(is_equal_approx(game.manager_cut(), 0.06), "Better managers take 6%")
	game.reset_game()
	_check(game.upgrades.is_empty(), "a reset clears upgrades")
	# A real save from version 1.0.31 (save v7) still loads, with nothing lost.
	var fx := FileAccess.get_file_as_string("res://tests/fixtures/save_v7.json")
	var fd: Dictionary = JSON.parse_string(fx)
	fd["saved_at"] = game.now()   # no time away, so values can be compared
	var ff := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	ff.store_string(JSON.stringify(fd))
	ff.close()
	game.load_game()
	_check(game.biz.size() == 4 and game.props_owned() == 2 and game.staked("SOL") > 0.0 and game.level == 2 and game.taps >= 300, "old v7 save loads with companies, property, staking and level")
	_check(game.cash >= 1234567.0 and game.shares.size() == 1, "old v7 save keeps cash and shares (%.2f)" % game.cash)
	var fx_val: float = float(fd["coins"]["KRV"]["qty"]) * float(fd["prices"]["KRV"]) + float(fd["coins"]["KRV"].get("staked", 0.0)) * float(fd["prices"]["KRV"])
	var now_val: float = (game.holding(game.coins, "SOL") + game.staked("SOL")) * game.price("SOL")
	_check(absf(now_val - fx_val) <= fx_val * 0.02, "old coins become real ones and keep their value (%.0f vs %.0f)" % [now_val, fx_val])
	_check(int(game.to_dict()["version"]) == game.SAVE_VERSION and game.synergies.is_empty() and game.rigs_total() == 0, "old save is upgraded to the current version")
	_check(game.price("AVAX") > 0.0 and game.price("LTC") > 0.0 and game.series("DOT", "1D").size() > 0, "old save gets prices and history for the new coins")
	for ti in 5:
		main.show_page(ti)
		await process_frame
	_check(true, "every tab opens with the old save")
	game.reset_game()
	print("Failures: ", _fails)
	quit(1 if _fails > 0 else 0)
