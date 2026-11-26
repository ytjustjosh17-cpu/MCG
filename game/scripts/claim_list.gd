class_name ClaimList
extends VBoxContainer
## "To claim": rewards you've earned (goals, the daily gift, achievements)
## waiting for a tap. Tap a row to claim it (the whole row is the button);
## Claim all sits on top when there are several. Hidden when nothing waits.

var kinds: Array = []
var _sig := "-"
var _card: VBoxContainer
var _title: Label


func _init(k: Array = []) -> void:
	kinds = k
	add_theme_constant_override("separation", 8)
	visible = false


func _ready() -> void:
	_title = UI.label("", 17, UI.TEXT, true)
	add_child(_title)
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
	var sig := ""
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
	_title.text = "To claim · %d · tap one to claim it" % list.size() if list.size() > 1 else "To claim · tap it"
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
	for i in range(list.size()):
		if i > 0:
			var sep := ColorRect.new()
			sep.color = UI.RAISED
			sep.custom_minimum_size = Vector2(0, 1)
			_card.add_child(sep)
		_card.add_child(_row(list[i]))


func _row(r: Dictionary) -> Control:
	var kind := String(r.get("kind", ""))
	var row := Row.new({"ach": "trophy", "goal": "goal", "streak": "star"}.get(kind, "star"), "", false)
	row.custom_minimum_size = Vector2(0, 56)
	(row.lead as Icon).set_style(UI.TEXT, true)
	row.title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.title_l.clip_text = true
	row.set_texts(String(r.get("title", "")), "", "+" + Game.money_short(float(r.get("amount", 0.0))))
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
