class_name BankPage
extends Page
## The bank: savings that earn interest every hour, fixed terms that lock
## cash for 1, 3 or 7 days at a set rate, and one loan at a time paid back in
## set payments.

const DAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

var _saved: Label
var _rate: Label
var _loan_title: Label
var _loan_line: Label
var _loan_btn: Button
var _minus: Label
var _dots: HBoxContainer
var _paid_l: Label
var _room_l: Label
var _opt_rows: Array = []   # [Row, days, rate]
var _run_card: VBoxContainer
var _run_sig := "-"


func _init() -> void:
	super("Bank", true)


func build() -> void:
	body.add_child(ClaimList.new(["term"]))   # ended terms wait here for a tap
	var sc := card()
	var sp := padded(sc, 16, 14)
	sp.add_child(UI.label("Savings", 13, UI.SUB))
	_saved = UI.display("", 40)
	sp.add_child(_saved)
	_rate = UI.label("", 13, UI.SUB)
	sp.add_child(_rate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	sp.add_child(row)
	for spec in [["Deposit", "bank_in", true], ["Withdraw", "bank_out", false]]:
		var b := UI.pill(String(spec[0]), UI.TEXT if spec[2] else UI.RAISED, UI.INK if spec[2] else UI.TEXT, 17, 16)
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m: String = spec[1]
		b.pressed.connect(func():
			Kit.tick()
			if (m == "bank_in" and Game.cash < 0.01) or (m == "bank_out" and Game.savings() < 0.01):
				Kit.toast("Nothing to move")
				return
			TradeSheet.open("bank", "", m))
		Kit.press_fx(b)
		row.add_child(b)

	# Fixed terms: lock cash for a set time at a set rate; the return is shown
	# before you commit.
	var th := HBoxContainer.new()
	body.add_child(th)
	var tl := UI.label("Fixed terms", 17, UI.TEXT, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tl)
	_room_l = UI.label("", 13, UI.SUB)
	_room_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(_room_l)
	var oc := card()
	var first := true
	for r in Game.term_rates():
		if not first:
			separator(oc, 16)
		first = false
		var orow := Row.new("", "", true)
		var d := int(r["days"])
		var rate := float(r["rate"])
		orow.pressed.connect(func(): _open_term_sheet(d, rate))
		oc.add_child(orow)
		_opt_rows.append([orow, d, rate])
	_run_card = card()
	_run_card.visible = false

	var lc := card()
	var lp := padded(lc, 16, 14)
	_loan_title = UI.label("", 17, UI.TEXT, true)
	lp.add_child(_loan_title)
	_loan_line = UI.label("", 13, UI.SUB)
	_loan_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lp.add_child(_loan_line)
	# Payments as segments: paid ones lit, the rest a quiet track, with words under.
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	lp.add_child(_dots)
	for i in Data.LOAN_PAYMENTS:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(0, 6)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(d)
	_paid_l = UI.label("", 13, UI.SUB)
	lp.add_child(_paid_l)
	_loan_btn = UI.secondary_btn("")
	_loan_btn.pressed.connect(_on_loan)
	Kit.press_fx(_loan_btn)
	lp.add_child(_loan_btn)
	_minus = UI.label("", 13, UI.DOWN)
	_minus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_minus)


func refresh() -> void:
	if _saved == null:
		return
	_saved.text = Game.money(Game.savings())
	_rate.text = "+%s an hour (%s%% interest, paid hourly)" % [Game.money_short(Game.savings_per_hour()), str(snappedf(Data.BANK_RATE_H * 100.0, 0.1))]
	var l := Game.loan()
	var has := not l.is_empty()
	var fee := int(round(Data.LOAN_FEE * 100.0))
	_dots.visible = has
	_paid_l.visible = has
	if has:
		var left := int(l["left"])
		var paid := Data.LOAN_PAYMENTS - left
		_loan_title.text = "Loan · %s left" % Game.money_short(Game.loan_owed())
		_loan_line.text = "Next payment %s in %s" % [Game.money_short(float(l["payment"])), Game.clock(maxf(0.0, float(l["next"]) - Game.now()))]
		for i in _dots.get_child_count():
			(_dots.get_child(i) as ColorRect).color = UI.TEXT if i < paid else UI.TRACK
		_paid_l.text = "%d of %d paid · %d%% fee included" % [paid, Data.LOAN_PAYMENTS, fee]
		_loan_btn.text = "Pay it all now · " + Game.money_short(Game.loan_owed())
		Page.set_enabled(_loan_btn, Game.cash >= Game.loan_owed(), false)
	else:
		_loan_title.text = "Loan"
		_loan_line.text = "Borrow up to %s. Pay it back in %d payments, one every %d h, plus a %d%% fee." % [Game.money_short(Game.loan_limit()), Data.LOAN_PAYMENTS, int(Data.LOAN_EVERY_H), fee]
		_loan_btn.text = "Borrow"
		Page.set_enabled(_loan_btn, true, false)
	_refresh_terms()
	_minus.visible = Game.in_minus()
	_minus.text = "You're %s in the minus. Buying waits until your income covers it." % Game.money_short(-Game.cash)


