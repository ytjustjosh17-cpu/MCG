extends SceneTree
## Pacing simulator: a robot player plays a few short sessions a day.
##   godot --headless --path game -s res://tests/pacing_sim.gd -- [days]

var g
var log_lines: Array = []
var marks := {}
var trader := ""   # "", "news" (buy good news) or "dip" (buy bad news)
var trade_profit := 0.0


func _initialize() -> void:
	_run.call_deferred()


var policy := "never"   # rebirth policy (SIM_REBIRTH): never, asap, patient
var run := 1
var run_start := 0.0
var best_rate := 0.0


func _mark(key: String, label: String) -> void:
	if run > 1:
		key = "r%d_%s" % [run, key]
		label = "run %d: %s" % [run, label]
	if not marks.has(key):
		var d: float = (g.sim_time - g.started_at) / 86400.0
		marks[key] = d
		print("  %-34s day %5.1f" % [label, d])


func _trade() -> void:
	## Sells last session's trade, then bets 30% of cash on the newest headline.
	if trader == "hold":
		_hold_trade()
		return
	if g.has_meta("trade"):
		var tr: Array = g.get_meta("trade")
		var got: float = g.sell_asset(tr[0], tr[1], 1.0)
		trade_profit += got - float(tr[2])
		g.remove_meta("trade")
	if g.news.is_empty():
		return
	var it: Dictionary = g.news[g.news.size() - 1]
	var sym := String(it["sym"])
	var kind := "share" if not g._stock(sym).is_empty() else ("coin" if not g._coin(sym).is_empty() else "")
	if kind == "" or g.holding(g.shares if kind == "share" else g.coins, sym) > 0.0:
		return
	var up := float(it["pct"]) > 0.0
	if (trader == "news" and up) or (trader == "dip" and not up):
		var amt: float = g.cash * 0.3
		if amt > 100.0 and g.buy_asset(kind, sym, amt):
			g.set_meta("trade", [kind, sym, amt])


var holds: Array = []   # [sym, cash spent, buy time]


func _hold_trade() -> void:
	## Buys every coin crash with most of the cash and holds for 3 days.
	for i in range(holds.size() - 1, -1, -1):
		var h: Array = holds[i]
		if g.sim_time - float(h[2]) >= 3 * 86400.0:
			trade_profit += g.sell_asset("coin", h[0], 1.0) - float(h[1])
			holds.remove_at(i)
	for k in range(g.news.size() - 1, maxi(-1, g.news.size() - 6), -1):
		var it: Dictionary = g.news[k]
		var sym := String(it["sym"])
		if g._coin(sym).is_empty() or float(it["pct"]) > -10.0 or float(it["t"]) < g.sim_time - 6 * 3600.0:
			continue
		if g.coins.has(sym):
			continue
		var amt: float = g.cash * 0.8
		if amt > 100.0 and g.buy_asset("coin", sym, amt):
			holds.append([sym, amt, g.sim_time])


var gamble_net := 0.0
var _slot: SlotMath


func _gamble() -> void:
	## Gambler persona (SIM_GAMBLE=1): 40 max-bet spins on the high-risk slot
	## every session, playing out free spins, then cashing out.
	if not g.casino_open():
		return   # opens with the Sol Casino node after a rebirth
	if _slot == null:
		_slot = SlotMath.new("vault", 4242 + int(OS.get_environment("SIM_SEED")))
	var line: float = g.casino_max_bet() / float(SlotMath.LINES)
	var need: float = g.casino_max_bet() * 40.0
	if g.cash < need * 2.0:
		return
	var c0: float = g.cash
	g.buy_chips(need)
	var free := 0
	for i in 40:
		if not g.casino_stake(line * SlotMath.LINES):
			break
		var r: Dictionary = _slot.spin(line)
		g.casino_pay(float(r["total"]))
		free += int(r["free_spins_awarded"])
		while free > 0:
			free -= 1
			var fr: Dictionary = _slot.spin(line, true)
			g.casino_pay(float(fr["total"]))
			free += int(fr["free_spins_awarded"])
	g.cash_out(g.chips())
	gamble_net += g.cash - c0


