class_name ForgeMath
extends RefCounted
## Sun Forge: a 6 x 5 "pays anywhere" tumble slot. Pure rules, seedable, no UI.
##
## - 8 or more of one symbol anywhere on the grid pays (x total bet, by count:
##   8-9, 10-11, 12+). Winning symbols vanish, the rest fall, new ones drop in,
##   and it repeats until nothing more pays (a tumble).
## - Sun orbs carry x2 to x100. If the tumble sequence won anything, the orbs
##   on the grid are added together and multiply that spin's win.
## - 4+ forge sigils (scatter) anywhere: 15 free spins, and the sigils pay
##   3x / 5x / 100x the bet for 4 / 5 / 6+. In free spins every orb in a
##   winning sequence adds to a total multiplier kept for the whole feature;
##   3+ sigils give 5 more spins.
## - Ante bet: +25% stake, about twice the chance of free spins.
## - Buy free spins: 100x the bet.
## - One round (spin plus any free spins) pays at most 5,000x the bet.
## Tuned by tests/forge_test.gd (Monte Carlo): about 96% back over time.

const COLS := 6
const ROWS := 5
const CELLS := 30
const SIGIL := 9
const ORB := 10
const SYMBOLS := ["teal", "amber", "violet", "ruby", "ingot", "anvil", "key", "crown", "disc", "sigil", "orb"]
const NAMES := ["Teal shard", "Amber shard", "Violet shard", "Ruby shard", "Molten ingot", "Anvil", "Sun key", "Iron crown", "Red sun disc", "Forge sigil", "Sun orb"]
# x total bet for 8-9, 10-11 and 12+ of one symbol.
const PAY := [
	[0.25, 0.75, 2.0], [0.4, 0.9, 4.0], [0.5, 1.0, 5.0], [0.8, 1.2, 8.0],
	[1.0, 1.5, 10.0], [1.5, 2.0, 12.0], [2.0, 5.0, 15.0], [2.5, 10.0, 25.0], [10.0, 25.0, 50.0]]
const SIGIL_PAY := {4: 3.0, 5: 5.0, 6: 100.0}
const ORB_VALUES := [2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 50, 100]
const ORB_WEIGHTS := [200.0, 150.0, 110.0, 90.0, 70.0, 50.0, 35.0, 25.0, 15.0, 10.0, 6.0, 2.0, 0.6]
# Symbol weights for each cell (the nine paying symbols), then sigil and orb.
const W_PAY := [20.0, 19.0, 17.0, 16.0, 13.0, 11.0, 9.0, 7.0, 5.0]
const W_FREE := [22.0, 20.0, 18.0, 16.0, 12.0, 10.0, 8.0, 6.0, 4.0]
const SIGIL_W := {"base": 2.04, "ante": 2.51, "free": 1.6}
const ORB_W := {"base": 1.15, "ante": 1.15, "free": 3.22}
const ANTE_X := 1.25
const BUY_X := 100.0
const MAX_WIN_X := 5000.0
const FREE_SPINS := 15
const RETRIGGER := 5

var rng := RandomNumberGenerator.new()
var _cum := {}        # mode -> cumulative weights
var _orb_cum: Array = []


func _init(rng_seed := -1) -> void:
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	for mode in ["base", "ante", "free"]:
		var ws: Array = (W_FREE if mode == "free" else W_PAY).duplicate()
		ws.append(float(SIGIL_W[mode]))
		ws.append(float(ORB_W[mode]))
		_cum[mode] = _cumulative(ws)
	_orb_cum = _cumulative(ORB_WEIGHTS)


static func _cumulative(ws: Array) -> Array:
	var out: Array = []
	var t := 0.0
	for w in ws:
		t += float(w)
		out.append(t)
	return out


func _pick(cum: Array) -> int:
	var r := rng.randf() * float(cum[cum.size() - 1])
	for i in range(cum.size()):
		if r < float(cum[i]):
			return i
	return cum.size() - 1


func _orb_value() -> int:
	return int(ORB_VALUES[_pick(_orb_cum)])


static func idx(col: int, row: int) -> int:
	return col * ROWS + row


static func tier(count: int) -> int:
	return 0 if count < 10 else (1 if count < 12 else 2)


static func pay_x(sym: int, count: int) -> float:
	if sym >= 9 or count < 8:
		return 0.0
	return float(PAY[sym][tier(count)])


func stake(bet: float, ante: bool) -> float:
	return bet * (ANTE_X if ante else 1.0)


func buy_cost(bet: float) -> float:
	return bet * BUY_X


