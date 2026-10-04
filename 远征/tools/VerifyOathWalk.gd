extends Node
const Oaths:=preload("res://src/world/OathService.gd")
var fails:=0
var map:MapScene
func check(ok:bool,line:String)->void:
	if not ok:
		fails+=1
		push_error("FAIL: "+line)
func release()->void:
	for action in ["move_up","move_down","move_left","move_right"]:Input.action_release(action)
func walk(target:Vector2)->bool:
	for i in 300:
		var diff:=target-map._player.position
		if diff.length()<12:
			release()
			return true
		release()
		if absf(diff.x)>8:Input.action_press("move_right" if diff.x>0 else "move_left")
		if absf(diff.y)>8:Input.action_press("move_down" if diff.y>0 else "move_up")
		await get_tree().physics_frame
		if is_instance_valid(map._oath_traveler):
			check(not Rect2(440,710,80,110).has_point(map._oath_traveler.position),"跟随者不穿过测试障碍")
	return false
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_oath_walk.json"
	G._init_state_defaults()
	G.save_locked=false
	G.prog.story={"step":"s13","done":["s12"],"goals":{}}
	G.prog.main_world={"map_id":"maple_road"}
	check(Oaths.choose(G,"shelter","lorin_wilds").ok,"设定护送夹具")
	var run:=RunState.new()
	run.setup({"theme":"forest","role_id":"zs","level":20,"seed":8})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":"maple_road","run":run,"node":{"type":"normal","layer":1,"index":0}}
	map=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	for monster in map._monsters:
		monster.position=Vector2(50,50)
		monster.set_process(false)
	var source:=Vector2.ZERO
	for entity in map._quest_entities:
		if entity.kind=="oath":source=entity.position
	# 仅设置起步夹具，后续全走生产输入和碰撞，不写任务阶段。
	map._player.position=source
	for i in 5:await get_tree().process_frame
	check(is_instance_valid(map._oath_traveler),"靠近旅人触发真实接应")
	var wall:=StaticBody2D.new()
	wall.collision_layer=2
	wall.collision_mask=0
	wall.position=Vector2(480,765)
	var collider:=CollisionShape2D.new()
	var rect:=RectangleShape2D.new()
	rect.size=Vector2(80,110)
	collider.shape=rect
	wall.add_child(collider)
	map._world.add_child(wall)
	check(await walk(Vector2(360,source.y)),"真实输入绕到左侧")
	check(await walk(Vector2(360,source.y-240)),"真实输入越过障碍")
	check(await walk(source-Vector2(0,240)),"真实输入抵达安全点")
	for i in 300:
		if String(Oaths.trip(G,map._oath_trip).get("status",""))=="done":break
		await get_tree().physics_frame
	check(String(Oaths.trip(G,map._oath_trip).get("status",""))=="done","旅人沿拐角跟上后才完成护送")
	release()
	map.queue_free()
	await get_tree().process_frame
	print("OATH_WALK_OK" if fails==0 else "OATH_WALK_FAIL fails=%d"%fails)
	get_tree().quit(0 if fails==0 else 1)
