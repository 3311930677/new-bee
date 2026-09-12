extends Control


onready var ok_cancel_btns = $"Middle/Btns"

onready var middle_five_btns = $"Middle/JNBTNS"

onready var list_menu_ = $ListMenu

onready var positions = $Middle / Positions

onready var xiaojian = $Middle / XiaoJian

onready var temp_auto_timer = $TempAuto

onready var middle = $Middle

onready var auto_btn = $Bottom / Auto

var script_selector = preload("res://src/tscn/scence/battle/BattleSelector.gd")

var ScreenUtils
var StaticGameData
var TBBattleManage


var selector = null


var op_type = 0




var op_behavior_type = 0


var auto_atk = false


var tb_battle_scence = null

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	TBBattleManage = Global.get("TBBattleManage")
	TBBattleManage.connect("operation_success", self, "_operation_success_")
	
	
	auto_atk = Global.get("RoleInfoManage").hot_role_op.get("auto_atk", false)
	
	
	positions.connect("index_click", self, "_index_click")
	list_menu_.connect("item_click_", self, "_on_skill_item_click")
	
	
	selector = script_selector.new()
	selector.xiaojians = xiaojian
	selector.init_data()
	selector.connect("auto_ok_select", self, "_on_ok_select_pressed")
	
	
	tb_battle_scence = Global.get_nodes_in_group("tb_battle_scence")[0]
	tb_battle_scence.connect("round_show_hourglass_", self, "round_show_hourglass_")
	tb_battle_scence.connect("battle_round_start_", self, "battle_round_start_")
	
	
	
	
	var role_ = TBBattleManage.get_role_entity_data()
	var pet_ = TBBattleManage.get_pet_entity_data()
	if role_ != null and not role_["death"]:
		op_type = 0
		toggle_btns()
	else:
		if pet_ != null and not pet_["death"]:
			op_type = 1
			toggle_btns()
	
	if auto_atk:
		temp_auto_timer.wait_time = 2
		temp_auto_timer.start()
		middle_five_btns.visible = false
		ok_cancel_btns.visible = false
		xiaojian.all_hide()
		auto_btn.text = "取消"
	pass






func toggle_btns(flag: bool = true):
	
	
	if tb_battle_scence.battle_end_data != null: return
	
	middle_five_btns.visible = flag
	auto_btn.visible = flag
	ok_cancel_btns.visible = not flag
	xiaojian.all_hide()
	pass


func _operation_success_():
	
	
	if op_type == 1: return
	
	
	if op_type == 0: op_type = 1
	
	
	if op_type == 1 and (TBBattleManage.get_pet_entity_data() == null or TBBattleManage.get_pet_entity_data()["death"]):
		return
	
	if op_type == 1:
		_on_TempAuto_timeout()
		
	



func _index_click(index):
	if selector != null:
		selector.click_index(index)

func _on_ok_select_pressed() -> void :
	var arr = xiaojian.get_select_arr()
	var targets = []
	
	var local_map = TBBattleManage.current_local_position_map
	for i in arr:
		targets.append(local_map.get(str(i)).real_index)
	Global.log_info(str("选择的真实下标", targets))
	
	
	middle_five_btns.visible = false
	ok_cancel_btns.visible = false
	auto_btn.visible = true
	xiaojian.all_hide()
	
	if targets.size() <= 0:
		Global.log_info(str("TBBattleUi->", "空目标，请手动尝试"))
		return
	
	match op_behavior_type:
		0:
			
			TBBattleManage.generate_atk(op_type, targets)
			
			pass
		1:
			
			TBBattleManage.skill_atk(op_type, selector.skill_data["id"], targets)
			
			list_menu_.release_skill(selector.skill_data["id"])
			pass
		2:
			
			TBBattleManage.capture(op_type, targets)
			pass
		4:
			
			pass
	
func _on_select_cancle_pressed() -> void :
	toggle_btns()
	pass



func _on_skill_item_click(data):
	toggle_btns(false)
	
	if int(data["id"]) == 99999999:
		
		buzhuo()
	else:
		if selector != null:
			selector.select_type = 1
			selector.skill_data = data
			selector.op_type = op_type
			op_behavior_type = 1
			
			selector.default_skill_select()
	pass

func _on_tao_ok_click():
	TBBattleManage.escape(op_type)
	middle_five_btns.visible = false
	ok_cancel_btns.visible = false
	auto_btn.visible = false
	xiaojian.all_hide()
	pass

func _on_jin_item_click() -> void :
	list_menu_.show_skill(op_type)


func _on_gong_item_click() -> void :
	toggle_btns(false)
	if selector != null:
		selector.select_type = 0
		op_behavior_type = 0
		selector.default_oop_select()
	pass


func _on_fang_item_click() -> void :
	var sk_data = StaticGameData.get_skill_data(100000)
	if selector != null:
		selector.select_type = 1
		selector.skill_data = sk_data
		selector.op_type = op_type
		op_behavior_type = 1
		
		selector.default_skill_select()
	pass

