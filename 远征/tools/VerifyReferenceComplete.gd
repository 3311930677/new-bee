extends Node
var checks:=0
var failures:=0
func check(ok:bool,words:String)->void:
	checks+=1
	if not ok:failures+=1;push_error("REFERENCE_COMPLETE_FAIL "+words)
func frames(count:=4)->void:
	for i in count:await get_tree().process_frame
func fixture()->void:
	G._init_state_defaults();G.save_locked=false;G.selected_role="zs";G.player_name="行旅人";G.prog.level=12
	G.collect_pet("pet_rockturtle");G.prog.tips_seen={"deploy":true}
func spawn_map(id:String)->MapScene:
	var run:=RunState.new();run.setup({"role_id":"zs","theme":"forest","level":12,"active_pet":"pet_rockturtle","potions":2,"seed":17})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":id,"run":run,"node":{"type":"normal","layer":0,"index":0}}
	var map:MapScene=preload("res://src/explore/MapScene.tscn").instantiate();add_child(map);await frames()
	map.set_process(false);map.set_physics_process(false)
	if map._city_content!=null:map._city_content.set_process(false)
	for mon in map._monsters:mon.set_process(false);mon.set_physics_process(false)
	for entity in map._quest_entities:entity.set_process(false)
	await get_tree().physics_frame
	return map
func navigation(map:MapScene)->AStarGrid2D:
	var grid:=AStarGrid2D.new();grid.region=Rect2i(3,3,int(map._main_cfg.map_cols)*3-5,int(map._main_cfg.map_rows)*3-5)
	grid.cell_size=Vector2(16,16);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	var query:=PhysicsShapeQueryParameters2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(30,26);query.shape=rect;query.collision_mask=2
	var space:=map._player.get_world_2d().direct_space_state
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			query.transform=Transform2D(0,Vector2(x*16,y*16+8))
			grid.set_point_solid(Vector2i(x,y),not space.intersect_shape(query,1).is_empty())
	return grid
func reachable(grid:AStarGrid2D,start:Vector2,end:Vector2)->bool:
	var a:=Vector2i(roundi(start.x/16),roundi(start.y/16));var b:=Vector2i(roundi(end.x/16),roundi(end.y/16))
	return grid.is_in_boundsv(a) and grid.is_in_boundsv(b) and not grid.is_point_solid(a) and not grid.is_point_solid(b) and not grid.get_id_path(a,b).is_empty()