func _on_loan() -> void:
	Kit.tick()
	if Game.loan().is_empty():
		TradeSheet.open("loan", "", "loan")
	elif Game.repay_loan():
		Kit.haptic("success")
		Kit.toast("Loan paid off", true)
		Game.flush_changes()
	else:
		Kit.toast("Need %s more" % Game.money_short(Game.loan_owed() - Game.cash))


static func when_text(unix: float) -> String:
	## "Mon 12:00" in local time.
	var d := Time.get_datetime_dict_from_unix_time(int(unix + float(Game._tz_bias_min) * 60.0))
	return "%s %02d:%02d" % [DAYS[int(d["weekday"])], int(d["hour"]), int(d["minute"])]


func _refresh_terms() -> void:
	var room := Game.term_cap_left()
	_room_l.text = "Room %s of %s" % [Game.money_short(room), Game.money_short(Game.term_cap())]
	for it in _opt_rows:
		var row: Row = it[0]
		var d: int = it[1]
		var rate: float = it[2]
		row.set_texts("%d day%s" % [d, "" if d == 1 else "s"], "Back %s" % when_text(Game.now() + float(d) * 86400.0))
		BusinessPage.price_pill(row, "+%s%%" % _pct(rate), room >= 1.0 and Game.cash >= 1.0)
	# Running terms: rebuilt only when the set changes; times update in place.
	var ts: Array = Game.terms()
	var sig := ""
	for t in ts:
		sig += "%d:%d," % [int(t["start"]), int(t["days"])]
	if sig != _run_sig:
		_run_sig = sig
		for ch in _run_card.get_children():
			ch.queue_free()
		for i in range(ts.size()):
			if i > 0:
				separator(_run_card, 16)
			var r := Row.new("", "", true)
			var idx := i
			r.pressed.connect(func(): _on_break(idx))
			_run_card.add_child(r)
	_run_card.visible = not ts.is_empty()
	var k := 0
	for ch in _run_card.get_children():
		if ch is Row and k < ts.size():
			var t: Dictionary = ts[k]
			(ch as Row).set_texts("%s for %d day%s" % [Game.money_short(float(t["amount"])), int(t["days"]), "" if int(t["days"]) == 1 else "s"],
				"%s back in %s" % [Game.money_short(float(t["payout"])), Game.clock(float(t["left_s"]))] if float(t["left_s"]) > 0.0 else "Ready to collect",
				"Break")
			(ch as Row).value_l.add_theme_color_override("font_color", UI.SUB)
			k += 1


static func _pct(rate: float) -> String:
	var v := rate * 100.0
	return str(snappedf(v, 0.1)) if absf(v - round(v)) > 0.01 else str(int(round(v)))


func _open_term_sheet(days: int, rate: float) -> void:
	Kit.tick()
	var most := minf(Game.cash, Game.term_cap_left())
	if most < 1.0:
		Kit.toast("No room left" if Game.term_cap_left() < 1.0 else "No cash to lock")
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var amt := UI.display("", 40)
	box.add_child(amt)
	var back := UI.label("", 15, UI.SUB)
	back.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(back)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	box.add_child(chips)
	var go := UI.primary_btn("")
	var cur := [most]
	var show := func():
		amt.text = Game.money_short(cur[0])
		back.text = "Get %s back on %s" % [Game.money_short(cur[0] * (1.0 + rate)), when_text(Game.now() + float(days) * 86400.0)]
		go.text = "Lock %s for %d day%s" % [Game.money_short(cur[0]), days, "" if days == 1 else "s"]
	for f in [0.25, 0.5, 0.75, 1.0]:
		var c := UI.pill("Max" if f == 1.0 else "%d%%" % int(f * 100.0), UI.RAISED, UI.TEXT, 15, 16)
		c.custom_minimum_size = Vector2(0, 48)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ff: float = f
		c.pressed.connect(func():
			Kit.tick()
			cur[0] = maxf(1.0, most * ff)
			show.call())
		Kit.press_fx(c)
		chips.add_child(c)
	box.add_child(go)
	show.call()
	var root := Kit.sheet("%d-day term · +%s%%" % [days, _pct(rate)], "Locked until it ends. Break early to get 95% back, no interest.", [{"text": "Close", "style": "plain"}], true, box)
	go.pressed.connect(func():
		if Game.open_term(days, cur[0]):
			Kit.haptic("success")
			Kit.toast("Locked %s for %d day%s" % [Game.money_short(cur[0]), days, "" if days == 1 else "s"], true)
			Game.flush_changes()
			Kit.close_top()
		else:
			Kit.haptic("error")
			Kit.toast("Couldn't lock that"))
	Kit.press_fx(go)


func _on_break(i: int) -> void:
	Kit.tick()
	var ts: Array = Game.terms()
	if i >= ts.size():
		return
	var t: Dictionary = ts[i]
	if float(t["left_s"]) <= 0.0:
		Kit.toast("It's in To claim at the top")
		return
	Kit.sheet("Break this term?", "You get %s back now (95%%), with no interest. Waiting %s gets you %s." % [Game.money_short(float(t["amount"]) * 0.95), Game.clock(float(t["left_s"])), Game.money_short(float(t["payout"]))], [
		{"text": "Keep it", "style": "primary"},
		{"text": "Break early", "style": "plain", "call": func():
			var got := Game.break_term(i)
			if got > 0.0:
				Kit.toast("%s back" % Game.money_short(got), true)
				Game.flush_changes()},
	])