func _session(active_s: float) -> void:
	if OS.get_environment("SIM_GAMBLE") == "1":
		_gamble()
	if OS.get_environment("SIM_LOAN") == "1" and g.loan().is_empty() and g.cash >= 0.0:
		g.take_loan(g.loan_limit())   # borrower persona: always the biggest loan
	if trader in ["news", "dip", "hold"]:
		_trade()
	# Tap for a while (3 taps a second), using the tap boost when ready.
	if g.boost_ready():
		g.start_boost()
	# Deals turn up while playing; the robot takes every one.
	if trader != "nodeals":
		g.tick_deals(active_s)
		if not g.deal.is_empty():
			g.accept_deal()
	# Golden suns turn up while playing; the robot catches every one.
	if trader != "nodeals":
		var before_c: int = g.sun_count
		g.tick_sun(active_s)
		if g.sun_count > before_c:
			g.catch_sun()
			# The robot's taps are instant, so turn buffs into what they'd pay
			# over their real length (20 s of taps at 3 a second, 10 min of Rush).
			if g.last_sun == "frenzy":
				g.frenzy_until = 0.0
				g._earn(g.tap_value() * (Data.FRENZY_MULT - 1.0) * Data.FRENZY_S * 3.0)
			elif g.last_sun == "rush":
				g.rush_until = 0.0
				g._earn(g.income_per_hour * Data.RUSH_S / 3600.0)
	var taps := int(active_s * 3.0)
	for i in taps:
		g.tap()
	for k in int(active_s):
		g.auto_tick(1.0)   # the auto clicker runs while the robot plays
	# Buy the next auto clicker level when it costs under a tenth of cash.
	if g.auto_cost() > 0.0 and g.auto_cost() < g.cash * 0.1:
		g.buy_auto()
	g.ibost_ready() and g.start_ibost()
	g._check_achievements()
	g.claim_all()   # claims every waiting reward before spending, like a player would
	_spend()
	g.claim_all()
	g._check_achievements()
	g.daily_tasks()


