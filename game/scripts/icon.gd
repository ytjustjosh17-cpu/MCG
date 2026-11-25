class_name Icon
extends Control
## Phosphor icons (MIT, github.com/phosphor-icons/core), tinted to any colour.
## `filled` switches to the solid version, used for the active tab.

const MAP := {
	"earn": "hand-tap", "business": "briefcase", "invest": "chart-line-up", "items": "diamond",
	"profile": "user-circle", "bolt": "lightning", "level": "arrow-fat-up", "chevron": "caret-right",
	"back": "caret-left", "check": "check-circle", "lock": "lock-simple", "list": "list-checks",
	"trophy": "trophy", "dots": "dots-three", "plus": "plus", "gear": "gear", "bug": "bug",
	"storage": "hard-drives", "update": "arrows-clockwise", "vibrate": "vibrate", "trash": "trash",
	"close": "x", "coins": "coins", "clock": "clock", "sparkle": "sparkle", "pie": "chart-pie-slice",
	"news": "newspaper", "gauge": "gauge", "unlock": "lock-simple-open", "copy": "copy", "download": "download-simple", "home": "house", "goal": "flag-checkered",
}
static var _cache := {}

@export var kind := "earn"
@export var color := UI.TEXT
@export var filled := false


func _init(k := "earn", c := UI.TEXT, side := 22.0) -> void:
	kind = k
	color = c
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_style(c: Color, f := false) -> void:
	color = c
	filled = f
	queue_redraw()


static func texture(name: String, fill := false) -> Texture2D:
	var key := name + ("-fill" if fill else "")
	if not _cache.has(key):
		var path := "res://assets/icons/%s.svg" % key
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


func _draw() -> void:
	var s := size.x / 24.0
	match kind:
		"up":
			draw_colored_polygon(PackedVector2Array([Vector2(12, 4) * s, Vector2(21, 18) * s, Vector2(3, 18) * s]), color)
			return
		"down":
			draw_colored_polygon(PackedVector2Array([Vector2(12, 20) * s, Vector2(21, 6) * s, Vector2(3, 6) * s]), color)
			return
	var tex := texture(MAP.get(kind, kind), filled)
	if tex == null:
		tex = texture(MAP.get(kind, kind), false)
	if tex:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, color)
