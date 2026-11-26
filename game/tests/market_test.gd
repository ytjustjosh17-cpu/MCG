extends SceneTree
## Market fairness: after crash news, pump news or a big dip, prices should not
## reliably bounce (that would let trading beat owning companies).
## Runs the market minute by minute for DAYS days on three seeds and compares
## the average return after each event with the plain average return.
## Usage: $G --headless --path . -s res://tests/market_test.gd [-- days]

const HORIZONS := [360, 1440, 4320]   # 6 h, 24 h, 72 h in minutes
const LIMITS := [0.03, 0.05, 0.08]    # largest allowed edge in log return

var fails := 0


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var g = root.get_node("Game")
	var days := 20
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		days = int(args[0])
	var minutes := days * 1440
	var syms: Array = []
	for c in Data.COINS:
		syms.append(c[0])
	for s in Data.STOCKS:
		syms.append(s[0])
	var sums := {}   # kind -> [n, sum per horizon...]
	for kind in ["plain", "crash", "pump", "dip"]:
		sums[kind] = [0, 0.0, 0.0, 0.0]
	for sd in [11, 22, 33]:
		seed(sd)
		g.sim_time = 1.7e9
		g.reset_game()
		g._quiet = true
		var hist := {}
		for s in syms:
			hist[s] = PackedFloat32Array()
		var events: Array = []   # [minute, sym, kind]
		var news_n := int(g.counters.get("news_total", 0))
		for t in minutes:
			g.sim_time += 60.0
			g._market_tick()
			for s in syms:
				hist[s].append(log(maxf(g.price(s), 1e-12)))
			var n2 := int(g.counters.get("news_total", 0))
			if n2 != news_n:
				news_n = n2
				var it: Dictionary = g.news.back()
				var sy: String = it.get("sym", "")
				if hist.has(sy) and absf(float(it.get("pct", 0.0))) > 0.5:
					events.append([t, sy, "pump" if float(it["pct"]) > 0.0 else "crash"])
		g._quiet = false
		# Plain returns (every hour), and dips (price under half its base).
		for s in syms:
			var base := 0.0
			for c in Data.COINS:
				if c[0] == s:
					base = log(float(c[2]))
			var h: PackedFloat32Array = hist[s]
			var last_dip := -100000
			for t in range(0, minutes - HORIZONS[2], 60):
				_add(sums["plain"], h, t)
				if base != 0.0 and h[t] < base - log(2.0) and t - last_dip > 1440:
					_add(sums["dip"], h, t)
					last_dip = t
		for e in events:
			if int(e[0]) + HORIZONS[2] < minutes:
				_add(sums[e[2]], hist[e[1]], int(e[0]))
	g.sim_time = -1.0
	g.reset_game()
	var plain: Array = sums["plain"]
	for kind in ["crash", "pump", "dip"]:
		var k: Array = sums[kind]
		if int(k[0]) < 10:
			print("SKIP  %s: only %d cases" % [kind, int(k[0])])
			continue
		for i in 3:
			var edge: float = k[i + 1] / float(k[0]) - plain[i + 1] / float(plain[0])
			_ok(absf(edge) < LIMITS[i], "after %s, %d h return differs from normal by %+.1f%% (%d cases, limit %.0f%%)" % [kind, HORIZONS[i] / 60, edge * 100.0, int(k[0]), LIMITS[i] * 100.0])
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)


func _add(acc: Array, h: PackedFloat32Array, t: int) -> void:
	acc[0] = int(acc[0]) + 1
	for i in 3:
		acc[i + 1] = float(acc[i + 1]) + (h[t + HORIZONS[i]] - h[t])
