extends Node

var _fails := 0

func _check(ok: bool, line: String) -> void:
	if not ok:
		_fails += 1
		push_error("FAIL: " + line)

func _ready() -> void:
	G.SAVE_PATH = "res://tools/_logs/save_verify_run_resume.json"
	G._init_state_defaults()
	G.save_locked = false
	G.selected_role = "zs"
	G.mark_beat_seen("forest", "intro")
	RouteScene.pending_run = {"theme": "forest", "role_id": "zs", "level": 5, "seed": 1,
		"active_pet": "pet_rockturtle", "potions": 2}
	var route := (load("res://src/run/RouteScene.tscn") as PackedScene).instantiate() as RouteScene
	add_child(route)
	await get_tree().process_frame
	_check(not route.st.run_id.is_empty() and not (G.prog.get("active_run", {}) as Dictionary).is_empty(), "开局有稳定整局ID")
	var node: Dictionary = route.st.route.layers[0][1]
	route._enter_node(node)
	await get_tree().process_frame
	var map := route._map
	_check(map != null and map._interactable != null, "原节点实际可进入")
	if map != null:
		map.on_interactable(map._interactable)
		if map._puzzle_panel != null:
			var button := _event_button(map._puzzle_panel, preload("res://src/run/RunEvents.gd").row(route.st.theme).choices.work)
			_check(button != null, "续局夹具通过实际事件选择按钮")
			if button != null:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = true
				button.gui_input.emit(e)
				await get_tree().process_frame
		route.st.hp = 123
		route.st.potions = 1
		route.st.traits = ["tr_atk_up_s"]
		# 未选祝福和剩余随机流一起保存，下一进程不能重摇。
		var rng := RandomNumberGenerator.new()
		rng.seed = 711
		var choices := route.st.roll_trait_choices(rng)
		map._show_trait_picker(choices)
		map._checkpoint_run()
		await get_tree().process_frame
		var encoded := JSON.stringify(G.prog.active_run)
		var file := FileAccess.open("res://tools/_logs/run_resume_expected.json", FileAccess.WRITE)
		file.store_string(encoded)
		file.close()
		_check(G.reload_save() and String(G.prog.active_run.state.run_id) == route.st.run_id, "磁盘保存整局ID")
		var before := G.prog.duplicate(true)
		G.save_locked = true
		_check(not G.run_abandon() and G.prog == before, "锁盘不吞掉可续局")
		G.save_locked = false
	# Check an actual unwritable path; transaction must refund every mutation.
	var st := RunState.new()
	st.setup({"theme": "forest", "role_id": "zs", "level": 5, "seed": 8})
	st.run_id = "settlement-failure-fixture"
	st.gold = 100
	st.exp = 80
	var before_prog := G.prog.duplicate(true)
	var before_wallet := G.wallet.duplicate(true)
	var before_items := G.items.duplicate(true)
	var path := G.SAVE_PATH
	G.SAVE_PATH = "res://tools/_logs/missing_run_parent/save.json"
	var errors_were_enabled := Engine.print_error_messages
	Engine.print_error_messages = false
	var failed_settlement := G.run_settle(st, true)
	Engine.print_error_messages = errors_were_enabled
	_check(not bool(failed_settlement.get("ok", false)) and G.prog == before_prog
		and G.wallet == before_wallet and G.items == before_items, "真实写盘失败回滚金币、经验、解锁与慰礼")
	G.SAVE_PATH = path
	# Do not settle the live fixture: it must survive process exit intact.
	print("RUN_RESUME_OK" if _fails == 0 else "RUN_RESUME_FAIL fails=%d" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _event_button(root: Node, wanted: String) -> Control:
	if root == null: return null
	if root is Button and String(root.text).replace(" ", "") == wanted.replace(" ", ""): return root as Control
	for child in root.get_children():
		if child is Label and String(child.text).replace(" ", "") == wanted.replace(" ", ""): return child.get_parent() as Control
		var found := _event_button(child, wanted)
		if found != null: return found
	return null
