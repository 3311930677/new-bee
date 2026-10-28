extends RefCounted

const SAFE_MAPS := ["lorin_wilds","shenyuan_port","frost_post"]

static func rows()->Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/oaths.json")).get("oaths",[])

static func row(id:String)->Dictionary:
	for r in rows():
		if String(r.id)==id:return r
	return {}

static func state(host:Object)->Dictionary:
	return host.prog.get("oaths",{})

static func choose(host:Object,id:String,map_id:String)->Dictionary:
	if host.save_locked:return {"ok":false,"line":"存档暂不可写"}
	if not host.story_step_done("s12") or map_id not in SAFE_MAPS or row(id).is_empty():
		return {"ok":false,"line":"修复首碑后，在三城巡界厅选择出行誓约"}
	var before:Dictionary=host.prog.duplicate(true)
	var next:=state(host).duplicate(true)
	next["current"]=id
	host.prog["oaths"]=next
	if not host.save_game():
		host.prog=before
		return {"ok":false,"line":"誓约未保存，请重试"}
	return {"ok":true,"line":"已立%s誓约；影响下一张尚未锁定誓约的野外地图"%String(row(id).name)}

static func enter(host:Object,map_id:String)->String:
	if map_id in SAFE_MAPS or host.save_locked:return ""
	var id:=String(state(host).get("current",""))
	if row(id).is_empty():return ""
	var key:="%s|%s"%[map_id,WorldCommission.day()]
	var trips:Dictionary=state(host).get("trips",{})
	if trips.has(key):return key
	var before:Dictionary=host.prog.duplicate(true)
	var next:=state(host).duplicate(true)
	trips=next.get("trips",{})
	trips[key]={"map":map_id,"oath":id,"status":"active","phase":0}
	next["trips"]=trips
	host.prog["oaths"]=next
	if not host.save_game():
		host.prog=before
		return ""
	return key

static func trip(host:Object,key:String)->Dictionary:
	return state(host).get("trips",{}).get(key,{})

static func objective(host:Object,key:String)->Dictionary:
	var record:=trip(host,key)
	return row(String(record.get("oath","")))

static func finish(host:Object,key:String,persist:=true)->Dictionary:
	if host.save_locked:return {"ok":false,"line":"存档暂不可写"}
	var record:=trip(host,key)
	if String(record.get("status",""))!="active":return {"ok":false,"line":"本图今日誓约已经记入"}
	var definition:=objective(host,key)
	if String(definition.id)=="shelter" and int(record.get("phase",0))<1:
		return {"ok":false,"line":"先接应旅人，再护送到前方安全点"}
	var before:Dictionary=host.prog.duplicate(true)
	var money:Dictionary=host.wallet.duplicate(true)
	var inventory:Dictionary=host.items.duplicate(true)
	var grants:Dictionary=definition.reward.duplicate(true)
	grants["flag:oath_pattern_"+String(definition.id)]=1
	var applied:=RewardLedger.apply(RewardLedger.make(RewardLedger.tx_id("oath",key,"finish"),{},grants),host.ledger(),host)
	if not bool(applied.ok) or bool(applied.duplicate):
		host.prog=before
		host.wallet=money
		host.items=inventory
		return {"ok":false,"line":"誓约结算未通过"}
	record.status="done"
	if persist and not host.save_game():
		host.prog=before
		host.wallet=money
		host.items=inventory
		return {"ok":false,"line":"誓约未写盘，奖励与目标已恢复"}
	return {"ok":true,"line":"%s已记录 · 普通材料到账"%String(definition.record)}

static func begin_escort(host:Object,key:String)->Dictionary:
	if host.save_locked:return {"ok":false,"line":"存档暂不可写"}
	var record:=trip(host,key)
	if String(record.get("status",""))!="active" or String(record.get("oath",""))!="shelter" or int(record.get("phase",0))!=0:
		return {"ok":false,"line":"旅人已经在路上"}
	var before:Dictionary=host.prog.duplicate(true)
	record["phase"]=1
	if not host.save_game():
		host.prog=before
		return {"ok":false,"line":"护送未保存，可再接应"}
	return {"ok":true,"line":"旅人跟上了 · 带他走到前方路灯安全点"}

static func validate(data:Dictionary)->bool:
	if not data.get("current","") is String:return false
	if not String(data.get("current","")).is_empty() and row(String(data.current)).is_empty():return false
	if not data.get("trips",{}) is Dictionary:return false
	for key in data.get("trips",{}):
		var t:Variant=data.trips[key]
		if not t is Dictionary:return false
		if row(String(t.get("oath",""))).is_empty() or String(t.get("status","")) not in ["active","done"]:return false
		if TableCache.main_world_map(String(t.get("map",""))).is_empty():return false
		if not String(key).begins_with(String(t.map)+"|"):return false
		if not t.get("phase",0) is int and not t.get("phase",0) is float:return false
		if float(t.get("phase",0))!=float(int(t.get("phase",0))):return false
		if int(t.get("phase",0)) not in [0,1]:return false
	return true
