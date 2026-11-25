extends SceneTree
## Renders every screen in a mid-game state and saves PNGs (needs a display).
##   xvfb-run godot --path game --resolution 390x844 -s res://tests/screenshot.gd -- <out_dir>

var out := "/tmp"
var main


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("saved ", name)


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	var g = root.get_node("Game")
	g.reset_game()
	# A believable mid-game save.
	g.cash = 5.0e7
	g.level = 6
	g.taps = 12480
	for id in ["shop", "taxi", "shipping", "factory"]:
		g.open_business(id, Data.business(id)["names"][0])
	g.biz["shop"]["stage"] = 5
	g.biz["shop"]["units"] = 23
	g.biz["taxi"]["stage"] = 3
	g.biz["taxi"]["units"] = 15
	g.biz["shipping"]["stage"] = 2
	g.biz["shipping"]["units"] = 6
	g.start_expansion("shipping")
	g.buy_asset("share", "NRV", 4.0e5)
	g.buy_asset("share", "LMG", 2.0e5)
	g.buy_asset("coin", "KRV", 1.5e5)
	g.buy_property(0)
	g.buy_property(8)
	g.improve_property(8, 2)
	g.buy_item("watches", 0)
	g.buy_item("watches", 1)
	g.cash = 2.4e5
	g.recalc()
	for i in 8:
		g._record_history()
		g.cash += 2000.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _shot("01_earn")
	main.show_page(1)
	await _shot("02_business")
	main.push(BusinessDetail.new("taxi"))
	await _shot("03_taxi")
	main.pop()
	await create_timer(0.4).timeout
	main.push(StartBusinessPage.new())
	await _shot("04_new_business")
	main.pop()
	await create_timer(0.4).timeout
	main.push(MergersPage.new())
	await _shot("05_mergers")
	main.show_page(2)
	await _shot("06_invest_shares")
	var inv = main._pages[2]
	inv._seg.select(1, true)
	await _shot("07_invest_property")
	inv._seg.select(2, true)
	await _shot("08_invest_crypto")
	main.push(CoinDetail.new("KRV"))
	await _shot("09_coin")
	main.pop()
	await create_timer(0.4).timeout
	main.push(PropertyDetail.new(8))
	await _shot("10_property")
	main.show_page(3)
	await _shot("11_items")
	main.push(ItemsPage.CollectionPage.new("watches"))
	await _shot("12_collection")
	main.show_page(4)
	await _shot("13_profile")
	main.push(AchievementsPage.new())
	await _shot("14_achievements")
	g.reset_game()
	quit()
