extends SceneTree
## Headless smoke test: run with
##   godot --headless --path game -s res://tests/smoke_test.gd

var _fails := 0


func _check(cond: bool, what: String) -> void:
	if cond:
		print("PASS  ", what)
	else:
		_fails += 1
		printerr("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	game.reset_game()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# Formatting.
	_check(game.money(2.5) == "$2.50", "money small")
	_check(game.money(19284.4) == "$19,284", "money grouped")
	_check(game.money(62480190) == "$62,480,190", "money millions")
	_check(game.money(1.25e9) == "$1.25B", "money billions")
	_check(game.money(3.4e12) == "$3.40T", "money trillions")
	_check(game.money_short(4658503.47) == "$4.66M", "money short")
	_check(game.clock(119) == "1:59", "clock")

	# Tapping through the tower card.
	var card = main.find_child("TowerCard", true, false)
	_check(card != null, "tower card exists")
	for i in 400:
		card._do_tap(Vector2(250, 100))
	_check(is_equal_approx(game.cash, 1000.0), "400 taps at $2.50 = $1,000 (got %s)" % game.cash)
	_check(game.taps == 400, "tap count")
	_check(game.can_level_up(), "can level up at $1,000")
	_check(game.level_up(), "level up")
	_check(game.level == 2 and is_equal_approx(game.cash, 0.0), "level 2, cash spent")
	_check(is_equal_approx(game.tap_value(), 4.1), "level 2 tap is $4.10")
	_check(is_equal_approx(game.level_cost(), 3280.0), "level 3 costs $3,280")

	# Boost.
	_check(game.start_boost(), "boost starts")
	_check(game.boost_active(), "boost active")
	card._do_tap(Vector2(250, 100))
	_check(is_equal_approx(game.cash, 12.3), "boosted tap is x3 (got %s)" % game.cash)
	_check(not game.start_boost(), "boost on cooldown")

	# History and chart drawing with real points.
	for i in 5:
		game._record_history()
	game.cash += 500.0
	game.changed.emit()
	await process_frame
	_check(game.week_change().size() == 2, "week change available")

	# Every tab opens.
	for i in 5:
		main.show_page(i)
		await process_frame
	main.show_page(0)
	await process_frame

	# Save and load round trip.
	var before_cash: float = game.cash
	game.save_game()
	game.cash = 0.0
	game.level = 1
	game.load_game()
	_check(is_equal_approx(game.cash, before_cash), "save/load keeps cash")
	_check(game.level == 2, "save/load keeps level")

	# Offline earnings are capped at 8 hours.
	game.income_per_hour = 1000.0
	game._apply_offline(24 * 3600)
	_check(is_equal_approx(game.away_earned, 8000.0), "offline capped at 8 h")
	game.reset_game()

	await create_timer(1.0).timeout
	print("Failures: ", _fails)
	quit(1 if _fails > 0 else 0)
