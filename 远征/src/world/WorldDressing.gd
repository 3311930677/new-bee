extends RefCounted
## Deterministic scenery in unused ground, with no navigation or gameplay RNG changes.
const Layout := preload("res://src/explore/FlatGroundLayout.gd")
const Art := preload("res://src/explore/IllustratedScenery.gd")
const Presentation := preload("res://src/world/WorldPresentation.gd")
const KitV4 := preload("res://src/ui/KitV4.gd")
const PROC := "res://image/map_proc/"
const ROCK := "res://image/main_world/broken_slope_props/"
const REF := "res://assets/world/reference_complete_20261011/ready/"

static func palette(cfg: Dictionary, map_id: String = "") -> Array:
	if cfg.get("name","")==TableCache.main_world_map("shenyuan_port").get("name","") or map_id == "shenyuan_port":
		return [[REF+"stonebox.png",Vector2(54,40)],[REF+"lantern.png",Vector2(40,74)],[REF+"nighttable.png",Vector2(96,46)]]
	if map_id in ["broken_slope", "stele_cavern"]:
		return [
			["f02a_broken_stele_1", Vector2(68, 98)],
			["f02a_broken_stele_2", Vector2(64, 92)],
			["f02a_fallen_tablet", Vector2(84, 58)],
			["f02b_moss_boulder_1", Vector2(96, 64)],
			["f02b_moss_boulder_2", Vector2(86, 56)],
			["f02b_stone_lantern", Vector2(52, 82)],
		]
	if map_id in ["old_salt_road", "tideflat", "tidal_gate"]:
		return [
			["f03a_salt_crystal_1", Vector2(82, 68)],
			["f03a_salt_crystal_2", Vector2(72, 60)],
			["f03a_salt_cart", Vector2(96, 74)],
			["f03b_wood_post_1", Vector2(48, 78)],
			["f03b_wood_post_2", Vector2(52, 74)],
			["f03b_salt_bucket", Vector2(50, 54)],
		]
	if map_id == "red_sand_route":
		return [
			["f04a_sandstone_1", Vector2(112, 86)],
			["f04a_sandstone_2", Vector2(92, 72)],
			["f04a_camel_bones", Vector2(88, 60)],
			["f04b_dry_shrub_1", Vector2(68, 60)],
			["f04b_dry_shrub_2", Vector2(64, 56)],
			["f04b_caravan_post", Vector2(56, 92)],
		]
	if map_id in ["rift_mine_road", "rift_mine_vault"]:
		return [
			["f05b_ore_crystal_1", Vector2(80, 74)],
			["f05b_ore_crystal_2", Vector2(72, 66)],
			["f05a_mine_timber", Vector2(88, 92)],
			["f05a_mine_cart", Vector2(84, 70)],
			["f05b_pickaxe_crate", Vector2(68, 60)],
		]
	if map_id in ["abyss_ring", "stele_entry", "stele_resonance", "stele_core"]:
		return [
			["f06b_obsidian_rock_1", Vector2(92, 64)],
			["f06b_obsidian_rock_2", Vector2(82, 54)],
			["f06a_abyss_pillar_1", Vector2(60, 102)],
			["f06a_abyss_pillar_2", Vector2(60, 98)],
			["f06a_rune_slab", Vector2(74, 68)],
			["f06b_void_brazier", Vector2(58, 84)],
		]
	match String(cfg.get("theme","forest")):
		"desert":
			return [["f04a_sandstone_1",Vector2(112,86)],
				["f04b_dry_shrub_1",Vector2(68,60)],
				["f04a_sandstone_2",Vector2(88,64)],
				[PROC+"046_deco_desert_drywell.png",Vector2(104,104)]]
		"snow","glacier":
			return [[PROC+"035_deco_snow_pine.png",Vector2(146,172)],
				[PROC+"037_deco_snow_snowdrift.png",Vector2(110,68)],
				[PROC+"036_deco_snow_icecrystal.png",Vector2(66,80)]]
		"tomb":
			return [["f05b_ore_crystal_1",Vector2(80,74)],
				["f05b_ore_crystal_2",Vector2(72,66)],
				["f02a_broken_stele_1",Vector2(64,94)]]
		"abyss":
			return [["f06b_obsidian_rock_1",Vector2(92,64)],
				["f06b_obsidian_rock_2",Vector2(82,54)],
				["f06a_abyss_pillar_1",Vector2(60,100)]]
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
	var sources:=palette(cfg, String(map._main_map_id))
	var routes:=Layout.sample_routes(cfg.get("flat_routes",[]))
	var count:=0
	var compact:=String(map._main_map_id) in ["shenyuan_port","tidal_gate","stele_cavern","rift_mine_vault"]
	var spacing:=88 if compact else 108
	var limit:=clampi(ceili(extent.x*extent.y/26000.0),24,100)
	var city:=bool(cfg.get("city",false))
	if city:limit=maxi(16,ceili(extent.y/220)*2)
	var occupied: Array[Rect2]=[]
	for row in cfg.get("illustrated_scenery",[]):
		var dimensions:=Vector2(row.size[0],row.size[1])*Presentation.SCENERY_ENLARGEMENT
		occupied.append(Rect2(Vector2(row.at[0]-dimensions.x*.5,row.at[1]-dimensions.y),dimensions))
	var candidates: Array[Dictionary]=[]
	# Anchor a small landmark near each stretch of the road before filling distant margins.
	if not city and not compact:
		for y in range(300,int(extent.y)-100,200):
			for fraction in [.35,.68]:
				candidates.append({"at":Vector2(extent.x*fraction,y),"rank":-1.0,"band":int(y/220),"anchor":true})
	for y in range(160,int(extent.y)-48,spacing):
		for x in range(64,int(extent.x)-48,spacing):
			candidates.append({"at":Vector2(x,y),"rank":rng.randf(),"band":int(y/220)})
	candidates.sort_custom(func(a,b):return a.band<b.band if a.band!=b.band else a.rank<b.rank)
	var bands: Dictionary={}
	var wells:=0
	for candidate in candidates:
		if count>=limit:break
		if int(bands.get(candidate.band,0))>=(2 if city else 7):continue
		var source: Array=sources[rng.randi_range(0,sources.size()-1)]
		if String(source[0]).contains("drywell") and wells>0:source=sources[0]
		var size: Vector2=source[1]*rng.randf_range(.9,1.15)
		var anchor:=bool(candidate.get("anchor",false))
		if anchor:
			var theme:=String(cfg.get("theme","forest"))
			var left:=float(candidate.at.x)<extent.x*.5
			source=sources[2] if theme=="desert" else sources[0 if left else 2] if theme in ["snow","glacier"] else sources[0]
			size=Vector2(92,70) if theme=="desert" else (Vector2(148,174) if left else Vector2(70,90)) if theme in ["snow","glacier"] else source[1]*.9
		if compact:size*=.55
		var at: Vector2=candidate.at+Vector2(rng.randf_range(-20,20),rng.randf_range(-22,22))
		if anchor:
			for offset in [Vector2.ZERO,Vector2(0,48),Vector2(0,-48),Vector2(-48,0),Vector2(48,0)]:
				if clear(map,candidate.at+offset,size,routes,occupied):at=candidate.at+offset;break
		if not clear(map,at,size,routes,occupied):continue
		var key_or_path := String(source[0])
		var texture: Texture2D = KitV4.commercial_tex(key_or_path) if key_or_path.begins_with("f0") else G.visual_texture(key_or_path)
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
		if String(source[0]).contains("drywell"):wells+=1
		bands[candidate.band]=int(bands.get(candidate.band,0))+1
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
			if at.distance_to(p)<minf(float(route.width)*.5,52)+size.x*.28+18:return false
	var spawn: Array=cfg.get("spawn",[480,1050])
	if at.distance_to(Vector2(spawn[0],spawn[1]))<130:return false
	for exit in cfg.get("exits",[]):
		var pos: Array=exit.get("at",[])
		if pos.size()>=2 and at.distance_to(Vector2(pos[0],pos[1]))<120:return false
	for row in cfg.get("entities",{}).values():
		var pos: Array=row.get("at",[])
		if pos.size()>=2 and rect.grow(24).has_point(Vector2(pos[0],pos[1])):return false
	for entity in map._quest_entities:
		if is_instance_valid(entity) and rect.grow(24).has_point(entity.position):return false
	for pos in cfg.get("city_npc_positions",{}).values():
		if rect.grow(96).has_point(Vector2(pos[0],pos[1])):return false
	for id in cfg.get("city_building_positions",{}):
		var pos: Array=cfg.city_building_positions[id]
		var source: Array=cfg.get("city_building_sizes",{}).get(id,[240,200])
		var dimensions:=Vector2(source[0],source[1])*Presentation.BUILDING_ENLARGEMENT
		if rect.intersects(Rect2(Vector2(pos[0]-dimensions.x*.5-24,pos[1]-dimensions.y),dimensions+Vector2(48,72))):return false
	for blocker in cfg.get("block_rects",[]):
		if Rect2(blocker[0],blocker[1],blocker[2],blocker[3]).has_point(at):return false
	if map._in_river_zone(at,size.x*.5):return false
	# These props have no colliders; leave each enemy visible without reserving its entire patrol disk.
	for monster in map._monsters:
		if is_instance_valid(monster) and rect.grow(16).has_point(monster.position):return false
	return true
