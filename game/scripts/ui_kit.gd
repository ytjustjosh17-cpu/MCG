extends CanvasLayer
## Custom sheets, alerts and toasts drawn in the game's own style.
## Nothing here uses Godot's or Android's default pop-ups.

const DIM := Color(0.0, 0.03, 0.03, 0.62)
const SHEET_TINT := Color(0.035, 0.133, 0.145, 0.9)
const ALERT_TINT := Color(0.035, 0.133, 0.145, 0.94)

var top_inset := 0.0
var bottom_inset := 0.0
var left_inset := 0.0
var right_inset := 0.0

# ---- orientation (1.2) -----------------------------------------------------
# Portrait is designed at 390 x 844 game units, landscape at 844 x 390, so text
# keeps the same size on the phone either way. A square window counts as
# portrait. main.gd lays the frame out again on `layout_changed`.
signal layout_changed(landscape: bool)
const PORTRAIT_SIZE := Vector2i(390, 844)
const LANDSCAPE_SIZE := Vector2i(844, 390)
const RAIL_W := 72.0         # the tab rail on the left in landscape
const COLUMN_MAX := 600.0    # page content never gets wider than this
var landscape := false
var _orient_busy := false
var _stack: Array = []  # [{"root": Control, "close": Callable}]
var _toast: Control
var _toast_q: Array = []     # waiting toasts: each gets its full time on screen
# Drag-versus-tap handling, so lists scroll even when the finger starts on a button.
const DRAG_PX := 14.0
var dragged := false
var _pressing := false
var _press_pos := Vector2.ZERO
var _down_btn: BaseButton
var _cancelled: Array = []


var sfx: Sfx


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = Sfx.new()
	add_child(sfx)
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_sync_orientation)
	_sync_orientation()
	layout_changed.connect(func(_l: bool): _refit_sheets.call_deferred())
	apply_rotation_setting()


func _sync_orientation() -> void:
	## Pick the design size that matches how the phone is held. The root's
	## content scale then keeps one game unit the same size on screen.
	if _orient_busy:
		return
	var root := get_tree().root
	var win := Vector2(root.size)
	var land := win.x > win.y * 1.05
	var want := LANDSCAPE_SIZE if land else PORTRAIT_SIZE
	_orient_busy = true
	if root.content_scale_size != want:
		root.content_scale_size = want
	_orient_busy = false
	if land != landscape:
		landscape = land
		layout_changed.emit(landscape)


func apply_rotation_setting() -> void:
	## Settings > Auto-rotate (on by default). Off keeps the game in portrait.
	if not OS.has_feature("mobile"):
		return
	var on := true
	if has_node("/root/Game"):
		on = bool(get_node("/root/Game").ui.get("rotate", true))
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR if on else DisplayServer.SCREEN_PORTRAIT)


func column_width() -> float:
	## Width of the page column: the full screen in portrait, capped in landscape.
	var w := screen().x
	if landscape:
		w = minf(COLUMN_MAX, w - RAIL_W - 32.0 - left_inset - right_inset)
	return w


func sheet_width(wide := false) -> float:
	## Pop-up card width. In landscape cards stay narrow (420) unless their
	## content asks for room (an `extra` with meta "wide_sheet", e.g. TradeSheet).
	if not landscape:
		return screen().x - SHEET_MARGIN * 2.0
	return minf(screen().x - SHEET_MARGIN * 2.0, 720.0 if wide else 420.0)


func _on_node_added(n: Node) -> void:
	## Every button lets drags through to the scroll view behind it.
	if n is BaseButton and not n.has_meta("kit_hooked"):
		var b := n as BaseButton
		b.set_meta("kit_hooked", true)   # rows re-added to a list would stack hooks
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.button_down.connect(func(): _down_btn = b)
		if not b.has_theme_stylebox_override("disabled") and b.has_theme_stylebox_override("normal"):
			b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = true
			dragged = false
			_press_pos = e.position
			_down_btn = null
		else:
			_pressing = false
			if not _cancelled.is_empty():
				_restore.call_deferred()
	elif e is InputEventMouseMotion and _pressing and not dragged:
		if e.position.distance_to(_press_pos) > DRAG_PX:
			dragged = true
			_cancel_press()


