extends Control
## Root: background, pages with transitions, the glass tab bar, back gesture
## handling and the update prompt.

var _content: Control
var _pages: Array = []
var _nav: NavBar
var _current := 0
var _back_armed := false
var _stack: Array = []


func _ready() -> void:
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
	Game.expansion_done.connect(func(id: String, stage: int):
		Kit.haptic("success")
		Kit.toast("%s · stage %d" % [Game.biz[id]["name"], stage], true))

	_nav = NavBar.new()
	_nav.anchor_left = 0.0
	_nav.anchor_right = 1.0
	_nav.anchor_top = 1.0
	_nav.anchor_bottom = 1.0
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
	_content.add_child(p)
	GameLog.info("ui", "Open %s" % (p.title if "title" in p else p.name))
	p.push_page.connect(push)
	p.pop_page.connect(pop)
	var w := _content.size.x
	var under: Control = _stack.back() if not _stack.is_empty() else _pages[_current]
	_stack.append(p)
	p.position.x = w
	if p.has_method("entered"):
		p.entered.call_deferred()
	var t := p.create_tween().set_parallel(true)
	t.tween_property(p, "position:x", 0.0, Motion.d(0.4)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(under, "position:x", -w * 0.25, Motion.d(0.4)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(under, "modulate:a", 0.4, 0.36)
	t.chain().tween_callback(func():
		if is_instance_valid(under):
			under.visible = false)


func pop() -> void:
	if _stack.is_empty():
		return
	var p: Control = _stack.pop_back()
	var under: Control = _stack.back() if not _stack.is_empty() else _pages[_current]
	var w := _content.size.x
	under.visible = true
	Kit.tick(5)
	var t := p.create_tween().set_parallel(true)
	t.tween_property(p, "position:x", w, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(under, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.tween_property(under, "modulate:a", 1.0, 0.26)
	t.chain().tween_callback(p.queue_free)


func _clear_stack() -> void:
	for p in _stack:
		p.queue_free()
	_stack.clear()
	var base: Control = _pages[_current]
	base.position.x = 0.0
	base.modulate.a = 1.0


func show_page(i: int) -> void:
	if not _stack.is_empty():
		_clear_stack()
		_pages[_current].visible = true
	if i == _current:
		return
	var old: Control = _pages[_current]
	var new: Control = _pages[i]
	GameLog.info("ui", "Tab %s" % NavBar.TABS[i][1])
	var dir := 1.0 if i > _current else -1.0
	_current = i
	_nav.set_active(i)
	Kit.tick(6)
	# Old page fades out quickly, new page fades in with a short slide.
	var to := old.create_tween()
	to.tween_property(old, "modulate:a", 0.0, 0.1)
	to.tween_callback(func():
		old.visible = false
		old.modulate.a = 1.0
		old.position.x = 0.0)
	new.visible = true
	new.modulate.a = 0.0
	new.position.x = 18.0 * dir
	var tn := new.create_tween().set_parallel(true)
	tn.tween_property(new, "modulate:a", 1.0, Motion.d(0.22)).set_delay(0.06)
	tn.tween_property(new, "position:x", 0.0, Motion.d(Motion.STANDARD)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(0.06)


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
