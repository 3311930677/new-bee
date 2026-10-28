extends RefCounted
## Deterministic scenery in unused ground, with no navigation or gameplay RNG changes.
const Layout := preload("res://src/explore/FlatGroundLayout.gd")
const Art := preload("res://src/explore/IllustratedScenery.gd")
const Presentation := preload("res://src/world/WorldPresentation.gd")
const PROC := "res://image/map_proc/"
const ROCK := "res://image/main_world/broken_slope_props/"
const REF := "res://assets/world/reference_complete_20261011/ready/"

static func palette(cfg: Dictionary) -> Array:
	if cfg.get("name","")==TableCache.main_world_map("shenyuan_port").get("name",""):
		return [[REF+"stonebox.png",Vector2(54,40)],[REF+"lantern.png",Vector2(40,74)],[REF+"nighttable.png",Vector2(96,46)]]
	match String(cfg.get("theme","forest")):
		"desert":
			return [[PROC+"045_deco_desert_sandstone.png",Vector2(110,100)],
				[PROC+"044_deco_desert_cactus.png",Vector2(90,112)],
				[PROC+"045_deco_desert_sandstone.png",Vector2(76,64)]]
		"snow","glacier":
			return [[PROC+"035_deco_snow_pine.png",Vector2(146,172)],
				[PROC+"037_deco_snow_snowdrift.png",Vector2(110,68)],
				[PROC+"036_deco_snow_icecrystal.png",Vector2(66,80)]]
		"tomb","abyss":
			return [[ROCK+"boulder_a.png",Vector2(118,68)],
				[ROCK+"boulder_b.png",Vector2(96,55)],
				[ROCK+"stele_mid_b.png",Vector2(56,94)]]
		_:
			return [[REF+"bush.png",Vector2(55,64)],[REF+"fern.png",Vector2(44,52)],
				[REF+"rocks.png",Vector2(90,58)]]

static func setup(map: Node) -> void:
	var cfg: Dictionary=map._main_cfg
	var extent: Vector2=map._map_extent()
	var layer:=Node2D.new()
	layer.name="WorldDressing"
	layer.y_sort_enabled=true
	layer.texture_filter=Presentation.sampling()
	map._world.add_child(layer)
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash("dressing_20261026_"+String(map._main_map_id))
	var sources:=palette(cfg)
	var routes:=Layout.sample_routes(cfg.get("flat_routes",[]))
	var count:=0
	var compact:=String(map._main_map_id) in ["shenyuan_port","tidal_gate","stele_cavern","rift_mine_vault"]
	var spacing:=56 if compact else 112
	var limit:=28 if String(cfg.get("theme",""))=="desert" else 16
	if bool(cfg.get("city",false)):limit=10
	var occupied: Array[Rect2]=[]
	for row in cfg.get("illustrated_scenery",[]):
		occupied.append(Rect2(Vector2(row.at[0]-row.size[0]*.5,row.at[1]-row.size[1]),Vector2(row.size[0],row.size[1])))
	var candidates: Array[Dictionary]=[]
	for y in range(160,int(extent.y)-48,spacing):
		for x in range(64,int(extent.x)-48,spacing):
			candidates.append({"at":Vector2(x,y),"rank":rng.randf()})
	candidates.sort_custom(func(a,b):return a.rank<b.rank)
	for candidate in candidates:
		if count>=limit:break
		var source: Array=sources[rng.randi_range(0,sources.size()-1)]
		var size: Vector2=source[1]*rng.randf_range(.9,1.15)
		if compact:size*=.55
		var at: Vector2=candidate.at+Vector2(rng.randf_range(-20,20),rng.randf_range(-22,22))
		if not clear(map,at,size,routes,occupied):continue
		var texture:=G.visual_texture(String(source[0]))
		if texture==null:continue
		var prop:=Art.Prop.new()
		prop.name="Dressing_%02d"%count
		prop.art=texture
		prop.position=at
		prop.display_size=size
		prop.canopy=size.y>110
		prop.texture_filter=Presentation.sampling()
		layer.add_child(prop)
		occupied.append(Rect2(at-Vector2(size.x*.5,size.y),size).grow(16))
		count+=1
	layer.set_meta("prop_count",count)
	layer.set_meta("map_id",String(map._main_map_id))

static func clear(map: Node,at: Vector2,size: Vector2,routes: Array,occupied: Array[Rect2]) -> bool:
	var cfg: Dictionary=map._main_cfg
	var rect:=Rect2(at-Vector2(size.x*.5,size.y),size)
	if not Rect2(Vector2(16,32),map._map_extent()-Vector2(32,48)).encloses(rect):return false
	for other in occupied:
		if rect.intersects(other):return false
	for route in routes:
		for p: Vector2 in route.points:
			if at.distance_to(p)<minf(float(route.width)*.5,52)+size.x*.4+26:return false
	var spawn: Array=cfg.get("spawn",[480,1050])
	if at.distance_to(Vector2(spawn[0],spawn[1]))<130:return false
	for exit in cfg.get("exits",[]):
		var pos: Array=exit.get("at",[])
		if pos.size()>=2 and at.distance_to(Vector2(pos[0],pos[1]))<120:return false
	for row in cfg.get("entities",{}).values():
		var pos: Array=row.get("at",[])
		if pos.size()>=2 and rect.grow(72).has_point(Vector2(pos[0],pos[1])):return false
	for pos in cfg.get("city_npc_positions",{}).values():
		if rect.grow(96).has_point(Vector2(pos[0],pos[1])):return false
	for id in cfg.get("city_building_positions",{}):
		var pos: Array=cfg.city_building_positions[id]
		var dimensions: Array=cfg.get("city_building_sizes",{}).get(id,[240,200])
		if rect.intersects(Rect2(Vector2(pos[0]-dimensions[0]*.5-24,pos[1]-dimensions[1]),Vector2(dimensions[0]+48,dimensions[1]+100))):return false
	for blocker in cfg.get("block_rects",[]):
		if Rect2(blocker[0],blocker[1],blocker[2],blocker[3]).has_point(at):return false
	if map._in_river_zone(at,size.x*.5):return false
	if map._foot_hits_patrol(at,1.3):return false
	return true