func _cancel_press() -> void:
	## The finger is scrolling: cancel the button it started on so it doesn't fire.
	if _down_btn == null or not is_instance_valid(_down_btn) or _down_btn.disabled:
		return
	var b := _down_btn
	_cancelled.append(b)
	b.disabled = true
	b.create_tween().tween_property(b, "scale", Vector2.ONE, Motion.d(0.15))


func _restore() -> void:
	for b in _cancelled:
		if is_instance_valid(b):
			b.disabled = false
	_cancelled.clear()


func screen() -> Vector2:
	return get_viewport().get_visible_rect().size


func has_open() -> bool:
	return not _stack.is_empty()


func close_top() -> bool:
	if _stack.is_empty():
		return false
	(_stack.back()["close"] as Callable).call()
	return true


func tick(ms := 8) -> void:
	## Light tap feedback; stronger values map to stronger haptics.
	haptic("selection" if ms <= 8 else ("light" if ms <= 15 else "medium"))
	sound("tap")


func sound(name: String) -> void:
	## Short sound effect (see sfx.gd); does nothing when sound is off.
	if sfx != null:
		sfx.play(name)


func haptic(kind: String) -> void:
	## Small haptic vocabulary, in the spirit of Apple's feedback generators.
	if kind == "success":
		sound("buy")
	elif kind == "error":
		sound("error")
	if not Game.vibrate:
		return
	match kind:
		"selection":
			Input.vibrate_handheld(6, 0.35)
		"light":
			Input.vibrate_handheld(10, 0.5)
		"medium":
			Input.vibrate_handheld(18, 0.75)
		"success":
			Input.vibrate_handheld(12, 0.6)
			get_tree().create_timer(0.09).timeout.connect(func(): Input.vibrate_handheld(22, 0.9))
		"error":
			Input.vibrate_handheld(24, 0.8)
			get_tree().create_timer(0.08).timeout.connect(func(): Input.vibrate_handheld(24, 0.8))


# ---- press feedback ---------------------------------------------------------