func grid_spin(mode: String, record := true) -> Dictionary:
	## One spin with all its tumbles. Returns every step for the UI:
	## steps: [{grid, vals, wins: [{sym, count, x, cells}], removed, x}]
	## and x (tumble win in bets), orbs (sum on the final grid), sigils.
	var cum: Array = _cum[mode]
	var grid := PackedInt32Array()
	var vals := PackedInt32Array()
	grid.resize(CELLS)
	vals.resize(CELLS)
	for i in range(CELLS):
		var s := _pick(cum)
		grid[i] = s
		vals[i] = _orb_value() if s == ORB else 0
	var steps: Array = []
	var total_x := 0.0
	var counts := PackedInt32Array()
	counts.resize(11)
	while true:
		for k in range(11):
			counts[k] = 0
		for i in range(CELLS):
			counts[grid[i]] += 1
		var wins: Array = []
		var winning := {}
		var step_x := 0.0
		for s in range(9):
			if counts[s] >= 8:
				var x := pay_x(s, counts[s])
				step_x += x
				winning[s] = true
				if record:
					var cells: Array = []
					for i in range(CELLS):
						if grid[i] == s:
							cells.append(i)
					wins.append({"sym": s, "count": counts[s], "x": x, "cells": cells})
		if record:
			steps.append({"grid": grid.duplicate(), "vals": vals.duplicate(), "wins": wins, "x": step_x})
		if winning.is_empty():
			break
		total_x += step_x
		# Tumble: in each column keep what didn't win (in order, falling to
		# the bottom) and drop new symbols in from the top.
		for c in range(COLS):
			var keep_s: Array = []
			var keep_v: Array = []
			for r in range(ROWS):
				var i := idx(c, r)
				if not winning.has(grid[i]):
					keep_s.append(grid[i])
					keep_v.append(vals[i])
			var need := ROWS - keep_s.size()
			for r in range(ROWS):
				var i := idx(c, r)
				if r < need:
					var s := _pick(cum)
					grid[i] = s
					vals[i] = _orb_value() if s == ORB else 0
				else:
					grid[i] = int(keep_s[r - need])
					vals[i] = int(keep_v[r - need])
	var orbs := 0
	var sigils := 0
	for i in range(CELLS):
		orbs += vals[i]
		if grid[i] == SIGIL:
			sigils += 1
	return {"steps": steps, "x": total_x, "orbs": orbs, "sigils": sigils, "grid": grid, "vals": vals}


func feature(bet: float, record := true, spins := FREE_SPINS) -> Dictionary:
	## A whole free spins feature, worked out up front.
	## spins: [{spin, x (spin win in bets), added, total_mult, left}]
	var left := spins
	var tm := 0
	var tot_x := 0.0
	var out: Array = []
	var capped := false
	var n := 0
	while left > 0:
		left -= 1
		n += 1
		var g := grid_spin("free", record)
		var x := float(g["x"])
		var added := 0
		if x > 0.0 and int(g["orbs"]) > 0:
			added = int(g["orbs"])
			tm += added
		var sx := x * (float(tm) if added > 0 else 1.0)
		var extra := RETRIGGER if int(g["sigils"]) >= 3 else 0
		left += extra
		if tot_x + sx >= MAX_WIN_X:
			sx = MAX_WIN_X - tot_x
			capped = true
		tot_x += sx
		if record:
			out.append({"spin": g, "x": sx, "added": added, "total_mult": tm, "left": left, "extra": extra})
		if capped:
			break
	return {"spins": out, "x": tot_x, "money": tot_x * bet, "total_mult": tm, "capped": capped, "count": n}


func base_spin(bet: float, ante := false, record := true) -> Dictionary:
	## One paid spin. total is the money the whole round pays (the spin,
	## the sigil pay and any free spins), capped at 5,000x the bet.
	var g := grid_spin("ante" if ante else "base", record)
	var x := float(g["x"])
	var mult := int(g["orbs"]) if (x > 0.0 and int(g["orbs"]) > 0) else 0
	var spin_x := x * (float(mult) if mult > 0 else 1.0)
	var sig := int(g["sigils"])
	var sig_x := float(SIGIL_PAY[mini(sig, 6)]) if sig >= 4 else 0.0
	var feat := {}
	var feat_x := 0.0
	if sig >= 4:
		feat = feature(bet, record)
		feat_x = float(feat["x"])
	var round_x := spin_x + sig_x + feat_x
	var capped := round_x > MAX_WIN_X
	round_x = minf(round_x, MAX_WIN_X)
	return {"spin": g, "tumble_x": x, "mult": mult, "spin_x": spin_x, "sigil_x": sig_x, "feature": feat,
		"x": round_x, "total": round_x * bet, "capped": capped or bool(feat.get("capped", false)),
		"bet": bet, "stake": stake(bet, ante), "ante": ante, "free_spins": FREE_SPINS if sig >= 4 else 0}


func buy(bet: float, record := true) -> Dictionary:
	## Buy free spins: the feature starts at once (with the 4-sigil pay).
	var feat := feature(bet, record)
	var round_x := minf(float(SIGIL_PAY[4]) + float(feat["x"]), MAX_WIN_X)
	return {"feature": feat, "sigil_x": float(SIGIL_PAY[4]), "x": round_x, "total": round_x * bet,
		"capped": bool(feat["capped"]) or round_x >= MAX_WIN_X, "bet": bet, "stake": buy_cost(bet), "bought": true}
