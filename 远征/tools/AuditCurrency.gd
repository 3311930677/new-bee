## Counts generated map encounters and applies production reward paths. No timing claims.
extends Node
const SNAPSHOT := "res://tools/fixtures/currency_balance_before_nodes.json"
const OUTPUT := "res://docs/plans/2026-10-06-currency-income-samples.json"
const Events := preload("res://src/run/RunEvents.gd")
var profiles := {
	"three_normal":["normal","normal","normal","boss"],
	"three_elite":["elite","elite","elite","boss"],
	"mixed":["normal","shop","elite","boss"],
	"leisure":["event","bonfire","chest","boss"]}

func _ready() -> void:
	G.SAVE_PATH="res://tools/_logs/save_currency_audit.json"
	G._init_state_defaults()
	G.save_locked=false
	G.selected_role="zs"
	var current:Dictionary=TableCache.nodes_config().duplicate(true)
	var previous:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
	var out:={"description":"生成实际地图的怪物与拾取数量，按生产结算核算；不是完整真人通关或耗时样本。全拾取全清剿，事件选择行动，不使用矿脉/祭坛/商店，不出售物品，不计每日委托与出征额外补给费用。", "samples_per_profile":12,"before":{},"after":{}}
	for revision in ["before","after"]:
		TableCache._cache["res://data/nodes.json"]=(previous if revision=="before" else current).duplicate(true)
		for key in profiles:
			var samples:Array=[]
			for seed in range(1,13):
				var run:=RunState.new()
				run.setup({"role_id":"zs","theme":"forest","level":20,"seed":seed,"potions":2})
				var encountered:Array=[]
				for layer in range(4):
					var kind:=String(profiles[key][layer])
					MapScene.pending_cfg={"mode":"expedition","run":run,"node":{"type":kind,"layer":layer+1,"index":1}}
					var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
					add_child(map)
					await get_tree().process_frame
					map.set_process(false)
					map.set_physics_process(false)
					map._world.process_mode=Node.PROCESS_MODE_DISABLED
					for monster in map._monsters:
						run.add_reward(String(monster.tier))
						map._add_score(map._cfg_int("kill_score",12),"audit")
						encountered.append(String(monster.tier))
					if not map._monsters.is_empty(): map._on_area_cleared()
					for pickup in map._pickups.duplicate(): map.on_pickup(pickup)
					if kind=="chest": run.add_reward("chest")
					if kind=="event": Events.apply(run,map._prog,"work")
					run.gold+=int(map._rank().get("bonus",0))
					map.queue_free()
					await get_tree().process_frame
				samples.append({"seed":seed,"gold":run.gold,"expedition":run.expedition,"soul":run.soul,"honor":run.honor,"encounters":encountered})
			var gold:Array=[]
			for sample in samples: gold.append(int(sample.gold))
			gold.sort()
			var total:=0
			for value in gold: total+=int(value)
			out[revision][key]={"min":gold.front(),"max":gold.back(),"mean":snappedf(float(total)/gold.size(),.01),"samples":samples}
			print("CURRENCY_PROFILE %s %s mean=%s" % [revision,key,out[revision][key].mean])
	TableCache._cache["res://data/nodes.json"]=current
	var file:=FileAccess.open(OUTPUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(out,"  "))
	file.close()
	for key in profiles: print("CURRENCY_SAMPLE %s before=%s after=%s" % [key,out.before[key].mean,out.after[key].mean])
	print("CURRENCY_AUDIT_OK profiles=4 seeds=12 comparisons=96")
	get_tree().quit()
