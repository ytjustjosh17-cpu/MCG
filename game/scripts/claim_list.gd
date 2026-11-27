class_name ClaimList
extends VBoxContainer
## "To claim": rewards you've earned (goals, the daily gift, achievements)
## waiting for a tap. Tap a row to claim it (the whole row is the button);
## Claim all sits on top when there are several. Hidden when nothing waits.

var kinds: Array = []
var _sig := "-"
var _card: VBoxContainer
var _title: Label
var _count: Label
var _more := false   # show every row, not just the first few
const SHOWN := 5


func _init(k: Array = []) -> void:
	kinds = k
	add_theme_constant_override("separation", 8)
	visible = false


func _ready() -> void:
	var head := HBoxContainer.new()
	add_child(head)
	_title = UI.label("To claim", 17, UI.TEXT, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = UI.label("", 13, UI.SUB)
	head.add_child(_count)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	add_child(pc)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 0)
	pc.add_child(_card)
	Game.changed.connect(refresh)
	refresh()


func _mine() -> Array:
	var out: Array = []
	for r in Game.rewards:
		if kinds.is_empty() or kinds.has(String(r.get("kind", ""))):
			out.append(r)
	return out


func refresh() -> void:
	if _card == null:
		return
	var list := _mine()
	var sig := str(_more) + ":"
	for r in list:
		sig += String(r["key"]) + ","
	if sig == _sig:
		return
	_sig = sig
	visible = not list.is_empty()
	for ch in _card.get_children():
		ch.queue_free()
	if list.is_empty():
		return
	var total := 0.0
	for r in list:
		total += float(r.get("amount", 0.0))
	_count.text = str(list.size())
	if list.size() > 1:
		# Claim all first, so a long list never pushes it out of reach.
		var top := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			top.add_theme_constant_override("margin_" + side, 12)
		var all := UI.pill("Claim all · " + Game.money_short(total), UI.TEXT, UI.INK, 17, 24)
		all.custom_minimum_size = Vector2(0, 48)
		all.pressed.connect(func():
			var got := 0.0
			for r in _mine():
				got += Game.claim(String(r["key"]))
			_celebrate(got))
		Kit.press_fx(all)
		top.add_child(all)
		_card.add_child(top)
	var n := list.size() if _more else mini(list.size(), SHOWN)
	for i in range(n):
		if i > 0:
			_card.add_child(_sep())
		_card.add_child(_row(list[i]))
	if list.size() > n:
		_card.add_child(_sep())
		var more := Row.new("", "", true)
		more.set_texts("Show %d more" % (list.size() - n))
		more.title_l.add_theme_color_override("font_color", UI.SUB)
		more.pressed.connect(func():
			Kit.tick()
			_more = true
			refresh())
		_card.add_child(more)


func _sep() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = UI.RAISED
	sep.custom_minimum_size = Vector2(0, 1)
	return sep


func _row(r: Dictionary) -> Control:
	var kind := String(r.get("kind", ""))
	var row := Row.new({"ach": "trophy", "goal": "goal", "streak": "star"}.get(kind, "star"), "", false)
	(row.lead as Icon).set_style(UI.TEXT, true)
	row.title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.title_l.clip_text = true
	row.set_texts(String(r.get("title", "")), "", "+" + Game.money_short(float(r.get("amount", 0.0))))
	# A visible "Claim" pill; the whole row is still the button.
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 16))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pl := UI.label("Claim", 13, UI.TEXT, true)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pl.custom_minimum_size = Vector2(0, 32)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 12)
	pm.add_theme_constant_override("margin_right", 12)
	pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pm.add_child(pl)
	pill.add_child(pm)
	row.value_l.get_parent().get_parent().add_child(pill)
	var key := String(r["key"])
	row.pressed.connect(func(): _celebrate(Game.claim(key)))
	Kit.press_fx(row)
	return row


func _celebrate(v: float) -> void:
	if v <= 0.0:
		return
	Kit.haptic("success")
	Kit.sound("fanfare")
	Kit.toast("+" + Game.money_short(v), true)
	if not Motion.reduced():
		var c := Confetti.new(global_position - get_viewport_rect().position + Vector2(size.x * 0.5, 40), 60)
		get_tree().root.get_node("Kit").add_child(c)
	Game.flush_changes()
