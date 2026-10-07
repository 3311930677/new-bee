extends Node
const Events := preload("res://src/world/SpecialEventService.gd")
var fails := 0

class FailedSaveHost extends RefCounted:
	var prog: Dictionary
	var wallet: Dictionary
	var items: Dictionary
	var save_locked := false
	func _init(source: Object) -> void:
		prog=source.prog.duplicate(true)
		wallet=source.wallet.duplicate(true)
		items=source.items.duplicate(true)
	func story_step_done(_id: String) -> bool: return true
	func ledger() -> Dictionary: return RewardLedger.ensure(prog.get("ledger",{}))
	func save_game() -> bool: return false
	func display_name() -> String: return "保存失败夹具"
	func grant_item(id: String, count: int, _persist := true) -> void:
		items[id]=int(items.get(id,0))+count

func check(ok: bool, message: String) -> void:
	if not ok:
		fails+=1
		push_error("FAIL: "+message)

func fixture() -> void:
	G.SAVE_PATH="res://tools/_logs/save_verify_special_events.json"
	G._init_state_defaults()
	G.save_locked=false
	G.selected_role="zs"
	G.prog.level=60
	G.wallet.gold=1000
	var done: Array=[]
	for i in range(1,37): done.append("s%02d" % i)
	G.prog.story={"step":"","done":done,"goals":{}}
	G.ensure_starter_equip()

func ally() -> Dictionary:
	return {"role_id":"zs","level":60,"traits":[],"active_pet":"","bench_pet":"",
		"potions":2,"hp_override":-1,"growth":G.growth_bonuses("zs"),"unlocked_skills":G.act1_unlocked_skills("zs")}