func _spend() -> void:
	var guard := 0
	var bought := true
	while bought and guard < 4000:
		guard += 1
		bought = false
		# Level up while cheap compared to cash.
		if g.can_level_up() and g.level_cost() < g.cash * 0.5:
			g.level_up(); bought = true; continue
		# Mergers.
		for m in Data.MERGERS:
			if not g.mergers.has(m["id"]) and g.merger_ready(m) and g.cash >= m["cost"]:
				g.merge(m["id"]); bought = true
		# Mining rigs when one pays back within 3 days and costs under a tenth of cash.
		# Mined coins are kept (they count for the Coin Exchange merger).
		# Point the miners at whichever coin news has sped up (free to switch).
		if g.rigs_total() > 0:
			var best_c: String = g.mine_target
			for mc in Data.COINS:
				if float(g.mine_eff.get(mc[0], 1.0)) > float(g.mine_eff.get(best_c, 1.0)) + 0.05:
					best_c = mc[0]
			if best_c != g.mine_target:
				g.set_mine_target(best_c)
		var rsym := ""
		var rbest := 0.0
		if g.rigs_total() < Data.RIG_MAX and g.rig_price() < g.cash * 0.1:
			for rc in Data.COINS:
				var rgain: float = g.rig_gain(rc[0])
				if rgain > rbest:
					rbest = rgain
					rsym = rc[0]
		if trader not in ["news", "dip", "hold", "nomine"] and g.rigs_total() < Data.RIG_MAX and rsym != "" and rbest * 72.0 >= g.rig_price():
			g.buy_rig(rsym); bought = true
		# Head office upgrades when they cost under a fifth of cash.
		for up in Data.UPGRADES:
			if not g.has_up(up[0]) and float(up[3]) <= g.cash * 0.2:
				g.buy_upgrade(up[0]); bought = true
		# Synergies when they pay back within about a day.
		for sy in Data.SYNERGIES:
			if g.synergy_ready(sy[0]) and g.cash >= float(sy[6]) and g.biz_income(sy[4]) * (float(sy[5]) - 1.0) * 24.0 >= float(sy[6]):
				g.buy_synergy(sy[0]); bought = true
		# Open the next business.
		for b in g.businesses():
			if not g.owns(b["id"]) and g.cash >= b["cost"]:
				g.open_business(b["id"], b["names"][0]); bought = true
				break
		# Expand full companies.
		for b in g.businesses():
			var id: String = b["id"]
			if g.owns(id) and g.biz[id]["units"] >= g.capacity(id) and g.can_expand(id):
				g.start_expansion(id); bought = true
		# Best value unit.
		var best := ""
		var best_roi := 0.0
		for b in g.businesses():
			var id: String = b["id"]
			if g.owns(id) and g.biz[id]["units"] < g.capacity(id):
				var p: float = g.unit_price(id)
				var gain: float = float(b["unit_income"]) * pow(float(b["stage_mult"]), int(g.biz[id]["stage"]) - 1)
				var roi := gain / p
				if p <= g.cash and roi > best_roi:
					best_roi = roi
					best = id
		if best != "":
			g.buy_unit(best); bought = true; continue
		# Hire managers when cheap compared to cash.
		if trader != "nodeals":
			for id in g.biz.keys():
				if not g.has_manager(id) and g.manager_cost(id) <= g.cash * 0.15:
					g.hire_manager(id); bought = true
		# Move home when it is a small part of cash.
		if trader != "nohome" and g.next_home_cost() > 0.0 and g.next_home_cost() <= g.cash * 0.4:
			g.move_home(); bought = true
		# Property: cheapest one not owned, if it is a small part of cash.
		for i in range(g.property_count()):
			if not g.prop_owned(i) and g.prop_price(i) <= g.cash * 0.6:
				g.buy_property(i); bought = true
				break
		for k in g.props.keys():
			for j in range(Data.IMPROVEMENTS.size()):
				if g.improve_property(int(k), j):
					bought = true
		# Collections: cheapest missing item if affordable.
		var cheapest := ["", -1, INF]
		for c in g.collections():
			for i in range(c["items"].size()):
				if not g.item_owned(c["id"], i) and float(c["items"][i][1]) < cheapest[2]:
					cheapest = [c["id"], i, float(c["items"][i][1])]
		if cheapest[1] >= 0 and cheapest[2] <= g.cash * 0.5:
			g.buy_item(cheapest[0], cheapest[1]); bought = true
		# Investing leftovers for the mergers that need shares and crypto.
		if not bought and g.cash > 50000.0:
			g.buy_asset("share", "NRV", g.cash * 0.25)
			g.buy_asset("coin", "SOL", g.cash * 0.05)


func _milestones() -> void:
	var nw: float = g.net_worth()
	if g.biz.size() >= 1: _mark("biz1", "First company")
	if g.biz.size() >= 3: _mark("biz3", "Three companies")
	if g.biz.size() >= 6: _mark("biz6", "Six companies")
	if g.biz.size() >= 11: _mark("biz11", "Eleven companies")
	if g.biz.size() >= Data.BUSINESSES.size(): _mark("bizall", "All companies")
	if g.props_owned() >= 1: _mark("prop1", "First property")
	for e in [5, 6, 7, 8, 9, 10, 11, 12]:
		if nw >= pow(10.0, e): _mark("nw%d" % e, "Net worth $1e%d" % e)
	for n in [1, 3, 6]:
		if g.mergers.size() >= n: _mark("mg%d" % n, "%d merger(s)" % n)
	for p in [10, 25, 50, 75, 90, 100]:
		if g.completion() >= p / 100.0 - 0.0001: _mark("c%d" % p, "Completion %d%%" % p)


