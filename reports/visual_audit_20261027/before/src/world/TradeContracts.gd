extends RefCounted

static func cfg() -> Dictionary:
	return TableCache._load("res://data/trade_contracts.json")
static func templates() -> Array:
	return cfg().get("templates",[])
static func row(id: String) -> Dictionary:
	for entry in templates():
		if String(entry.id)==id:return entry
	return {}
static func state(host: Object) -> Dictionary:
	return host.prog.get("trade_contracts",{})
static func day(host: Object) -> int:
	return int(host.economy_state().day)
static func map_for(site: String) -> String:
	return String(EconomyService.site(TableCache.economy_config(),site).get("map_id",""))
static func at_site(host: Object,site: String) -> bool:
	return String(host.prog.get("main_world",{}).get("map_id",""))==map_for(site)
static func snapshot(host: Object) -> Dictionary:
	return {"prog":host.prog.duplicate(true),"wallet":host.wallet.duplicate(true),"items":host.items.duplicate(true)}
static func rollback(host: Object,before: Dictionary) -> void:
	host.prog=before.prog
	host.wallet=before.wallet
	host.items=before.items
static func commit(host: Object,before: Dictionary,line: String,persist:=true) -> Dictionary:
	if persist and not host.save_game():
		rollback(host,before)
		return {"ok":false,"line":"合约未能保存，资源与状态已还原"}
	return {"ok":true,"line":line}
static func transaction(host: Object,id: String,action: String,costs: Dictionary,rewards: Dictionary) -> bool:
	var result:=RewardLedger.apply(RewardLedger.make(RewardLedger.tx_id("trade_contract",id,action),costs,rewards),host.ledger(),host)
	return bool(result.ok) and not bool(result.duplicate)
static func active_count(host: Object) -> int:
	var count:=0
	for record in state(host).values():
		if String(record.status)=="active":count+=1
	return count
static func quote(host: Object,template: String,mode: String) -> Dictionary:
	var definition:=row(template)
	if definition.is_empty() or mode not in ["insured","self"]:return {}
	var reference:=0
	for good in definition.cargo:
		reference+=int(host.economy_quote(String(definition.origin),String(good)).get("buy_gold",0))*int(definition.cargo[good])
	var economic:Dictionary=host.economy_state()
	var index:=templates().find(definition)
	var event:=String(economic.get("port_event",""))+"/"+String(economic.get("frost_event",""))
	var event_term:=7 if "dredge" in event or "wardens" in event else 3
	var risk:=posmod(int(economic.seed)+day(host)*37+index*17+event_term,4)==0
	var config:=cfg()
	var profit:=int(config.insured_profit) if mode=="insured" else int(config.self_profit)
	var fee:=int(config.insured_fee) if mode=="insured" else 0
	return {"reference":reference,"deposit":int(config.deposit),"fee":fee,"profit":profit,"payout":reference+profit,
		"risk":risk,"event":event,"due":day(host)+int(config.deadline_days),"max_loss":fee if mode=="insured" else 30}
static func sign(host: Object,template: String,mode: String,site: String) -> Dictionary:
	var definition:=row(template)
	if host.save_locked:return {"ok":false,"line":"存档暂不可写"}
	if definition.is_empty() or not host.story_step_done(String(definition.unlock)):return {"ok":false,"line":"这条商路尚未开放"}
	if site!=String(definition.origin) or not at_site(host,site):return {"ok":false,"line":"请在签发城的实际市集办理"}
	var id:=template+"|"+str(day(host))
	if state(host).has(id) or active_count(host)>=2:return {"ok":false,"line":"同批合约不可重接；最多两张未结单"}
	var before:=snapshot(host)
	var offered:=quote(host,template,mode)
	if offered.is_empty():return {"ok":false,"line":"请选择保价或自担方式"}
	if not transaction(host,id,"sign",{"gold":int(offered.deposit)},{}):
		rollback(host,before)
		return {"ok":false,"line":"保证金不足或该批已签发"}
	var records:=state(host).duplicate(true)
	records[id]={"id":id,"template":template,"status":"active","mode":mode,"signed_day":day(host),"due_day":int(offered.due),
		"extended":false,"aid":false,"reference":int(offered.reference),"payout":int(offered.payout),"risk":bool(offered.risk),"event":String(offered.event),"rules":{"deposit":int(cfg().deposit),"insured_fee":int(cfg().insured_fee),"obstruction_loss":int(cfg().obstruction_loss),"extension_fee":int(cfg().extension_fee),"extension_days":int(cfg().extension_days),"grace_days":int(cfg().grace_days),"self_refund":30}}
	host.prog.trade_contracts=records
	return commit(host,before,"已签约："+String(definition.name)+"；报价和路况已锁定，不看现实日期")