func _ready() -> void:
	fixture()
	check(Events.rows().size()==3,"首批三条奇遇")
	check(G.side_quest_rows().size()==36,"原支线与四幕任务数量不改")
	var old := {"version":6,"wallet":{"gold":753},"items":{"pet_food":8},"prog":{"level":40,"story":{"done":["s12"]}}}
	var migrated := SaveData.migrate(old)
	check(bool(migrated.ok) and migrated.steps==["v6→v7"],"旧档逐版迁移")
	check(migrated.data.wallet==old.wallet and migrated.data.items==old.items \
		and migrated.data.prog.special_events=={"records":{},"tracked":""},"迁移不改旧金币和物品，无虚构完成记录")
	var malformed: Dictionary=migrated.data.duplicate(true)
	malformed.prog.special_events={"records":[]}
	check(not bool(SaveData.validate(malformed,int(Time.get_unix_time_from_system())).ok),"坏奇遇结构明确拒绝")
	G.prog.story.done=[]
	check(not bool(Events.action(G,"misdelivered_invitation","lorin_wilds","accept").ok),"主线前置真实生效")
	for entry in Events.rows():
		for branch in entry.branches:
			fixture()
			var id:=String(entry.id)
			check(bool(Events.action(G,id,String(entry.board.map),"accept").ok),id+"可接取")
			var before:=G.prog.duplicate(true)
			check(not bool(Events.action(G,id,String(entry.encounter.map),String(branch)).ok) and G.prog==before,"不能跳过线索")
			check(not bool(Events.action(G,id,"wrong_map","inspect").ok) and G.prog==before,"错误地点不推进")
			G.save_locked=true
			check(not bool(Events.action(G,id,String(entry.clue.map),"inspect").ok) and G.prog==before,"锁盘不推进")
			G.save_locked=false
			check(bool(Events.action(G,id,String(entry.clue.map),"inspect").ok),"实地线索")
			check(bool(Events.action(G,id,String(entry.encounter.map),String(branch)).ok),"分支可选")
			if (entry.branches[branch] as Dictionary).has("enemy"):
				var battle:=Events.prepare_battle(G,id,String(entry.encounter.map),ally())
				check(bool(battle.ok),"开战前保存种子与完整配置")
				var frozen:Dictionary=battle.battle.duplicate(true)
				check(G.reload_save(),"战前可读回")
				var changed:Dictionary=ally()
				changed.level=1
				check(Events.prepare_battle(G,id,String(entry.encounter.map),changed).battle==JSON.parse_string(JSON.stringify(frozen)),"重进复用完整开场，不重掷种子或换战力")
				before=G.prog.duplicate(true)
				check(not bool(Events.resolve_battle(G,id,String(entry.encounter.map),"wrong","victory").ok) and G.prog==before,"其他战斗结果不能推进奇遇")
				check(bool(Events.resolve_battle(G,id,String(entry.encounter.map),String(frozen.token),"flee").ok) \
					and String(Events.record(G,id).phase)=="battle","撤退保留分支，无谢礼")
				battle=Events.prepare_battle(G,id,String(entry.encounter.map),ally())
				check(int(battle.battle.seed)==int(frozen.seed),"重新整备仍是同种子")
				check(bool(Events.resolve_battle(G,id,String(entry.encounter.map),String(frozen.token),"victory").ok),"本场胜利推进复命")
			var fault:=FailedSaveHost.new(G)
			var fault_before:=[fault.prog.duplicate(true),fault.wallet.duplicate(true),fault.items.duplicate(true)]
			check(not bool(Events.action(fault,id,String(entry.board.map),"gear").ok) and fault.prog==fault_before[0] \
				and fault.wallet==fault_before[1] and fault.items==fault_before[2],"写盘失败回滚奖励、选择和去重账本")
			var gift:="gear" if (entry.branches[branch] as Dictionary).has("enemy") else "partner"
			var gold:=int(G.wallet.gold)
			var previous_items:=G.items.duplicate(true)
			check(bool(Events.action(G,id,String(entry.board.map),gift).ok) and int(G.wallet.gold)==gold+int(entry.gold),"二选一谢礼真实入账")
			for grant in entry.rewards[gift].grants:
				var item_id:=String(grant).trim_prefix("item:")
				check(G.item_count(item_id)==int(previous_items.get(item_id,0))+int(entry.rewards[gift].grants[grant]),"公布的道具数量真实入袋")
			var done_state:=G.prog.duplicate(true)
			var done_items:=G.items.duplicate(true)
			check(not bool(Events.action(G,id,String(entry.board.map),"partner").ok) and G.prog==done_state and G.items==done_items,"另一份谢礼不可重复领取")
			check(G.reload_save() and String(Events.record(G,id).reward)==gift,"结局和谢礼跨读档保留")
			check(Events.entities(G,String(entry.board.map)).any(func(entity): return bool(entity.feedback)),"完成后地图留物件")
			check(Events.validate(Events.state(G)),"写出的阶段可校验")
	await test_map_input(false)
	await test_map_input(true)
	await test_close_controls()
	await test_locations()
	fixture()
	G.SAVE_PATH="res://tools/_logs/save_verify_special_resume.json"
	Events.action(G,"misdelivered_invitation","lorin_wilds","accept")
	Events.action(G,"misdelivered_invitation","maple_road","inspect")
	Events.action(G,"misdelivered_invitation","maple_road","chase")
	Events.prepare_battle(G,"misdelivered_invitation","maple_road",ally())
	print("SPECIAL_EVENTS_OK branches=6 ui_routes=2" if fails==0 else "SPECIAL_EVENTS_FAIL fails=%d" % fails)
	get_tree().quit(0 if fails==0 else 1)

func button(root: Node, caption: String) -> Control:
	if root is Label and root.text.replace(" ","")==caption.replace(" ","") and root.get_parent() is Control: return root.get_parent()
	for child in root.get_children():
		var found:=button(child,caption)
		if found!=null: return found
	return null

func press(root: Node, caption: String) -> void:
	var target:=button(root,caption)
	check(target!=null,"真实按钮存在："+caption)
	if target==null: return
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	target.gui_input.emit(event)

func open_map(mid: String) -> MapScene:
	var run:=RunState.new()
	run.setup({"role_id":"zs","theme":"forest","level":60,"seed":99})
	MapScene.pending_cfg={"mode":"main_world","main_map_id":mid,"run":run,"node":{"type":"normal","layer":0,"index":0}}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map.set_process(false)
	map.set_physics_process(false)
	map._world.process_mode=Node.PROCESS_MODE_DISABLED
	if map._city_content!=null: map._city_content._close_panel()
	return map

func event_entity(map: MapScene) -> Node:
	for entity in map._quest_entities:
		if String(entity.special_event_id)=="misdelivered_invitation" and not entity.used: return entity
	return null