func press_fx(c: Control) -> void:
	## Apple-style squish on press for any button.
	if not c is BaseButton:
		return
	var b := c as BaseButton
	var fit := func(): b.pivot_offset = b.size / 2.0
	b.resized.connect(fit)
	fit.call()
	b.button_down.connect(func():
		if Game.reduce_motion:
			return
		var t := Motion.tween(b, "press")
		t.tween_property(b, "scale", Vector2(0.97, Motion.d(0.97)), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	b.button_up.connect(func():
		var t := Motion.tween(b, "press")
		t.tween_property(b, "scale", Vector2.ONE, Motion.d(0.2)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT))


# ---- buttons used inside overlays ------------------------------------------

func _action_button(a: Dictionary, height := 52) -> Button:
	var style: String = a.get("style", "primary")
	var b: Button
	match style:
		"primary":
			b = UI.pill(a["text"], UI.TEXT, UI.INK, 17, height / 2)
		"plain":
			b = UI.pill(a["text"], Color(0, 0, 0, 0), UI.SUB, 17, height / 2)
		_:
			b = UI.pill(a["text"], UI.RAISED, UI.TEXT, 17, height / 2)
	b.custom_minimum_size = Vector2(0, height)
	b.disabled = a.get("disabled", false)
	press_fx(b)
	return b


# ---- bottom sheet -----------------------------------------------------------

const SHEET_MARGIN := 14.0   # pop-up cards float with this gap at the sides


func sheet(title: String, body: String, actions: Array, dismissable := true, extra: Control = null) -> Control:
	## actions: [{"text": String, "style": "primary"|"secondary"|"plain", "call": Callable}]
	# A fast double tap mustn't stack two copies of the same sheet.
	for it in _stack:
		if is_instance_valid(it["root"]) and String(it.get("title", "")) == title and title != "":
			return it["root"]
	var scr := screen()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(DIM, 0.0)
	root.add_child(dim)

	# A card that floats in the middle of the screen (owner's choice).
	var pad := 20.0
	var wide := extra != null and extra.has_meta("wide_sheet")
	var w := sheet_width(wide)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.position = Vector2(pad, 22)
	col.size = Vector2(w - pad * 2, 0)
	if title != "":
		var t := UI.label(title, 22, UI.TEXT, true)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = w - pad * 2
		col.add_child(t)
	if body != "":
		var bl := UI.label(body, 17, UI.SUB)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size.x = w - pad * 2
		col.add_child(bl)
	if extra != null:
		col.add_child(extra)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)
	var closing := [false]
	var panel := GlassPanel.new(28.0, SHEET_TINT, 10.0)
	panel.set_meta("wide_sheet", wide)
	var close := func(after: Callable = Callable()):
		if closing[0]:
			return
		closing[0] = true
		for i in range(_stack.size()):
			if _stack[i]["root"] == root:
				_stack.remove_at(i)
				break
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(panel, "position:y", panel.position.y + 16.0, Motion.d(0.18)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(panel, "modulate:a", 0.0, 0.18)
		tw.tween_property(dim, "color:a", 0.0, 0.22)
		tw.chain().tween_callback(func():
			root.queue_free()
			if after.is_valid():
				after.call())
	for a in actions:
		var b := _action_button(a)
		b.custom_minimum_size.x = w - pad * 2
		var cb: Callable = a.get("call", Callable())
		var keep_open: bool = a.get("keep_open", false)
		b.pressed.connect(func():
			tick()
			if keep_open:
				if cb.is_valid():
					cb.call()
			elif not closing[0]:
				# Do the action now (so leaving the page can't lose it), then slide away.
				close.call()
				if cb.is_valid():
					cb.call())
		col.add_child(b)
	panel.size = Vector2(w, 10)
	panel.position = Vector2((scr.x - w) * 0.5, scr.y * 0.4)
	panel.modulate.a = 0.0
	root.add_child(panel)
	panel.add_child(col)
	var geo := {"rest": scr.y}
	_present_sheet(root, panel, col, dim, geo)

	var opened_ms := Time.get_ticks_msec()
	if dismissable:
		dim.gui_input.connect(func(e: InputEvent):
			# A double tap on whatever opened the sheet mustn't close it at once.
			if e is InputEventMouseButton and e.pressed and Time.get_ticks_msec() - opened_ms > 400:
				close.call())
		# Apple-style drag: follows the finger down, resists going up (rubber
		# band), and a quick flick down closes it even if it moved only a little.
		var drag := {"on": false, "y0": 0.0, "last_y": 0.0, "last_t": 0, "vel": 0.0}
		panel.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					drag["on"] = true
					drag["y0"] = e.global_position.y
					drag["last_y"] = e.global_position.y
					drag["last_t"] = Time.get_ticks_msec()
					drag["vel"] = 0.0
				elif drag["on"]:
					drag["on"] = false
					var moved: float = panel.position.y - float(geo["rest"])
					if moved > 90.0 or (float(drag["vel"]) > 900.0 and moved > 12.0):
						close.call()
					else:
						var back := root.create_tween()
						back.tween_property(panel, "position:y", geo["rest"], Motion.d(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			elif e is InputEventMouseMotion and drag["on"]:
				var t_ms := Time.get_ticks_msec()
				var dt := maxf(1.0, float(t_ms - int(drag["last_t"]))) / 1000.0
				drag["vel"] = lerpf(float(drag["vel"]), (e.global_position.y - float(drag["last_y"])) / dt, 0.5)
				drag["last_y"] = e.global_position.y
				drag["last_t"] = t_ms
				var dy: float = e.global_position.y - float(drag["y0"])
				# Downwards follows the finger; upwards moves a little and pushes back.
				panel.position.y = float(geo["rest"]) + (dy if dy >= 0.0 else -sqrt(-dy) * 2.5))
	_stack.append({"root": root, "title": title, "close": func(): close.call() if dismissable else null,
		"panel": panel, "col": col, "geo": geo})
	return root


func _present_sheet(root: Control, panel: Control, col: Control, dim: ColorRect, geo: Dictionary) -> void:
	await get_tree().process_frame
	if not is_instance_valid(root):
		return
	var scr := screen()
	var inner := col.get_combined_minimum_size().y
	col.size = Vector2(col.size.x, inner)
	var h := inner + 22.0 + 20.0
	# Taller than the screen (landscape is only 390 high): the card's content
	# scrolls inside it instead of running off the bottom.
	var avail := scr.y - top_inset - bottom_inset - 24.0
	if h > avail and col.get_parent() == panel:
		var sc := ScrollContainer.new()
		sc.scroll_deadzone = 10
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		sc.position = col.position
		sc.size = Vector2(col.size.x, avail - 42.0)
		panel.remove_child(col)
		col.position = Vector2.ZERO
		sc.add_child(col)
		panel.add_child(sc)
		h = avail
	var sw := sheet_width(bool(panel.get_meta("wide_sheet", false)))
	panel.size = Vector2(sw, h)
	panel.position.x = (scr.x - sw) * 0.5
	# Centred; a tall card starts under the status bar and stays on screen.
	geo["rest"] = maxf(top_inset + 12.0, (scr.y - h) * 0.5)
	panel.position.y = float(geo["rest"]) + 24.0
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(panel, "position:y", geo["rest"], Motion.d(0.32)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, Motion.d(0.2))
	tw.tween_property(dim, "color:a", DIM.a, Motion.d(0.25))


func _refit_sheets() -> void:
	## The phone turned with a pop-up open: resize and re-centre each card for
	## the new screen (its content, typed amounts and scroll stay as they are).
	await get_tree().process_frame
	var scr := screen()
	for it in _stack:
		if not it.has("panel") or not is_instance_valid(it["panel"]):
			continue
		var panel: Control = it["panel"]
		var col: Control = it["col"]
		var geo: Dictionary = it["geo"]
		var pad := 20.0
		var old_inner := panel.size.x - pad * 2.0
		var sw := sheet_width(bool(panel.get_meta("wide_sheet", false)))
		var new_inner := sw - pad * 2.0
		for ch in col.get_children():
			if ch is Control and absf((ch as Control).custom_minimum_size.x - old_inner) < 1.0:
				(ch as Control).custom_minimum_size.x = new_inner
		col.size.x = new_inner
		var inner := col.get_combined_minimum_size().y
		var avail := scr.y - top_inset - bottom_inset - 24.0
		var h := inner + 42.0
		if col.get_parent() is ScrollContainer:
			var sc := col.get_parent() as ScrollContainer
			h = minf(h, avail)
			sc.size = Vector2(new_inner, h - 42.0)
		elif h > avail:
			var sc2 := ScrollContainer.new()
			sc2.scroll_deadzone = 10
			sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc2.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
			sc2.position = col.position
			sc2.size = Vector2(new_inner, avail - 42.0)
			panel.remove_child(col)
			col.position = Vector2.ZERO
			sc2.add_child(col)
			panel.add_child(sc2)
			h = avail
		panel.size = Vector2(sw, h)
		panel.position.x = (scr.x - sw) * 0.5
		geo["rest"] = maxf(top_inset + 12.0, (scr.y - h) * 0.5)
		panel.position.y = float(geo["rest"])


# ---- money flies to your cash (1.2) -------------------------------------------
# A claimed amount leaves where you tapped and lands on the cash readout (the
# pill, or the big number on Earn), which then counts up. Never blocks taps.
var cash_target: Callable   # set by main.gd: returns the global centre of the cash readout


func fly_money(from: Vector2, amount: float) -> void:
	if amount <= 0.0 or not cash_target.is_valid():
		return
	var to: Vector2 = cash_target.call()
	if Motion.reduced():
		return
	var chip := Label.new()
	chip.text = "+" + Game.money_short(amount)
	chip.add_theme_font_override("font", UI.SEMI)
	chip.add_theme_font_size_override("font_size", 15)
	chip.add_theme_color_override("font_color", UI.INK)
	chip.add_theme_stylebox_override("normal", UI.box(UI.TEXT, 14, 12, 4))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	chip.position = from - Vector2(30, 14)
	var mid := (from + to) * 0.5 + Vector2(0, -60)
	var t := chip.create_tween()
	t.tween_method(func(k: float):
		var p := from.lerp(mid, k).lerp(mid.lerp(to, k), k)   # a soft arc
		chip.position = p - chip.size * 0.5
		chip.scale = Vector2.ONE * (1.0 - 0.35 * k), 0.0, 1.0, Motion.d(0.55)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		chip.queue_free()
		haptic("light"))


# ---- centred alert ----------------------------------------------------------

func alert(title: String, body: String, actions: Array) -> Control:
	var scr := screen()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(DIM, 0.0)
	root.add_child(dim)
	var w := minf(310.0, scr.x - 48.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.position = Vector2(20, 22)
	var t := UI.label(title, 17, UI.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = w - 40
	col.add_child(t)
	if body != "":
		var b := UI.label(body, 13, UI.SUB)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = w - 40
		col.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	col.add_child(gap)
	var card := GlassPanel.new(22.0, ALERT_TINT, 10.0)
	var closing := [false]
	var close := func(after: Callable = Callable()):
		if closing[0]:
			return
		closing[0] = true
		for i in range(_stack.size()):
			if _stack[i]["root"] == root:
				_stack.remove_at(i)
				break
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(card, "modulate:a", 0.0, 0.16)
		tw.tween_property(dim, "color:a", 0.0, 0.18)
		tw.chain().tween_callback(func():
			root.queue_free()
			if after.is_valid():
				after.call())
	for a in actions:
		var btn := _action_button(a, 44)
		btn.custom_minimum_size.x = w - 40
		var cb: Callable = a.get("call", Callable())
		btn.pressed.connect(func():
			tick()
			close.call(cb))
		col.add_child(btn)
	card.size = Vector2(w, 100)
	card.modulate.a = 0.0
	root.add_child(card)
	card.add_child(col)
	_present_alert(root, card, col, dim)
	_stack.append({"root": root, "close": func(): close.call()})
	return root


func _present_alert(root: Control, card: Control, col: Control, dim: ColorRect) -> void:
	await get_tree().process_frame
	if not is_instance_valid(root):
		return
	var scr := screen()
	var inner := col.get_combined_minimum_size().y
	col.size = Vector2(card.size.x - 40.0, inner)
	card.size = Vector2(card.size.x, inner + 22.0 + 20.0)
	card.position = (scr - card.size) / 2.0
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(1.08, 1.08)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2.ONE, Motion.d(0.24)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.tween_property(dim, "color:a", DIM.a, 0.2)


# ---- toast ------------------------------------------------------------------

func toast(text: String, red_mark := false) -> void:
	## Toasts queue: a new one never cuts the last one short.
	if _toast != null and is_instance_valid(_toast):
		if String(_toast.get_meta("text", "")) == text:
			return   # the same message is already showing
		for q in _toast_q:
			if String(q[0]) == text:
				return
		_toast_q.append([text, red_mark])
		if _toast_q.size() > 3:
			_toast_q.pop_front()   # keep the newest few
		return
	var pill := GlassPanel.new(22.0, Color(0.035, 0.133, 0.145, 0.88), 10.0)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.modulate.a = 0.0
	pill.position = Vector2(-1000, -1000)
	add_child(pill)
	var l := UI.label(text, 15, UI.TEXT, true)
	l.position = Vector2(32.0 if red_mark else 20.0, 12)
	pill.add_child(l)
	if red_mark:
		var m := ColorRect.new()
		m.color = UI.RED
		m.size = Vector2(8, 8)
		m.position = Vector2(18, 18)
		pill.add_child(m)
	_toast = pill
	pill.set_meta("text", text)
	_present_toast(pill, l, red_mark)


func _present_toast(pill: Control, l: Label, red_mark: bool) -> void:
	await get_tree().process_frame
	if not is_instance_valid(pill):
		return
	var scr := screen()
	var w := l.get_minimum_size().x + (52.0 if red_mark else 40.0)
	pill.size = Vector2(w, 44)
	var y := top_inset + 62.0   # under the cash pill, never on top of it
	pill.position = Vector2((scr.x - w) / 2.0, y - 60.0)
	var tw := pill.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pill, "position:y", y, Motion.d(0.4)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(pill, "modulate:a", 1.0, 0.2)
	# Long enough to read: at least 2.6 s, longer for longer messages.
	tw.chain().tween_interval(clampf(1.4 + 0.045 * float(l.text.length()), 2.6, 4.5))
	tw.chain().set_parallel(true)
	tw.tween_property(pill, "position:y", y - 40.0, Motion.d(0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pill, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		pill.queue_free()
		_toast = null
		if not _toast_q.is_empty():
			var nx: Array = _toast_q.pop_front()
			toast(String(nx[0]), bool(nx[1])))


# ---- celebration ------------------------------------------------------------

var _cele_queue: Array = []
var _cele_open := false


func celebrate(title: String, line: String, amount: String) -> void:
	## Centred card with confetti, for finished goals. Queues if one is showing.
	_cele_queue.append([title, line, amount])
	sound("fanfare")
	if not _cele_open:
		_next_celebration()


func _next_celebration() -> void:
	if _cele_queue.is_empty():
		_cele_open = false
		return
	_cele_open = true
	var item: Array = _cele_queue.pop_front()
	var scr := screen()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(DIM, 0.0)
	root.add_child(dim)
	var w := minf(300.0, scr.x - 56.0)
	# A solid panel: the glass shader bends the sides of a card this shape.
	var card := UI.panel(Color(UI.PANEL, 0.97), 26)
	card.size = Vector2(w, 210)
	card.position = Vector2((scr.x - w) * 0.5, scr.y * 0.36 - 105.0)
	card.pivot_offset = card.size * 0.5
	root.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.position = Vector2(20, 20)
	col.size = Vector2(w - 40, 170)
	card.add_child(col)
	var ic := Icon.new("check", UI.RED, 44.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.set_style(UI.RED, true)
	col.add_child(ic)
	var t := UI.label(item[0], 15, UI.SUB)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var l := UI.label(item[1], 17, UI.TEXT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w - 40
	col.add_child(l)
	var a := UI.display(item[2], 34, UI.TEXT)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(a)
	haptic("success")
	if not Game.reduce_motion:
		root.add_child(Confetti.new(Vector2(scr.x * 0.5, card.position.y + 40.0)))
	# The glass can't be scaled cleanly, so it rises and fades in instead.
	var rest := card.position
	card.position.y += 24.0
	card.modulate.a = 0.0
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", DIM.a * 0.7, 0.2)
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	tw.tween_property(card, "position", rest, Motion.d(0.4)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var closing := [false]
	var close := func():
		if closing[0] or not is_instance_valid(root):
			return
		closing[0] = true
		var tc := root.create_tween().set_parallel(true)
		tc.tween_property(card, "modulate:a", 0.0, 0.18)
		tc.tween_property(card, "position:y", card.position.y - 12.0, Motion.d(0.18))
		tc.tween_property(dim, "color:a", 0.0, 0.22)
		tc.chain().tween_callback(func():
			root.queue_free()
			_next_celebration())
	# It never blocks: taps go straight through, and it leaves by itself.
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in card.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().create_timer(3.2).timeout.connect(close)


# ---- drop-down picker -------------------------------------------------------

func pick(title: String, options: Array, current, on_pick: Callable, body := "") -> void:
	## A simple drop-down: a sheet listing the choices, the current one lit.
	## options: [[value, label], ...]
	var actions: Array = []
	for o in options:
		var v = o[0]
		actions.append({"text": String(o[1]), "style": "primary" if v == current else "secondary", "call": func(): on_pick.call(v)})
	actions.append({"text": "Close", "style": "plain"})   # a clear way out, near the thumb
	sheet(title, body, actions)


static func drop_pill(text: String) -> Button:
	## The button that opens a drop-down: label plus a small down arrow.
	var b := UI.pill(text + "  ▾", UI.PANEL, UI.TEXT, 15, 24)
	b.custom_minimum_size = Vector2(0, 48)
	return b
