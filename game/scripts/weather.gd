class_name SkyTime
extends RefCounted
## Time of day and weather for the scenes (1.2).
## Day and night follow the phone's own clock; the weather changes every few
## hours from a fixed schedule (the same for everyone at the same hour), so it
## never flickers. Tests and screenshots can force both.

static var force_hour := -1.0      # 0..24 to pin the time (tests, screenshots)
static var force_weather := ""     # "clear", "rain" or "fog" to pin the weather

const WEATHER_BLOCK_S := 3.0 * 3600.0


static func hour() -> float:
	if force_hour >= 0.0:
		return force_hour
	var d := Time.get_datetime_dict_from_system()
	return float(d["hour"]) + float(d["minute"]) / 60.0


static func night() -> float:
	## 0 in daylight, 1 at night, easing in at dusk (19-21) and out at dawn (5-7).
	var h := hour()
	if h >= 7.0 and h <= 19.0:
		return 0.0
	if h >= 21.0 or h <= 5.0:
		return 1.0
	return (7.0 - h) / 2.0 if h < 7.0 else (h - 19.0) / 2.0


static func warm() -> float:
	## Dawn and dusk glow, 0..1 (around 6:30 and 19:30).
	var h := hour()
	return clampf(maxf(1.0 - absf(h - 6.5) / 1.5, 1.0 - absf(h - 19.5) / 1.8), 0.0, 1.0)


static func sun_height() -> float:
	## 0 on the horizon, 1 at midday; the sun is up from 6 to 20.
	var h := hour()
	if h < 6.0 or h > 20.0:
		return 0.0
	return sin(PI * (h - 6.0) / 14.0)


static func weather() -> String:
	if force_weather != "":
		return force_weather
	var block := int(Time.get_unix_time_from_system() / WEATHER_BLOCK_S)
	var rng := RandomNumberGenerator.new()
	rng.seed = block * 7919 + 13
	var r := rng.randf()
	if r < 0.18:
		return "rain"
	if r < 0.36:
		return "fog"
	return "clear"


static func key() -> String:
	## Changes every 15 minutes or when the weather turns: a cue to redraw.
	return "%d|%s" % [int(hour() * 4.0), weather()]


static func sun_center(w: float, h: float, base: Vector2) -> Vector2:
	## Where the sun sits in a scene of size w x h; `base` is its daytime spot.
	var sh := sun_height()
	var y := lerpf(h * 0.64, base.y, sh)
	if sh <= 0.0:
		y = h * 0.66   # at night a dim red sun sits low on the horizon
	return Vector2(base.x, y)


static func sun_colour() -> Color:
	return UI.RED.darkened(0.55 * night())


static func shade(ci: CanvasItem, rect: Rect2, clip: PackedVector2Array) -> void:
	## Dusk glow low down, then the night tint and a few faint stars on top.
	var wm := warm()
	if wm > 0.0:
		for i in 3:
			var y := rect.size.y * (0.4 + 0.15 * i)
			Art._fill(ci, UI.rect_poly(Rect2(rect.position + Vector2(0, y), Vector2(rect.size.x, rect.size.y - y))), clip, Color(UI.FLASH, 0.035 * wm))
	var n := night()
	if n > 0.0:
		Art._fill(ci, clip, clip, Color(UI.INK, 0.42 * n))
		var rng := RandomNumberGenerator.new()
		rng.seed = 2024
		for i in 14:
			var p := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y * 0.32)
			ci.draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(UI.TEXT, 0.35 * n), true)


class Layer extends Control:
	## Rain streaks or drifting fog over a scene. Cheap: a few lines and bands,
	## redrawn at about 15 frames a second only while it rains or fogs, and
	## never with Less motion (then it is drawn once, still).
	var _kind := ""
	var _t := 0.0
	var _acc := 0.0
	var _check := 0.0
	var _drops: PackedVector2Array = PackedVector2Array()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(_seed_drops)

	func _ready() -> void:
		_kind = SkyTime.weather()
		_seed_drops()

	func _seed_drops() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		_drops = PackedVector2Array()
		for i in 70:
			_drops.append(Vector2(rng.randf(), rng.randf()))
		queue_redraw()

	func _process(delta: float) -> void:
		_check -= delta
		if _check <= 0.0:
			_check = 30.0
			var k := SkyTime.weather()
			if k != _kind:
				_kind = k
				queue_redraw()
		if _kind == "clear" or Game.reduce_motion or not is_visible_in_tree():
			return
		_t += delta
		_acc += delta
		if _acc >= 1.0 / 15.0:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 10.0 or _kind == "clear":
			return
		if _kind == "rain":
			draw_rect(Rect2(Vector2.ZERO, size), Color(UI.INK, 0.12), true)
			var fall := _t * h * 1.4
			for d in _drops:
				var x := d.x * w
				var y := fmod(d.y * h + fall * (0.8 + d.x * 0.4), h + 20.0) - 10.0
				draw_line(Vector2(x, y), Vector2(x - 2.0, y + 11.0), Color(UI.SUB, 0.35), 1.0)
		else:
			# Fog: soft bands that drift slowly sideways.
			for i in 3:
				var y := h * (0.42 + 0.16 * i)
				var dx := sin(_t * 0.08 + float(i) * 1.7) * w * 0.08
				for k in 3:
					var g := 10.0 + 8.0 * k
					draw_rect(Rect2(Vector2(dx - w * 0.1, y - g), Vector2(w * 1.2, g * 2.0)), Color(UI.HAZE, 0.07), true)
