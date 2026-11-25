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
	draw_circle(c, 30.0, Color(gold, 0.12 + 0.1 * pulse))
	draw_circle(c, 22.0, Color(gold, 0.25))
	draw_circle(c, 16.0, gold)
	for i in 8:
		var a := TAU * float(i) / 8.0 + _t
		draw_line(c + Vector2(cos(a), sin(a)) * 20.0, c + Vector2(cos(a), sin(a)) * 27.0, gold, 2.0, true)


func _catch() -> void:
	if _caught:
		return
	_caught = true
	var v := Game.catch_sun()
	Kit.haptic("success")
	Kit.toast("Golden sun · +" + Game.money_short(v), true)
	var parent := get_parent()
	if parent and not Motion.reduced():
		parent.add_child(Confetti.new(position + size * 0.5, 50))
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(queue_free)
