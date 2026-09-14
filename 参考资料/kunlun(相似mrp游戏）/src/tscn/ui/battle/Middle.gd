extends Control
const prefix = "CombatUi-Middle->"


onready var auto_btn = $"../Bottom/Auto"

var ScreenUtils
var CombatManage



var atkmode = 2
var atk_skill_prop = 0

var atknum = 1

var atktype = 1


var atk_skill_info = null

var skill_cd_map = {}

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	CombatManage = Global.get("CombatManage")
	CombatManage.connect("fight_continue_", self, "fight_continue_")
	_hide_all_xiaojian()
	$Btns.hide()


func _hide_all_xiaojian():
	for x in $XiaoJian.get_children():
		x.hide()


func _on_gong_jn_item_click() -> void :
	atkmode = 2
	atknum = 1
	atk_skill_prop = 0
	select_target()


func _on_jn_item_click() -> void :
	
	atk_skill_prop = 1
	$"../ListMenu".show_m(atktype, self, "on_jn_result")
	
	pass


func _on_fang_item_click() -> void :
	
	if CombatManage.room_type != 1:
		ScreenUtils.show_message("当前战斗不允许捕捉")
		return
	
	if atktype != 1:
		ScreenUtils.show_message("宠物不可执行捕捉动作")
		return
	
	
	var map_info = Global.get("MapInfoManage").get_current_map_info()
	
	if map_info["pet_catch"] != 1:
		ScreenUtils.show_message("当前地图不允许捕捉宠物！")
		return
	
	atkmode = 2
	atknum = 1
	atk_skill_prop = - 1
	select_target()
	pass


func _on_tao_item_click() -> void :
	
	if atktype != 1:
		return
	
	ScreenUtils.show_message("确定逃离战斗？", self, "ok_run_away_")
	pass



func _on_wu_item_click() -> void :
	atk_skill_prop = 2
	pass



func select_target():
	
	$JNBTNS.hide()
	
	auto_btn.hide()
	
	$Btns.show()
	
	var local_map = Global.get("CombatManage").local_mapping_map
	var arr_key = local_map.keys()
	
	
	
	if atkmode == 1 or atkmode == 14 or atkmode == 16 or atkmode == 18 or atkmode == 19:
		
		if atkmode == 18:
			if atktype == 1:
				var index = CombatManage.get_player_local_index()
				
				$Positions.get_child(int(index)).get_child(0).checked()
				pass
			elif atktype == 2:
				
				var index = CombatManage.get_pet_local_index()
				$Positions.get_child(int(index)).get_child(0).checked()
				pass
			pass
		else:
			
			for key in arr_key:
				if int(key) >= 6:
					var entity = local_map[str(key)]
					
					if entity != null and not entity["death"]:
						$Positions.get_child(int(key)).get_child(0)._on_btn_click_s()
	else:
		
		var temp_arr = []
		
		for key in arr_key:
			if int(key) < 6:
				var entity = local_map[str(key)]
				if entity != null and not entity["death"]:
					if atkmode == 15:
						temp_arr.append(key)
					else:
						$Positions.get_child(int(key)).get_child(0)._on_btn_click_s()
		
		if atkmode == 15:
			var ind = randi() % temp_arr.size()
			$Positions.get_child(int(temp_arr[ind])).get_child(0)._on_btn_click_s()
	
	
	if Global.get("RoleInfoManage").hot_role_op.get("auto_atk", false) or atkmode == 15 or atkmode == 18:
		_on_Ok_pressed()
	



func _on_Ok_pressed() -> void :
	var local_index_arr = []
	var ind = 0
	for i in $XiaoJian.get_children():
		if i.visible: local_index_arr.append(ind)
		ind = ind + 1
	if local_index_arr.size() <= 0:
		ScreenUtils.show_message("目标不能为空,请重新选择")
		_on_Cancle_pressed()
		return
	Global.log_info(str(prefix, local_index_arr))
	if atk_skill_prop == 0:
		CombatManage.normal_atk(local_index_arr)
	elif atk_skill_prop == 1:
		
		
		skill_cd_map[str(atk_skill_info["id"])] = $"..".round_num
		CombatManage.skill_atk(local_index_arr, atk_skill_info["id"])
	elif atk_skill_prop == - 1:
		
		CombatManage.catch_pet(local_index_arr)
	hide_all()



func _on_Cancle_pressed() -> void :
	_hide_all_xiaojian()
	$Btns.hide()
	$JNBTNS.show()
	auto_btn.show()


func on_jn_result(skill_info):
	atk_skill_info = skill_info
	atknum = skill_info["target_num"]
	atkmode = skill_info["target_type"]
	
	
	var c_round = $"..".round_num
	
	if skill_cd_map.has(str(atk_skill_info["id"])):
		
		
		var pre_round = int(skill_cd_map[str(atk_skill_info["id"])])
		
		if (pre_round + int(skill_info["cd"])) > c_round:

			ScreenUtils.show_tips("技能冷却时间未到,自动改为普攻")
			
			_on_gong_jn_item_click()
			return
	
	select_target()


func auto_atk():
	if not Global.get("RoleInfoManage").hot_role_op.get("auto_atk", false):
		
		$JNBTNS.show()
		return
	
	var key = "role_atk"
	if int(Global.get("CombatManage").atk_type) == 2:
		key = "pet_atk"
	var id = Global.get("RoleInfoManage").hot_role_op.get(key, - 1)
	
	
	if id > 0:
		if key == "role_atk":
			
			var info = Global.get("CombatManage").get_player_info()
			var flag = false
			for i in info["skill_ids"]:
				if int(i) == int(id):
					flag = true
					break;
				pass
			if not flag: id = - 1
			
		else:
			var info = Global.get("CombatManage").get_player_pet_info()
			var flag = false
			for i in info["skill_ids"]:
				if int(i) == int(id):
					flag = true
					break;
				pass
			if not flag: id = - 1
		pass
	
	if id < 0:
		
		atk_skill_prop = 0
		_on_gong_jn_item_click()
	else:
		
		atk_skill_prop = 1
		var skill_info = Global.get("StaticGameData").get_skill_data(id)
		on_jn_result(skill_info)
		
	pass



func fight_continue_(atk_type):
	atktype = atk_type
	$"../Bottom/Auto".show()
	if atk_type == 1 or atk_type == 2:
		if Global.get("RoleInfoManage").hot_role_op.get("auto_atk", false):
			
			$"..".auto_atk()
			pass
		else:
			$JNBTNS.show()

func ok_run_away_():
	hide_all()
	CombatManage.run_away()
	pass


func hide_all():
	$JNBTNS.hide()
	$Btns.hide()
	$"../Bottom/Auto".show()
	_hide_all_xiaojian()


