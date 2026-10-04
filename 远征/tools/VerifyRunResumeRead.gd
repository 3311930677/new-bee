extends Node

var _fails := 0

func _check(ok: bool, line: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + line)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_run_resume.json"
	_check(G.reload_save(), "第二进程读取历练档")
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/_logs/run_resume_expected.json"))
	_check(JSON.stringify(G.prog.get("active_run", {})) == JSON.stringify(expected), "第二进程全字段与第一进程原快照一致")
	RouteScene.pending_run = {"resume": true}
	var route := (load("res://src/run/RouteScene.tscn") as PackedScene).instantiate() as RouteScene
	add_child(route)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(route.st.hp == 123 and route.st.potions == 1 and route.st.traits == ["tr_atk_up_s"], "血量、药剂、词条原样恢复")
	_check(route._map != null, "重进原节点，不能另抽路线")
	if route._map != null:
		var map := route._map
		_check(map._interactable == null and bool(map._prog.get("interact_done", false)), "用过物件不复生，不重发事件金币")
		_check(map._picker != null and map._picker.choices == expected.state.map_state["1_1"].pending_choices, "待选祝福原样恢复，不重掷")
		_check(str(map._rng.state) == String(expected.state.map_state["1_1"].rng_state), "随机流跨JSON以字符串保持64位精度")
	var gold := int(G.wallet.gold)
	var total := route.st.gold
	var settled := G.run_settle(route.st, false)
	_check(bool(settled.get("ok", false)) and int(G.wallet.gold) == gold + total, "恢复后报酬正常结算")
	gold = int(G.wallet.gold)
	_check(bool(G.run_settle(route.st, false).get("ok", false)) and int(G.wallet.gold) == gold, "重复整局结算不再发奖或重复慰礼")
	_check((G.prog.get("active_run", {}) as Dictionary).is_empty(), "结算后续局入口清除")
	print("RUN_RESUME_READ_OK" if _fails == 0 else "RUN_RESUME_READ_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
