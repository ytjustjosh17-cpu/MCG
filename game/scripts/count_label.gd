class_name CountLabel
extends Label
## A money label that glides to new values instead of jumping.

var target := 0.0
var shown := 0.0
var formatter: Callable


func _init(fmt: Callable) -> void:
	formatter = fmt
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float, instant := false) -> void:
	target = v
	if instant:
		shown = v
		text = formatter.call(shown)


func _process(delta: float) -> void:
	if is_equal_approx(shown, target):
		return
	shown = lerpf(shown, target, minf(1.0, delta * 12.0))
	if absf(target - shown) < maxf(0.005, absf(target) * 0.0005):
		shown = target
	text = formatter.call(shown)
