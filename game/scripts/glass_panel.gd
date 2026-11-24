class_name GlassPanel
extends ColorRect
## Frosted glass surface. Size it like any Control.

const SHADER := preload("res://shaders/glass.gdshader")


func _init(radius := 32.0, tint := Color(0.035, 0.133, 0.145, 0.72), blur := 9.0) -> void:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("blur", blur)
	material = m
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_sync)


func _sync() -> void:
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
