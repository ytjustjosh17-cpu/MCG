extends SceneTree
## Pacing simulator: a robot player plays a few short sessions a day.
##   godot --headless --path game -s res://tests/pacing_sim.gd -- [days]

var g
var log_lines: Array = []
var marks := {}


func _initialize() -> void:
	_run.call_deferred()


func _mark(key: String, label: String) -> void:
	if not marks.has(key):
		var d: float = (g.sim_time - g.started_at) / 86400.0
		marks[key] = d
		print("  %-34s day %5.1f" % [label, d])


func _session(active_s: float) -> void:
	# Tap for a while (3 taps a second), using the tap boost when ready.
	if g.boost_ready():
		g.start_boost()
	var taps := int(active_s * 3.0)
	for i in taps:
		g.tap()
	g.ibost_ready() and g.start_ibost()
	_spend()
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
		# Open the next business.
		for b in Data.BUSINESSES:
			if not g.owns(b["id"]) and g.cash >= b["cost"]:
				g.open_business(b["id"], b["names"][0]); bought = true
				break
		# Expand full companies.
		for b in Data.BUSINESSES:
			var id: String = b["id"]
			if g.owns(id) and g.biz[id]["units"] >= g.capacity(id) and g.can_expand(id):
				g.start_expansion(id); bought = true
		# Best value unit.
		var best := ""
		var best_roi := 0.0
		for b in Data.BUSINESSES:
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
		# Property: cheapest one not owned, if it is a small part of cash.
		for i in range(Data.PROPERTIES.size()):
			if not g.prop_owned(i) and g.prop_price(i) <= g.cash * 0.6:
				g.buy_property(i); bought = true
				break
		for k in g.props.keys():
			for j in range(Data.IMPROVEMENTS.size()):
				if g.improve_property(int(k), j):
					bought = true
		# Collections: cheapest missing item if affordable.
		var cheapest := ["", -1, INF]
		for c in Data.COLLECTIONS:
			for i in range(c["items"].size()):
				if not g.item_owned(c["id"], i) and float(c["items"][i][1]) < cheapest[2]:
					cheapest = [c["id"], i, float(c["items"][i][1])]
		if cheapest[1] >= 0 and cheapest[2] <= g.cash * 0.5:
			g.buy_item(cheapest[0], cheapest[1]); bought = true
		# Investing leftovers for the mergers that need shares and crypto.
		if not bought and g.cash > 50000.0:
			g.buy_asset("share", "NRV", g.cash * 0.25)
			g.buy_asset("coin", "KRV", g.cash * 0.05)


func _milestones() -> void:
	var nw: float = g.net_worth()
	if g.biz.size() >= 1: _mark("biz1", "First company")
	if g.biz.size() >= 3: _mark("biz3", "Three companies")
	if g.biz.size() >= 6: _mark("biz6", "Six companies")
	if g.biz.size() >= 11: _mark("biz11", "All eleven companies")
	if g.props_owned() >= 1: _mark("prop1", "First property")
	for e in [5, 6, 7, 8, 9, 10, 11, 12]:
		if nw >= pow(10.0, e): _mark("nw%d" % e, "Net worth $1e%d" % e)
	for n in [1, 3, 6]:
		if g.mergers.size() >= n: _mark("mg%d" % n, "%d merger(s)" % n)
	for p in [10, 25, 50, 75, 90, 100]:
		if g.completion() >= p / 100.0 - 0.0001: _mark("c%d" % p, "Completion %d%%" % p)


func _run() -> void:
	g = root.get_node("Game")
	var days := 35
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		days = int(args[0])
	seed(1234)
	g.reset_game()
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
			_session(float(s[1]))
			g.sim_time += float(s[1])
			g.advance(float(s[1]))
			t_prev = g.sim_time
			_milestones()
		print("day %2d  worth %10s  income/h %10s  companies %2d  stages %3d  props %2d  items %2d  mergers %d  done %4.1f%%" % [
			day + 1, g.money_short(g.net_worth()), g.money_short(g.income_per_hour), g.biz.size(),
			_stages(), g.props_owned(), g.items.size(), g.mergers.size(), g.completion() * 100.0])
	quit()


func _stages() -> int:
	var n := 0
	for id in g.biz.keys():
		n += int(g.biz[id]["stage"])
	return n
