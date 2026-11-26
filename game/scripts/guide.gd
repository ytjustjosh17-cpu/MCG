class_name Guide
extends Control
## A short first-time guide: five steps, one short line each, a ring around
## the thing to tap, and Skip always there. It never blocks taps: the ring
## and card let touches through (only Skip takes them). Each step moves on
## when the player does the thing. Progress lives in Game.ui.

const STEPS := [
	# key, text, target
	["tap", "Tap the tower to earn", "tower"],
	["level", "Level up: bigger taps", "level"],
	["company", "Open your first company", "tab1"],
	["invest", "Invest: shares, property, crypto", "tab2"],
	["profile", "Profile: stats, and rebirth later", "tab4"],
]

var main: Control
var _step := 0
var _card: PanelContainer
var _text: Label
var _count: Label
var _t := 0.0
var _ring := Rect2()


static func maybe_start(m: Control) -> void:
	## Starts the guide for a brand-new player (or a replay from Settings).
	if bool(Game.ui.get("guide_done", false)):
		return
	if not bool(Game.ui.get("guide_replay", false)) and (Game.taps > 0 or not Game.biz.is_empty()):
		Game.ui["guide_done"] = true   # an old save: no guide
		return
	for c in m.get_children():
		if c is Guide:
			return
	var g := Guide.new()
	g.main = m
	m.add_child(g)


static func replay() -> void:
	## Settings > Replay guide: shows again from the first step.
	Game.ui["guide_done"] = false
	Game.ui["guide_step"] = 0
	Game.ui["guide_replay"] = true
	Game.save_game()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	_step = clampi(int(Game.ui.get("guide_step", 0)), 0, STEPS.size() - 1)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 18, 16, 10))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_count = UI.label("", 13, UI.SUB)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_count)
	_text = UI.label("", 17, UI.TEXT, true)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	var skip := UI.pill("Skip", UI.PANEL, UI.TEXT, 15, 16)
	skip.custom_minimum_size = Vector2(72, 48)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func():
		Kit.tick()
		finish())
	h.add_child(skip)
	_show_step()


func _show_step() -> void:
	_count.text = "Guide · %d of %d" % [_step + 1, STEPS.size()]
	_text.text = String(STEPS[_step][1])
	Game.ui["guide_step"] = _step
	if not Motion.reduced():
		_card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_card, "modulate:a", 1.0, Motion.d(0.25))


func _done(key: String) -> bool:
	match key:
		"tap": return Game.taps >= 5
		"level": return Game.level >= 2
		"company": return not Game.biz.is_empty()
		"invest": return main != null and main._current == 2
		"profile": return main != null and main._current == 4
	return true


func _target_rect(t: String) -> Rect2:
	## The thing to tap, in this control's coordinates (empty if not on screen).
	if main == null:
		return Rect2()
	var c: Control = null
	match t:
		"tower":
			var e = main._pages[0]
			if main._current == 0 and e.get("_card") != null:
				var r: Rect2 = (e._card as Control).get_global_rect()
				# A ring round the middle of the tower, not the whole card.
				return Rect2(r.get_center() - Vector2(70, 90) - global_position, Vector2(140, 180))
		"level":
			var e2 = main._pages[0]
			if main._current == 0 and e2.get("_level_btn") != null:
				c = e2._level_btn
		"tab1", "tab2", "tab4":
			var i := int(t.substr(3))
			if main._nav != null and i < main._nav._buttons.size():
				c = main._nav._buttons[i]
	if c == null or not c.is_visible_in_tree():
		return Rect2()
	var g := c.get_global_rect()
	return Rect2(g.position - global_position, g.size)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _done(String(STEPS[_step][0])):
		if _step >= STEPS.size() - 1:
			finish()
			return
		_step += 1
		Kit.haptic("selection")
		_show_step()
	# Stay out of the way of open pop-ups and pushed pages.
	var busy: bool = Kit.has_open() or (main != null and not main._stack.is_empty())
	_card.visible = not busy
	_ring = Rect2() if busy else _target_rect(String(STEPS[_step][2]))
	# The card sits at the top, under the cash, or above the ring if that's high.
	var w := size.x - 32.0
	_card.size = Vector2(w, 0)
	_card.size = Vector2(w, _card.get_combined_minimum_size().y)
	var y := 152.0   # under the cash and income lines
	if _ring.size != Vector2.ZERO and _ring.position.y < y + _card.size.y + 20.0:
		y = _ring.end.y + 16.0
	_card.position = Vector2(16, y)
	queue_redraw()


func _draw() -> void:
	if _ring.size == Vector2.ZERO:
		return
	var pulse := 0.0 if Motion.reduced() else 0.5 + 0.5 * sin(_t * 4.0)
	var c := _ring.get_center()
	var r := maxf(_ring.size.x, _ring.size.y) * 0.5 + 6.0 + pulse * 4.0
	draw_arc(c, r, 0.0, TAU, 64, Color(UI.RED, 0.9), 3.0, true)
	draw_arc(c, r + 8.0, 0.0, TAU, 64, Color(UI.RED, 0.25 + 0.2 * pulse), 2.0, true)


func finish() -> void:
	Game.ui["guide_done"] = true
	Game.ui["guide_replay"] = false
	Game.save_game()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, Motion.d(0.2))
	tw.tween_callback(queue_free)
