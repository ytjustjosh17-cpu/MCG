class_name Confetti
extends Control
## A short burst of paper confetti from a point. Frees itself when done.

const LIFE := 2.4
const GRAVITY := 900.0

var _parts: Array = []
var _t := 0.0


func _init(origin: Vector2, count := 90) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cols := [UI.RED, UI.TEXT, UI.UP, UI.SECTOR_COL["Energy"], UI.SECTOR_COL["Tech"], UI.SECTOR_COL["Finance"]]
	for i in count:
		var a := randf_range(-PI * 0.92, -PI * 0.08)  # upwards fan
		var sp := randf_range(320.0, 760.0)
		_parts.append({
			"p": origin, "v": Vector2(cos(a), sin(a)) * sp,
			"r": randf() * TAU, "w": randf_range(-9.0, 9.0),
			"s": Vector2(randf_range(5.0, 9.0), randf_range(9.0, 15.0)),
			"c": cols[i % cols.size()], "f": randf() * TAU,
		})


func _process(dt: float) -> void:
	_t += dt
	if _t >= LIFE:
		queue_free()
		return
	for p in _parts:
		p["v"].y += GRAVITY * dt
		p["v"] *= 1.0 - 1.6 * dt  # air drag, so pieces flutter down
		p["p"] += p["v"] * dt
		p["r"] += p["w"] * dt
		p["f"] += 9.0 * dt
	queue_redraw()


func _draw() -> void:
	var fade := clampf((LIFE - _t) / 0.6, 0.0, 1.0)
	for p in _parts:
		# The flip makes each piece look like paper turning in the air.
		var sz: Vector2 = p["s"]
		sz.x *= absf(cos(float(p["f"])))
		draw_set_transform(p["p"], p["r"], Vector2.ONE)
		var c: Color = p["c"]
		c.a = fade
		draw_rect(Rect2(-sz * 0.5, sz), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
