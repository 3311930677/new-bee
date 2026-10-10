extends Node
const ROOT:="res://assets/world/natural_ground_20261011/"
const OLD:="res://assets/world/reference_complete_20261011/"
func source_texture(id:String)->Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(ROOT+"source/"+id+".png"))
func soil_center(image:Image,row:int)->float:
	var sum:=0.0;var count:=0
	for x in image.get_width():
		var color:=image.get_pixel(x,clampi(row,0,image.get_height()-1))
		if color.r>color.g*1.035 and color.g>color.b*1.3 and color.r>.55:sum+=x;count+=1
	return (sum/maxi(1,count))/image.get_width() if count>0 else .5
func _ready()->void:
	G.SAVE_PATH="res://shots/reference_complete_20261011/natural_bake_save.json";G.save_locked=true
	var grass:=source_texture("grass")
	var north:=source_texture("road_north");var middle:=source_texture("road_middle");var south:=source_texture("road_south")
	var water:=load(OLD+"ready/material_water.png") as Texture2D
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform sampler2D grass_tex : source_color,filter_nearest,repeat_enable;
uniform sampler2D north_tex : source_color,filter_nearest;
uniform sampler2D middle_tex : source_color,filter_nearest;
uniform sampler2D south_tex : source_color,filter_nearest;
uniform sampler2D water_tex : source_color,filter_nearest,repeat_enable;
uniform vec2 world_size;
uniform vec2 grass_world_size;
uniform float center_x;
uniform float river_on;
uniform float middle_shift;
void fragment(){
 vec2 p=UV*world_size;
 vec4 base=texture(grass_tex,p/grass_world_size);
 float u=(p.x-center_x+240.0)/480.0;
 vec4 n=texture(north_tex,vec2(u,(p.y+32.0)/768.0));
 vec4 m=texture(middle_tex,vec2(u-middle_shift/480.0,(p.y-704.0+32.0)/768.0));
 vec4 s=texture(south_tex,vec2(u,(p.y-1408.0+32.0)/768.0));
 vec4 strip=mix(n,m,smoothstep(680.0,728.0,p.y));
 strip=mix(strip,s,smoothstep(1384.0,1432.0,p.y));
 float blend=smoothstep(0.0,.15,u)*(1.0-smoothstep(.85,1.0,u));
 base=mix(base,strip,blend);
 if(river_on>.5){
  float river_y=1200.0+p.x/960.0*60.0;
  float edge=sin(p.x*.029)*1.5+sin(p.x*.071)*.6;
  float wet=1.0-smoothstep(30.0+edge,34.0+edge,abs(p.y-river_y));
  base=mix(base,texture(water_tex,p/160.0),wet);
 }
 COLOR=vec4(base.rgb,1.0);
}"""
	var manifest:={}
	for id in ["lorin_wilds","maple_road"]:
		var cfg:Dictionary=TableCache.main_world_map(id)
		var extent:=Vector2(float(cfg.map_cols)*48,float(cfg.map_rows)*48)
		var shift:=0.0
		if id=="maple_road":shift=-(soil_center(middle.get_image(),roundi((1230.0-704+32)/768*middle.get_height()))-.5)*480
		var mat:=ShaderMaterial.new();mat.shader=shader
		for pair in [["grass_tex",grass],["north_tex",north],["middle_tex",middle],["south_tex",south],["water_tex",water]]:mat.set_shader_parameter(pair[0],pair[1])
		mat.set_shader_parameter("world_size",extent);mat.set_shader_parameter("grass_world_size",grass.get_size()*.5)
		mat.set_shader_parameter("center_x",600.0 if id=="lorin_wilds" else 500.0)
		mat.set_shader_parameter("middle_shift",shift);mat.set_shader_parameter("river_on",1.0 if id=="maple_road" else 0.0)
		for part in ["full","top","bottom"]:
			var vp:=SubViewport.new();vp.size=Vector2i(extent) if part=="full" else Vector2i(roundi(extent.x*2),roundi(extent.y))
			vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(vp)
			var parent:=Node2D.new();parent.scale=Vector2.ONE if part=="full" else Vector2.ONE*2;vp.add_child(parent)
			var ground:=Ground.new();ground.extent=extent;ground.material=mat
			if part=="bottom":ground.position.y=-extent.y*.5
			parent.add_child(ground);await get_tree().process_frame;await RenderingServer.frame_post_draw
			var path:String=ROOT+"ready/"+id+"_floor"+("" if part=="full" else "_"+part)+".png"
			assert(vp.get_texture().get_image().save_png(path)==OK)
			vp.remove_child(parent);parent.free();vp.queue_free();await get_tree().process_frame
		manifest[id]={"extent":[extent.x,extent.y],"texel_world_size":.5,"branches":0,"middle_shift":shift,"road_source":"three newly generated hand-painted segments; original props remain separate"}
	var file:=FileAccess.open(ROOT+"ground_manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"\t"))
	print("NATURAL_GROUND_BAKED branches=0 density=.5")
	get_tree().quit()
class Ground extends Node2D:
	var extent:=Vector2.ZERO
	var white:Texture2D
	func _ready()->void:
		var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);white=ImageTexture.create_from_image(image)
	func _draw()->void:draw_texture_rect(white,Rect2(Vector2.ZERO,extent),false)
