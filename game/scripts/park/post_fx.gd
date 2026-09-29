class_name PostFx
extends CanvasLayer
## Full-screen colour grade + vignette under the HUD.

func _ready() -> void:
	layer = 5
	var r: ColorRect = ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://shaders/post.gdshader")
	r.material = m
	add_child(r)
