extends Node
const Events := preload("res://src/world/SpecialEventService.gd")
var fails:=0

class WorkHost extends "res://src/autoload/G.gd":
	var audit_clock:=1000000
	var can_save:=true
	func now_ts() -> int: return audit_clock
	func save_game() -> bool: return can_save

func check(value:bool,message:String) -> void:
	if not value:
		fails+=1
		push_error("FAIL: "+message)

func _ready() -> void:
	G.SAVE_PATH="res://tools/_logs/save_verify_currency_balance.json"
	G._init_state_defaults()
	G.save_locked=false
	G.selected_role="zs"
	G.prog.level=20
	var config:=TableCache.nodes_config()
	var relic:Dictionary=preload("res://src/world/RelicService.gd").cfg()
	check(int(relic.buy_gold)==90000 and int(relic.buy_requires_wins)==20 \
		and int(relic.pity_wins)==400 and is_equal_approx(float(relic.drop_chance),.004),"金币收紧后大额目标适配，挑战与稀有掉落规则保留")
	var rewards:Dictionary=config.rewards
	var expected_other:={"normal":[20,0,1],"elite":[45,5,3],"boss":[120,15,15],"chest":[30,0,0],"clear":[40,0,2]}
	for key in expected_other:
		check([int(rewards[key].get("expedition",0)),int(rewards[key].get("soul",0)),int(rewards[key].get("honor",0))]==expected_other[key],"金币调整不削减其他三币 "+key)
	var upper:=12*int(rewards.normal.gold)+int(rewards.boss.gold)+4*int(rewards.clear.gold) \
		+4*int(config.explore.pickup_count[1])*int(config.explore.pickup_gold[1]) \
		+3*int(config.explore.rank_bonus_gold[2])+int(config.explore.rank_bonus_gold[1])
	var lower:=9*int(rewards.normal.gold)+int(rewards.boss.gold)+4*int(rewards.clear.gold) \
		+4*int(config.explore.pickup_count[0])*int(config.explore.pickup_gold[0]) \
		+3*int(config.explore.rank_bonus_gold[1])+int(config.explore.rank_bonus_gold[0])
	check(lower>=1400 and upper<=2200,"三普通图加首领的完整搜图金币预算1400—2200，保留常规收入")
	G.prog.world_cleared={"forest":true}
	var sweep:=G.sweep_world("forest")
	print("CURRENCY_SWEEP "+JSON.stringify(sweep))
	check(int(sweep.get("gold",-1))==406 and int(sweep.get("expedition",0))==125 \
		and int(sweep.get("soul",0))==10 and int(sweep.get("honor",0))==12,"扫荡真实入账金币406，其余三币保持")
	G.wallet.gold=1000
	var work:=G.economy_work("city_market","carry")
	check(bool(work.get("ok",false)) and int(G.wallet.gold)==1042,"工作保留42金兜底")
	check(bool(G.economy_rest("city_market").get("ok",false)),"歇脚仍正常推进行情")
	var gold:=int(G.wallet.gold)
	var before:=G.prog.duplicate(true)
	check(not bool(G.economy_work("city_market","carry").get("ok",false)) and int(G.wallet.gold)==gold and G.prog==before,"跨经济日不能绕过现实休整")
	check(G.reload_save() and G.economy_work_left("carry")>0 \
		and not bool(G.economy_work("city_market","carry").get("ok",false)),"休整时间跨进程存档读取保留")
	var host:=WorkHost.new()
	host._init_state_defaults()
	host.wallet.gold=1000
	check(bool(host.economy_work("city_market","carry").get("ok",false)),"时间边界夹具首次领取")
	host.economy_rest("city_market")
	host.audit_clock+=3599
	check(host.economy_work_left("carry")==1 and not bool(host.economy_work("city_market","carry").get("ok",false)),"一小时前一秒仍不可领取")
	host.audit_clock+=1
	check(host.economy_work_left("carry")==0 and bool(host.economy_work("city_market","carry").get("ok",false)),"满一小时且换日后可以正常工作")
	host.audit_clock+=3600
	check(not bool(host.economy_work("city_market","carry").get("ok",false)),"现实休整结束仍不能重复同一经济日的差事")
	host._init_state_defaults()
	host.wallet.gold=1000
	host.can_save=false
	host.economy_state()
	var p:=host.prog.duplicate(true)
	var w:=host.wallet.duplicate(true)
	var c:=host.city.duplicate(true)
	check(not bool(host.economy_work("city_market","carry").get("ok",false)) and host.prog==p \
		and host.wallet==w and host.city==c,"工作保存失败回滚钱、经济日记录、休整与账本")
	host.free()
	G._init_state_defaults()
	var done:Array=[]
	for i in range(1,37): done.append("s%02d" % i)
	G.prog.story={"step":"","done":done,"goals":{}}
	var index:=0
	for entry in Events.rows():
		check(int(entry.gold)==[480,800,1200][index],"一次性奇遇分幕奖励")
		var id:=String(entry.id)
		Events.action(G,id,String(entry.board.map),"accept")
		Events.action(G,id,String(entry.clue.map),"inspect")
		Events.action(G,id,String(entry.encounter.map),String(entry.branches.keys()[0]))
		Events.action(G,id,String(entry.board.map),"gear")
		index+=1
	check(int(G.wallet.gold)==2480 and G.reload_save() and int(G.wallet.gold)==2480,"三条金币合计2480，已领取和读档不重复发钱")
	for entry in Events.rows(): check(not bool(Events.action(G,String(entry.id),String(entry.board.map),"partner").ok),"升奖后另一份谢礼仍不可重复领")
	await check_previews()
	print("CURRENCY_BALANCE_OK gold_budget=%d..%d special_total=2480 work_cd=3600" % [lower,upper] if fails==0 else "CURRENCY_BALANCE_FAIL fails=%d" % fails)
	get_tree().quit(0 if fails==0 else 1)

func check_previews() -> void:
	for mode in ["main_world","expedition"]:
		var run:=RunState.new()
		run.setup({"role_id":"zs","theme":"forest","level":20,"seed":19,"potions":2,"ascetic":true})
		MapScene.pending_cfg={"mode":mode,"main_map_id":"lorin_wilds","run":run,"node":{"type":"normal","layer":1,"index":0}}
		var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
		add_child(map)
		await get_tree().process_frame
		map.set_process(false)
		map.set_physics_process(false)
		map._world.process_mode=Node.PROCESS_MODE_DISABLED
		var monster:Node=map._monsters[0]
		var preview:Dictionary=map._battle_reward_preview(monster)
		check(int(preview.get("gold",0))==(28 if mode=="main_world" else 78),"主世界与苦行战利预览显示各自真实金币")
		monster.trial=true
		check(map._battle_reward_preview(monster).is_empty(),"复战练习不显示额外金币")
		map.queue_free()
		await get_tree().process_frame
