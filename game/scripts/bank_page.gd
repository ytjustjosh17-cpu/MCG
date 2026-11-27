class_name BankPage
extends Page
## The bank: savings that earn interest every hour, and one loan at a time
## paid back in set payments.

var _saved: Label
var _rate: Label
var _loan_title: Label
var _loan_line: Label
var _loan_btn: Button
var _minus: Label
var _dots: HBoxContainer
var _paid_l: Label


func _init() -> void:
	super("Bank", true)


func build() -> void:
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
