class_name MedalRow
extends Row
## One medal per kind of achievement: a ring that fills a tier at a time
## (SUB, then TEXT, GOLD once every tier is done), "Taps · 3 of 5", a thin bar
## to the next tier, and a Claim pill while a tier's reward waits. Tapping the
## row claims what waits; ids and rewards are the achievements' own.

var g: Dictionary
var _badge: Badge
var _pill: PanelContainer
var _bar: Control


func _init(group: Dictionary, icon: String) -> void:
	super("", "", false)
	g = group
	set_meta("fixed_h", true)
	custom_minimum_size.y = 68
	_badge = Badge.new(icon)
	set_lead(_badge)
	value_l.add_theme_font_size_override("font_size", 13)
	value_l.add_theme_color_override("font_color", UI.SUB)
	# "Claim" pill, shown while a tier waits (the whole row is the button).
	_pill = PanelContainer.new()
	_pill.add_theme_stylebox_override("panel", UI.box(UI.TEXT, 16))
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 12)
	pm.add_theme_constant_override("margin_right", 12)
	pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(pm)
	var pl := UI.label("Claim", 13, UI.INK, true)
	pl.custom_minimum_size = Vector2(0, 32)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pm.add_child(pl)
	value_l.get_parent().get_parent().add_child(_pill)
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	resized.connect(func():
		_bar.position = Vector2(68, size.y - 10)
		_bar.size = Vector2(maxf(0.0, size.x - 68 - 16), 6)
		_bar.queue_redraw())
	pressed.connect(_claim)
	set_group(group)


func waiting() -> Array:
	## Achievement ids of tiers done but not yet claimed.
	var out: Array = []
	for t in g["tiers"]:
		if t["done"] and not t["claimed"]:
			out.append(String(t["id"]))
	return out


func set_group(group: Dictionary) -> void:
	g = group
	var tiers: Array = g["tiers"]
	var n := tiers.size()
	var lvl := int(g["level"])
	var nxt := int(g["next"])
	var sub := "%d of %d" % [lvl, n]
	if nxt >= 0:
		sub += " · next: " + String(tiers[nxt]["title"])
	set_texts(String(g["title"]), sub, "" if not waiting().is_empty() else ("Done" if nxt < 0 else _progress()))
	sub_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub_l.clip_text = true
	sub_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pill.visible = not waiting().is_empty()
	value_l.visible = not _pill.visible
	title_l.add_theme_color_override("font_color", UI.TEXT if lvl > 0 else UI.SUB)
	_badge.set_tiers(lvl, n)
	_bar.queue_redraw()


func _progress() -> String:
	var nxt := int(g["next"])
	var goal := float(g["tiers"][nxt]["goal"])
	var have := minf(Game.metric(String(g["metric"])), goal)
	if String(g["metric"]) in AchievementsPage.MONEY:
		return "%s / %s" % [Game.money_short(have), Game.money_short(goal)]
	return "%s / %s" % [Game.group(int(have)), Game.group(int(goal))]


func _draw_bar() -> void:
	if int(g["next"]) < 0:
		return   # every tier done: no bar
	var w := _bar.size.x
	var y := 3.0
	_bar.draw_line(Vector2(0, y), Vector2(w, y), UI.TRACK, 4.0, true)
	var p := clampf(float(g["progress"]), 0.0, 1.0)
	if p > 0.0:
		_bar.draw_line(Vector2(0, y), Vector2(w * p, y), UI.TEXT, 4.0, true)


func _claim() -> void:
	var ids := waiting()
	if ids.is_empty():
		return
	var got := 0.0
	for id in ids:
		got += Game.claim("ach:" + id)
	if got > 0.0:
		Kit.haptic("success")
		Kit.sound("fanfare")
		Kit.toast("+" + Game.money_short(got), true)
		Kit.fly_money(get_global_rect().get_center(), got)
	Game.flush_changes()


class Badge extends Control:
	## A ring split into one arc per tier, the done ones lit; the kind's icon inside.
	var _lvl := 0
	var _n := 1
	var _icon: Icon

	func _init(icon: String) -> void:
		custom_minimum_size = Vector2(40, 40)
		_icon = Icon.new(icon, UI.SUB, 18.0)
		_icon.position = Vector2(11, 11)
		add_child(_icon)

	func set_tiers(lvl: int, n: int) -> void:
		_lvl = lvl
		_n = maxi(1, n)
		var c := ring_color()
		_icon.set_style(c if _lvl > 0 else UI.SUB, _lvl > 0)
		queue_redraw()

	func ring_color() -> Color:
		if _lvl >= _n:
			return UI.GOLD   # the top tier: the only gold on the page
		if _lvl == 0:
			return UI.TRACK
		return UI.TEXT if float(_lvl) / float(_n) >= 0.5 else UI.SUB

	func _draw() -> void:
		var c := Vector2(20, 20)
		var r := 18.0
		var gap := 0.18 if _n > 1 else 0.0
		var step := TAU / float(_n)
		for i in range(_n):
			var a0 := -PI / 2.0 + step * i + gap * 0.5
			var a1 := -PI / 2.0 + step * (i + 1) - gap * 0.5
			draw_arc(c, r, a0, a1, 16, ring_color() if i < _lvl else UI.TRACK, 3.0, true)
