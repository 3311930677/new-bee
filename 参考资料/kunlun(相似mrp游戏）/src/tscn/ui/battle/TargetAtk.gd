extends TextureButton
const prefix = "CombatUiPosition->Texture:"
export (int) var local_index = 0


var CombatManage
var ScreenUtils
var atkmode
var atknum

func _ready() -> void :
	CombatManage = Global.get("CombatManage")
	ScreenUtils = Global.get("ScreenUtils")
	connect("pressed", self, "_on_btn_click")


func random_select():
	pass


func select():
	
	
	atkmode = $"../../..".atkmode
	atknum = $"../../..".atknum
	
	if ( not invalid()): return false
	
	if CombatManage.local_mapping_map == null or CombatManage.local_mapping_map[str(local_index)] == null:
		return false
	var entity_info = CombatManage.local_mapping_map[str(local_index)]
	if entity_info == null: return
	
	
	if entity_info["death"]:
		if atkmode != 16:
			return false
	
	
	
	if atkmode == 16 and entity_info["death"]:
		checked()
		return
	elif atkmode == 16: return false
	checked()
	
	
	match int(atkmode):
		11:
			
			check_hd_target()
			pass
		12:
			
			check_vd_target()
			pass
		13:
			
			check_ad_target()
			pass
		14:
			
			check_rm_target()
			pass
		15:
			
			check_rd_target()
			pass
		16:
			check_sm_target()
			
			pass
		17:
			check_sd_target()
			
			pass
		
	return true



func invalid():
	if atkmode == 2 or atkmode == 11 or atkmode == 12 or atkmode == 13 or atkmode == 15:
		if local_index >= 0 and local_index <= 5: return true
	if atkmode == 1 or atkmode == 14 or atkmode == 10:
		if local_index >= 6 and local_index <= 11: return true
	
	if atkmode == 16 and local_index >= 6:
		return true
	if atkmode == 17 and local_index < 6:
		return true
	if atkmode == 19 and local_index >= 6:
		
		var entity_info = CombatManage.local_mapping_map[str(local_index)]
		if entity_info == null: return false
		if CombatManage.atk_type == 1:
			if entity_info["id"] == Global.get("RoleInfoManage").get_role_id(): return false
			else: return true
		if CombatManage.atk_type == 2:
			if entity_info["id"] == Global.get("PetInfoManage").get_fight_pet_id(): return false
			else: return true
	
	return false


func checked():
	var arr_x = $"../../../XiaoJian".get_children()
	arr_x[local_index].show()
func is_checked(inde):
	var arr_x = $"../../../XiaoJian".get_children()
	return arr_x[int(inde)].visible

func checked_(local_i):
	var map = CombatManage.local_mapping_map
	if map[str(local_i)] == null: return
	if map[str(local_i)]["death"]: return
	var arr_x = $"../../../XiaoJian".get_children()
	arr_x[int(local_i)].show()


func _on_btn_click():
	if not $"../../../..".round_start: return
	
	if get_parent().get_parent().get_parent().get_parent().is_auto_run: return
	
	clear_checked()
	select()

func _on_btn_click_s():
	clear_checked()
	select()
	pass


func clear_checked():
	var arr_x = $"../../../XiaoJian".get_children()
	for i in arr_x: i.hide()


func check_hd_target():
	
	if local_index % 2 == 1:
		checked_(local_index - 1)
	else:
		checked_(local_index + 1)

func check_vd_target():
	var arr_x = $"../../../XiaoJian".get_children()
	if local_index % 2 == 1:
		
		checked_(1)
		checked_(3)
		checked_(5)
	else:
		
		checked_(0)
		checked_(2)
		checked_(4)

func check_ad_target():
	
	var h: int = local_index / 2
	if atknum >= 6:
		checked_(0)
		checked_(1)
		checked_(2)
		checked_(3)
		checked_(4)
		checked_(5)
	else:
		if h == 0 or h == 1:
			checked_(0)
			checked_(1)
			checked_(2)
			checked_(3)
		if h == 2:
			checked_(4)
			checked_(5)
			checked_(2)
			checked_(3)


func check_rd_target():
	var s_num = atknum - 1
	if s_num == 0: return
	
	
	var temp_arr = []
	var local_map = Global.get("CombatManage").local_mapping_map
	var arr_key = local_map.keys()
	for key in arr_key:
		if int(key) < 6:
			var entity = local_map[str(key)]
			if entity != null and not entity["death"] and entity["index"] != local_index:
				temp_arr.append(key)
	
	if temp_arr.size() <= 0: return
	if temp_arr.size() <= s_num:
		
		for i in temp_arr: checked_(i)
		return
	
	var selected_index = []
	for i in s_num:
		
		var max_x = 20
		var temp_max_x = 0
		while (true):
			temp_max_x += 1
			if temp_max_x >= max_x:
				Global.log_info(str(prefix, "无法选中更多"))
				break
			var ii = randi() % temp_arr.size()
			
			if not is_checked(int(temp_arr[ii])) and selected_index.find(int(temp_arr[ii])) == - 1:
				checked_(int(temp_arr[ii]))
				selected_index.append(int(temp_arr[ii]))
				break


func check_rm_target():
	
	var h: int = local_index / 2
	if atknum >= 6:
		checked_(6)
		checked_(7)
		checked_(8)
		checked_(9)
		checked_(10)
		checked_(11)
	else:
		if h == 0 or h == 1:
			checked_(6)
			checked_(7)
			checked_(8)
			checked_(9)
		if h == 2:
			checked_(10)
			checked_(11)
			checked_(8)
			checked_(9)
	pass

func check_sm_target():
	var map = CombatManage.local_mapping_map
	for local_i in 12:
		if map[str(local_i)] == null: continue
		if map[str(local_i)]["death"]:
			var arr_x = $"../../../XiaoJian".get_children()
			arr_x[local_i].show()
			return

func check_sd_target():
	var map = CombatManage.local_mapping_map
	for local_i in 6:
		if map[str(local_i)] == null: continue
		if map[str(local_i)]["death"]:
			var arr_x = $"../../../XiaoJian".get_children()
			arr_x[local_i].show()
			return
