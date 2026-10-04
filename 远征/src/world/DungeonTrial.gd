extends RefCounted

static func rows()->Dictionary:
	return TableCache._load("res://data/dungeon_trials.json").get("trials",{})

static func row(map_id:String)->Dictionary:
	return rows().get(map_id,{})

static func record(host:Object,map_id:String)->Dictionary:
	return host.prog.get("dungeon_trials",{}).get(map_id,{})

static func unlocked(host:Object,map_id:String)->bool:
	var definition:=row(map_id)
	return not definition.is_empty() and host.story_step_done(String(definition.requires_story))

static func current(host:Object,map_id:String)->Dictionary:
	var saved:=record(host,map_id)
	if String(saved.get("status",""))!="active":return {}
	var steps:Array=row(map_id).get("steps",[])
	var p:=int(saved.get("progress",0))
	return steps[p] if p<steps.size() else {}

static func choose(host:Object,map_id:String,action:String)->Dictionary:
	if host.save_locked or not unlocked(host,map_id):return {"ok":false,"line":"首通后才可选择附加挑战"}
	var saved:=record(host,map_id)
	if action not in ["begin","abort"]:return {"ok":false,"line":"请选择开始或结束本次挑战"}
	if action=="begin" and String(saved.get("status",""))=="active":return {"ok":true,"line":"继续已保存的附加挑战"}
	var before:Dictionary=host.prog.duplicate(true)
	var trials:Dictionary=host.prog.get("dungeon_trials",{}).duplicate(true)
	trials[map_id]={"status":"active" if action=="begin" else "abandoned","progress":0,
		"attempt":int(saved.get("attempt",0))+1}
	host.prog["dungeon_trials"]=trials
	if not host.save_game():
		host.prog=before
		return {"ok":false,"line":"挑战未保存，可以重试"}
	return {"ok":true,"line":"附加挑战已开始，原副本首通进度不变" if action=="begin" else "附加挑战已结束，之后可重新开始"}

static func advance(host:Object,map_id:String,id:String,choice:="",battle:=false,persist:=true)->Dictionary:
	if host.save_locked:return {"ok":false,"line":"存档暂不可写"}
	var step:=current(host,map_id)
	if step.is_empty() or String(step.id)!=id:return {"ok":false,"line":"这不是本次挑战的当前目标"}
	if String(step.kind)=="defeat" and not battle:return {"ok":false,"line":"需要击退练习残影"}
	if not (step.get("choices",{}) as Dictionary).is_empty():
		if choice!=String(step.get("correct","")):return {"ok":false,"line":String(step.get("wrong","请回想刚听到的线索"))}
	var before:Dictionary=host.prog.duplicate(true)
	var inventory:Dictionary=host.items.duplicate(true)
	var wallet:Dictionary=host.wallet.duplicate(true)
	var saved:=record(host,map_id)
	saved.progress=int(saved.progress)+1
	var line:=String(step.get("line","已记下这处目标"))
	if int(saved.progress)==(row(map_id).steps as Array).size():
		saved.status="done"
		var grants:Dictionary=row(map_id).reward.duplicate(true)
		grants["flag:trial_note_"+map_id]=1
		var result:=RewardLedger.apply(RewardLedger.make(RewardLedger.tx_id("dungeon_trial",map_id,"first"),{},grants),host.ledger(),host)
		if not bool(result.ok):
			host.prog=before
			host.items=inventory
			host.wallet=wallet
			return {"ok":false,"line":"附加挑战报酬未通过结算"}
		line="练习完成 · 已有附注，本次不重复给材料" if bool(result.duplicate) else "附注写进行旅图志 · 强化石×2，首通物和经验不重发"
	if persist and not host.save_game():
		host.prog=before
		host.items=inventory
		host.wallet=wallet
		return {"ok":false,"line":"挑战未写盘，线索与材料已恢复"}
	return {"ok":true,"line":line}

static func no_potions(host:Object,map_id:String)->bool:
	return String(record(host,map_id).get("status",""))=="active" and bool(row(map_id).get("no_potions",false))

static func validate(data:Dictionary)->bool:
	for map_id in data:
		if row(String(map_id)).is_empty() or not data[map_id] is Dictionary:return false
		var value:Dictionary=data[map_id]
		if String(value.get("status","")) not in ["active","abandoned","done"]:return false
		for key in ["progress","attempt"]:
			if not value.get(key) is int and not value.get(key) is float:return false
			if float(value[key])!=float(int(value[key])) or int(value[key])<0:return false
		var p:=int(value.progress)
		var size:=(row(String(map_id)).steps as Array).size()
		if p>size or (value.status=="active" and p==size) or (value.status=="done" and p!=size):return false
	return true
