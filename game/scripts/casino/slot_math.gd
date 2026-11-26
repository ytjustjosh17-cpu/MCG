class_name SlotMath
extends RefCounted
## The maths of one slot machine, no pictures: 5 reels of 3 rows, 20 fixed
## paylines, weighted reel strips, a wild and a scatter. 3 or more scatters
## anywhere give 10 free spins (they can trigger again), and free spins pay
## double. Every result is worked out here before anything moves on screen.
##
## Three made-up machines with different swings (volatility). Their return
## to player was worked out exactly from the strips and checked by
## tests/casino_test.gd:
##   classic  "Red Sun Classic"  low swings     95.7%
##   neon     "Neon Reef"        medium swings  95.5%
##   vault    "Iron Vault"       high swings    95.7%

const SYMBOLS := ["sun", "crown", "bar", "seven", "bell", "cherry", "lemon", "wild", "scatter"]
const WILD := 7
const SCATTER := 8
const LINES := 20
const ROWS := 3
const REELS := 5
const FREE_SPINS := 10        # given by 3 or more scatters
const FREE_MULT := 2.0        # free spins pay double
const MAX_WIN_X := 500.0      # no single spin pays more than 500 x the total bet

## Paylines: the row (0 top, 1 middle, 2 bottom) on each of the 5 reels.
const PAYLINES := [
	[1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0],
	[2, 1, 0, 1, 2], [0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1],
	[1, 2, 2, 2, 1], [1, 0, 1, 2, 1], [1, 2, 1, 0, 1], [0, 1, 1, 1, 0],
	[2, 1, 1, 1, 2], [0, 1, 0, 1, 0], [2, 1, 2, 1, 2], [1, 1, 0, 1, 1],
	[1, 1, 2, 1, 1], [0, 0, 2, 0, 0], [2, 2, 0, 2, 2], [0, 2, 2, 2, 0],
]

## Per machine: name, a short line, how many of each symbol sit on each reel
## (in SYMBOLS order), what 3, 4 and 5 in a row pay (times the line bet),
## what 3, 4 and 5 scatters pay (times the total bet) and the bonus buy
## price (times the total bet, for 10 free spins).
const THEMES := {
	"classic": {
		"name": "Red Sun Classic", "volatility": "Low",
		"blurb": "Lots of small wins. Steady.",
		"reels": [
			[2, 3, 4, 5, 7, 10, 12, 2, 2], [2, 3, 4, 5, 7, 10, 12, 2, 2], [2, 3, 4, 5, 7, 10, 12, 2, 2],
			[2, 3, 4, 5, 7, 10, 12, 2, 2], [2, 3, 4, 5, 7, 10, 12, 2, 2],
		],
		"pay": {
			"sun": [40, 150, 600], "wild": [40, 150, 600], "crown": [25, 80, 300], "bar": [15, 50, 150],
			"seven": [12, 40, 120], "bell": [11, 32, 100], "cherry": [5, 16, 45], "lemon": [3, 10, 30],
		},
		"scatter_pay": [2, 10, 50],
		"bonus_buy": 17.5,
	},
	"neon": {
		"name": "Neon Reef", "volatility": "Medium",
		"blurb": "More wilds in the middle. Bigger top prize.",
		"reels": [
			[2, 3, 4, 5, 6, 9, 11, 1, 2], [2, 3, 4, 5, 6, 9, 11, 2, 2], [2, 3, 4, 5, 6, 9, 11, 3, 2],
			[2, 3, 4, 5, 6, 9, 11, 2, 2], [2, 3, 4, 5, 6, 9, 11, 1, 2],
		],
		"pay": {
			"sun": [50, 250, 1000], "wild": [50, 250, 1000], "crown": [30, 100, 400], "bar": [20, 60, 200],
			"seven": [15, 40, 150], "bell": [8, 25, 80], "cherry": [4, 12, 36], "lemon": [2, 7, 23],
		},
		"scatter_pay": [2, 12, 60],
		"bonus_buy": 17.0,
	},
	"vault": {
		"name": "Iron Vault", "volatility": "High",
		"blurb": "Long dry spells, rare huge hits.",
		"reels": [
			[1, 2, 3, 5, 7, 10, 12, 0, 2], [1, 2, 3, 5, 7, 10, 12, 3, 2], [1, 2, 3, 5, 7, 10, 12, 3, 2],
			[1, 2, 3, 5, 7, 10, 12, 3, 2], [1, 2, 3, 5, 7, 10, 12, 0, 2],
		],
		"pay": {
			"sun": [100, 500, 2500], "wild": [100, 500, 2500], "crown": [50, 200, 800], "bar": [25, 80, 300],
			"seven": [12, 40, 120], "bell": [6, 20, 60], "cherry": [3, 10, 30], "lemon": [2, 6, 20],
		},
		"scatter_pay": [3, 15, 80],
		"bonus_buy": 17.0,
	},
}

