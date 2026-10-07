extends Control
## Authored brush segments reveal the original gold artwork; no whole-logo fade or loop.

const ART := preload("res://image/ui/expedition_wordmark_v1.png")
const REVEAL_SHADER := """shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
vec4 stroke(int i) {
 if(i==0) return vec4(.22,.12,.37,.06);
 if(i==1) return vec4(.18,.31,.43,.22);
 if(i==2) return vec4(.27,.30,.18,.58);
 if(i==3) return vec4(.34,.32,.33,.51);
 if(i==4) return vec4(.33,.51,.42,.51);
 if(i==5) return vec4(.06,.13,.13,.23);
 if(i==6) return vec4(.07,.40,.15,.33);
 if(i==7) return vec4(.15,.33,.07,.52);
 if(i==8) return vec4(.07,.52,.13,.62);
 if(i==9) return vec4(.02,.74,.18,.70);
 if(i==10) return vec4(.18,.70,.39,.88);
 if(i==11) return vec4(.39,.88,.49,.79);
 if(i==12) return vec4(.61,.12,.51,.32);
 if(i==13) return vec4(.60,.33,.51,.48);
 if(i==14) return vec4(.56,.43,.55,.80);
 if(i==15) return vec4(.64,.31,.94,.24);
 if(i==16) return vec4(.76,.30,.72,.76);
 if(i==17) return vec4(.76,.49,.91,.48);
 if(i==18) return vec4(.64,.57,.64,.84);
 return vec4(.61,.86,.97,.83);
}
void fragment() {
 vec2 p = UV * vec2(2.1,1.0);
 float nearest = 100.0;
 float ink_time = 1.0;
 for(int i=0;i<20;i++) {
  vec4 line = stroke(i);
  vec2 a = line.xy * vec2(2.1,1.0);
  vec2 b = line.zw * vec2(2.1,1.0);
  float t = clamp(dot(p-a,b-a)/max(dot(b-a,b-a),.00001),0.0,1.0);
  float d = length(p-mix(a,b,t));
  if(d<nearest) { nearest=d; ink_time=(float(i)+t*.8+.1)/20.0; }
 }
 float visible = smoothstep(ink_time-.009,ink_time+.009,reveal);
 float tip = max(0.0,1.0-abs(reveal-ink_time)/.016)*.16;
 COLOR.rgb = mix(COLOR.rgb,vec3(1.0,.88,.56),tip);
 COLOR.a *= visible;
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
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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

