class_name ClaimList
extends VBoxContainer
## "To claim": rewards you've earned (goals, the daily gift, achievements)
## waiting for a tap. Each has its own Claim button; Claim all when there are
## several. Hidden when nothing is waiting.

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
	_title.text = "To claim · %s" % Game.money_short(total)
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
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 12)
	m.custom_minimum_size = Vector2(0, 64)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)
	var kind := String(r.get("kind", ""))
	var ic := Icon.new({"ach": "trophy", "goal": "goal", "streak": "star"}.get(kind, "star"), UI.TEXT, 22.0)
	ic.set_style(UI.TEXT, true)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UI.label(String(r.get("title", "")), 15, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	var b := UI.pill("Claim " + Game.money_short(float(r.get("amount", 0.0))), UI.TEXT, UI.INK, 15, 20)
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var key := String(r["key"])
	b.pressed.connect(func(): _celebrate(Game.claim(key)))
	Kit.press_fx(b)
	h.add_child(b)
	return m


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
