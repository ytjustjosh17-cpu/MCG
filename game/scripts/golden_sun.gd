class_name GoldenSun
extends Button
## A small gold sun that drifts across the tower card for a few seconds.
## Tap it for a small prize. It never blocks the tower or anything else.

var _t := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _caught := false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)
	pressed.connect(_catch)


func start(area: Vector2) -> void:
	## Drift from one side of the card to the other, a little above the middle.
	var y := area.y * randf_range(0.22, 0.45)
	_from = Vector2(-60.0, y)
	_to = Vector2(area.x + 10.0, y - 40.0)
	if Motion.reduced():
		_from = Vector2(area.x * 0.5 - 32.0, y)
		_to = _from
	position = _from
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)


func _process(dt: float) -> void:
	if _caught:
		return
	_t += dt
	var k := _t / Data.SUN_STAY_S
	if k >= 1.0:
		queue_free()
		return
	position = _from.lerp(_to, k) + Vector2(0.0, sin(_t * 2.2) * 8.0 * (0.0 if Motion.reduced() else 1.0))
	if k > 0.85:
		modulate.a = (1.0 - k) / 0.15
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var gold := UI.SECTOR_COL["Energy"]
	# A soft glow in fine steps, then long and short rays turning slowly.
	for k in 6:
		draw_circle(c, 31.0 - k * 2.0, Color(gold, (0.04 + 0.03 * pulse)))
	for i in 12:
		var a := TAU * float(i) / 12.0 + _t * 0.8
		var r1 := 27.0 if i % 2 == 0 else 23.5
		draw_line(c + Vector2(cos(a), sin(a)) * 19.0, c + Vector2(cos(a), sin(a)) * r1, gold, 2.0 if i % 2 == 0 else 1.5, true)
	draw_circle(c, 16.5, gold.darkened(0.25))   # a darker rim
	draw_circle(c, 15.0, gold)
	draw_circle(c + Vector2(-4.0, -4.0), 6.0, gold.lightened(0.35))   # where the light hits
	draw_circle(c + Vector2(-5.5, -5.5), 2.2, Color(UI.TEXT, 0.85))


func _catch() -> void:
	if _caught:
		return
	_caught = true
	var v := Game.catch_sun()
	Kit.haptic("success")
	# A proper moment, not a flash: the centred card (never blocks taps).
	match Game.last_sun:
		"frenzy":
			Kit.celebrate("Golden sun", "Frenzy: taps ×%d for %d s" % [int(Data.FRENZY_MULT), int(Data.FRENZY_S)], "×%d" % int(Data.FRENZY_MULT))
		"rush":
			Kit.celebrate("Golden sun", "Rush: income ×2 for %d min" % int(Data.RUSH_S / 60.0), "×2")
		_:
			Kit.celebrate("Golden sun", "Cash bonus", "+" + Game.money_short(v))
	var parent := get_parent()
	if parent and not Motion.reduced():
		parent.add_child(Confetti.new(position + size * 0.5, 50))
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(queue_free)
