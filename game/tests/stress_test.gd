extends SceneTree
## Stress test: spam, odd input, clock changes, a year away, huge numbers.
var fails := 0
func _ok(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c: fails += 1
func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): quit(1))
	_run.call_deferred()
func _sane() -> bool:
	for k in Data.STOCKS + Data.COINS:
		var p: float = root.get_node("Game").price(k[0])
		if is_nan(p) or is_inf(p) or p <= 0.0 or p > float(k[2]) * 1000.0 or p < float(k[2]) / 1000.0:
			print("   bad price ", k[0], " ", p)
			return false
	return true
func _run() -> void:
	var g = root.get_node("Game")
	seed(42)
	g.reset_game()
	g.cash = 1000.0
	for i in 2000:
		g.buy_asset("coin", "PEPE", 0.37)
	_ok(g.cash >= 0.0, "spam-buying 2000 times never goes below $0 (cash %.2f)" % g.cash)
	_ok(not g.buy_asset("share", "NRV", -50.0), "negative buy refused")
	_ok(not g.buy_asset("share", "NRV", 1e12), "buy more than cash refused")
	_ok(not g.buy_asset("share", "NOPE", 10.0), "unknown symbol refused")
	var c0: float = g.cash
	_ok(g.sell_asset("coin", "PEPE", 5.0) >= 0.0 and g.holding(g.coins, "PEPE") == 0.0, "sell fraction above 1 clamps to all")
	_ok(g.sell_asset("coin", "PEPE", -1.0) == 0.0, "negative sell does nothing")
	_ok(not g.stake("SOL", 1.0), "stake with no coins refused")
	g.buy_asset("coin", "SOL", 100.0)
	_ok(not g.stake("SOL", 0.0), "stake zero refused")
	g.stake("SOL", 1.0)
	_ok(not g.unstake("SOL") and not g.unstake("SOL"), "double unlock early refused")
	# Phone clock set back two days.
	g.sim_time = g.now() - 2 * 86400.0
	var st: float = g.staked("SOL")
	g.advance(-50.0)
	g.apply_offline(-3600.0)
	_ok(g.staked("SOL") >= st and g.cash >= 0.0 and _sane(), "clock going backwards breaks nothing")
	# A year away, in weekly chunks.
	var t := Time.get_ticks_msec()
	for w in 52:
		g.sim_time += 7 * 86400.0
		g.apply_offline(7 * 86400.0)
	_ok(_sane(), "prices stay sensible after a year away")
	_ok(Time.get_ticks_msec() - t < 15000, "a year of catch-up is quick (%d ms)" % (Time.get_ticks_msec() - t))
	_ok(g.unstake("SOL"), "unlock works after time away")
	# A year of play minute by minute for one coin path (fast check on drift).
	for i in 60 * 24 * 30:
		g._market_tick()
	_ok(_sane(), "prices stay sensible after a month of live ticks")
	_ok(g.money_short(1e18) != "" and g.money_short(1e30) != "", "huge numbers format (%s)" % g.money_short(1e30))
	g.save_game()
	g.load_game()
	_ok(_sane() and g.news.size() <= g.NEWS_MAX, "save and load after stress")
	g.sim_time = -1.0
	g.reset_game()
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
