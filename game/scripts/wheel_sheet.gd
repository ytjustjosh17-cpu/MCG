class_name WheelSheet
extends BoxContainer
## The free daily wheel: eight segments from Data.WHEEL. The prize is worked
## out and paid by Game.spin_wheel() first; the wheel then spins to it.

var _view: WheelView
var _btn: Button
var _prize: Label


static func open() -> void:
	Kit.sheet("Daily wheel", "", [{"text": "Close", "style": "plain"}], true, WheelSheet.new())


var _right: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_view = WheelView.new()
	add_child(_view)
	# Prize and button together, so landscape can put them beside the wheel.
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 12)
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_right)
	_prize = UI.display("", 32)
	_prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(_prize)
	_btn = UI.pill("", UI.TEXT, UI.INK, 17, 24)
	_btn.custom_minimum_size = Vector2(0, 52)
	_btn.pressed.connect(_spin)
	Kit.press_fx(_btn)
	_right.add_child(_btn)
	_layout()
	Kit.layout_changed.connect(func(_l: bool): _layout())
	_show()


func _layout() -> void:
	## Portrait: wheel, prize, button down the card. Landscape (only 390 high):
	## the wheel on the left, prize and button beside it.
	vertical = not Kit.landscape
	_view.custom_minimum_size = Vector2(190, 190) if Kit.landscape else Vector2(0, 260)


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
		var rad := minf(size.x, size.y) * 0.41   # leaves room for the bulb rim and the pointer
		var n := Data.WHEEL.size()
		var f: Font = UI.SEMI
		# The rim: a dark ring with marquee bulbs, every other one lit.
		draw_circle(c + Vector2(0, 4), rad + 12.0, Color(UI.INK, 0.5))
		draw_circle(c, rad + 12.0, UI.SIDE)
		draw_circle(c, rad + 10.0, UI.SIDE.lerp(UI.RAISED, 0.5))
		draw_arc(c, rad + 10.5, PI * 1.05, PI * 1.6, 24, Color(UI.TEXT, 0.25), 1.2, true)
		var bulbs := n * 2
		for k in bulbs:
			var ba := TAU * float(k) / float(bulbs) - PI / 2.0
			var bp := c + Vector2(cos(ba), sin(ba)) * (rad + 6.0)
			if k % 2 == 0:
				draw_circle(bp, 4.0, Color(UI.GOLD, 0.25))
				draw_circle(bp, 2.2, UI.GOLD)
			else:
				draw_circle(bp, 2.0, UI.TRACK)
		draw_circle(c, rad + 1.0, UI.SIDE)
		for i in n:
			var a0 := angle + TAU * float(i) / float(n) - PI / 2.0
			var a1 := angle + TAU * float(i + 1) / float(n) - PI / 2.0
			var pts := PackedVector2Array([c])
			for k in 9:
				var a := lerpf(a0, a1, float(k) / 8.0)
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			var seg: Array = Data.WHEEL[i]
			var chips := String(seg[0]) == "chips"
			# Tonal segments; the top prize is gold (gold means a win, red is for the button).
			var top := float(seg[1]) >= 180.0
			var col: Color = UI.RAISED if chips else UI.PANEL
			if float(seg[1]) >= 60.0:
				col = UI.GOLD if top else UI.FELT
			draw_colored_polygon(pts, col)
			# Shade towards the hub and a light edge along the outer rim: a bevel.
			var inner := PackedVector2Array([c])
			for k in 9:
				var a := lerpf(a0, a1, float(k) / 8.0)
				inner.append(c + Vector2(cos(a), sin(a)) * rad * 0.45)
			draw_colored_polygon(inner, Color(UI.INK, 0.18))
			draw_arc(c, rad - 2.0, a0 + 0.03, a1 - 0.03, 8, Color(UI.TEXT, 0.18), 2.0, true)
			draw_line(c, c + Vector2(cos(a0), sin(a0)) * rad, UI.SIDE, 2.0, true)
			# Label: minutes of income, and a chip mark for chip prizes.
			var mid := (a0 + a1) * 0.5
			var lp := c + Vector2(cos(mid), sin(mid)) * rad * 0.66
			var mins := int(seg[1])
			var txt := ("%d h" % (mins / 60)) if mins >= 60 else ("%d m" % mins)
			# A chip prize gets a small chip just after its label (out on the
			# rim it ran into the labels of the sideways segments).
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var shift := -6.0 if chips else 0.0
			draw_string(f, lp + Vector2(-30 + shift, 5), txt, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 15, UI.INK if top else UI.TEXT)
			if chips:
				draw_circle(lp + Vector2(shift + tw * 0.5 + 8.0, 0.0), 4.0, UI.INK if top else UI.GOLD)
		draw_arc(c, rad, 0.0, TAU, 64, UI.GOLD, 2.0, true)
		# A soft sheen across the top left of the face.
		draw_arc(c, rad * 0.8, PI * 1.08, PI * 1.45, 24, Color(UI.TEXT, 0.06), rad * 0.3, true)
		# The hub: a polished gold boss.
		draw_circle(c, rad * 0.19, UI.SIDE)
		CasinoGame.draw_ball(self, c, rad * 0.16, UI.GOLD)
		# Pointer at the top: gold, with a shadow and a round cap.
		var tipy := -rad + 12.0
		var tri := PackedVector2Array([c + Vector2(-12, -rad - 14), c + Vector2(12, -rad - 14), c + Vector2(0, tipy)])
		var sh := PackedVector2Array()
		for q in tri:
			sh.append(q + Vector2(2, 3))
		draw_colored_polygon(sh, Color(UI.INK, 0.5))
		draw_colored_polygon(tri, UI.GOLD)
		draw_line(c + Vector2(-12, -rad - 14), c + Vector2(0, tipy), Color(UI.TEXT, 0.5), 1.2, true)
		CasinoGame.draw_ball(self, c + Vector2(0, -rad - 15), 6.0, UI.GOLD)
