extends Control
## Root: background, pages with transitions, the glass tab bar, back gesture
## handling and the update prompt.

var _content: Control
var _pages: Array = []
var _nav: NavBar
var _current := 0
var _back_armed := false
var _stack: Array = []
var _last_push_ms := -10000


func _ready() -> void:
	# Default font for everything, including overlays.
	var th := Theme.new()
	th.default_font = UI.REG
	get_tree().root.theme = th
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)

	var earn := EarnPage.new()
	_pages = [earn, BusinessPage.new(), InvestPage.new(), ItemsPage.new(), ProfilePage.new()]
	for p in _pages:
		_content.add_child(p)
		p.visible = false
		if p.has_signal("push_page"):
			p.push_page.connect(push)
	earn.open_tab.connect(show_page)
	Game.achievement.connect(func(title: String, reward: float):
		Kit.toast("%s · +%s" % [title, Game.money_short(reward)], true))
	Game.goal_done.connect(func(scope: String, text: String, reward: float):
		Kit.celebrate("Daily goal done" if scope == "daily" else "Weekly goal done", text, "+" + Game.money_short(reward)))
	Game.rival_beaten.connect(func(i: int):
		var r: Array = Data.RIVALS[i]
		Kit.haptic("success")
		Kit.toast("You passed %s · now #%d" % [r[0], Data.RIVALS.size() - i], true))
	Game.deal_ready.connect(func(_d): _show_deal())
	var dt := Timer.new()
	dt.wait_time = 1.0
	dt.autostart = true
	dt.timeout.connect(_show_deal)
	dt.timeout.connect(_update_badges)
	add_child(dt)
	Game.market_news.connect(func(item: Dictionary):
		# Only tell the player about news that touches what they own.
		var sym := String(item.get("sym", ""))
		var mine := Game.shares.has(sym) or Game.coins.has(sym)
		for k in Game.shares.keys():
			if Game.sector_of(k) == sym:
				mine = true
		if mine:
			Kit.toast("%s · %s" % [item["text"], AssetDetail.change_text(float(item["pct"]))], float(item["pct"]) >= 0.0))
	Game.expansion_done.connect(func(id: String, stage: int):
		Kit.haptic("success")
		Kit.toast("%s · stage %d" % [Game.biz[id]["name"], stage], true))

	_nav = NavBar.new()
	_nav.anchor_left = 0.0
	_nav.anchor_right = 1.0
	_nav.anchor_top = 1.0
	_nav.anchor_bottom = 1.0
	# Soft fade so list rows melt away behind the floating tab bar.
	var fade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(UI.BG, 0.0))
	grad.set_color(1, Color(UI.BG, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	fade.texture = gt
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	fade.offset_top = -120
	add_child(fade)
	add_child(_nav)
	_nav.tab_selected.connect(show_page)

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_pages[0].visible = true
	_nav.set_active(0)

	Updater.update_available.connect(_on_update)
	Updater.state_changed.connect(func(): _nav.set_badge(4, Updater.has_update()))
	if OS.has_feature("android"):
		get_tree().create_timer(3.0).timeout.connect(func(): Updater.check())


func push(p: Control) -> void:
	## Slides a detail page in from the right, over the current tab.
	## Repeated taps while a page is sliding in don't stack copies.
	var now_ms := Time.get_ticks_msec()
	var same: bool = not _stack.is_empty() and _stack.back().get_script() == p.get_script()
	if now_ms - _last_push_ms < 450 or (same and p.get_script() != AssetDetail):
		p.queue_free()
		return
	_last_push_ms = now_ms
	_content.add_child(p)
	GameLog.info("ui", "Open %s" % (p.title if "title" in p else p.name))
	p.push_page.connect(push)
	p.pop_page.connect(func(): _pop_from(p))
	var w := _content.size.x
	var under: Control = _stack.back() if not _stack.is_empty() else _pages[_current]
	_stack.append(p)
	p.position.x = w
	if p.has_method("entered"):
		p.entered.call_deferred()
	var t := p.create_tween().set_parallel(true)
	p.set_meta("push_tw", t)
	t.tween_property(p, "position:x", 0.0, Motion.d(0.4)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(under, "position:x", -w * 0.25, Motion.d(0.4)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(under, "modulate:a", 0.4, Motion.d(0.36))
	t.chain().tween_callback(func():
		# Only hide the page underneath if this page is still on top.
		if is_instance_valid(under) and not _stack.is_empty() and _stack.back() == p:
			under.visible = false)


func _pop_from(p: Control) -> void:
	## Only the page on top may close itself (stops double back taps skipping pages).
	if not _stack.is_empty() and _stack.back() == p:
		pop()


func pop() -> void:
	if _stack.is_empty():
		return
	var p: Control = _stack.pop_back()
	_stop_push(p)
	var under: Control = _stack.back() if not _stack.is_empty() else _pages[_current]
	var w := _content.size.x
	under.visible = true
	Kit.tick(5)
	var t := p.create_tween().set_parallel(true)
	t.tween_property(p, "position:x", w, Motion.d(0.26)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(under, "position:x", 0.0, Motion.d(0.3)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(under, "modulate:a", 1.0, Motion.d(0.26))
	t.chain().tween_callback(p.queue_free)


func _kill_tab_tween(page: Control) -> void:
	var t = page.get_meta("tab_tw", null)
	if t is Tween and t.is_valid():
		t.kill()


func _stop_push(p: Control) -> void:
	## Stops a page's slide-in if it is still running (fast back taps).
	var t = p.get_meta("push_tw", null)
	if t is Tween and t.is_valid():
		t.kill()


func _clear_stack() -> void:
	for p in _stack:
		_stop_push(p)
		p.queue_free()
	_stack.clear()
	var base: Control = _pages[_current]
	base.position.x = 0.0
	base.modulate.a = 1.0
	base.visible = true


func show_page(i: int) -> void:
	if not _stack.is_empty():
		_clear_stack()
		_pages[_current].visible = true
	if i == _current:
		# Re-tapping the current tab always leaves it fully shown,
		# and scrolls it back to the top (like iOS).
		var cur: Control = _pages[_current]
		_kill_tab_tween(cur)
		cur.visible = true
		cur.modulate.a = 1.0
		cur.position.x = 0.0
		var sc = cur.get("scroll")
		if sc is ScrollContainer and sc.scroll_vertical > 0:
			var t: Tween = sc.create_tween()
			t.tween_property(sc, "scroll_vertical", 0, Motion.d(0.35)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		return
	var old: Control = _pages[_current]
	var new: Control = _pages[i]
	GameLog.info("ui", "Tab %s" % NavBar.TABS[i][1])
	var dir := 1.0 if i > _current else -1.0
	_current = i
	_nav.set_active(i)
	Kit.tick(6)
	# Old page fades out quickly, new page fades in with a short slide.
	_kill_tab_tween(old)
	_kill_tab_tween(new)
	var to := old.create_tween()
	old.set_meta("tab_tw", to)
	to.tween_property(old, "modulate:a", 0.0, Motion.d(0.1))
	to.tween_callback(func():
		# Only hide it if the player hasn't already switched back to it.
		if _pages[_current] != old:
			old.visible = false
		old.modulate.a = 1.0
		old.position.x = 0.0)
	new.visible = true
	new.modulate.a = 0.0
	new.position.x = 0.0 if Motion.reduced() else 18.0 * dir
	var tn := new.create_tween().set_parallel(true)
	new.set_meta("tab_tw", tn)
	tn.tween_property(new, "modulate:a", 1.0, Motion.d(0.22)).set_delay(Motion.d(0.06))
	tn.tween_property(new, "position:x", 0.0, Motion.d(Motion.STANDARD)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(Motion.d(0.06))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_WM_CLOSE_REQUEST:
			Game.save_game()
			get_tree().quit()
		NOTIFICATION_APPLICATION_RESUMED:
			if OS.has_feature("android"):
				Updater.check()


func _on_back() -> void:
	if Kit.close_top():
		return
	if not _stack.is_empty():
		pop()
		return
	if _current != 0:
		show_page(0)
		return
	if _back_armed:
		Game.save_game()
		get_tree().quit()
		return
	_back_armed = true
	Kit.toast("Swipe back again to close")
	get_tree().create_timer(2.2).timeout.connect(func(): _back_armed = false)


func _on_update(version: String) -> void:
	_nav.set_badge(4, true)
	Kit.toast("Update ready · Profile", true)


func _apply_safe_area() -> void:
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("mobile"):
		var win := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if win.y > 0:
			var k := get_viewport_rect().size.y / float(win.y)
			top = clampf(safe.position.y * k, 0.0, 80.0)
			bottom = clampf((win.y - safe.end.y) * k, 0.0, 60.0)
	Kit.top_inset = top
	Kit.bottom_inset = bottom
	_content.offset_top = top
	_content.offset_bottom = -bottom
	_nav.offset_left = 16
	_nav.offset_right = -16
	_nav.offset_bottom = -(12 + bottom)
	_nav.offset_top = _nav.offset_bottom - 64


var _deal_open := false


func _show_deal() -> void:
	## Shows the waiting deal when nothing else is open. One line, two choices.
	## Also shows the welcome-back card after time away.
	if Game.away_unseen and not Kit.has_open():
		Game.away_unseen = false
		var lines: Array = ["Away %s" % Game.clock(Game.away_seconds)] + Game.away_notes
		Kit.sheet("Welcome back", "\n".join(lines), [
			{"text": "Collect " + Game.money_short(Game.away_earned), "style": "primary"},
		])
		return
	if not Game.streak_unseen.is_empty() and not Kit.has_open() and not Kit._cele_open:
		var st: Array = Game.streak_unseen
		Game.streak_unseen = []
		Kit.celebrate("Daily gift" if st[0] <= 1 else "Day %d in a row" % st[0], "Come back tomorrow for a bigger gift" if st[0] < 7 else "Top streak gift", "+" + Game.money_short(st[1]))
		return
	if Game.deal.is_empty() or _deal_open or Kit.has_open():
		return
	if not _stack.is_empty() or Game.now() - Game.last_tap_at < 4.0 or Kit._cele_open:
		return  # wait until the player is on a main tab and not tapping
	_deal_open = true
	var d: Dictionary = Game.deal
	var sh := Kit.sheet(d["title"], d["text"], [
		{"text": d["yes"], "style": "primary", "call": func():
			_deal_open = false
			if Game.accept_deal():
				Kit.toast("Deal done", true)
			else:
				Kit.toast("That deal isn't possible any more")},
		{"text": "No thanks", "style": "plain", "call": func():
			_deal_open = false
			Game.decline_deal()},
	])
	# Swiping the sheet away counts as "No thanks".
	sh.tree_exited.connect(func():
		_deal_open = false
		if Game.deal == d:
			Game.decline_deal())


func _update_badges() -> void:
	var b: Array = Game.tab_badges()
	for i in range(b.size()):
		_nav.set_badge(i, b[i] and i != _current)
	_nav.set_badge(4, Updater.has_update())
