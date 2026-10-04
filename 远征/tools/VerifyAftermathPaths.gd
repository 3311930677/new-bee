extends Node
var fails:=0
var map:MapScene
func check(ok:bool,line:String)->void:
	if not ok:
		fails+=1
		push_error("FAIL: "+line)
func blocked(x:float)->bool:
	var query:=PhysicsRayQueryParameters2D.create(Vector2(x,535),Vector2(x,655),2)
	return not map._player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func settle()->void:
	await get_tree().create_timer(.4).timeout
	await get_tree().physics_frame
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_aftermath_paths.json"
	G._init_state_defaults()
	G.save_locked=false
	G.prog.story={"step":"s13","done":["s12"],"goals":{}}
	G.prog.main_world={"map_id":"maple_road"}
	var run:=RunState.new()
	run.setup({"theme":"forest","role_id":"zs","level":20,"seed":1})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"maple_road","run":run,"node":{"type":"normal","layer":1,"index":0}}
	map=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await settle()
	map.set_process(false)
	map.set_physics_process(false)
	check(blocked(380) and blocked(620) and not blocked(480),"未修两处断桥，中央原路始终可走")
	G.act1_state()["side_quests"]={"a1_trade_bridge":{"status":QuestService.SIDE_DONE,"branch_flags":{"a1_trade_bridge_step_3":"west"}}}
	await settle()
	check(not blocked(380) and blocked(620) and not blocked(480),"先稳西侧后实际开西桥，东侧仍可绕行")
	check(G.save_game() and G.reload_save(),"保存与重载修桥选择")
	await settle()
	check(not blocked(380),"修桥碰撞由存档选择持续重建")
	G.act1_state().side_quests.a1_trade_bridge.branch_flags.a1_trade_bridge_step_3="east"
	await settle()
	check(blocked(380) and not blocked(620) and not blocked(480),"东侧选择等价开放东桥，原路保持")
	map.queue_free()
	await get_tree().process_frame
	print("AFTERMATH_PATHS_OK" if fails==0 else "AFTERMATH_PATHS_FAIL fails=%d"%fails)
	get_tree().quit(0 if fails==0 else 1)