func _ready()->void:
	G.SAVE_PATH="res://shots/reference_complete_20261011/verify_isolated_save.json";G.set_meta("ui_review_mode",true)
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/reference_complete_20261011/baseline_main_world_maps.json"))
	for id in ["lorin_wilds","maple_road"]:
		fixture();var map:=await spawn_map(id);var cfg:Dictionary=map._main_cfg
		check(ReferenceWorldArt.active(id),id+" production profile enabled")
		check(map._flat_ground!=null and map._flat_ground.routes==cfg.flat_routes,id+" minimap routes match world")
		check(cfg.flat_routes.size()==1,id+" single main path, no branches")
		check(not bool(cfg.get("minimap_show_roads",true)),id+" road diagram disabled")
		var thumbnail:Image=map._minimap._cartography.terrain_thumbnail(map).get_image()
		var road_pixels:=0
		for y in thumbnail.get_height():
			for x in thumbnail.get_width():
				if thumbnail.get_pixel(x,y).is_equal_approx(Color("c9b88a")):road_pixels+=1
		check(road_pixels==0,id+" minimap contains no road-colored pixels")
		check(is_equal_approx(map._player_anim.scale.x,.65),id+" original hero scale .65")
		check(map._player_anim.sprite_frames.resource_path=="res://image/role/zs/pojun_walk_frames.tres",id+" existing hero retained")
		for suffix in ["top","bottom"]:
			var image:=ReferenceWorldArt.texture(id+"_floor_"+suffix).get_image()
			check(image.get_width()==int(cfg.map_cols)*96 and image.get_height()==int(cfg.map_rows)*48,id+" 2x density chunk "+suffix)
			check(maxi(image.get_width(),image.get_height())<=4096,id+" chunk fits 4096 texture limit")
		var old:Dictionary=baseline.maps[id]
		for key in ["monster_ids","monster_count","battle_rewards","monster_respawn_seconds","monster_contact_radius","encounter_solo"]:check(cfg.get(key)==old.get(key),id+" gameplay preserved "+key)
		check(cfg.entities.keys()==old.entities.keys(),id+" all quest entity IDs preserved")
		for e:Dictionary in cfg.exits:
			var prior:Dictionary=old.exits.filter(func(row):return row.id==e.id)[0]
			check(e.to==prior.to and e.get("arrival")==prior.get("arrival") and e.get("requires_story")==prior.get("requires_story"),id+" exit contract "+e.id)
		var grid:=navigation(map)
		var start:=Vector2(cfg.spawn[0],cfg.spawn[1])
		check(reachable(grid,start,start+Vector2(0,-80)),id+" spawn and main road clear")
		if id=="lorin_wilds":
			var city:CityScene=map._city_content
			check(city._buildings.size()==9,"eight facilities plus visitor ledger")
			var roofs:Array[Rect2]=[]
			for building in city._buildings:
				var bid:=String(building.data.id)
				var door:Array=cfg.city_building_approaches[bid];var at:=Vector2(door[0],door[1])
				check(reachable(grid,start,at),"real collision path to "+bid)
				var box:=Rect2(building.position-Vector2(building._w*.5,building._h),Vector2(building._w,building._h))
				check(Rect2(0,0,cfg.map_cols*48,cfg.map_rows*48).encloses(box),bid+" inside world")
				if bid!="gate":
					for other in roofs:check(not box.grow(12).intersects(other.grow(12)),bid+" roof gap >=24")
					roofs.append(box)
				map._player.position=at
				city._check_interact();check(city.has_modal(),bid+" original interaction opens")
				city._close_panel();await frames()
			for npc in city._npcs:
				check(reachable(grid,start,npc.position+Vector2(0,36)),"real collision path to "+String(npc.data.id))
				if not npc.guest:
					check(npc.frames.get_meta("fine_art",false),"new fine sprite "+String(npc.data.id))
					var image:Image=npc.frames.get_frame_texture(&"idle",0).get_image()
					check(image.get_used_rect().end.y==318,"fixed feet "+String(npc.data.id))
					map._player.position=npc.position+Vector2(0,36)
					city._check_interact();check(city.has_modal(),"original dialogue "+String(npc.data.id));city._close_panel();await frames()
			for pos:Array in cfg.monster_positions:
				for entity:Dictionary in cfg.entities.values():check(Vector2(pos[0],pos[1]).distance_to(Vector2(entity.at[0],entity.at[1]))>=300,"south encounter clearance")
		else:
			check(reachable(grid,start,Vector2(480,270)),"river physically traversable through main bridge")
			for eid in cfg.entities:
				var at:Array=cfg.entities[eid].at
				check(reachable(grid,start,Vector2(at[0],at[1])),"field quest reachable "+String(eid))
			check(map._in_river_zone(Vector2(200,map._river_center_y(200))),"river follows slope")
			check(not map._in_river_zone(Vector2(200,578)),"old river position no phantom water")
			var waypoint:=map._river_detour(Vector2(500,1235),Vector2(800,1500))
			check(is_equal_approx(waypoint.x,500),"bridge detour stays on crossing until clear")
		map.queue_free();await frames()
	fixture()
	G.prog.main_world={"map_id":"lorin_wilds","layout_version":5,"position":[500,1050],"respawn_by_map":{"lorin_wilds":{"0":9999999999}},"custom_progress":42}
	var migrated:=await spawn_map("lorin_wilds")
	check(migrated._player.position==Vector2(600,1520),"old town spawn migrates to new safe road")
	check(G.prog.main_world.custom_progress==42 and migrated._main_respawn_at.get("0")==9999999999,"position migration retains progression and respawn")
	migrated.queue_free();await frames()
	for height in [800,1067]:
		var vp:=SubViewport.new();vp.size=Vector2i(480,height);add_child(vp)
		var login:=preload("res://src/ui/Login.tscn").instantiate();vp.add_child(login);await frames()
		check(login._account.secret==false and login._password.secret,"login field behavior retained")
		login._do_login(false);await frames();check(login._chest._error.visible,"empty-account error visible")
		for control:Control in [login._account,login._password,login._chest._go,login._chest._guest]:check(Rect2(0,0,480,height).encloses(control.get_global_rect()),"login control within "+str(height))
		login._chest.layout(Rect2(0,0,480,height),320);await frames()
		check(login._chest._go.get_global_rect().end.y<=height-320,"keyboard keeps submit visible")
		check(not login._wordmark.visible and not login._chest._guest.visible,"keyboard prioritises form")
		login.queue_free();await frames()
		var loading:=preload("res://src/ui/LoadScreen.tscn").instantiate();loading.auto_advance=false;vp.add_child(loading);loading.set_process(false);await frames()
		for ratio in [0.0,.45,1.0]:
			loading._set_bar_ratio(ratio);check(is_equal_approx(loading.bar_fill_width(),(loading._gauge.size.x-2)*ratio),"real loading ratio "+str(ratio))
		loading.queue_free();vp.queue_free();await frames()
	print("REFERENCE_COMPLETE_%s checks=%d failures=%d"%["OK" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)
