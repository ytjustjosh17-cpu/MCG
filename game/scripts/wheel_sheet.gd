class_name WheelSheet
extends VBoxContainer
## The free daily wheel: eight segments from Data.WHEEL. The prize is worked
## out and paid by Game.spin_wheel() first; the wheel then spins to it.

var _view: WheelView
var _btn: Button
var _prize: Label


static func open() -> void:
	Kit.sheet("Daily wheel", "", [{"text": "Close", "style": "plain"}], true, WheelSheet.new())


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_view = WheelView.new()
	_view.custom_minimum_size = Vector2(0, 260)
	add_child(_view)
	_prize = UI.display("", 32)
	_prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prize)
	_btn = UI.pill("", UI.TEXT, UI.INK, 17, 24)
	_btn.custom_minimum_size = Vector2(0, 52)
	_btn.pressed.connect(_spin)
	Kit.press_fx(_btn)
	add_child(_btn)
	_show()


func _show() -> void:
	var ready := Game.wheel_ready()
	_btn.text = "Spin · free" if ready else "Next spin tomorrow"
	Page.set_enabled(_btn, ready)
	if _prize.text == "":
		_prize.text = "One free spin a day" if ready else "Come back tomorrow"
		_prize.add_theme_font_size_override("font_size", 20)


func _spin() -> void:
	var res := Game.spin_wheel()   # paid and saved before the wheel turns
	if res.is_empty():
		Motion.shake(_btn)
		return
	Kit.haptic("medium")
	Kit.sound("tap")
	Page.set_enabled(_btn, false)
	_btn.text = "Spinning..."
	var seg := int(res["index"])
	var n := Data.WHEEL.size()
	# Land with the chosen segment under the pointer at the top.
	var target := TAU * 5.0 - (TAU * (float(seg) + 0.5) / float(n))
	var t := create_tween()
	t.tween_property(_view, "angle", target, Motion.d(3.2)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		var what := "chips" if String(res["kind"]) == "chips" else "cash"
		_prize.add_theme_font_size_override("font_size", 32)
		_prize.text = "+%s %s" % [Game.money_short(float(res["amount"])), what]
		Kit.haptic("success")
		Kit.sound("fanfare")
		_show())


class WheelView extends Control:
	var angle := 0.0:
		set(v):
			angle = v
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.46
		var n := Data.WHEEL.size()
		var f: Font = UI.SEMI
		draw_circle(c, rad + 6.0, UI.SIDE)
		for i in n:
			var a0 := angle + TAU * float(i) / float(n) - PI / 2.0
			var a1 := angle + TAU * float(i + 1) / float(n) - PI / 2.0
			var pts := PackedVector2Array([c])
			for k in 9:
				var a := lerpf(a0, a1, float(k) / 8.0)
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			var seg: Array = Data.WHEEL[i]
			var chips := String(seg[0]) == "chips"
			var col: Color = UI.RAISED if chips else UI.PANEL
			if float(seg[1]) >= 60.0:
				col = UI.RED if float(seg[1]) >= 180.0 else UI.FELT
			draw_colored_polygon(pts, col)
			draw_line(c, c + Vector2(cos(a0), sin(a0)) * rad, UI.SIDE, 2.0, true)
			# Label: minutes of income, and a chip mark for chip prizes.
			var mid := (a0 + a1) * 0.5
			var lp := c + Vector2(cos(mid), sin(mid)) * rad * 0.66
			var mins := int(seg[1])
			var txt := ("%d h" % (mins / 60)) if mins >= 60 else ("%d m" % mins)
			draw_string(f, lp + Vector2(-30, 5), txt, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 14, UI.TEXT)
			if chips:
				draw_circle(c + Vector2(cos(mid), sin(mid)) * rad * 0.88, 5.0, UI.GOLD)
		draw_arc(c, rad, 0.0, TAU, 64, UI.GOLD, 2.0, true)
		draw_circle(c, rad * 0.16, UI.GOLD)
		draw_circle(c, rad * 0.08, UI.SIDE)
		# Pointer at the top.
		draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -rad - 12), c + Vector2(11, -rad - 12), c + Vector2(0, -rad + 10)]), UI.TEXT)
