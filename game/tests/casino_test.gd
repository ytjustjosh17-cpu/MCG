extends SceneTree
## Casino fairness: every game and every bet must pay back less than it takes
## (the house always has a small edge), and no slot spin may pay more than
## 500 times the bet. Fixed seeds, so the numbers repeat exactly.
## Usage: $G --headless --path . -s res://tests/casino_test.gd [-- slot_spins bj_hands]

var fails := 0


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func():
		print("FAIL  casino test took too long")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var t0 := Time.get_ticks_msec()
	var spins := 300000
	var bj_hands := 300000
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		spins = int(args[0])
	if args.size() > 1:
		bj_hands = int(args[1])
	_slots(spins)
	print("  (slots %.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	_roulette()
	_tower()
	_jackpot()
	var t1 := Time.get_ticks_msec()
	_blackjack(bj_hands)
	print("  (blackjack %.1f s)" % ((Time.get_ticks_msec() - t1) / 1000.0))
	print("Casino test took %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("Failures: %d" % fails)
	quit(1 if fails > 0 else 0)


func _jackpot() -> void:
	## The jackpot's chance and size (its effect on the return is measured
	## in smoke_test with the real pot).
	var hits := 1.0 / Data.JP_CHANCE
	_ok(hits >= 5000.0 and hits <= 20000.0, "jackpot: 1 in %d bets (5,000 to 20,000)" % int(hits))
	_ok(Data.JP_SEED_H >= 12.0 and Data.JP_CAP_H <= 72.0, "jackpot: starts at %d h of income, stops at %d h" % [int(Data.JP_SEED_H), int(Data.JP_CAP_H)])


func _session(m: SlotMath, bet: float) -> float:
	## Plays a full free-spin round (10 spins, more if scatters come again).
	var left := SlotMath.FREE_SPINS
	var won := 0.0
	var guard := 0
	while left > 0 and guard < 2000:
		var r: Dictionary = m.spin(bet, true)
		won += float(r["total"])
		left += int(r["free_spins_awarded"]) - 1
		guard += 1
	return won


func _slots(spins: int) -> void:
	var bet := 1.0
	for th in SlotMath.THEMES.keys():
		var m := SlotMath.new(th, 1234)
		var tb := m.total_bet(bet)
		var paid := 0.0
		var staked := 0.0
		var triggers := 0
		var biggest := 0.0
		var hits := 0
		var over_cap := false
		for i in range(spins):
			staked += tb
			var r: Dictionary = m.spin(bet)
			var won := float(r["total"])
			if won > 0.0:
				hits += 1
			if won > tb * SlotMath.MAX_WIN_X + 1e-6:
				over_cap = true
			biggest = maxf(biggest, won / tb)
			if int(r["free_spins_awarded"]) > 0:
				triggers += 1
				var fs := _session(m, bet)
				biggest = maxf(biggest, fs / tb)
				paid += fs
			paid += won
		var rtp := paid / staked
		var ex: Dictionary = m.theoretical()
		print("  %-16s exact RTP %.2f%%, played %.2f%%  hit rate %.1f%%  free spins 1 in %d  biggest %.0fx" % [
			SlotMath.THEMES[th]["name"], float(ex["rtp"]) * 100.0, rtp * 100.0, 100.0 * hits / spins, int(spins / maxi(1, triggers)), biggest])
		_ok(float(ex["rtp"]) > 0.94 and float(ex["rtp"]) < 0.965, "%s exact return is 94 to 96.5%% (%.2f%%)" % [th, float(ex["rtp"]) * 100.0])
		_ok(float(ex["bonus_rtp"]) < 0.96, "%s bonus buy exact return under 96%% (%.2f%%)" % [th, float(ex["bonus_rtp"]) * 100.0])
		_ok(rtp > 0.92 and rtp < 0.98, "%s played return agrees: 92 to 98%% (%.2f%%)" % [th, rtp * 100.0])
		_ok(not over_cap, "%s: no spin pays over %dx the bet" % [th, int(SlotMath.MAX_WIN_X)])
		# Bonus buy: pay the price, play the free spins.
		var bm := SlotMath.new(th, 777)
		var buys := maxi(2000, spins / 75)
		var cost := 0.0
		var back := 0.0
		for i in range(buys):
			cost += bm.bonus_buy_cost(bet)
			back += _session(bm, bet)
		var brtp := back / cost
		print("  %-16s bonus buy (%.1fx) RTP %.2f%%" % [SlotMath.THEMES[th]["name"], bm.bonus_buy_cost_mult(), brtp * 100.0])
		_ok(brtp < 1.0, "%s bonus buy pays back under 100%% (%.2f%%)" % [th, brtp * 100.0])
	# A capped spin really is capped.
	var cm := SlotMath.new("vault", 5)
	var forced := false
	for i in range(50000):
		var r: Dictionary = cm.spin(1.0, true)
		if bool(r["capped"]):
			forced = true
			_ok(is_equal_approx(float(r["total"]), 20.0 * SlotMath.MAX_WIN_X), "a capped spin pays exactly the cap")
			break
	if not forced:
		print("  (no spin reached the cap in 50k free spins; cap checked above)")


func _roulette() -> void:
	var checks := [["straight", 17], ["straight", 0], ["split", [17, 20]], ["split", [0, 2]],
		["street", 13], ["corner", [14, 15, 17, 18]], ["six", 25], ["dozen", 1], ["dozen", 3],
		["column", 2], ["red", null], ["black", null], ["odd", null], ["even", null], ["low", null], ["high", null]]
	var all_ok := true
	for c in checks:
		var ret := 0.0
		for n in range(37):
			ret += RouletteMath.payout(c[0], c[1], n)
		ret /= 37.0
		if not is_equal_approx(ret, 36.0 / 37.0):
			all_ok = false
			print("  roulette %s %s returns %.4f" % [c[0], str(c[1]), ret])
	_ok(all_ok, "every roulette bet returns exactly 36/37 (97.30%%) over all 37 numbers")
	_ok(not RouletteMath.valid("split", [3, 4]) and not RouletteMath.valid("corner", [3, 4, 6, 7]) and RouletteMath.valid("split", [3, 6]), "bets that aren't next to each other are refused")
	_ok(RouletteMath.payout("red", null, 0) == 0.0 and RouletteMath.payout("even", null, 0) == 0.0, "zero loses outside bets")
	var w := RouletteMath.WHEEL.duplicate()
	w.sort()
	var full := true
	for n in range(37):
		full = full and w[n] == n
	_ok(full and RouletteMath.RED.size() == 18, "the wheel has each number once and 18 reds")
	var rm := RouletteMath.new(9)
	var bad := false
	for i in range(20000):
		var n := rm.spin()
		bad = bad or n < 0 or n > 36
	_ok(not bad, "spins land on 0 to 36")
	_ok(is_equal_approx(RouletteMath.settle([{"type": "straight", "arg": 7, "amount": 10.0}, {"type": "red", "arg": null, "amount": 5.0}], 7), 370.0), "settle adds up several bets")


func _blackjack(n_hands: int) -> void:
	var bj := BlackjackMath.new(4242)
	var staked := 0.0
	var back := 0.0
	var fresh := true
	var serial := bj.shoe_serial
	for i in range(n_hands):
		bj.deal(1.0)
		if bj.shoe_serial != serial + 1 or bj.cards_left() != BlackjackMath.DECKS * 52 - 4:
			fresh = false
		serial = bj.shoe_serial
		var guard := 0
		while not bj.is_over() and guard < 30:
			guard += 1
			var h: Dictionary = bj.current_hand()
			var move := BlackjackMath.basic_strategy(h["cards"], bj.dealer_up(), bj.can_double(), bj.can_split())
			match move:
				"split":
					bj.split()
				"double":
					bj.double()
				"stand":
					bj.stand()
				_:
					bj.hit()
		var r: Dictionary = bj.result()
		staked += float(r["staked_total"])
		back += float(r["payout_total"])
	var rtp := back / staked
	print("  Blackjack        RTP %.2f%% over %d hands (basic strategy)" % [rtp * 100.0, n_hands])
	_ok(rtp > 0.98 and rtp < 1.0, "blackjack with perfect play pays back 98 to 100%% (%.2f%%)" % (rtp * 100.0))
	_ok(fresh, "every hand starts from a fresh, full shoe (counting cards can't work)")
	# Rules spot checks.
	var v := BlackjackMath.hand_value([{"rank": "A", "suit": "hearts"}, {"rank": "6", "suit": "clubs"}])
	_ok(int(v["total"]) == 17 and bool(v["soft"]), "A+6 is soft 17")
	v = BlackjackMath.hand_value([{"rank": "A", "suit": "hearts"}, {"rank": "A", "suit": "clubs"}, {"rank": "K", "suit": "clubs"}])
	_ok(int(v["total"]) == 12 and not bool(v["soft"]), "A+A+K is hard 12")
	_ok(BlackjackMath.card_file({"rank": "10", "suit": "diamonds"}) == "cardDiamonds10.png", "card file names match the Kenney pack")
	# A natural pays 3 to 2; a split 21 pays even money.
	var t := BlackjackMath.new(1)
	t.dealer = [{"rank": "9", "suit": "hearts"}, {"rank": "7", "suit": "clubs"}]
	t.hands = [{"cards": [{"rank": "A", "suit": "hearts"}, {"rank": "K", "suit": "clubs"}], "bet": 10.0, "done": true, "doubled": false, "split_aces": false, "bust": false, "from_split": false}]
	t.phase = "done"
	_ok(is_equal_approx(float(t.result()["payout_total"]), 25.0), "blackjack pays 3 to 2")
	t.hands[0]["from_split"] = true
	_ok(is_equal_approx(float(t.result()["payout_total"]), 20.0), "21 after a split pays even money")


func _tower() -> void:
	## Tower: every cash-out point pays back 95 to 97%, the top prize never
	## passes the smallest win cap over the biggest bet (so the cap never cuts
	## a ladder short), and laid-out towers are fair (bad boxes spread evenly).
	var cap_x := Data.CASINO_MIN_WIN_CAP / Data.CASINO_MIN_BET_CAP
	for m in TowerMath.ORDER:
		var d := TowerMath.mode(m)
		var p := float(int(d["boxes"]) - int(d["bad"])) / float(d["boxes"])
		var worst := 1.0
		var best := 0.0
		for k in range(1, int(d["rows"]) + 1):
			var rtp := pow(p, k) * TowerMath.mult(m, k)
			worst = minf(worst, rtp)
			best = maxf(best, rtp)
		_ok(worst >= 0.95 and best <= 0.9701, "tower %s: every cash-out pays back 95-97%% (%.4f to %.4f)" % [m, worst, best])
		_ok(TowerMath.mult(m, int(d["rows"])) <= cap_x, "tower %s: top prize x%.1f stays under the x%.0f cap" % [m, TowerMath.mult(m, int(d["rows"])), cap_x])
		# Simulated climbs that cash out after one or two rows (low variance).
		var tm := TowerMath.new(7)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var staked := 0.0
		var paid := 0.0
		var bad_at := {}
		var runs := 120000
		for i in runs:
			var lay := tm.roll_layout(m)
			for b in (lay[0] as Array):
				bad_at[b] = int(bad_at.get(b, 0)) + 1
			var target := 1 + (i % 2)
			var step := 0
			staked += 1.0
			while step < target:
				if not TowerMath.is_safe(lay, step, rng.randi_range(0, int(d["boxes"]) - 1)):
					step = -1
					break
				step += 1
			if step > 0:
				paid += TowerMath.mult(m, step)
		var rtp_sim := paid / staked
		_ok(rtp_sim > 0.94 and rtp_sim < 0.99, "tower %s: simulated climbs pay back %.3f" % [m, rtp_sim])
		var even := true
		for b in int(d["boxes"]):
			var share := float(bad_at.get(b, 0)) / float(runs * int(d["bad"]))
			if absf(share - 1.0 / float(d["boxes"])) > 0.01:
				even = false
		_ok(even, "tower %s: bad boxes are spread evenly" % m)
	var a := TowerMath.new(3).roll_layout("hard")
	var b2 := TowerMath.new(3).roll_layout("hard")
	_ok(a == b2 and a.size() == 4 and (a[0] as Array).size() == 2, "tower: a seeded layout is fixed (a restore can't re-roll it)")

