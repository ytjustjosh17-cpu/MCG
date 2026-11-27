extends SceneTree
## Bank and company-upgrade screens, through the UI, upright and sideways:
## the next-upgrade card buys a step; a fixed term opens from its sheet, one
## breaks early, and an ended one is collected from "To claim".
##   godot --headless --path game -s res://tests/bank_ui_test.gd

var fails := 0
var main
var g
var kit


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func():
		print("FAIL  timed out")
		print("Failures: ", fails + 1)
		quit(1))
	_run.call_deferred()


func _ok(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c:
		fails += 1


func _button(root_c: Node, prefix: String) -> Button:
	for n in root_c.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


func _on_screen(c: Control, land: bool) -> bool:
	var r := c.get_global_rect()
	var v := root.get_visible_rect()
	return r.position.x >= (84.0 if land else 0.0) - 1.0 and r.end.x <= v.size.x + 1.0


func _run() -> void:
	g = root.get_node("Game")
	kit = root.get_node("Kit")
	root.size = Vector2i(390, 844)
	g.reset_game(true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	g.ui["guide_done"] = true
	g.reduce_motion = true
	g.cash = 1.0e9
	g.open_business("shop", "Test Shop")
	g.biz["shop"]["stage"] = 4
	g.biz["shop"]["units"] = 20
	g.recalc()
	while kit.close_top():
		await create_timer(0.3).timeout

	for land in [false, true]:
		root.size = Vector2i(844, 390) if land else Vector2i(390, 844)
		await create_timer(0.5).timeout
		var tag := "landscape" if land else "portrait"
		# ---- company upgrade path ----
		var bd = load("res://scripts/business_detail.gd").new("shop")
		main.push(bd)
		await create_timer(0.8).timeout
		var lvl0: int = g.biz_up_level("shop")
		_ok(bd._up_title.text == "Upgrade %d of 5" % (lvl0 + 1) and bd._up_name.text != "", "%s: next-upgrade card names the step (%s)" % [tag, bd._up_name.text])
		_ok(bd._up_change.text.contains("→") or bd._up_change.text.contains("->"), "%s: card shows before -> after income" % tag)
		bd.scroll.ensure_control_visible(bd._up_btn)
		await create_timer(0.3).timeout
		_ok(_on_screen(bd._up_btn, land), "%s: upgrade button fits the screen" % tag)
		bd._up_btn.pressed.emit()
		await create_timer(0.3).timeout
		_ok(g.biz_up_level("shop") == lvl0 + 1, "%s: tapping Upgrade buys the step" % tag)
		main.pop()
		await create_timer(0.6).timeout
		# ---- fixed terms ----
		var bp = load("res://scripts/bank_page.gd").new()
		main.push(bp)
		await create_timer(0.8).timeout
		var n0: int = g.terms().size()
		bp._open_term_sheet(7, 0.20)
		await create_timer(0.5).timeout
		var sheet: Node = kit._stack.back()["root"]
		var go := _button(sheet, "Lock")
		_ok(go != null and _on_screen(go, false), "%s: term sheet shows its Lock button" % tag)
		var half := _button(sheet, "50%")
		if half != null:
			half.pressed.emit()
		var cash0: float = g.cash
		if go != null:
			go.pressed.emit()
		await create_timer(0.5).timeout
		_ok(g.terms().size() == n0 + 1 and g.cash < cash0, "%s: Lock opens a term and takes the cash" % tag)
		_ok(bp._run_card.visible, "%s: running terms are listed" % tag)
		# A second one, then break it from its row's confirm.
		bp._open_term_sheet(1, 0.025)
		await create_timer(0.5).timeout
		var go2 := _button(kit._stack.back()["root"], "Lock")
		if go2 != null:
			go2.pressed.emit()
		await create_timer(0.5).timeout
		var before_break: float = g.cash
		var n1: int = g.terms().size()
		bp._on_break(n1 - 1)
		await create_timer(0.5).timeout
		var brk := _button(kit._stack.back()["root"], "Break early")
		_ok(brk != null, "%s: breaking early asks first" % tag)
		if brk != null:
			brk.pressed.emit()
		await create_timer(0.5).timeout
		_ok(g.terms().size() == n1 - 1 and g.cash > before_break, "%s: Break early returns cash" % tag)
		while kit.close_top():
			await create_timer(0.3).timeout
		main.pop()
		await create_timer(0.6).timeout

	# ---- an ended term is collected from "To claim" on the Bank page ----
	root.size = Vector2i(390, 844)
	await create_timer(0.4).timeout
	g.sim_time = g.now() + 8.0 * 86400.0
	g._tick_terms()
	g.recalc()
	var bp2 = load("res://scripts/bank_page.gd").new()
	main.push(bp2)
	await create_timer(0.8).timeout
	var waiting := 0
	for r in g.rewards:
		if String(r.get("kind", "")) == "term":
			waiting += 1
	_ok(waiting >= 2 and g.terms().is_empty(), "ended terms wait to be claimed (%d)" % waiting)
	var cl: Node = bp2.body.find_children("*", "ClaimList", true, false)[0] if not bp2.body.find_children("*", "ClaimList", true, false).is_empty() else null
	_ok(cl != null and cl.visible, "the Bank page shows them under To claim")
	var c0: float = g.cash
	g.claim_all("term")
	await create_timer(0.5).timeout
	_ok(g.cash > c0, "collecting an ended term pays out")
	g.sim_time = -1.0
	main.pop()
	await create_timer(0.4).timeout
	print("Failures: ", fails)
	quit(1 if fails > 0 else 0)