var theme_id := "classic"
var rng := RandomNumberGenerator.new()
var strips: Array = []          # 5 PackedInt32Array reel strips
var _pay: Array = []            # [symbol][count - 3] -> times line bet
var _scatter_pay: Array = []
var _lines := PackedInt32Array()  # flattened cell index (reel * 3 + row) per line


func _init(theme := "classic", rng_seed := -1) -> void:
	theme_id = theme if THEMES.has(theme) else "classic"
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var t: Dictionary = THEMES[theme_id]
	for s in SYMBOLS:
		var p: Array = t["pay"].get(s, [0, 0, 0])
		_pay.append([float(p[0]), float(p[1]), float(p[2])])
	for v in t["scatter_pay"]:
		_scatter_pay.append(float(v))
	for line in PAYLINES:
		for r in range(REELS):
			_lines.append(r * ROWS + int(line[r]))
	for r in range(REELS):
		strips.append(_build_strip(t["reels"][r], 1000 + r))


static func themes() -> Array:
	## [{id, name, volatility, blurb}] for the machine picker.
	var out: Array = []
	for id in THEMES.keys():
		var t: Dictionary = THEMES[id]
		out.append({"id": id, "name": t["name"], "volatility": t["volatility"], "blurb": t["blurb"]})
	return out


func total_bet(bet_per_line: float) -> float:
	return bet_per_line * LINES


func bonus_buy_cost_mult() -> float:
	## Price of 10 free spins, in total bets.
	return float(THEMES[theme_id]["bonus_buy"])


func bonus_buy_cost(bet_per_line: float) -> float:
	return bonus_buy_cost_mult() * total_bet(bet_per_line)


func paytable() -> Dictionary:
	## {symbol: [3, 4, 5 in a row, times the line bet]} plus "scatter" (times
	## the total bet), for the paytable sheet.
	var t: Dictionary = THEMES[theme_id]
	var out: Dictionary = (t["pay"] as Dictionary).duplicate(true)
	out["scatter"] = (t["scatter_pay"] as Array).duplicate()
	return out


func theoretical() -> Dictionary:
	## The exact maths of this machine, worked out from the reel strips:
	## {rtp, line, scatter, trigger (chance of free spins per spin),
	## session (what a free-spin round pays, in total bets), bonus_rtp}.
	var probs: Array = []   # per reel: [[symbol, chance], ...]
	for r in range(REELS):
		var strip: PackedInt32Array = strips[r]
		var counts := {}
		for s in strip:
			counts[s] = int(counts.get(s, 0)) + 1
		var pr: Array = []
		for s in counts.keys():
			pr.append([int(s), float(counts[s]) / float(strip.size())])
		probs.append(pr)
	var line_ev := 0.0
	var cells := PackedInt32Array([0, 0, 0, 0, 0])
	var idx := [0, 0, 0, 0, 0]
	var sizes: Array = probs.map(func(p): return (p as Array).size())
	while true:
		var p := 1.0
		for r in range(REELS):
			var e: Array = probs[r][idx[r]]
			cells[r] = int(e[0])
			p *= float(e[1])
		line_ev += p * _pay_cells(cells)
		var k := REELS - 1
		while k >= 0:
			idx[k] += 1
			if idx[k] < sizes[k]:
				break
			idx[k] = 0
			k -= 1
		if k < 0:
			break
	# Scatters: strips never show two on one reel, so each reel shows one
	# with chance 3 x its share.
	var dist := [1.0]
	for r in range(REELS):
		var q := 0.0
		for e in probs[r]:
			if int(e[0]) == SCATTER:
				q = minf(1.0, 3.0 * float(e[1]))
		var nd: Array = []
		nd.resize(dist.size() + 1)
		nd.fill(0.0)
		for k2 in range(dist.size()):
			nd[k2] += dist[k2] * (1.0 - q)
			nd[k2 + 1] += dist[k2] * q
		dist = nd
	var sc_ev := 0.0
	var trig := 0.0
	for k3 in range(3, 6):
		sc_ev += dist[k3] * _scatter_pay[k3 - 3]
		trig += dist[k3]
	var v := line_ev + sc_ev
	var session := float(FREE_SPINS) * FREE_MULT * v / (1.0 - float(FREE_SPINS) * trig)
	return {"rtp": v + trig * session, "line": line_ev, "scatter": sc_ev, "trigger": trig,
		"session": session, "bonus_rtp": session / bonus_buy_cost_mult()}