func test_map_input(combat: bool) -> void:
	fixture()
	var map:MapScene=await open_map("lorin_wilds")
	var entity:=event_entity(map)
	check(entity!=null,"城中有真实奇遇入口")
	if entity==null: return
	map.on_quest_entity(entity)
	check(map._special_panel!=null and map._modal_open(),"打开奇遇时世界交互冻结")
	if map._special_panel==null: return
	press(map._special_panel,"接下这件趣事")
	await get_tree().process_frame
	check(String(Events.record(G,"misdelivered_invitation").phase)=="clue","真实输入接取")
	map.queue_free()
	await get_tree().process_frame

	map=await open_map("maple_road")
	entity=event_entity(map)
	check(entity!=null,"野外依当前阶段生成目标")
	if entity==null: return
	map.on_quest_entity(entity)
	press(map._special_panel,"核对线索，继续寻找")
	await get_tree().process_frame
	map._special_panel.close()
	await get_tree().process_frame
	await get_tree().process_frame
	entity=event_entity(map)
	check(entity!=null,"核对后出现信使")
	if entity==null: return
	map.on_quest_entity(entity)
	press(map._special_panel,"替信使追回红绳 · 战斗" if combat else "问清戏票上的赵字")
	await get_tree().process_frame
	if combat:
		check(map._battle!=null,"选择战斗进入真实战斗场景")
		if map._battle!=null:
			var sim:BattleSim=map._battle.sim
			check(sim.potions_left==2,"奇遇临时药剂明确为两瓶")
			sim.auto_mode=true
			for i in range(9000):
				if sim.finished: break
				sim.step()
			check(sim.result=="victory","实际模拟战斗能获胜")
			map._battle.confirm_result()
			await get_tree().process_frame
	check(String(Events.record(G,"misdelivered_invitation").phase)=="return","两条真实操作路线都能复命")
	map.queue_free()
	await get_tree().process_frame
	map=await open_map("lorin_wilds")
	entity=event_entity(map)
	if entity!=null:
		map.on_quest_entity(entity)
		press(map._special_panel,"攻击宝石Ⅰ ×1")
		check(G.item_count("gem_atk_1")==1,"地图领奖按钮实际给宝石")
	map.queue_free()
	await get_tree().process_frame

func test_close_controls() -> void:
	var panel:=SpecialEventPanel.new()
	add_child(panel)
	panel.open_event(Events.presentation(G,"misdelivered_invitation","lorin_wilds"))
	var closed:={"count":0}
	panel.closed.connect(func(): closed.count+=1)
	await get_tree().process_frame
	var event:=InputEventKey.new()
	event.keycode=KEY_ESCAPE
	event.pressed=true
	G.ui_blocked=true
	panel._unhandled_input(event)
	check(int(closed.count)==0,"GM覆盖期间返回键不穿透关闭奇遇")
	G.ui_blocked=false
	press(panel,"回到路上")
	check(int(closed.count)==1,"手机可见返回按钮实际关闭奇遇")
	await get_tree().process_frame
	panel=SpecialEventPanel.new()
	add_child(panel)
	panel.open_event(Events.presentation(G,"misdelivered_invitation","lorin_wilds"))
	panel.closed.connect(func(): closed.count+=1)
	await get_tree().process_frame
	panel._unhandled_input(event)
	check(int(closed.count)==2,"键盘返回键实际关闭奇遇")
	await get_tree().process_frame

func test_locations() -> void:
	fixture()
	for entry in Events.rows():
		for key in ["board","clue","encounter"]:
			var location:Dictionary=entry[key]
			var map:MapScene=await open_map(String(location.map))
			map._world.process_mode=Node.PROCESS_MODE_INHERIT
			map._player.set_physics_process(false)
			for monster in map._monsters: monster.process_mode=Node.PROCESS_MODE_DISABLED
			await get_tree().physics_frame
			var point:=Vector2(float(location.at[0]),float(location.at[1]))
			var reachable:=false
			for offset:Vector2 in [Vector2.ZERO,Vector2(28,0),Vector2(-28,0),Vector2(0,28),Vector2(0,-28)]:
				var query:=PhysicsPointQueryParameters2D.new()
				query.position=point+offset
				query.collision_mask=2
				if map._player.get_world_2d().direct_space_state.intersect_point(query).is_empty(): reachable=true
			check(reachable,String(entry.id)+" "+key+"目标交互半径内存在可站立位置")
			map.queue_free()
			await get_tree().process_frame
