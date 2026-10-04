extends Node
var _fails:=0
func _check(ok:bool,msg:String)->void:
	if not ok:
		_fails+=1
		push_error("FAIL: "+msg)
func _saved()->Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(G.SAVE_PATH)).prog.active_run.state
func _ready()->void:
	G.SAVE_PATH="res://tools/_logs/save_verify_immediate.json"
	G._init_state_defaults()
	G.save_locked=false
	var st:=RunState.new()
	st.setup({"theme":"forest","role_id":"zs","level":5,"seed":911,"potions":2})
	st.run_id="immediate-fixture"
	st.gold=900
	G.run_checkpoint(st)
	var node:Dictionary=st.route.layers[0][0]
	MapScene.pending_cfg={"run":st,"node":node}
	var map:=preload("res://src/explore/MapScene.tscn").instantiate() as MapScene
	add_child(map)
	await get_tree().process_frame
	_check(not map._pickups.is_empty(),"实际历练生成拾取物")
	var pickup=map._pickups[0]
	var before:=st.snapshot()
	var rng_before:=map._rng.state
	var path:=G.SAVE_PATH
	G.SAVE_PATH="res://tools/_logs/no_immediate_parent/save.json"
	var errors:=Engine.print_error_messages
	Engine.print_error_messages=false
	_check(not map.on_pickup(pickup),"真实写盘失败不能吞掉拾取物")
	Engine.print_error_messages=errors
	_check(st.snapshot()==before and map._rng.state==rng_before and map._pickups.has(pickup),"拾取奖励、进度和随机流全部回滚")
	G.SAVE_PATH=path
	_check(map.on_pickup(pickup),"同一拾取物可重试成功")
	var saved:=_saved()
	_check(int(saved.gold)==st.gold and int(saved.expedition)==st.expedition and saved.map_state==JSON.parse_string(JSON.stringify(st.snapshot().map_state)),"拾取立即写入磁盘快照")
	var gold:=st.gold
	_check(not map.on_pickup(pickup) and st.gold==gold,"同一拾取物不得重复领奖")
	pickup.queue_free()
	var choices:=st.roll_trait_choices(map._rng)
	map._show_trait_picker(choices)
	var tid:=String(choices[0].id)
	before=st.snapshot()
	G.save_locked=true
	map._picker._emit_pick(tid)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(st.snapshot()==before and map._picker!=null,"锁盘时祝福不生效且保留重试界面")
	G.save_locked=false
	map._picker._emit_pick(tid)
	await get_tree().process_frame
	_check(st.traits.has(tid) and _saved().traits==st.traits,"最终祝福选择立即持久化")
	var count:=st.traits.size()
	map._on_trait_picked(tid)
	_check(st.traits.size()==count,"过期祝福选择回调不会重复赋予词条")
	map._show_trait_remove()
	var click:=InputEventMouseButton.new()
	click.pressed=true
	click.button_index=MOUSE_BUTTON_LEFT
	G.save_locked=true
	map._on_remove_row(click,tid)
	_check(st.traits.has(tid) and map._remover!=null,"舍弃写盘失败保留词条和窗口")
	G.save_locked=false
	map._on_remove_row(click,tid)
	_check(not st.traits.has(tid) and not _saved().traits.has(tid),"篝火舍弃立即持久化")
	var altar:=MapScene._Spot.new()
	altar.idx=909
	altar.kind="altar"
	altar.map_ref=map
	map._world.add_child(altar)
	map._spots.append(altar)
	map._open_altar(altar)
	before=st.snapshot()
	rng_before=map._rng.state
	G.SAVE_PATH="res://tools/_logs/no_immediate_parent/save.json"
	Engine.print_error_messages=false
	map._altar_pay(altar,200)
	Engine.print_error_messages=errors
	_check(st.snapshot()==before and map._rng.state==rng_before and not altar.used and map._altar_ui!=null,"祭坛写盘失败退还货款、随机流及熄灯状态")
	G.SAVE_PATH=path
	map._altar_pay(altar,200)
	_check(st.gold==int(before.gold)-200 and altar.used and _saved().gold==st.gold,"祭坛付费和待选祝福一起保存")
	_check(not map._prog.get("pending_choices",[]).is_empty(),"祭坛保存未选祝福避免重开重摇")
	map.queue_free()
	await get_tree().process_frame
	print("RUN_IMMEDIATE_OK" if _fails==0 else "RUN_IMMEDIATE_FAIL count=%d"%_fails)
	get_tree().quit(0 if _fails==0 else 1)
