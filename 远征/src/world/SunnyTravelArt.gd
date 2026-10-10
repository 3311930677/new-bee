class_name SunnyTravelArt
extends RefCounted
## 晴野枫城样板：程序绘制的亮色地表（草、沙路、广场、河道与石桥）和框景树。只改画面，碰撞与玩法数据由地图配置决定。
const ROOT:="res://assets/world/sunny_travel_20261010/ready/"
const Layout:=preload("res://src/explore/FlatGroundLayout.gd")
const FlatMapGround:=preload("res://src/explore/FlatMapGround.gd")
static var _textures:Dictionary={}
static var _frames:Dictionary={}
static var _grounds:Dictionary={}
static func active(map_id:String) -> bool:
	if String(TableCache.main_world_map(map_id).get("art_profile",""))=="reference_complete":return false
	return map_id in ["lorin_wilds","maple_road"] and not bool(G.get_meta("sunny_sample_disabled",false)) and ResourceLoader.exists(ROOT+"terrain.png")
static func texture(id:String) -> Texture2D:
	if not _textures.has(id):_textures[id]=load(ROOT+id+".png")
	return _textures[id]
static func npc_frames(id:String) -> SpriteFrames:
	if id not in ["npc_steward","npc_guard"]:return null
	if not _frames.has(id):
		var frames:=SpriteFrames.new();frames.remove_animation(&"default");frames.add_animation(&"idle")
		frames.set_animation_loop(&"idle",true);frames.set_animation_speed(&"idle",5)
		var source:=texture("steward" if id=="npc_steward" else "guard")
		for i in 4:
			var frame:=AtlasTexture.new();frame.atlas=source;frame.region=Rect2(i*128,0,128,128);frame.filter_clip=true;frames.add_frame(&"idle",frame)
		_frames[id]=frames
	return _frames[id]
## 广场与河道随地图配置走；烘焙清单用它们与路线一起做签名，改配置即自动失效。
static func extras_for(cfg:Dictionary) -> Dictionary:
	return {"plazas":cfg.get("plazas",[]),"river":cfg.get("river",{})}
static func route_hash(routes:Array,extras:Dictionary) -> String:
	return JSON.stringify([routes,extras]).sha256_text()
static func ground(id:String,dimensions:Vector2,routes:Array,extras:Dictionary={}) -> Texture2D:
	if _grounds.has(id):return _grounds[id]
	var floor_manifest:=ROOT+"ground_manifest.json"
	if not bool(G.get_meta("sunny_baking",false)) and FileAccess.file_exists(floor_manifest):
		var entries:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(floor_manifest))
		if entries.has(id) and entries[id].route_hash==route_hash(routes,extras) and entries[id].extent==[dimensions.x,dimensions.y] and ResourceLoader.exists(ROOT+id+"_floor.png"):
			_grounds[id]=load(ROOT+id+"_floor.png");return _grounds[id]
	_grounds[id]=ImageTexture.create_from_image(paint(dimensions,routes,extras,hash(id)))
	return _grounds[id]
static func prepare() -> void:
	for id in ["steward","guard","hall","signpost","trunk1","trunk2","crown1","crown2","leaves1","leaves2","rock1","rock2","rock3","rock4","rock5","rock6"]:texture(id)
	for id in ["lorin_wilds","maple_road"]:
		var row:=TableCache.main_world_map(id)
		ground(id,Vector2(float(row.map_cols)*48,float(row.map_rows)*48),row.flat_routes,extras_for(row))