static func payout(record: Dictionary) -> int:
	var loss:=int(record.rules.obstruction_loss) if String(record.mode)=="self" and bool(record.risk) and not bool(record.aid) else 0
	return int(record.payout)-loss
static func refund(record: Dictionary) -> int:
	return int(record.rules.deposit)-int(record.rules.insured_fee) if String(record.mode)=="insured" else int(record.rules.self_refund)
static func action(host: Object,id: String,kind: String,site: String="",persist:=true) -> Dictionary:
	if host.save_locked:return {"ok":false,"line":"存档暂不可写"}
	var record:Dictionary=state(host).get(id,{})
	if String(record.get("status",""))!="active":return {"ok":false,"line":"没有待办合约"}
	var definition:=row(String(record.template))
	var config:Dictionary=record.rules
	var now:=day(host)
	var costs:Dictionary={}
	var rewards:Dictionary={}
	if kind=="aid":
		if String(host.prog.get("main_world",{}).get("map_id",""))!=String(definition.route_map) or bool(record.aid):return {"ok":false,"line":"请到对应路点核准，不能重复处理"}
	elif kind=="deliver":
		if site!=String(definition.destination) or not at_site(host,site):return {"ok":false,"line":"请亲到交货城的市集"}
		if now>int(record.due_day):return {"ok":false,"line":"已逾期，可延期一次或退单；长期逾期自动退押"}
		for good in definition.cargo:costs["item:"+String(good)]=int(definition.cargo[good])
		var held_deposit:=int(config.deposit)-(int(config.insured_fee) if String(record.mode)=="insured" else 0)
		rewards.gold=payout(record)+held_deposit
	elif kind in ["extend","cancel","expire"]:
		if kind!="expire" and (site not in [String(definition.origin),String(definition.destination)] or not at_site(host,site)):return {"ok":false,"line":"请在签约或交货市集办理"}
		if kind=="extend":
			if bool(record.extended) or now<=int(record.due_day) or now>int(record.due_day)+int(config.grace_days):return {"ok":false,"line":"只有宽限期内的首次逾期可延期"}
			costs.gold=int(config.extension_fee)
		else:
			if kind=="expire" and now<=int(record.due_day)+int(config.grace_days):return {"ok":false,"line":"尚未到自动退押时间"}
			rewards.gold=refund(record)
	else:return {"ok":false,"line":"合约操作无效"}
	var before:=snapshot(host)
	if not transaction(host,id,kind,costs,rewards):
		rollback(host,before)
		return {"ok":false,"line":"材料、费用不足或本项已记账，合约保留"}
	if kind=="aid":record.aid=true
	elif kind=="extend":
		record.extended=true
		record.due_day=now+int(config.extension_days)
	else:record.status="done" if kind=="deliver" else "cancelled"
	var lines:Dictionary={"aid":"路线已核准，自担路阻扣款取消","extend":"已延期一次，日期与费用见合约页","deliver":"交货一次到账；货款、报酬及剩余押金见账单","cancel":"退单已返还押金，未扣任何货物","expire":"长期逾期已自动退押，未扣货物"}
	return commit(host,before,String(lines.get(kind,"已记录")),persist)
static func tick(host: Object) -> bool:
	for id in state(host).keys():
		var record:Dictionary=state(host)[id]
		if String(record.status)=="active" and day(host)>int(record.due_day)+int(record.rules.grace_days):
			if not bool(action(host,String(id),"expire","",false).ok):return false
	return true
static func validate(records: Dictionary) -> bool:
	var open:=0
	for id in records:
		var value:Variant=records[id]
		if not value is Dictionary:return false
		var r:Dictionary=value
		if row(String(r.get("template",""))).is_empty() or String(r.get("id",""))!=String(id):return false
		if String(r.get("mode","")) not in ["insured","self"] or String(r.get("status","")) not in ["active","done","cancelled"]:return false
		if not r.get("rules") is Dictionary:return false
		for key in ["deposit","insured_fee","obstruction_loss","extension_fee","extension_days","grace_days","self_refund"]:
			var n:Variant=r.rules.get(key)
			if not n is int and not n is float:return false
			if float(n)!=float(int(n)) or int(n)<0:return false
		if int(r.rules.insured_fee)>int(r.rules.deposit) or int(r.rules.self_refund)>int(r.rules.deposit):return false
		for key in ["extended","aid","risk"]:
			if not r.get(key) is bool:return false
		for key in ["signed_day","due_day","reference","payout"]:
			var n:Variant=r.get(key)
			if not n is int and not n is float:return false
			if float(n)!=float(int(n)) or int(n)<1:return false
		if String(id)!=String(r.template)+"|"+str(int(r.signed_day)) or int(r.due_day)<=int(r.signed_day) or int(r.payout)<int(r.reference) or not r.get("event") is String:return false
		if r.status=="active":open+=1
	return open<=2
