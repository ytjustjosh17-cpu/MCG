class_name Motion
extends RefCounted
## One motion language for the whole game ("premium" personality):
## a single signature curve (quint ease-out in, quad ease-in out),
## three durations, no bounce on frequent actions, and a Reduce Motion switch.
## Built from the LottieFiles motion-design skill, design-motion-principles
## and Apple's Human Interface Guidelines on motion.

const STANDARD := 0.28


static func reduced() -> bool:
	return Game.reduce_motion


static func d(t: float) -> float:
	## Duration respecting Reduce Motion.
	return 0.01 if reduced() else t


static func tween(node: Node, key := "fx") -> Tween:
	## A fresh tween that replaces any running one with the same key,
	## so animations can be interrupted and retargeted instead of fighting.
	var old = node.get_meta("tw_" + key) if node.has_meta("tw_" + key) else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var t := node.create_tween()
	node.set_meta("tw_" + key, t)
	return t


static func shake(c: Control) -> void:
	## "No": a short horizontal shake with decreasing amplitude.
	Kit.haptic("error")
	if reduced():
		return
	var x0 := c.position.x
	var t := tween(c, "shake")
	for a in [10.0, -8.0, 5.0, -3.0, 0.0]:
		t.tween_property(c, "position:x", x0 + a, 0.06).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): c.position.x = x0)


static func pop(c: Control, amount := 1.08) -> void:
	## "Yes": a quick scale pop with a small, controlled overshoot.
	if reduced():
		return
	c.pivot_offset = c.size / 2.0
	var t := tween(c, "pop")
	t.tween_property(c, "scale", Vector2(amount, amount), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func enter_stagger(items: Array, offset := 10.0) -> void:
	## Content arrives in order: fade + small rise, 30 ms apart, at most 8 items.
	if reduced():
		return
	var n := 0
	for it in items:
		if not (it is CanvasItem) or n >= 8:
			continue
		var c := it as CanvasItem
		c.modulate.a = 0.0
		var t := tween(c, "enter")
		t.tween_interval(0.03 * n)
		t.tween_property(c, "modulate:a", 1.0, 0.24)
		n += 1
		if c is Control:
			var ctl := c as Control
			# Containers own position, so rise using the visual offset only.
			ctl.pivot_offset = ctl.size / 2.0
			ctl.scale = Vector2(0.985, 0.985)
			var s := tween(ctl, "enter_scale")
			s.tween_interval(0.03 * (n - 1))
			s.tween_property(ctl, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