func _on_tao_item_click() -> void :
	if op_type != 0:
		ScreenUtils.show_message("宠物不可执行逃跑")
		return
	ScreenUtils.show_message("确定逃跑？", self, "_on_tao_ok_click")
	op_behavior_type = 3
	pass


func _on_wu_item_click() -> void :
	toggle_btns(false)
	if selector != null:
		selector.select_type = 4
		op_behavior_type = 4
	pass


func _on_quit_pressed() -> void :
	tb_battle_scence._on_EndTimer_timeout()
	pass


func round_show_hourglass_():
	
	if tb_battle_scence.battle_end_data != null: return
	
	var role_entity = TBBattleManage.get_role_entity_data()
	var pet_entity = TBBattleManage.get_pet_entity_data()
	
	if not role_entity["death"]: op_type = 0
	
	elif not pet_entity["death"]: op_type = 1
	
	else: op_type = 3
	
	if op_type < 2: toggle_btns()
	
	if auto_atk:
		middle_five_btns.visible = false
		ok_cancel_btns.visible = false
		auto_btn.visible = true
		xiaojian.all_hide()
		temp_auto_timer.wait_time = 2
		temp_auto_timer.start()



func _auto_atk_proccess():
	var atk_id = - 1
	
	if op_type == 0: atk_id = Global.get("RoleInfoManage").hot_role_op.get("role_atk", - 1)
	else: atk_id = Global.get("RoleInfoManage").hot_role_op.get("pet_atk", - 1)
	
	if atk_id == - 1:
		
		_on_gong_item_click()
		_on_ok_select_pressed()
		pass
	else:
		

		var data = Global.get("StaticGameData").get_skill_data_temp(atk_id)
		
		var entity_data = null
		if op_type == 0:
			entity_data = Global.get("TBBattleManage").get_role_entity_data()
		else:
			entity_data = Global.get("TBBattleManage").get_pet_entity_data()
		
		if entity_data != null and not entity_data["otherData"]["skill"].has(atk_id):
			
			_on_gong_item_click()
			_on_ok_select_pressed()
			return
			pass
		
		if atk_id != 100000:
			var end_round = list_menu_.skill_cd_map.get(str(atk_id), - 999) + data["cd"]

			
			if end_round > TBBattleManage.get_battle_round():
				
				selector.select_type = 0
				_on_gong_item_click()
				_on_ok_select_pressed()
				return
		
		if int(data.get("mp_consume", 0)) > 0 and int(entity_data["otherData"]["mp"]) < int(data.get("mp_consume", 0)):
			
			selector.select_type = 0
			_on_gong_item_click()
			_on_ok_select_pressed()
			return
		
		selector.select_type = 1
		selector.skill_data = data
		selector.op_type = op_type
		op_behavior_type = 1

		
		selector.default_skill_select()
		
		if data["target_type"] != 101:
			_on_ok_select_pressed()
		pass
	
	pass
	


func _on_auto_timeout() -> void :
	Global.log_info("执行自动操作")
	
	_on_Auto_pressed()










func battle_round_start_():
	op_type = 1
	
	middle_five_btns.visible = false
	ok_cancel_btns.visible = false
	auto_btn.visible = true
	xiaojian.all_hide()
	pass


func _on_Auto_pressed() -> void :
	auto_atk = not auto_atk
	Global.get("RoleInfoManage").hot_role_op["auto_atk"] = auto_atk
	
	if auto_atk: auto_btn.text = "取消"
	else: auto_btn.text = "自动"
		
	
	if tb_battle_scence.current_line_run_down:

		
		temp_auto_timer.stop()
		temp_auto_timer.wait_time = 1
		temp_auto_timer.start()


func _on_TempAuto_timeout() -> void :
	if auto_atk:
		
		middle_five_btns.visible = false
		ok_cancel_btns.visible = false
		auto_btn.visible = true
		xiaojian.all_hide()
		
		if tb_battle_scence.current_line_run_down:
			_auto_atk_proccess()
		auto_btn.text = "取消"
	else:
		auto_btn.text = "自动"
		
		
		if tb_battle_scence.current_line_run_down:
			toggle_btns()



func buzhuo():
	if op_type != 0:
		ScreenUtils.show_message("宠物不可执行此操作")
		return
	if TBBattleManage.get_battle_room_type() != 0:
		ScreenUtils.show_message("当前战斗不可执行此操作")
		return
	var local_map = TBBattleManage.current_local_position_map
	for k in local_map.keys():
		if local_map[k].entity_data["type"] == "monster":
			if not local_map[k].entity_data.get("isCatch", false):
				ScreenUtils.show_message("此宠物不可捕捉")
				return
	
	
	toggle_btns(false)
	if selector != null:
		selector.select_type = 2
		op_behavior_type = 2
		selector.default_oop_select()