func _pay_cells(c: PackedInt32Array) -> float:
	## Line pay (times the line bet) for 5 symbols, left to right.
	var best := 0.0
	var w := 0
	while w < REELS and c[w] == WILD:
		w += 1
	if w >= 3:
		best = _pay[WILD][w - 3]
	if w == REELS:
		return best
	var sym := c[w]
	if sym == SCATTER:
		return best
	var n := w + 1
	while n < REELS and (c[n] == sym or c[n] == WILD):
		n += 1
	if n >= 3:
		best = maxf(best, _pay[sym][n - 3])
	return best


func spin(bet_per_line: float, free := false) -> Dictionary:
	## One spin. Returns {grid: [reel][row] symbol ids, stops: [5], wins:
	## [{line, symbol, count, pay}], scatter: n, scatter_pay, free_spins_awarded,
	## total (money paid, already capped), capped: bool, total_bet, free}.
	var cells := PackedInt32Array()
	cells.resize(REELS * ROWS)
	var stops: Array = []
	var scat := 0
	for r in range(REELS):
		var strip: PackedInt32Array = strips[r]
		var n := strip.size()
		var stop := rng.randi_range(0, n - 1)
		stops.append(stop)
		for row in range(ROWS):
			var s := strip[(stop + row) % n]
			cells[r * ROWS + row] = s
			if s == SCATTER:
				scat += 1
	var mult := FREE_MULT if free else 1.0
	var wins: Array = []
	var total := 0.0
	for li in range(LINES):
		var base := li * REELS
		var res := _line(cells, base)
		if res.x > 0.0:
			var pay := res.x * bet_per_line * mult
			total += pay
			wins.append({"line": li, "symbol": SYMBOLS[int(res.y)], "count": int(res.z), "pay": pay})
	var tb := total_bet(bet_per_line)
	var sp := 0.0
	var awarded := 0
	if scat >= 3:
		sp = _scatter_pay[mini(scat, 5) - 3] * tb * mult
		total += sp
		awarded = FREE_SPINS
	var capped := false
	if total > MAX_WIN_X * tb:
		total = MAX_WIN_X * tb
		capped = true
	var grid: Array = []
	for r in range(REELS):
		var col: Array = []
		for row in range(ROWS):
			col.append(SYMBOLS[cells[r * ROWS + row]])
		grid.append(col)
	return {"grid": grid, "stops": stops, "wins": wins, "scatter": scat, "scatter_pay": sp,
		"free_spins_awarded": awarded, "total": total, "capped": capped, "total_bet": tb, "free": free}


func _line(cells: PackedInt32Array, base: int) -> Vector3:
	## Best pay on one line: (pay in line bets, symbol, count). Pays left to
	## right, 3 or more in a row; wild stands in for anything but the scatter.
	var best := 0.0
	var best_sym := -1
	var best_n := 0
	# A run of wilds alone pays as wilds.
	var w := 0
	while w < REELS and cells[_lines[base + w]] == WILD:
		w += 1
	if w >= 3:
		best = _pay[WILD][w - 3]
		best_sym = WILD
		best_n = w
	if w == REELS:
		return Vector3(best, best_sym, best_n)
	var sym := cells[_lines[base + w]]
	if sym == SCATTER:
		return Vector3(best, best_sym, best_n)
	var n := w + 1
	while n < REELS:
		var c := cells[_lines[base + n]]
		if c != sym and c != WILD:
			break
		n += 1
	if n >= 3:
		var p: float = _pay[sym][n - 3]
		if p > best:
			best = p
			best_sym = sym
			best_n = n
	return Vector3(best, best_sym, best_n)


func _build_strip(counts: Array, strip_seed: int) -> PackedInt32Array:
	## A fixed reel strip (same every time): symbols mixed with a fixed seed,
	## scatters spread out so a reel never shows two at once.
	var r := RandomNumberGenerator.new()
	r.seed = strip_seed + theme_id.hash()
	var others: Array = []
	var n_scat := 0
	for i in range(counts.size()):
		if i == SCATTER:
			n_scat = int(counts[i])
		else:
			for k in range(int(counts[i])):
				others.append(i)
	# Fisher-Yates with the fixed seed.
	for i in range(others.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = others[i]
		others[i] = others[j]
		others[j] = tmp
	var total := others.size() + n_scat
	var out := PackedInt32Array()
	out.resize(total)
	out.fill(-1)
	for k in range(n_scat):
		out[int(floor(float(k) * float(total) / float(n_scat)))] = SCATTER
	var oi := 0
	for i in range(total):
		if out[i] == -1:
			out[i] = others[oi]
			oi += 1
	return out
