class_name ReferenceWorldArt
extends RefCounted
## Fine native sprites, anchored independently from gameplay data.
const ROOT:="res://assets/world/reference_complete_20261011/ready/"
static var _manifest:Dictionary={}
static var _textures:Dictionary={}
static var _frames:Dictionary={}
static func active(id:String)->bool:
	return String(TableCache.main_world_map(id).get("art_profile",""))=="reference_complete" and ResourceLoader.exists(ROOT+id+"_floor.png")
static func manifest()->Dictionary:
	if _manifest.is_empty():_manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"sprite_manifest.json"))
	return _manifest
static func texture(id:String)->Texture2D:
	var root:=ROOT
	for map_id in ["lorin_wilds","maple_road"]:
		if id.begins_with(map_id+"_floor"):root=String(TableCache.main_world_map(map_id).get("reference_floor_root",ROOT))
	var path:=root+id+".png"
	if not _textures.has(path):_textures[path]=load(path)
	return _textures[path]
static func info(group:String,id:String)->Dictionary:
	return manifest().get(group,{}).get(id,{})
static func dimensions(group:String,id:String)->Vector2:
	var size:Array=info(group,id).get("size",[64,64])
	return Vector2(size[0],size[1])
static func building_size(id:String)->Vector2:
	return dimensions("props","ledger") if id=="gate" else dimensions("buildings",id)
static func building_texture(id:String)->Texture2D:
	return texture("ledger" if id=="gate" else id)
static func npc_frames(id:String)->SpriteFrames:
	if not manifest().npcs.has(id):return null
	if not _frames.has(id):
		var frames:=SpriteFrames.new()
		frames.remove_animation(&"default");frames.add_animation(&"idle")
		frames.add_frame(&"idle",texture(id))
		frames.set_animation_speed(&"idle",1)
		frames.set_meta("foot_registered",true);frames.set_meta("fine_art",true)
		frames.set_meta("canvas_height",320);frames.set_meta("world_height",160)
		frames.set_meta("visible_world_height",float(manifest().npcs[id].visible_world_height))
		_frames[id]=frames
	return _frames[id]
static func prepare()->void:
	for group in ["buildings","npcs","foliage","props"]:
		for id in manifest().get(group,{}):texture(id)
	for id in ["lorin_wilds","maple_road"]:
		for suffix in ["_floor","_floor_top","_floor_bottom"]:texture(id+suffix)
static func add_prop(world:Node2D,id:String,at:Vector2,group:="props",solid:=false)->Node2D:
	var prop:=Scenery.new()
	prop.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	prop.position=at;prop.art=texture(id);prop.display_size=dimensions(group,id)
	prop.solid=solid;prop.canopy=group=="foliage" and id not in ["bush","fern"]
	prop.name="Reference_"+id
	world.add_child(prop)
	return prop
static func scenery(map:Node)->void:
	var cfg:Dictionary=map.get("_main_cfg")
	var world:Node2D=map.get("_world")
	for row:Dictionary in cfg.get("reference_scenery",[]):
		add_prop(world,String(row.id),Vector2(row.at[0],row.at[1]),String(row.get("group","foliage")),bool(row.get("solid",false)))
class Scenery extends Node2D:
	var art:Texture2D
	var display_size:=Vector2(64,64)
	var solid:=false
	var canopy:=false
	var opacity:=1.0
	func _ready()->void:
		if solid:
			var body:=StaticBody2D.new();body.collision_layer=2;body.collision_mask=0
			var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=14
			shape.shape=circle;shape.position=Vector2(0,-6);body.add_child(shape);add_child(body)
	func _process(delta:float)->void:
		if not canopy:return
		var hero:=get_tree().get_first_node_in_group("reference_hero") as Node2D
		var behind:=hero!=null and Rect2(global_position-Vector2(display_size.x*.5,display_size.y),display_size).grow(-12).has_point(hero.global_position)
		opacity=move_toward(opacity,.35 if behind else 1.0,delta*3)
		queue_redraw()
	func _draw()->void:
		draw_set_transform(Vector2(0,2),0,Vector2(1,.25));draw_circle(Vector2.ZERO,minf(42,display_size.x*.24),Color("3e4b2f",.16));draw_set_transform(Vector2.ZERO)
		draw_texture_rect(art,Rect2(Vector2(-display_size.x*.5,-display_size.y),display_size),false,Color(1,1,1,opacity))
