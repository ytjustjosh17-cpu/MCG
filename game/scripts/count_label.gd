class_name CountLabel
extends Label
## A money label that glides to new values instead of jumping.

var target := 0.0
var shown := 0.0
var formatter: Callable
var fit_width := 0.0   # if set, the font shrinks so long numbers stay on one line
var _base_size := 0


func _init(fmt: Callable) -> void:
	formatter = fmt
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float, instant := false) -> void:
	target = v
	if instant:
		shown = v
		_show(formatter.call(shown))


func _show(t: String) -> void:
	var grew := t.length() != text.length()
	text = t
	if fit_width <= 0.0 or not grew:
		return
	if _base_size == 0:
		_base_size = get_theme_font_size("font_size")
	var f := get_theme_font("font")
	var fs := _base_size
	while fs > 20 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > fit_width:
		fs -= 2
	add_theme_font_size_override("font_size", fs)


func _process(delta: float) -> void:
	if is_equal_approx(shown, target):
		return
	shown = lerpf(shown, target, minf(1.0, delta * 12.0))
	if absf(target - shown) < maxf(0.005, absf(target) * 0.0005):
		shown = target
	_show(formatter.call(shown))