func _maybe_rebirth() -> void:
	## Rebirths by the chosen policy, then spends RBP on the tree.
	var pend: int = g.rebirth_pending()
	if pend <= 0 or policy == "never":
		return
	var earned := int(g.rebirth.get("earned", 0))
	var go := false
	if policy == "asap":
		go = true
	elif policy == "rate":
		# A sensible player: rebirth once RBP per day of this run stops rising.
		var d_run: float = maxf(0.5, (g.sim_time - g.started_at) / 86400.0 - run_start)
		var rate := float(pend) / d_run
		if rate > best_rate:
			best_rate = rate
		go = rate < best_rate * 0.92 and d_run > 2.0
	elif policy == "patient":
		go = pend >= maxi(10, earned) or (g.completion() >= 0.95 and pend >= maxi(10, earned / 2))
	if not go:
		return
	var d: float = (g.sim_time - g.started_at) / 86400.0
	var got: int = g.do_rebirth()
	print("  REBIRTH %d on day %5.1f (run took %4.1f days): +%d RBP" % [g.rebirths(), d, d - run_start, got])
	run += 1
	run_start = d
	best_rate = 0.0
	_spend_rbp()


func _spend_rbp() -> void:
	## Cheapest open node first; among equal prices, money nodes first.
	var pref := ["income", "all", "start", "rent", "div", "level", "speed", "away", "tap", "mine", "rbp"]
	while true:
		var best := {}
		var best_score := 1e18
		for n in RebirthTree.nodes():
			if not g.node_open(String(n["id"])):
				continue
			var score := float(n["cost"]) * 100.0
			for k in (n["fx"] as Dictionary).keys():
				var i := pref.find(k)
				score += float(i if i >= 0 else 50)
			if score < best_score:
				best_score = score
				best = n
		if best.is_empty() or int(best["cost"]) > g.rbp_free():
			break
		g.buy_node(String(best["id"]))
	print("    tree: %d of %d nodes, %d RBP left" % [g.tree_owned_count(), RebirthTree.nodes().size() - 1, g.rbp_free()])
	if g.tree_owned_count() >= RebirthTree.nodes().size() - 1:
		_mark("tree", "Whole tree bought")


func _run() -> void:
	g = root.get_node("Game")
	var days := 35
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		days = int(args[0])
	if args.size() > 1:
		trader = args[1]
	if OS.get_environment("SIM_REBIRTH") != "":
		policy = OS.get_environment("SIM_REBIRTH")
	seed(int(OS.get_environment("SIM_SEED")) if OS.get_environment("SIM_SEED") != "" else 1234)
	g._tap_rng.seed = int(OS.get_environment("SIM_SEED")) if OS.get_environment("SIM_SEED") != "" else 1234
	g._news_rng.seed = g._tap_rng.seed + 1
	g.reset_game(true)
	g.sim_time = 1.7e9
	g.started_at = g.sim_time
	g.history = []
	g.recalc()
	# Session start times (hours) and active seconds each.
	var sessions := [[8.0, 240.0], [12.5, 180.0], [18.0, 300.0], [22.5, 180.0]]
	var t_prev: float = g.sim_time
	print("Robot player: 4 sessions a day, about 15 minutes of play")
	for day in range(days):
		for s in sessions:
			var start: float = 1.7e9 + day * 86400.0 + float(s[0]) * 3600.0
			var gap := start - t_prev
			g.sim_time = start
			if gap > 0.0:
				g.apply_offline(gap)
			g._check_streak()
			_session(float(s[1]))
			g.sim_time += float(s[1])
			g.advance(float(s[1]))
			t_prev = g.sim_time
			_milestones()
			_maybe_rebirth()
		print("day %2d  worth %10s  income/h %10s  companies %2d  stages %3d  props %2d  items %2d  mergers %d  done %4.1f%%  rigs %2d mine %4.1f%%" % [
			day + 1, g.money_short(g.net_worth()), g.money_short(g.income_per_hour), g.biz.size(),
			_stages(), g.props_owned(), g.items.size(), g.mergers.size(), g.completion() * 100.0,
			g.rigs_total(), g.mining_value_per_hour() / maxf(1.0, g.income_per_hour) * 100.0])
	if OS.get_environment("SIM_GAMBLE") == "1":
		print("Gambler net from the casino: %s" % g.money_short(gamble_net))
	if trader in ["news", "dip", "hold"]:
		print("Trader (%s) profit from news trades: %s" % [trader, g.money_short(trade_profit)])
	quit()


func _stages() -> int:
	var n := 0
	for id in g.biz.keys():
		n += int(g.biz[id]["stage"])
	return n
