extends SceneTree
## Renders every screen in a mid-game state and saves PNGs (needs a display).
##   xvfb-run godot --path game --resolution 390x844 -s res://tests/screenshot.gd -- <out_dir>

var out := "/tmp"
var main


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("saved ", name)


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	var g = root.get_node("Game")
	# Pin the time and weather so pictures don't change with the clock (1.2).
	SkyTime.force_hour = 15.0
	SkyTime.force_weather = "clear"
	g.reset_game()
	# A believable mid-game save.
	g.cash = 5.0e7
	g.level = 6
	g.taps = 12480
	for id in ["shop", "taxi", "shipping", "factory"]:
		g.open_business(id, Data.business(id)["names"][0])
	g.biz["shop"]["stage"] = 5
	g.biz["shop"]["units"] = 23
	g.biz["taxi"]["stage"] = 3
	g.biz["taxi"]["units"] = 15
	g.biz["shipping"]["stage"] = 2
	g.biz["shipping"]["units"] = 6
	g.start_expansion("shipping")
	g.buy_asset("share", "NRV", 4.0e5)
	g.buy_asset("share", "LMG", 2.0e5)
	g.buy_asset("coin", "SOL", 1.5e5)
	g.buy_asset("coin", "XRP", 6.0e4)
	g.stake("XRP", 1.0)
	for i in 6:
		g._news_event()
	g.buy_property(0)
	g.buy_property(8)
	g.improve_property(8, 2)
	g.buy_item("watches", 0)
	g.buy_item("watches", 1)
	g.home = 3
	g.counters["rivals"] = float(Data.RIVALS.size())  # no pop-ups during the shots
	g.streak_day = g._today()  # no daily-gift pop-up either
	g.streak_unseen = []
	g.cash = 2.4e5
	# SHOT_RICH=1: a very late game with huge numbers, to check nothing spills.
	if OS.get_environment("SHOT_RICH") == "1":
		g.cash = 1.0e16
		for b in Data.BUSINESSES:
			g.open_business(b["id"], b["names"][0])
			g.biz[b["id"]]["stage"] = 10
			g.biz[b["id"]]["units"] = 50
		g.cash = 9.87654e14
		g.buy_asset("coin", "LTC", 3.0e14)
		g.cash = 9.87654e14
		for k in 12:
			g.buy_rig("AVAX")
		g.cash = 9.87654e14
	if OS.get_environment("SHOT_SCI") == "1":
		g.sci = true
	g.recalc()
	for i in 8:
		g._record_history()
		g.cash += 2000.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	SkyTime.force_hour = 15.0   # again: loading the scene can reset static vars
	SkyTime.force_weather = "clear"
	await _shot("01_earn")
	main.show_page(1)
	await _shot("02_business")
	main.push(BusinessDetail.new("taxi"))
	await _shot("03_taxi")
	main._stack[-1]._on_hire()
	await _shot("03b_manager")
	root.get_node("Kit").close_top()
	await create_timer(0.4).timeout
	main.pop()
	await create_timer(0.4).timeout
	main.push(StartBusinessPage.new())
	await _shot("04_new_business")
	main.pop()
	await create_timer(0.4).timeout
	main.push(MergersPage.new())
	await _shot("05_mergers")
	main.pop()
	await create_timer(0.5).timeout
	main.push(load("res://scripts/head_office_page.gd").new())
	await _shot("05b_head_office")
	main.show_page(2)
	await _shot("06_invest_shares")
	var inv = main._pages[2]
	inv._seg.select(1, true)
	await _shot("07_invest_property")
	inv._seg.select(2, true)
	await _shot("08_invest_crypto")
	main.push(AssetDetail.new("coin", "XRP"))
	await _shot("09_coin")
	main._stack[-1].scroll.scroll_vertical = 600
	await _shot("09b_coin_staking")
	g.buy_asset("coin", "XRP", 2.0e4)
	TradeSheet.open("coin", "XRP", "sell")
	await _shot("09e_sell")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	TradeSheet.open("coin", "XRP", "convert")
	await _shot("09f_convert")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	TradeSheet.open("coin", "XRP", "buy")
	await _shot("09g_buy")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	TradeSheet.open("coin", "XRP", "lock")
	await _shot("09h_lock")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	main.pop()
	await create_timer(0.4).timeout
	inv._seg.select(0, true)
	main.push(AssetDetail.new("share", "NRV"))
	await _shot("09c_share")
	main.pop()
	await create_timer(0.4).timeout
	main.push(NewsPage.new())
	await _shot("09d_news")
	main.pop()
	await create_timer(0.4).timeout
	main.push(PropertyDetail.new(8))
	await _shot("10_property")
	main.show_page(3)
	await _shot("11_items")
	main.push(ItemsPage.CollectionPage.new("watches"))
	await _shot("12_collection")
	var up = root.get_node("Updater")
	up.latest_version = "1.0.7"
	up._set_state(up.State.AVAILABLE)
	g.set_showcase(["watches:0", "watches:1"])
	main.show_page(4)
	await _shot("13_profile")
	main._pages[4].scroll.scroll_vertical = 900
	await _shot("13b_profile_end")
	main._pages[4].scroll.scroll_vertical = 0
	main.push(AchievementsPage.new())
	await _shot("14_achievements")
	main.pop()
	await create_timer(0.4).timeout
	g.daily_tasks()[0]["progress"] = 150
	g.weekly_tasks()[1]["progress"] = float(g.weekly_tasks()[1]["goal"]) * 0.6
	g.daily_tasks()[1]["done"] = true
	g.streak = 12
	main.push(GoalsPage.new())
	await _shot("15_goals")
	root.get_node("Kit").celebrate("Daily goal done", "Tap your tower 300 times", "+£12.4K")
	await create_timer(0.3).timeout
	await _shot("16_confetti")
	await create_timer(2.6).timeout
	main.pop()
	await create_timer(0.4).timeout
	main.push(RivalsPage.new())
	await _shot("17_rivals")
	main.pop()
	await create_timer(0.4).timeout
	main.push(RecordsPage.new())
	await _shot("17b_records")
	main.pop()
	await create_timer(0.4).timeout
	main.show_page(1)
	g.deal = {"kind": "supplier", "id": "taxi", "value": 1.0, "title": "Supplier discount", "text": "Halden Taxis · next expansion 25% off", "yes": "Take it"}
	main._show_deal()
	await _shot("18_deal")
	root.get_node("Kit").close_top()
	g.deal = {}
	main._deal_open = false
	main.push(BusinessDetail.new("taxi"))
	await create_timer(0.6).timeout
	main._stack[-1].scroll.scroll_vertical = 520
	await _shot("19_manager")
	main.show_page(0)
	await create_timer(0.5).timeout
	g.away_seconds = 11 * 3600.0
	g.away_earned = 2.4e6
	g.away_notes = ["2 expansions finished", "Earnings stop after 8 h away"]
	g.away_unseen = true
	main._show_deal()
	await _shot("20_welcome")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	g.streak_unseen = [3, 52000.0]
	main._show_deal()
	await create_timer(0.5).timeout
	await _shot("21_streak")
	# Page shots must show the page, not a left-over pop-up on top of it.
	g.streak_unseen = []
	while root.get_node("Kit").close_top():
		await create_timer(0.3).timeout
	await create_timer(2.6).timeout
	var card = main.find_child("TowerCard", true, false)
	for k in 60:
		card._do_tap(card.size * 0.5)
		await create_timer(0.02).timeout
	await _shot("22_combo")
	main.show_page(4)
	await create_timer(0.6).timeout
	main.push(SettingsPage.new())
	await _shot("23_settings")
	main._stack[-1]._on_backup_menu()
	await _shot("23b_backup")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	main.pop()
	await create_timer(0.6).timeout
	g.streak_unseen = []
	while root.get_node("Kit").close_top():
		await create_timer(0.3).timeout
	for k in 60:
		g.history.append([g.now() - (60 - k) * 1800.0, 2.0e6 * pow(1.06, k), 3.0e4 * pow(1.05, k)])
	main.push(load("res://scripts/stats_page.gd").new())
	await _shot("23c_stats")
	await create_timer(0.4).timeout
	main.pop()
	await create_timer(0.4).timeout
	main.show_page(2)
	g.ui["sort"] = "up"
	main._pages[2]._seg.select(0, true)
	main._pages[2]._paint_sort()
	await _shot("24_sorted")
	# 1.1 screens: What's new, pickers, synergies, crit and buffs, mining.
	main.show_page(4)
	await create_timer(0.5).timeout
	ProfilePage._show_whats_new()
	await _shot("25_whats_new")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	main.push(SettingsPage.new())
	await create_timer(0.6).timeout
	main._stack[-1]._on_sound()
	await _shot("26_sound_pick")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	main._stack[-1]._on_numbers()
	await _shot("27_numbers_pick")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	main.show_page(1)
	await create_timer(0.4).timeout
	g.cash = 5.0e7
	g.open_business("food", "Hatch & Ladle")
	g.biz["taxi"]["stage"] = 3
	main.push(load("res://scripts/business_detail.gd").new("food"))
	await create_timer(0.8).timeout
	main._stack[-1].scroll.scroll_vertical = 600
	await _shot("28_synergies")
	main.show_page(0)
	await create_timer(0.5).timeout
	g.frenzy_until = g.now() + 18.0
	g.rush_until = g.now() + 500.0
	var tcard = main._pages[0].find_child("TowerCard", true, false)
	tcard._spawn_crit(Vector2(200, 300), 1680.0)
	await create_timer(0.15).timeout
	await _shot("29_crit_buffs")
	g.frenzy_until = 0.0
	g.rush_until = 0.0
	g.cash = 1.0e8
	for k in 3:
		g.buy_rig("AVAX")
	g.sim_time = g.now()
	g.advance(3 * 3600.0)
	g.sim_time = -1.0
	main.push(AssetDetail.new("coin", "AVAX"))
	await create_timer(0.8).timeout
	main._stack[-1].scroll.scroll_vertical = 420
	await _shot("30_mining")
	main.pop()
	await create_timer(0.5).timeout
	g.streak_unseen = []
	while root.get_node("Kit").close_top():
		await create_timer(0.3).timeout
	for i in 5:
		g.buy_miner()
	main.show_page(2)
	main._pages[2]._seg.select(2, true)
	await create_timer(0.4).timeout
	main._pages[2].scroll.scroll_vertical = 300
	await create_timer(1.6).timeout   # let a few coins rise
	await _shot("31_crypto_mining")
	main._pages[2]._on_pick_target()
	await _shot("32_mine_pick")
	root.get_node("Kit").close_top()
	await create_timer(0.4).timeout
	# Casino lobby: locked, then open with chips.
	g.streak_unseen = []
	while root.get_node("Kit").close_top():
		await create_timer(0.3).timeout
	main.show_page(3)
	await create_timer(0.5).timeout
	main.push(CasinoPage.new())
	await create_timer(0.9).timeout
	await _shot("35_casino_locked")
	g.cash = 5.0e9
	g.grant_node("u_casino")
	g.grant_node("u_tables")
	g.buy_chips(2.5e5)
	g.counters["casino_bet"] = 1.8e5
	g.counters["casino_won"] = 1.62e5
	g.flush_changes()
	await create_timer(0.4).timeout
	await _shot("36_casino")
	main.push(load("res://scripts/forge_page.gd").new())
	await create_timer(1.6).timeout
	await _shot("37b_sun_forge")
	main.pop()
	await create_timer(0.6).timeout
	main.push(load("res://scripts/slots_page.gd").new("classic"))
	await create_timer(1.0).timeout
	await _shot("37_slots")
	main.pop()
	await create_timer(0.6).timeout
	main.push(load("res://scripts/roulette_page.gd").new())
	await create_timer(1.0).timeout
	await _shot("38_roulette")
	main.pop()
	await create_timer(0.6).timeout
	main.push(load("res://scripts/blackjack_page.gd").new())
	await create_timer(1.0).timeout
	await _shot("39_blackjack")
	main.pop()
	await create_timer(0.6).timeout
	# 1.2 casino: wheel, video poker, crash, plinko, races.
	var keep_rm: bool = g.reduce_motion
	g.reduce_motion = false
	g.casino["wheel_day"] = -1
	WheelSheet.open()
	await create_timer(0.8).timeout
	await _shot("39b_wheel")
	root.get_node("Kit").close_top()
	await create_timer(0.5).timeout
	var vp = load("res://scripts/video_poker_page.gd").new()
	main.push(vp)
	await create_timer(0.9).timeout
	vp._on_go()
	await create_timer(1.0).timeout
	await _shot("39c_video_poker")
	main.pop()
	await create_timer(0.6).timeout
	var cp = load("res://scripts/crash_page.gd").new()
	main.push(cp)
	await create_timer(0.9).timeout
	cp._cm.rng.seed = 12
	cp._on_go()
	await create_timer(4.0).timeout
	await _shot("39d_crash")
	main.pop()
	await create_timer(0.6).timeout
	var pp = load("res://scripts/plinko_page.gd").new()
	main.push(pp)
	await create_timer(0.9).timeout
	for k in 4:
		pp._on_drop()
		await create_timer(0.25).timeout
	await _shot("39e_plinko")
	main.pop()
	await create_timer(0.6).timeout
	var rp = load("res://scripts/race_page.gd").new()
	main.push(rp)
	await create_timer(0.9).timeout
	rp._on_go()
	await create_timer(2.6).timeout
	await _shot("39f_races")
	main.pop()
	await create_timer(0.4).timeout
	main.push(load("res://scripts/tower_page.gd").new())
	await _shot("39g_tower")
	main.pop()
	await create_timer(0.6).timeout
	g.reduce_motion = keep_rm
	main.pop()
	await create_timer(0.5).timeout
	# Bank with savings and a loan running.
	g.cash = 2.0e6
	g.deposit(5.0e5)
	g.take_loan(g.loan_limit() * 0.5)
	main.show_page(4)
	await create_timer(0.5).timeout
	main.push(BankPage.new())
	await create_timer(0.9).timeout
	await _shot("48_bank")
	main.pop()
	await create_timer(0.5).timeout
	g.bank = {"saved": 0.0, "loan": {}}
	# Rebirth and the tree: a second run with part of the tree bought.
	g.streak_unseen = []
	while root.get_node("Kit").close_top():
		await create_timer(0.3).timeout
	g.rebirth = {"count": 2, "earned": 260, "nodes": {}}
	g._rb_cache = {}
	for id in ["emp_g", "emp_t1", "emp_t2", "emp_t3", "hand_g", "soul_g", "est_g", "est_t1", "bridge_1", "hand_t1"]:
		g.rebirth["nodes"][id] = true
	g._rb_cache = {}
	g.cash = 3.0e10
	main.show_page(4)
	await create_timer(0.6).timeout
	main.push(RebirthPage.new())
	await create_timer(1.0).timeout
	await _shot("33_rebirth_tree")
	main._stack[-1]._on_node("emp_t4")
	await _shot("34_tree_node")
	root.get_node("Kit").close_top()
	await create_timer(0.4).timeout
	main.pop()
	await create_timer(0.4).timeout
	# Tree unlock content: relics, island estates, frontier companies.
	g.grant_node("u_frontier")
	g.grant_node("u_isles")
	g.grant_node("u_relics")
	g.cash = 5.0e12
	g.buy_item("relics", 0)
	g.buy_item("relics", 3)
	main.show_page(3)
	await create_timer(0.5).timeout
	main.push(ItemsPage.CollectionPage.new("relics"))
	await create_timer(0.9).timeout
	await _shot("40_relics")
	main.pop()
	await create_timer(0.5).timeout
	main.show_page(1)
	await create_timer(0.4).timeout
	main.push(StartBusinessPage.new())
	await create_timer(0.9).timeout
	main._stack[-1].scroll.scroll_vertical = 2000
	await _shot("41_frontier")
	main.pop()
	await create_timer(0.5).timeout
	main.show_page(2)
	main._pages[2]._seg.select(1, true)
	await create_timer(0.5).timeout
	main._pages[2].scroll.scroll_vertical = 5000
	await _shot("42_isles")
	# 1.2 look and feel: night, rain at dusk, fog, and inside your home.
	g.cash = 5.0e9
	for col in ["art", "watches", "cars", "jets"]:
		g.buy_item(col, 2)
	for h in 5:
		g.move_home()
	main.show_page(0)
	for spec in [[23.0, "clear", "43_night"], [19.5, "rain", "44_rain_dusk"], [8.0, "fog", "45_fog_morning"]]:
		SkyTime.force_hour = float(spec[0])
		SkyTime.force_weather = String(spec[1])
		var tc = main._pages[0].find_child("TowerCard", true, false)
		if tc:
			tc._sky_t = 0.0
			for ch in tc.get_children():
				if ch is SkyTime.Layer:
					ch._check = 0.0
		await create_timer(0.8).timeout
		await _shot(String(spec[2]))
	SkyTime.force_hour = 21.5
	SkyTime.force_weather = "clear"
	main.show_page(3)
	await create_timer(0.5).timeout
	main.push(HomePage.new())
	await create_timer(1.0).timeout
	await _shot("46_home")
	main.pop()
	await create_timer(0.5).timeout
	# First-time guide on a brand-new game.
	g.reset_game()
	g.ui["guide_done"] = false
	main.show_page(0)
	await create_timer(0.5).timeout
	Guide.maybe_start(main)
	await create_timer(0.8).timeout
	await _shot("47_guide")
	g.ui["guide_done"] = true
	g.reset_game()
	quit()
