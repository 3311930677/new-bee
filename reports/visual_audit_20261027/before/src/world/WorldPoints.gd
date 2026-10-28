extends RefCounted
## One catalog derived from the same authored coordinates used by world interactions.
static var _catalog: Dictionary = {}
const LABELS := {"fishing":"垂钓","shop":"商店","station":"驿站","npc":"人物","landmark":"设施"}

static func _ensure() -> void:
	if not _catalog.is_empty():return
	for map_id in TableCache.main_world_config().get("maps",{}):
		var cfg := TableCache.main_world_map(map_id)
		var entities: Dictionary = cfg.get("entities",{})
		for id in entities:
			var row: Dictionary = entities[id]
			var kind := String(row.get("kind",""))
			if kind not in ["fishing","road_mail","trade","journey_return"]:continue
			_add(map_id,id,String(row.get("name",id)),"fishing" if kind=="fishing" else "station" if kind in ["road_mail","journey_return"] else "shop",row.get("at",[]),row)
		if not bool(cfg.get("city",false)):continue
		var city := TableCache.city_config_for(map_id)
		for building in city.get("buildings",[]):
			var id := String(building.get("id",""))
			var at: Array = cfg.get("city_building_positions",{}).get(id,[])
			if at.size()<2:continue
			var action := String(building.get("action",""))
			var kind := "shop" if action in ["shop","exchange","trade","supply","market"] or id.contains("market") or id.contains("supply") else "station" if action in ["rest","journey"] or id.contains("lodge") else "landmark"
			_add(map_id,id,String(building.get("name",id)),kind,at,building)
			var key := String(map_id)+":"+id
			var approach: Array = cfg.get("city_building_approaches",{}).get(id,[0,42])
			_catalog[key]["approach"] = [float(at[0])+float(approach[0]),float(at[1])+float(approach[1])]
		for npc in city.get("npcs",[]):
			var id := String(npc.get("id",""))
			var at: Array = cfg.get("city_npc_positions",{}).get(id,[])
			if at.size()>=2:_add(map_id,id,String(npc.get("name",id)),"npc",at,npc)

static func _add(map_id: String,id: String,title: String,kind: String,at: Array,source: Dictionary) -> void:
	if at.size()<2:return
	var key := map_id+":"+id
	_catalog[key] = {"id":key,"entity":id,"map":map_id,"name":title,"kind":kind,"at":at.duplicate(),"source":source.duplicate(true)}

static func rows(map_id := "") -> Array[Dictionary]:
	_ensure()
	var result: Array[Dictionary] = []
	for point in _catalog.values():
		if map_id.is_empty() or point.map==map_id:result.append(point)
	return result

static func find(id: String) -> Dictionary:
	_ensure()
	return _catalog.get(id,{})

static func target() -> Dictionary:
	return find(String(G.prog.get("map_destination","")))

static func gate_reason(row: Dictionary) -> String:
	if G.world_gate_open():return ""
	var story := String(row.get("requires_story",""))
	if not story.is_empty() and not G.story_step_done(story):return String(row.get("locked_hint","先完成入口主线"))
	for flag in row.get("requires_flags",[]):
		if not bool(G.prog.get("flags",{}).get(String(flag),false)):return String(row.get("locked_hint","先完成入口机关"))
	return ""

static func reachable(from: String,to: String) -> bool:
	if from==to:return true
	var queue: Array[String] = [from]
	var seen := {from:true}
	while not queue.is_empty():
		var current := String(queue.pop_front())
		for exit in TableCache.main_world_map(current).get("exits",[]):
			var next := String(exit.get("to",""))
			if next.is_empty() or seen.has(next) or not gate_reason(exit).is_empty():continue
			if next==to:return true
			seen[next]=true
			queue.append(next)
	return false

static func status(point: Dictionary,from := "") -> String:
	if point.is_empty():return "地点不存在"
	if from.is_empty():from=String(G.prog.get("main_world",{}).get("map_id","lorin_wilds"))
	if not reachable(from,String(point.map)):return "路线未开放 · 先完成沿路主线或机关"
	var reason := gate_reason(point.get("source",{}))
	if not reason.is_empty():return reason
	if int(point.get("source",{}).get("min_level",1))>int(G.prog.get("level",1)):return "等级尚未达到"
	if point.kind=="fishing" and G.fishing_remaining(String(point.entity))<=0:return "今日竿次已尽 · 可在市集歇脚"
	return "可前往"

static func track(id: String) -> Dictionary:
	var point := find(id)
	var reason := status(point)
	if reason!="可前往":return {"ok":false,"line":reason}
	var previous: Variant = G.prog.get("map_destination",null)
	G.prog["map_destination"] = id
	if not G.save_game():
		if previous==null:G.prog.erase("map_destination")
		else:G.prog["map_destination"]=previous
		return {"ok":false,"line":"目的地未能保存，请重试"}
	return {"ok":true,"line":"已追踪 · "+String(point.name)}

static func cancel() -> bool:
	var previous: Variant = G.prog.get("map_destination",null)
	G.prog.erase("map_destination")
	if G.save_game():return true
	if previous!=null:G.prog["map_destination"]=previous
	return false

static func position(point: Dictionary,approach := false) -> Vector2:
	var at: Array = point.get("approach",point.at) if approach else point.at
	return Vector2(float(at[0]),float(at[1]))

static func icon(kind: String) -> Texture2D:
	if kind=="fishing":return G.res_tex("itm_fish_common")
	return G.NavigationIcons.texture("bag" if kind=="shop" else "world" if kind in ["station","landmark"] else "person")
