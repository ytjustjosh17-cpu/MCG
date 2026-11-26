extends SceneTree
## Sun Forge maths: the house keeps a small edge on the base game, the ante
## bet and the bonus buy (each about 96%, all under 97%), tumbles and orbs
## behave, and no round pays over 5,000x. Fixed seeds, so it repeats exactly.
##   godot --headless --path . -s res://tests/forge_test.gd [-- base_spins features]
##
## Base and ante RTP are measured in two parts to tame the long tail: the
## spins themselves (millions of cheap samples) plus trigger rate x the average
## feature (from many bought features). The plain average is printed too.

var fails := 0


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func():
		print("FAIL  timed out")
		quit(1))
	_run.call_deferred()


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	var n_spins := int(args[0]) if args.size() > 0 else 400000
	var n_feat := int(args[1]) if args.size() > 1 else 20000
	var fm: Script = load("res://scripts/casino/forge_math.gd")

	# Rules on a fixed grid.
	_ok(fm.pay_x(8, 8) == 10.0 and fm.pay_x(8, 12) == 50.0 and fm.pay_x(0, 7) == 0.0, "pays need 8 or more of a symbol, more pays more")
	var m = fm.new(1)
	var seen_tumble := false
	var orbs_mult_ok := true
	var refill_ok := true
	for i in range(3000):
		var r: Dictionary = m.base_spin(1.0, false, true)
		var g: Dictionary = r["spin"]
		var steps: Array = g["steps"]
		if steps.size() >= 3:
			seen_tumble = true
		for s in steps:
			if (s["grid"] as PackedInt32Array).size() != fm.CELLS:
				refill_ok = false
		if int(r["mult"]) > 0 and absf(float(r["spin_x"]) - float(r["tumble_x"]) * float(r["mult"])) > 1e-6:
			orbs_mult_ok = false
	_ok(seen_tumble, "tumbles happen (a win, a refill, another win)")
	_ok(refill_ok, "every tumble step refills a full 6 x 5 grid")
	_ok(orbs_mult_ok, "orbs add up and multiply the spin's win")

	# Features: average win from many bought features (also the buy RTP).
	var fb = fm.new(77)
	var f_sum := 0.0
	var f_max := 0.0
	var tm_max := 0
	for i in range(n_feat):
		var b: Dictionary = fb.buy(1.0, false)
		var x := float(b["x"])
		f_sum += x
		f_max = maxf(f_max, x)
		tm_max = maxi(tm_max, int(b["feature"]["total_mult"]))
	var feat_avg: float = f_sum / float(n_feat) - float(fm.SIGIL_PAY[4])
	var buy_rtp: float = (f_sum / float(n_feat)) / fm.BUY_X

	# Spins: base and ante, without paying out features (counted by rate).
	var res := {}
	var round_max := 0.0
	for ante in [false, true]:
		var sm = fm.new(1234 if not ante else 4321)
		var spin_sum := 0.0
		var trig := 0
		var hits := 0
		for i in range(n_spins):
			var g: Dictionary = sm.grid_spin("ante" if ante else "base", false)
			var x := float(g["x"])
			var o := int(g["orbs"])
			var w := minf(x * (float(o) if (x > 0.0 and o > 0) else 1.0), fm.MAX_WIN_X)
			if int(g["sigils"]) >= 4:
				trig += 1
				w += float(fm.SIGIL_PAY[mini(int(g["sigils"]), 6)])
			spin_sum += w
			round_max = maxf(round_max, w)
			if w > 0.0:
				hits += 1
		var stake: float = fm.ANTE_X if ante else 1.0
		var rate := float(trig) / float(n_spins)
		var rtp := (spin_sum / float(n_spins) + rate * feat_avg) / stake
		res["ante" if ante else "base"] = {"rtp": rtp, "rate": rate, "hit": float(hits) / float(n_spins)}

	# A plain average of whole rounds (features played out), as a cross-check.
	var pm = fm.new(99)
	var plain := 0.0
	var n_plain := mini(n_spins, 60000)
	var capped_ok := true
	for i in range(n_plain):
		var r: Dictionary = pm.base_spin(1.0, false, false)
		plain += float(r["x"])
		if float(r["x"]) > fm.MAX_WIN_X + 1e-6:
			capped_ok = false
		round_max = maxf(round_max, float(r["x"]))

	var b_r: Dictionary = res["base"]
	var a_r: Dictionary = res["ante"]
	print("Sun Forge base  RTP %.2f%%  hit rate %.1f%%  free spins 1 in %d" % [float(b_r["rtp"]) * 100.0, float(b_r["hit"]) * 100.0, int(round(1.0 / maxf(float(b_r["rate"]), 1e-9)))])
	print("Sun Forge ante  RTP %.2f%%  free spins 1 in %d (x%.2f the base chance)" % [float(a_r["rtp"]) * 100.0, int(round(1.0 / maxf(float(a_r["rate"]), 1e-9))), float(a_r["rate"]) / maxf(float(b_r["rate"]), 1e-9)])
	print("Sun Forge buy   RTP %.2f%%  average feature %.1fx  best %.0fx  top total multiplier x%d" % [buy_rtp * 100.0, feat_avg, f_max, tm_max])
	print("Plain average of %d whole rounds: %.2f%%  (long tail, noisy)" % [n_plain, plain / float(n_plain) * 100.0])
	print("Biggest round seen: %.0fx  time %.1f s" % [round_max, float(Time.get_ticks_msec() - t0) / 1000.0])
	for k in ["base", "ante"]:
		var v := float(res[k]["rtp"])
		_ok(v > 0.935 and v < 0.97, "%s RTP %.2f%% is under 97%% (target about 96%%)" % [k, v * 100.0])
	_ok(buy_rtp > 0.935 and buy_rtp < 0.97, "bonus buy RTP %.2f%% is under 97%%" % (buy_rtp * 100.0))
	var ratio := float(a_r["rate"]) / maxf(float(b_r["rate"]), 1e-9)
	_ok(ratio > 1.7 and ratio < 2.4, "ante bet roughly doubles the free spins chance (x%.2f)" % ratio)
	_ok(capped_ok and round_max <= fm.MAX_WIN_X + 1e-6, "no round pays over 5,000x")
	# The cap really bites: a feature asked to pay more stops at 5,000x.
	var cm = fm.new(5)
	var big := 0.0
	for i in range(200):
		var f: Dictionary = cm.feature(1.0, false, 400)
		big = maxf(big, float(f["x"]))
	_ok(big <= fm.MAX_WIN_X + 1e-6, "a very long feature still stops at 5,000x (%.0fx)" % big)
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
