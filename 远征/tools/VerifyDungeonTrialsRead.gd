extends Node
const Trials:=preload("res://src/world/DungeonTrial.gd")
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_dungeon_trials.json"
	var ok:=G.reload_save()
	ok=ok and int(Trials.record(G,"stele_cavern").get("progress",0))==2 and String(Trials.current(G,"stele_cavern").get("id",""))=="trial_echo_3"
	var run:=RunState.new()
	run.setup({"role_id":"fz","level":30,"potions":2,"seed":12})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"stele_cavern","run":run,"node":{"type":"boss","layer":0,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	var targets:Array=[]
	for e in map._quest_entities:
		if e.kind=="trial":targets.append(e.eid)
	ok=ok and targets==["trial_echo_3"]
	if not ok:push_error("FAIL: 第二进程附加挑战阶段与真实实体恢复")
	print("DUNGEON_TRIALS_READ_OK" if ok else "DUNGEON_TRIALS_READ_FAIL")
	get_tree().quit(0 if ok else 1)
