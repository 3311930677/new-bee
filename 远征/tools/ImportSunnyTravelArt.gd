extends Node
## Native engine import: nearest sampling, shared palette and registered animation frames.
const ROOT:="res://assets/world/sunny_travel_20261010/"
var manifest:Dictionary={}
func _ready() -> void:
	G.SAVE_PATH="res://shots/world_art_samples_20261010/import_isolated_save.json"
	DirAccess.make_dir_recursive_absolute(ROOT+"ready")
	import_npc("steward",106)
	import_npc("guard",120)
	import_terrain()
	import_props()
	var file:=FileAccess.open(ROOT+"import_manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"\t"))
	print("SUNNY_IMPORT_OK assets=",manifest.size()," palette_limits=48/20/40")
	get_tree().quit()
func source(id:String) -> Image:
	var selected:=id+"_v2" if FileAccess.file_exists(ROOT+"source/"+id+"_v2.png") else id
	var image:=Image.new();var result:=image.load(ROOT+"source/"+selected+".png")
	if result!=OK:push_error("SUNNY_IMPORT_FAIL "+id);get_tree().quit(1)
	image.convert(Image.FORMAT_RGBA8)
	return image
func binary_alpha(image:Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color:=image.get_pixel(x,y)
			color.a=1 if color.a>=.5 else 0
			image.set_pixel(x,y,color if color.a>0 else Color.TRANSPARENT)
func quantize(image:Image,limit:int) -> void:
	var histogram:Dictionary={}
	for y in image.get_height():
		for x in image.get_width():
			var color:=image.get_pixel(x,y)
			if color.a<.5:continue
			var key:=color.to_rgba32();histogram[key]=int(histogram.get(key,0))+1
	var entries:Array=[]
	for key in histogram:
		var color:=Color.hex(key)
		entries.append({"color":Vector3(color.r,color.g,color.b),"weight":histogram[key]})
	var buckets:Array=[entries]
	while buckets.size()<limit:
		var choice:=-1;var best:=0.0;var axis:=0
		for i in buckets.size():
			var bucket:Array=buckets[i]
			if bucket.size()<2:continue
			var low:=Vector3.ONE;var high:=Vector3.ZERO;var weight:=0.0
			for entry in bucket:low=low.min(entry.color);high=high.max(entry.color);weight+=entry.weight
			var span:=high-low;var channel:=span.max_axis_index();var score:=span[channel]*sqrt(weight)
			if score>best:best=score;choice=i;axis=channel
		if choice<0:break
		var split:Array=buckets[choice];split.sort_custom(func(a,b):return a.color[axis]<b.color[axis])
		var total:=0
		for entry in split:total+=entry.weight
		var accumulated:=0;var index:=1
		for i in split.size()-1:
			accumulated+=split[i].weight
			if accumulated>=total*.5:index=i+1;break
		buckets[choice]=split.slice(0,index);buckets.append(split.slice(index))
	var palette:Array[Color]=[]
	for bucket in buckets:
		var sum:=Vector3.ZERO;var count:=0.0
		for entry in bucket:sum+=entry.color*entry.weight;count+=entry.weight
		var c:=sum/maxf(1,count);palette.append(Color(roundf(c.x*255)/255,roundf(c.y*255)/255,roundf(c.z*255)/255,1))
	var lookup:Dictionary={}
	for entry in entries:
		var winner:=0;var distance:=INF
		for i in palette.size():
			var p:=palette[i];var d:float=entry.color.distance_squared_to(Vector3(p.r,p.g,p.b))
			if d<distance:distance=d;winner=i
		lookup[Color(entry.color.x,entry.color.y,entry.color.z,1).to_rgba32()]=palette[winner]
	for y in image.get_height():
		for x in image.get_width():
			var color:=image.get_pixel(x,y)
			if color.a>=.5:image.set_pixel(x,y,lookup[color.to_rgba32()])
func save_asset(image:Image,id:String,limit:int) -> void:
	var result:=image.save_png(ROOT+"ready/"+id+".png")
	if result!=OK:push_error("SUNNY_IMPORT_FAIL save "+id);get_tree().quit(1)
	var colors:Dictionary={}
	for y in image.get_height():
		for x in image.get_width():
			var c:=image.get_pixel(x,y)
			if c.a>.5:colors[c.to_rgba32()]=true
	manifest[id]={"file":"ready/"+id+".png","size":[image.get_width(),image.get_height()],"colors":colors.size(),"palette_limit":limit}
func import_npc(id:String,visible_height:int) -> void:
	var original:=source(id);binary_alpha(original)
	var cell_w:=original.get_width()/4
	var bounds:=Rect2i()
	for i in 4:
		var frame:=original.get_region(Rect2i(i*cell_w,0,cell_w,original.get_height()))
		bounds=bounds.merge(frame.get_used_rect()) if bounds.has_area() else frame.get_used_rect()
	var atlas:=Image.create(512,128,false,Image.FORMAT_RGBA8)
	var width:=roundi(float(bounds.size.x)/bounds.size.y*visible_height)
	for i in 4:
		var frame:=original.get_region(Rect2i(i*cell_w+bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
		frame.resize(width,visible_height,Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(frame,Rect2i(0,0,width,visible_height),Vector2i(i*128+64-width/2,124-visible_height))
	quantize(atlas,48)
	var first_bounds:=atlas.get_region(Rect2i(0,0,128,128)).get_used_rect()
	var aligned:=Image.create(512,128,false,Image.FORMAT_RGBA8)
	aligned.blit_rect(atlas,Rect2i(0,0,512,128),Vector2i(0,124-first_bounds.end.y))
	atlas=aligned
	# Build controlled local motion from the approved keyframe; generative frame jitter is discarded.
	for i in range(1,4):atlas.blit_rect(atlas,Rect2i(0,0,128,128),Vector2i(i*128,0))
	for y in 76:
		for x in 128:atlas.set_pixel(128+x,y,Color.TRANSPARENT)
	atlas.blit_rect(atlas,Rect2i(0,0,128,76),Vector2i(128,-1))
	atlas.blit_rect(atlas,Rect2i(0,76,128,1),Vector2i(128,75))
	var cloth:=Rect2i(89,20,24,28) if id=="guard" else Rect2i(84,46,25,28)
	for y in range(cloth.position.y,cloth.end.y):
		for x in range(cloth.position.x,cloth.end.x):atlas.set_pixel(384+x,y,Color.TRANSPARENT)
	atlas.blit_rect(atlas,cloth,Vector2i(384+cloth.position.x-1,cloth.position.y))
	if id=="guard":
		for i in range(1,4):atlas.blit_rect(atlas,Rect2i(0,0,42,128),Vector2i(i*128,0))
	save_asset(atlas,id,48)
func import_terrain() -> void:
	var original:=source("terrain")
	var atlas:=Image.create(192,288,false,Image.FORMAT_RGBA8)
	var w:=original.get_width()/4;var h:=original.get_height()/6
	for y in 6:
		for x in 4:
			var tile:=original.get_region(Rect2i(x*w+2,y*h+2,w-4,h-4));tile.resize(48,48,Image.INTERPOLATE_NEAREST)
			atlas.blit_rect(tile,Rect2i(0,0,48,48),Vector2i(x*48,y*48))
	quantize(atlas,20)
	# All base-tile edges share their family's most frequent colour, including across variants.
	for row in 2:
		var frequencies:Dictionary={}
		for y in range(row*48,(row+1)*48):
			for x in 192:
				var key:=atlas.get_pixel(x,y).to_rgba32();frequencies[key]=int(frequencies.get(key,0))+1
		var best:=0;var key_value:=0
		for key in frequencies:
			if frequencies[key]>best:best=frequencies[key];key_value=key
		var edge:=Color.hex(key_value)
		for tile in 4:
			for n in 48:
				atlas.set_pixel(tile*48,row*48+n,edge);atlas.set_pixel(tile*48+47,row*48+n,edge)
				atlas.set_pixel(tile*48+n,row*48,edge);atlas.set_pixel(tile*48+n,row*48+47,edge)
	save_asset(atlas,"terrain",20)
func import_props() -> void:
	var original:=source("vegetation");binary_alpha(original)
	var w:=original.get_width()/3;var h:=original.get_height()/4
	var dimensions:Array[Vector2i]=[Vector2i(64,80),Vector2i(64,80),Vector2i(32,20),Vector2i(176,144),Vector2i(176,144),Vector2i(40,24),Vector2i(24,22),Vector2i(40,32),Vector2i(64,48),Vector2i(24,26),Vector2i(40,38),Vector2i(64,52)]
	var names:Array[String]=["trunk1","trunk2","leaves1","crown1","crown2","leaves2","rock1","rock2","rock3","rock4","rock5","rock6"]
	var region_list:Array=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source_regions.json")).vegetation
	for i in names.size():
		var r:Array=region_list[i].rect
		var cell:=original.get_region(Rect2i(r[0],r[1],r[2],r[3]))
		var art:=cell.get_region(cell.get_used_rect());art.resize(dimensions[i].x,dimensions[i].y,Image.INTERPOLATE_NEAREST);quantize(art,32)
		save_asset(art,names[i],32)
	var hall:=source("hall");binary_alpha(hall)
	hall=hall.get_region(hall.get_used_rect());hall.resize(192,224,Image.INTERPOLATE_NEAREST);quantize(hall,40)
	save_asset(hall,"hall",40)
	var sign_image:=Image.new();sign_image.load("res://image/main_world/art_v2/signpost.png")
	sign_image.convert(Image.FORMAT_RGBA8);binary_alpha(sign_image)
	sign_image=sign_image.get_region(sign_image.get_used_rect());sign_image.resize(92,96,Image.INTERPOLATE_NEAREST);quantize(sign_image,32)
	save_asset(sign_image,"signpost",32)