## 地表绘制：草地大块明暗 + 细点与小花；沙路边缘按噪声起伏并带草穗过渡；广场与河道石桥最后压上。
static func paint(dimensions:Vector2,routes:Array,extras:Dictionary,salt:int) -> Image:
	var w:=roundi(dimensions.x)
	var h:=roundi(dimensions.y)
	var road:=_road_field(dimensions,routes,w,h)
	var edge:=_noise(salt+1,.028,3)
	var fine:=_noise(salt+2,.11,1)
	var grass:=_noise(salt+3,.022,2)
	var sand:=_noise(salt+4,.035,2)
	var water:=_noise(salt+5,.06,2)
	# 大尺度蜿蜒：长路段（如城内主街）也不会退化成尺子画的直边。
	var meander:=_noise(salt+6,.011,2)
	var grass_a:=Color("9dc04f");var grass_b:=Color("b8d863");var grass_c:=Color("7fae43");var grass_d:=Color("4f8030")
	var flower_w:=Color("f7f3de");var flower_y:=Color("f4cb4e")
	var sand_a:=Color("e6c884");var sand_b:=Color("f2dc9d");var sand_c:=Color("cba766");var pebble:=Color("b8a474");var dry_c:=Color("c9ab5a")
	var plaza_a:=Color("f0e3b8");var plaza_b:=Color("f6ecc9");var plaza_line:=Color("d7c48f");var ring_c:=Color("d8b45c")
	var water_a:=Color("3f8ea0");var water_m:=Color("5aaab9");var water_b:=Color("86cbd0");var water_hi:=Color("e4f6ef");var bank_c:=Color("b7b48a")
	var stone_a:=Color("cfc4a7");var stone_line:=Color("7f7561");var stone_hi:=Color("e6dcc2")
	var image:=Image.create(w,h,false,Image.FORMAT_RGBA8)
	# 1. 草地：大块明暗、单点深绿、2×2 小花，避免整张平涂。
	for y in h:
		for x in w:
			var hs:=_hash(x,y,salt)
			var g:=grass.get_noise_2d(x,y)
			var c:=grass_a
			if g<-.24:c=grass_c
			elif g>.3:c=grass_b
			if hs%37==0:c=grass_b
			elif hs%53==1 and g<0.0:c=grass_c
			if hs%157==5:c=grass_d
			var fh:=_hash(x>>1,y>>1,salt+9)
			if fh%180==3:c=flower_w if fh%2==0 else flower_y
			image.set_pixel(x,y,c)
	# 2. 沙路：边缘带噪声起伏；外侧 4px 为草穗过渡，不做直边色带。
	for y in h:
		for x in w:
			var i:=y*w+x
			if road[i]>20.0:continue
			var hs:=_hash(x,y,salt)
			var s:=road[i]-(edge.get_noise_2d(x,y)*8.0+fine.get_noise_2d(x,y)*2.5+meander.get_noise_2d(x,y)*6.0)
			if s<0.0:
				var sn:=sand.get_noise_2d(x,y)
				var c:=sand_a
				if sn>.32:c=sand_b
				elif sn<-.42:c=sand_c
				if hs%83==5:c=sand_c
				elif hs%211==17:c=pebble
				image.set_pixel(x,y,c)
			elif s<4.0 and hs%3!=0:
				image.set_pixel(x,y,dry_c if hs%2==0 else grass_c)
			elif s<10.0 and hs%7==0:
				image.set_pixel(x,y,grass_d)
	# 3. 广场：奶油色铺面、淡接缝与金黄草缘。
	for plaza_v in extras.get("plazas",[]):
		var plaza:=plaza_v as Array
		var r:=Rect2(float(plaza[0]),float(plaza[1]),float(plaza[2]),float(plaza[3]))
		var box:=r.grow(22.0)
		for y in range(maxi(0,floori(box.position.y)),mini(h,ceili(box.end.y))):
			for x in range(maxi(0,floori(box.position.x)),mini(w,ceili(box.end.x))):
				var pd:=_rect_distance(Vector2(float(x),float(y)),r)+edge.get_noise_2d(x,y)*5.0
				if pd>=22.0:continue
				var hs:=_hash(x,y,salt)
				if pd<0.0:
					var c:=plaza_a if sand.get_noise_2d(x,y)>-.2 else plaza_b
					if (x-int(r.position.x))%48==0 or (y-int(r.position.y))%48==0:
						if hs%3!=0:c=plaza_line
					elif hs%97==3:c=plaza_line
					image.set_pixel(x,y,c)
				elif pd<16.0:
					image.set_pixel(x,y,ring_c if hs%5!=0 else dry_c)
				else:
					image.set_pixel(x,y,grass_d if hs%2==0 else grass_c)
	# 4. 河道：横贯地图的枫溪，岸边碎石过渡。
	var river:Dictionary=extras.get("river",{})
	if not river.is_empty():
		var ry:=float(river.get("y",0.0))
		var rh:=float(river.get("half",16.0))
		var crossing:=river.get("crossing",[0,0]) as Array
		for x in w:
			var center:=_river_center(float(x),ry)
			for y in range(maxi(0,floori(center-rh-8.0)),mini(h,ceili(center+rh+8.0))):
				var rs:=absf(float(y)-center)-rh-edge.get_noise_2d(x,y)*1.5
				if rs>=9.0:continue
				var hs:=_hash(x,y,salt)
				var c:=bank_c
				if rs<0.0:
					var wn:=water.get_noise_2d(float(x)*.6,float(y)*1.5)
					c=water_b if wn>.22 else (water_a if wn<-.3 else water_m)
					if (x+y*2)%41<2 and hs%3==0:c=water_hi
				elif rs<4.0:
					c=bank_c if hs%3!=0 else grass_c
				else:
					c=grass_d if hs%3==0 else grass_c
				image.set_pixel(x,y,c)
		# 5. 石桥：只压在河道与大路交叠的 crossing 段上，桥面有板缝。
		var xa:=int(crossing[0])
		var xb:=int(crossing[1])
		for x in range(xa,xb):
			var center2:=_river_center(float(x),ry)
			for y in range(floori(center2-rh-3.0),ceili(center2+rh+3.0)):
				if y<0 or y>=h:continue
				var rs2:=absf(float(y)-center2)-rh
				var c2:=stone_a
				if (x-xa)%16==0 or x==xb-1:c2=stone_line
				elif y%9==0:c2=stone_line
				elif _hash(x,y,salt)%29==4:c2=stone_hi
				if rs2>-1.0:c2=stone_line
				image.set_pixel(x,y,c2)
	return image
