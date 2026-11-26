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


func _init() -> void:
	super("Bank", true)


func build() -> void:
	var sc := card()
	var sp := padded(sc, 16, 14)
	sp.add_child(UI.label("Savings", 13, UI.SUB))
	_saved = UI.display("", 36)
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
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	lp.add_child(_dots)
	for i in Data.LOAN_PAYMENTS:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(0, 6)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(d)
	_loan_btn = UI.pill("", UI.TEXT, UI.INK, 17, 16)
	_loan_btn.custom_minimum_size = Vector2(0, 48)
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
	_rate.text = "+%s an hour · 0.2%% interest, paid hourly" % Game.money_short(Game.savings_per_hour())
	var l := Game.loan()
	var has := not l.is_empty()
	_dots.visible = has
	if has:
		var left := int(l["left"])
		_loan_title.text = "Loan · %s left" % Game.money_short(Game.loan_owed())
		_loan_line.text = "Next payment %s in %s · %d of %d to go" % [Game.money_short(float(l["payment"])), Game.clock(maxf(0.0, float(l["next"]) - Game.now())), left, Data.LOAN_PAYMENTS]
		for i in _dots.get_child_count():
			(_dots.get_child(i) as ColorRect).color = UI.TRACK if i < Data.LOAN_PAYMENTS - left else UI.TEXT
		_loan_btn.text = "Pay it all now · " + Game.money_short(Game.loan_owed())
		Page.set_enabled(_loan_btn, Game.cash >= Game.loan_owed(), false)
	else:
		_loan_title.text = "Loan"
		_loan_line.text = "Borrow up to %s. Pay back %d payments, one every %d h, plus 25%%." % [Game.money_short(Game.loan_limit()), Data.LOAN_PAYMENTS, int(Data.LOAN_EVERY_H)]
		_loan_btn.text = "Borrow"
		Page.set_enabled(_loan_btn, true)
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
