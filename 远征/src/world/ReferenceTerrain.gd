class_name ReferenceTerrain
extends Node2D
const ROOT:="res://assets/world/reference_complete_20261011/ready/"
var extent:=Vector2.ZERO
var map_id:=""
var _white:Texture2D
func setup(id:String,size:Vector2)->void:
	map_id=id
	extent=size
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D shade_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D water_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D layout_mask : filter_nearest;
uniform vec2 world_size;
void fragment() {
	vec2 world = UV * world_size;
	vec2 uv = world / 128.0;
	vec4 m = texture(layout_mask, UV);
	vec4 grass = texture(grass_tex, uv);
	vec4 shade = texture(shade_tex, uv + vec2(0.37,0.19));
	vec4 soil = texture(soil_tex, uv + vec2(0.21,0.53));
	vec4 water = texture(water_tex, world / 160.0);
	vec4 base = mix(grass, shade, 0.10 + m.b * 0.12);
	base = mix(base, soil, m.r);
	base = mix(base, water, m.g);
	COLOR = vec4(base.rgb,1.0);
}"""
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	mat.set_shader_parameter("grass_tex",load(ROOT+"material_grass.png"))
	mat.set_shader_parameter("shade_tex",load(ROOT+"material_shade.png"))
	mat.set_shader_parameter("soil_tex",load(ROOT+"material_soil.png"))
	mat.set_shader_parameter("water_tex",load(ROOT+"material_water.png"))
	mat.set_shader_parameter("layout_mask",load(ROOT+id+"_mask.png"))
	mat.set_shader_parameter("world_size",extent)
	material=mat
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_white=ImageTexture.create_from_image(image)
	z_index=-20
	queue_redraw()
func _draw()->void:
	if _white!=null:draw_texture_rect(_white,Rect2(Vector2.ZERO,extent),false)
