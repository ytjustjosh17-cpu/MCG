extends SceneTree
## Renders the game and saves screenshots (needs a display, e.g. xvfb-run).
##   godot --path game --resolution 390x844 -s res://tests/screenshot.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var game = root.get_node("Game")
	game.reset_game()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	_shot(out_dir + "/earn_fresh.png")
	var card = main.find_child("TowerCard", true, false)
	for i in 380:
		card._do_tap(Vector2(240, 100))
	for i in 6:
		game._record_history()
		game.cash += 40.0
	card._do_tap(Vector2(250, 120))
	card._do_tap(Vector2(230, 150))
	await create_timer(0.2).timeout
	_shot(out_dir + "/earn_playing.png")
	main.show_page(4)
	await create_timer(0.3).timeout
	_shot(out_dir + "/profile.png")
	main.show_page(1)
	await create_timer(0.5).timeout
	_shot(out_dir + "/business.png")
	main.show_page(0)
	await create_timer(0.5).timeout
	var kit = root.get_node("Kit")
	kit.toast("Level 2 · $4.10 per tap", true)
	await create_timer(0.6).timeout
	_shot(out_dir + "/toast.png")
	kit.sheet("Update ready", "Version 1.0.7 is out. Your progress stays exactly where it is.", [
		{"text": "Download update", "style": "primary"},
		{"text": "Later", "style": "plain"}])
	await create_timer(0.7).timeout
	_shot(out_dir + "/sheet.png")
	kit.close_top()
	await create_timer(0.4).timeout
	kit.alert("Start again?", "This wipes your cash, levels and everything else. It can't be undone.", [
		{"text": "Wipe and start again", "style": "secondary"},
		{"text": "Keep my progress", "style": "primary"}])
	await create_timer(0.5).timeout
	_shot(out_dir + "/alert.png")
	game.reset_game()
	quit()


func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
