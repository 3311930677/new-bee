extends Control
## 独立标题素材。笔锋沿横向显露，随后落稳；无循环闪光或逐帧缩放文字。

const ART := preload("res://image/ui/expedition_wordmark_v1.png")
const REVEAL_SHADER := """shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.08) = 0.0;
void fragment() {
	COLOR.a *= 1.0 - smoothstep(reveal - 0.045, reveal, UV.x);
}
"""

var animated := true
var delay := 0.08
var _ink: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink = TextureRect.new()
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var atlas := AtlasTexture.new()
	atlas.atlas = ART
	atlas.region = Rect2(ART.get_image().get_used_rect())
	_ink.texture = atlas
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ink.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ink)
	if not animated or G.get_meta("ui_review_mode", false):
		return
	var shader := Shader.new()
	shader.code = REVEAL_SHADER
	var ink_material := ShaderMaterial.new()
	ink_material.shader = shader
	_ink.material = ink_material
	_ink.position.y = 7
	_ink.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(_ink, "modulate:a", 1.0, 0.20)
	tw.parallel().tween_method(func(value: float):
		ink_material.set_shader_parameter("reveal", value), 0.0, 0.53, 0.42)
	tw.tween_method(func(value: float):
		ink_material.set_shader_parameter("reveal", value), 0.53, 1.08, 0.38)
	tw.parallel().tween_property(_ink, "position:y", 0.0, 0.38)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

