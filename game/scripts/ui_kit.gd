extends CanvasLayer
## Custom sheets, alerts and toasts drawn in the game's own style.
## Nothing here uses Godot's or Android's default pop-ups.

const DIM := Color(0.0, 0.03, 0.03, 0.62)
const SHEET_TINT := Color(0.035, 0.133, 0.145, 0.9)
const ALERT_TINT := Color(0.035, 0.133, 0.145, 0.94)

var top_inset := 0.0
var bottom_inset := 0.0
var _stack: Array = []  # [{"root": Control, "close": Callable}]
var _toast: Control
# Drag-versus-tap handling, so lists scroll even when the finger starts on a button.
const DRAG_PX := 14.0
var dragged := false
var _pressing := false
var _press_pos := Vector2.ZERO
var _down_btn: BaseButton
var _cancelled: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	## Every button lets drags through to the scroll view behind it.
	if n is BaseButton:
		var b := n as BaseButton
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


func haptic(kind: String) -> void:
	## Small haptic vocabulary, in the spirit of Apple's feedback generators.
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

func sheet(title: String, body: String, actions: Array, dismissable := true, extra: Control = null) -> Control:
	## actions: [{"text": String, "style": "primary"|"secondary"|"plain", "call": Callable}]
	var scr := screen()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(DIM, 0.0)
	root.add_child(dim)

	var pad := 20.0
	var w := scr.x
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.position = Vector2(pad, 28)
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
	var close := func(after: Callable = Callable()):
		if closing[0]:
			return
		closing[0] = true
		for i in range(_stack.size()):
			if _stack[i]["root"] == root:
				_stack.remove_at(i)
				break
		var tw := root.create_tween().set_parallel(true)
		tw.tween_property(panel, "position:y", scr.y + 8.0, Motion.d(0.22)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
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
			else:
				close.call(cb))
		col.add_child(b)
	panel.size = Vector2(w, scr.y)
	panel.position = Vector2(0, scr.y + 8.0)
	root.add_child(panel)
	var grab := ColorRect.new()
	grab.color = UI.TRACK
	grab.size = Vector2(36, 5)
	grab.position = Vector2(w / 2.0 - 18.0, 10)
	grab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grab)
	panel.add_child(col)
	var geo := {"rest": scr.y}
	_present_sheet(root, panel, col, dim, geo)

	if dismissable:
		dim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				close.call())
		var drag := {"on": false, "y0": 0.0}
		panel.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					drag["on"] = true
					drag["y0"] = e.global_position.y
				elif drag["on"]:
					drag["on"] = false
					if panel.position.y - geo["rest"] > 90.0:
						close.call()
					else:
						var back := root.create_tween()
						back.tween_property(panel, "position:y", geo["rest"], Motion.d(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			elif e is InputEventMouseMotion and drag["on"]:
				panel.position.y = geo["rest"] + maxf(0.0, e.global_position.y - drag["y0"]))
	_stack.append({"root": root, "close": func(): close.call() if dismissable else null})
	return root


func _present_sheet(root: Control, panel: Control, col: Control, dim: ColorRect, geo: Dictionary) -> void:
	await get_tree().process_frame
	if not is_instance_valid(root):
		return
	var scr := screen()
	var inner := col.get_combined_minimum_size().y
	col.size = Vector2(col.size.x, inner)
	var h := inner + 28.0 + 20.0 + bottom_inset
	panel.size = Vector2(scr.x, h + 40.0)
	geo["rest"] = scr.y - h
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(panel, "position:y", geo["rest"], Motion.d(Motion.SLOW)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(dim, "color:a", DIM.a, Motion.d(0.25))


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
	if _toast != null and is_instance_valid(_toast):
		_toast.queue_free()
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
	_present_toast(pill, l, red_mark)


func _present_toast(pill: Control, l: Label, red_mark: bool) -> void:
	await get_tree().process_frame
	if not is_instance_valid(pill):
		return
	var scr := screen()
	var w := l.get_minimum_size().x + (52.0 if red_mark else 40.0)
	pill.size = Vector2(w, 44)
	var y := top_inset + 10.0
	pill.position = Vector2((scr.x - w) / 2.0, y - 60.0)
	var tw := pill.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pill, "position:y", y, Motion.d(0.4)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(pill, "modulate:a", 1.0, 0.2)
	tw.chain().tween_interval(2.2)
	tw.chain().set_parallel(true)
	tw.tween_property(pill, "position:y", y - 40.0, Motion.d(0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pill, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(pill.queue_free)


# ---- celebration ------------------------------------------------------------

var _cele_queue: Array = []
var _cele_open := false


func celebrate(title: String, line: String, amount: String) -> void:
	## Centred card with confetti, for finished goals. Queues if one is showing.
	_cele_queue.append([title, line, amount])
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
	get_tree().create_timer(2.4).timeout.connect(close)
