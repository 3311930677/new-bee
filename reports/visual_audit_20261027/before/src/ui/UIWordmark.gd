extends Control
## Authored brush segments reveal the original gold artwork; no whole-logo fade or loop.

const ART := preload("res://assets/ui/review_fixes_20261009/wordmark_body.png")
const REVEAL_SHADER := """shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= reveal;
}
"""

var animated := true
var delay := 0.08
var _ink: TextureRect
var ink_material: ShaderMaterial
var _write_motion: Tween
static var _logo_texture: AtlasTexture
static var _shader_cache: Shader

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink = TextureRect.new()
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _logo_texture == null:
		_logo_texture = AtlasTexture.new()
		_logo_texture.atlas = ART
		_logo_texture.region = Rect2(ART.get_image().get_used_rect())
	_ink.texture = _logo_texture
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ink.modulate = Color(0.87,0.83,0.80)
	_ink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ink.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ink)
	if not animated or G.get_meta("ui_review_mode", false):
		return
	if _shader_cache == null:
		_shader_cache = Shader.new()
		_shader_cache.code = REVEAL_SHADER
	ink_material = ShaderMaterial.new()
	ink_material.shader = _shader_cache
	_ink.material = ink_material
	_write_motion = create_tween()
	_write_motion.tween_interval(delay)
	_write_motion.tween_method(set_reveal,0.0,1.0,.86)

func set_reveal(value: float) -> void:
	if ink_material != null: ink_material.set_shader_parameter("reveal",clampf(value,0.0,1.0))

