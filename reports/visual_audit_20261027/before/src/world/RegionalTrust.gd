extends RefCounted

const CITIES := {"lorin_wilds":"zhaoyuan", "shenyuan_port":"shenyuan", "frost_post":"frost"}
const REPRESENTATIVES := {"npc_steward":"zhaoyuan", "npc_harbormaster":"shenyuan", "npc_frost_envoy":"frost"}
const STORIES := {
	"zhaoyuan":"闻叔把新补的路簿摊开：以前谁出门都得在城门留个名字。如今路标有人查，桥板有人修，夜岗也有人接。灯架上多的那盏灯，写的是你的名字。",
	"shenyuan":"沈澜递来一张旧潮线纸：当年我们怕船出去就回不来，缆绳上系满了姓名。如今水线、货签和受力点都有人核对，港口可以把一趟短程托给熟悉这片潮的人。",
	"frost":"宁砚翻到轮岗簿的空页：过去这里常常没人接班，炉息停了才知道有人没出来。如今烟道通、矿车让道、外岗补给到了，空页上终于能写下一班人的名字。"
}

# Derived from retained completed facts: old saves get credit without regranting rewards.
static func sources(host:Object, region:String)->Array:
	var found:Array=[]
	for side in host.side_quest_rows():
		var city:=String(side.get("turn_in_map",""))
		if String(CITIES.get(city,""))==region and host.side_status_of(String(side.id))==QuestService.SIDE_DONE:
			found.append("side|"+String(side.id))
	for posting in WorldCommission.state(host):
		var record:Dictionary=WorldCommission.state(host)[posting]
		if String(record.status)=="done" and String(WorldCommission.row(String(record.template)).get("region",""))==region:
			found.append("commission|"+String(posting))
	for id in host.prog.get("trade_contracts",{}):
		var record:Dictionary=host.prog.trade_contracts[id]
		var definition:=preload("res://src/world/TradeContracts.gd").row(String(record.template))
		var destination:=preload("res://src/world/TradeContracts.gd").map_for(String(definition.get("destination","")))
		if String(record.status)=="done" and String(CITIES.get(destination,""))==region:found.append("contract|"+String(id))
	# Completion transactions persist after a contract is replaced by the next batch.
	# Deposits, extensions, cancellations and automatic refunds never grant trust.
	for transaction in host.prog.get("ledger",{}).get("applied",[]):
		var parts:=String(transaction).split("|")
		if parts.size()<4:continue
		var shipping:=parts[0]=="shipping" and parts[2]=="arrive" and region=="shenyuan"
		var medicine:=parts[0]=="frost_herb" and parts[2]=="deliver" and region=="frost"
		if (shipping or medicine) and not found.has("delivery|"+String(transaction)):
			found.append("delivery|"+String(transaction))
	return found

static func info(host:Object,region:String)->Dictionary:
	var count:=sources(host,region).size()
	var tier:=2 if count>=8 else 1 if count>=3 else 0
	return {"count":count,"tier":tier,"name":["认识","信任","托付"][tier],
		"hint":"已达托付：三城可同时信任，不排斥其他地区" if tier==2 else
		"再办妥 %d 件本城支线、世界事务或按期交货可到%s"%[(3 if tier==0 else 8)-count,"信任" if tier==0 else "托付"]}

static func npc_line(host:Object,npc:String)->String:
	var region:=String(REPRESENTATIVES.get(npc,""))
	if region.is_empty() or int(info(host,region).tier)<1:return ""
	return String(STORIES[region])

static func shop_mult(host:Object,map_id:String)->float:
	var region:=String(CITIES.get(map_id,""))
	if region.is_empty():return 1.0
	var tier:=int(info(host,region).tier)
	return .95 if tier==2 else .98 if tier==1 else 1.0