static func _river_center(x:float,river_y:float) -> float:
	return river_y+sin(x*.011+1.3)*2.0+sin(x*.034)*1.0
static func _road_field(dimensions:Vector2,routes:Array,w:int,h:int) -> PackedFloat32Array:
	var field:=PackedFloat32Array()
	field.resize(w*h)
	field.fill(1.0e6)
	for route:Dictionary in Layout.sample_routes(FlatMapGround._surface_routes(dimensions,routes)):
		var half:=float(route.width)*.5
		var reach:=half+16.0
		for p:Vector2 in route.points:
			for y in range(maxi(0,floori(p.y-reach)),mini(h,ceili(p.y+reach)+1)):
				for x in range(maxi(0,floori(p.x-reach)),mini(w,ceili(p.x+reach)+1)):
					var d:=Vector2(float(x),float(y)).distance_to(p)-half
					if d<field[y*w+x]:field[y*w+x]=d
	return field
static func _rect_distance(p:Vector2,r:Rect2) -> float:
	var c:=r.get_center()
	var q:=(p-c).abs()-r.size*.5
	return Vector2(maxf(q.x,0.0),maxf(q.y,0.0)).length()+minf(maxf(q.x,q.y),0.0)
static func _noise(seed_value:int,freq:float,octaves:int) -> FastNoiseLite:
	var n:=FastNoiseLite.new()
	n.seed=seed_value
	n.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency=freq
	n.fractal_octaves=octaves
	return n
static func _hash(x:int,y:int,salt:int) -> int:
	var k:=salt%1000003
	return absi((x*73856093)^(y*19349663)^(k*83492791))%100000
static func construction(c:CanvasItem,w:float,h:float) -> void:
	# Unbuilt plots stay unbuilt; show solid foundations and materials rather than a ghost house.
	c.draw_rect(Rect2(-w*.42,-h*.32,w*.84,h*.72),Color("8c886a"))
	c.draw_rect(Rect2(-w*.40,-h*.30,w*.80,h*.66),Color("b3a98a"))
	for x in [-w*.38,w*.38]:
		for y in [-h*.28,h*.32]:
			c.draw_rect(Rect2(x-3,y-16,6,18),Color("654a32"));c.draw_rect(Rect2(x-2,y-16,2,15),Color("91704d"))
	for i in 3:
		c.draw_rect(Rect2(-w*.25+i*10,h*.04,9,7),Color("716c60"));c.draw_rect(Rect2(-w*.24+i*10,h*.04,7,3),Color("a49d82"))
	for i in 3:c.draw_rect(Rect2(w*.10,h*.10+i*6,w*.20,4),Color("85633e"))
	# Small tied ochre pennant communicates a worksite, not an open building.
	c.draw_colored_polygon(PackedVector2Array([Vector2(-w*.38,-h*.28-15),Vector2(-w*.38+18,-h*.28-12),Vector2(-w*.38,-h*.28-7)]),Color("a68e55"))

