extends Node
const ROOT := "res://assets/world/reference_complete_20261011/"
var manifest := {"buildings":{},"npcs":{},"foliage":{},"props":{}}
func trim(source:Image, keyed:=false)->Image:
	source.convert(Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var c:=source.get_pixel(x,y)
			if c.a<.5 or (keyed and c.r>.65 and c.b>.60 and c.g<.45):
				source.set_pixel(x,y,Color.TRANSPARENT)
	return source.get_region(source.get_used_rect())
func export_sprite(id:String,source:Image,world:Vector2,group:String)->void:
	var crop:=trim(source)
	var size:=Vector2i(roundi(world.x*2),roundi(world.y*2))
	crop.resize(size.x,size.y,Image.INTERPOLATE_NEAREST)
	crop.save_png(ROOT+"ready/"+id+".png")
	manifest[group][id]={"size":[world.x,world.y],"path":ROOT+"ready/"+id+".png","anchor":"bottom_center","source_to_world":.5}
func _ready()->void:
	G.SAVE_PATH="res://shots/reference_complete_20261011/export_save.json"
	G.save_locked=true
	var sizes:={"stable":Vector2(360,191),"barracks":Vector2(376,239),"storehouse":Vector2(395,249),"forge":Vector2(392,253),"archive":Vector2(332,329),"kennel":Vector2(400,230),"shrine":Vector2(240,164)}
	for id in sizes:export_sprite(id,Image.load_from_file(ROOT+"source/"+id+".png"),sizes[id],"buildings")
	var hall:=trim(Image.load_from_file("res://assets/world/reference_playable_20261010/source/hall.png"),true)
	export_sprite("hall",hall,Vector2(420,259),"buildings")
	if FileAccess.file_exists(ROOT+"source/construction.png"):
		var plot:=trim(Image.load_from_file(ROOT+"source/construction.png"))
		export_sprite("construction",plot,Vector2(240,145),"props")
	var sheet:=Image.load_from_file(ROOT+"source/npcs.png")
	var ids:=["npc_steward","npc_guard","npc_scribe","npc_keeper","npc_smith","npc_mentor","npc_stablemaster","npc_warden","npc_child"]
	# Generated figures extend past equal third-row gutters. Keep complete boots and spear.
	var npc_bounds:=[Rect2i(120,80,240,385),Rect2i(480,25,270,440),Rect2i(870,95,240,370),Rect2i(120,475,245,403),Rect2i(450,490,320,388),Rect2i(860,460,250,418),Rect2i(130,880,250,370),Rect2i(460,870,330,380),Rect2i(860,960,260,290)]
	var head_bounds:=[Rect2i(175,96,165,196),Rect2i(540,104,178,200),Rect2i(886,105,210,200),Rect2i(140,495,220,190),Rect2i(492,508,250,200),Rect2i(878,470,224,204),Rect2i(142,891,226,194),Rect2i(504,884,218,198),Rect2i(876,977,199,151)]
	for i in ids.size():
		var raw:=sheet.get_region(npc_bounds[i])
		var crop:=trim(raw)
		assert(crop.get_width()>0 and crop.get_height()>0,"Missing NPC "+ids[i])
		var height:=104 if ids[i]=="npc_child" else 172 if ids[i]=="npc_guard" else 144
		var width:=roundi(float(crop.get_width())/crop.get_height()*height)
		crop.resize(width,height,Image.INTERPOLATE_NEAREST)
		var canvas:=Image.create(320,320,false,Image.FORMAT_RGBA8)
		canvas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((320-width)/2,318-height))
		canvas.save_png(ROOT+"ready/"+ids[i]+".png")
		manifest.npcs[ids[i]]={"path":ROOT+"ready/"+ids[i]+".png","visible_world_height":height*.5,"body_world_height":52 if ids[i]=="npc_child" else 72,"canvas_height":320,"world_height":160,"idle_frames":1,"source_crop":[npc_bounds[i].position.x,npc_bounds[i].position.y,npc_bounds[i].size.x,npc_bounds[i].size.y]}
		var head:=trim(sheet.get_region(head_bounds[i]))
		var ratio:=minf(256.0/head.get_width(),256.0/head.get_height())
		head.resize(roundi(head.get_width()*ratio),roundi(head.get_height()*ratio),Image.INTERPOLATE_NEAREST)
		var portrait:=Image.create(256,256,false,Image.FORMAT_RGBA8)
		portrait.blit_rect(head,Rect2i(Vector2i.ZERO,head.get_size()),Vector2i((256-head.get_width())/2,256-head.get_height()))
		portrait.save_png(ROOT+"ready/"+ids[i]+"_portrait.png")
		manifest.npcs[ids[i]]["portrait_path"]=ROOT+"ready/"+ids[i]+"_portrait.png"
	if FileAccess.file_exists(ROOT+"source/foliage_alpha.png"):
		var leaves:=Image.load_from_file(ROOT+"source/foliage_alpha.png")
		var names:=["green_tree","gold_maple","red_maple","pine","bush","fern"]
		var heights:=[230,220,220,242,52,42]
		for i in 6:
			var cell:=Vector2i(leaves.get_width()/3,leaves.get_height()/2)
			var crop:=trim(leaves.get_region(Rect2i(Vector2i(i%3,i/3)*cell,cell)))
			var h:=float(heights[i]);var w:=float(crop.get_width())/crop.get_height()*h
			export_sprite(names[i],crop,Vector2(w,h),"foliage")
	if FileAccess.file_exists(ROOT+"source/props.png"):
		var props:=Image.load_from_file(ROOT+"source/props.png")
		var names:=["bridge","barricade","stonebox","nighttable","ledger","lantern","windchime","stele","rocks"]
		var heights:=[128,60,38,58,64,82,62,64,48]
		# Sheet gutters are uneven; explicit object bounds exclude neighbouring stools/posts.
		var bounds:=[Rect2i(190,10,265,376),Rect2i(595,105,410,250),Rect2i(1140,188,205,157),Rect2i(137,475,410,193),Rect2i(670,403,268,280),Rect2i(1143,374,223,337),Rect2i(192,686,249,316),Rect2i(670,720,265,285),Rect2i(1070,744,410,259)]
		for i in 9:
			var crop:=trim(props.get_region(bounds[i]))
			var h:=float(heights[i]);var w:=float(crop.get_width())/crop.get_height()*h
			if names[i]=="bridge":w=72
			export_sprite(names[i],crop,Vector2(w,h),"props")
	var sign:=Image.load_from_file("res://assets/world/sunny_travel_20261010/ready/signpost.png")
	export_sprite("signpost",sign,Vector2(61,64),"props")
	var file:=FileAccess.open(ROOT+"ready/sprite_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	print("REFERENCE_SPRITES_EXPORTED buildings=",manifest.buildings.size()," npcs=",manifest.npcs.size()," foliage=",manifest.foliage.size()," props=",manifest.props.size())
	get_tree().quit()