class Ground extends Node2D:
	var texture:Texture2D
	var extent:Vector2
	var routes:Array
	func setup(id:String,dimensions:Vector2,centerlines:Array,extras:Dictionary={}) -> void:
		extent=dimensions;routes=centerlines.duplicate(true);texture=SunnyTravelArt.ground(id,dimensions,centerlines,extras);z_index=-20;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:draw_texture_rect(texture,Rect2(Vector2.ZERO,extent),false)

class Scenery extends Node2D:
	var kind:="tree"
	var variant:=1
	var tint:=Color.WHITE
	func _ready() -> void:texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		if kind=="tree":
			draw_texture_rect(SunnyTravelArt.texture("leaves%d"%variant),Rect2(-20,-4,40,24),false)
			draw_set_transform(Vector2(4,2),0,Vector2(1,.28));draw_circle(Vector2.ZERO,27,Color("483b2e",.35));draw_set_transform(Vector2.ZERO)
			draw_texture_rect(SunnyTravelArt.texture("trunk%d"%variant),Rect2(-32,-80,64,80),false)
			draw_texture_rect(SunnyTravelArt.texture("crown%d"%variant),Rect2(-88,-188,176,144),false,tint)
		else:
			for i in 3:
				var tex:=SunnyTravelArt.texture("rock%d"%(1+posmod(i+variant,6)))
				var size:=tex.get_size();draw_texture_rect(tex,Rect2(Vector2(-48+i*30,-size.y+posmod(i,2)*8),size),false)
## 树冠（相对树根）与建筑底座+立面的矩形是否重叠；城镇里树不能盖住建筑和它的入口。
static func _clear_of_buildings(map:Node,p:Vector2) -> bool:
	var crown:=Rect2(p.x-88,p.y-188,176,144)
	var positions:Dictionary=map._main_cfg.get("city_building_positions",{})
	for id in positions:
		var at:Vector2=map._cfg_point(positions[id],Vector2.ZERO)
		if crown.intersects(Rect2(at.x-96,at.y-150,192,160)):return false
	return true
## 框景树：左右两侧成排，城镇留出街区与广场；枫林两侧是林墙。只画不挡，树干避开路面与怪物巡逻区。
static func scenery(map:Node) -> void:
	var id:=String(map._main_map_id)
	var river:Dictionary=map._main_cfg.get("river",{})
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash("sunny_frame_"+id)
	var autumn:=[Color("ff9a5c"),Color("ffc27a"),Color("f0857a"),Color("ffffff")]
	for y in range(96,1200,112):
		for side in 2:
			var x:=rng.randf_range(60.0,196.0) if side==0 else rng.randf_range(764.0,904.0)
			var p:=Vector2(x,float(y)+rng.randf_range(-22.0,22.0))
			if not river.is_empty() and absf(p.y-float(river.get("y",0.0)))<56.0:continue
			if map._foot_hits_road(p,1) or map._foot_hits_patrol(p,1) or not _clear_of_buildings(map,p):continue
			var tree:=Scenery.new()
			tree.variant=1+rng.randi_range(0,1)
			tree.tint=autumn[rng.randi_range(0,autumn.size()-1)] if id=="maple_road" else Color.WHITE
			tree.position=p
			map._world.add_child(tree)
	if id=="lorin_wilds":
		# 城内两株枫：压住仓廪与兽栏之间的街角，给广场一个红金框。
		for p in [Vector2(110,680),Vector2(840,660)]:
			if not _clear_of_buildings(map,p):continue
			var maple:=Scenery.new()
			maple.variant=1+rng.randi_range(0,1)
			maple.tint=autumn[rng.randi_range(0,2)]
			maple.position=p
			map._world.add_child(maple)
	else:
		for p in [Vector2(280,1190),Vector2(730,1090)]:
			if map._foot_hits_road(p,1) or map._foot_hits_patrol(p,1):continue
			var rock:=Scenery.new();rock.kind="rock";rock.position=p;map._world.add_child(rock)
