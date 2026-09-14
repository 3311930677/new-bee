extends Node


var TBBattleManage
var RoleInfoManage
var PetInfoManage

signal auto_ok_select


var fight_local_map

var xiaojians







var select_type

var op_type = - 1

var skill_data


var current_click_index = - 1


var left_index_sort = [3, 1, 5, 4, 2, 6]


var right_index_sort = [10, 8, 12, 9, 7, 11]


func init_data():
	TBBattleManage = Global.get("TBBattleManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	PetInfoManage = Global.get("PetInfoManage")
	fight_local_map = TBBattleManage.current_local_position_map
	pass














func default_skill_select():
	
	if skill_data == null: return
	var target_type = skill_data["target_type"]
	
	
	match int(target_type):
		100:
			
			current_click_index = private_get_oop_life_index()
			pass
		102:
			
			current_click_index = private_get_oop_life_index()
			pass
		103:
			
			current_click_index = private_get_oop_life_index()
			pass
		104:
			current_click_index = private_get_oop_life_index()
			
			pass
		105:
			current_click_index = private_get_oop_life_index()
			pass
		200:
			
			current_click_index = private_get_self_life_index( - 99)
			pass
		202:
			
			current_click_index = private_get_self_life_index(private_get_self_index())
			pass
		203:
			
			current_click_index = private_get_self_die()
	_skill_select()



func default_oop_select():
	var c_index = private_get_oop_life_index()
	
	if c_index > 0:
		current_click_index = c_index
		_atk_select()


func click_index(index):
	current_click_index = index
	if select_type == 0 or select_type == 2: _atk_select()
	elif select_type == 1: _skill_select()

	elif select_type == 4: _prop_select()






func _atk_select():
	
	if current_click_index > 6: return
	
	xiaojians.all_hide()
	
	if fight_local_map.has(str(current_click_index)) and current_click_index <= 6:
		
		if fight_local_map[str(current_click_index)].entity_data["death"]: return
		if fight_local_map[str(current_click_index)].entity_data["escape"]: return
		if fight_local_map[str(current_click_index)].entity_data["snap"]: return
		var a = [current_click_index]
		
		if xiaojians != null: xiaojians.select(a)
	
	pass


func _skill_select():
	if skill_data == null: return
	xiaojians.all_hide()
	var target_type = skill_data["target_type"]
	
	match int(target_type):
		100:
			
			if int(skill_data["target_num"]) == 1:
				_atk_select()
			else:
				private_select_left_all()
		101:
			private_select_left_random()
			
		102:
			
			private_select_left_horizontal()
			pass
		103:
			
			private_select_left_vertical()
			pass
		104:
			
			private_select_left_four()
			pass
		105:
			
			private_select_left_random_around()
			pass
		200:
			
			if int(skill_data["target_num"]) == 6:
				private_select_right_all()
			else:
				private_select_right()
				Global.log_info("有单个数量的选择情况")
		201:
			private_select_right_self()
			
			pass
		202:
			private_select_right_teammate()
			
			pass
		203:
			private_select_right_die()
			pass
	pass

func _prop_select():
	pass






func private_select_left_all():
	for ind in left_index_sort:
		if fight_local_map.has(str(ind)) and ind <= 6:
			
			if fight_local_map[str(ind)].entity_data["death"]: continue
			if fight_local_map[str(ind)].entity_data["escape"]: continue
			if fight_local_map[str(ind)].entity_data["snap"]: continue
			
			var a = [ind]
			
			if xiaojians != null: xiaojians.select(a)
	emit_signal("auto_ok_select")


func private_select_left_vertical():
	if current_click_index > 6: return
	var num = 0;
	var max_num = skill_data["target_num"]
	
	
	if private_oop_has_life(current_click_index):
		xiaojians.select([current_click_index])
		num += 1
	
	var k = []
	
	for i in max_num - 1:
		if current_click_index + 2 * (i + 1) > 0 and current_click_index + 2 * (i + 1) <= 6:
			k.append(current_click_index + 2 * (i + 1))
		if current_click_index - 2 * (i + 1) > 0 and current_click_index - 2 * (i + 1) <= 6:
			k.append(current_click_index - 2 * (i + 1))
	
	while (k.size() > 0):
		var inde = k.front()
		k.erase(inde)
		
		if private_oop_has_life(inde):
			xiaojians.select([inde])
			num += 1
		if num >= max_num: break
		pass


func private_select_left_horizontal():
	if current_click_index > 6: return
	if private_oop_has_life(current_click_index):
		xiaojians.select([current_click_index])
	if current_click_index % 2 == 0:
		if private_oop_has_life(current_click_index - 1):
			xiaojians.select([current_click_index - 1])
	else:
		if private_oop_has_life(current_click_index + 1):
			xiaojians.select([current_click_index + 1])


func private_select_left_random():
	
	var indexs = left_index_sort.duplicate(true)
	var num = 0
	var max_num = skill_data["target_num"]
	while (indexs.size() > 0):
		var i = indexs[randi() % indexs.size()]
		
		indexs.erase(i)
		
		if private_oop_has_life(i):
			
			num += 1
			
			xiaojians.select([i])
		
		if num >= max_num: break
		pass
	emit_signal("auto_ok_select")


func private_select_left_four():
	
	var indexs = [1, 2, 3, 4]
	if current_click_index >= 1 and current_click_index <= 2:
		
		indexs = [1, 2, 3, 4]
	else:
		
		indexs = [current_click_index]
		if current_click_index % 2 == 0:
			indexs.append(current_click_index - 1)
			indexs.append(current_click_index - 2)
			indexs.append(current_click_index - 3)
			pass
		else:
			indexs.append(current_click_index - 1)
			indexs.append(current_click_index - 2)
			indexs.append(current_click_index + 1)
			pass
	for i in indexs:
		if private_oop_has_life(i):
			if xiaojians != null: xiaojians.select([i])



func private_select_left_random_around():
	if current_click_index > 6:
		
		current_click_index = private_get_oop_life_index()
	var indexs = left_index_sort.duplicate(true)
	var num = 0
	var max_num = skill_data["target_num"] - 1
	if private_oop_has_life(current_click_index):
		xiaojians.select([current_click_index])
	while (indexs.size() > 0):
		var i = indexs[randi() % indexs.size()]
		indexs.erase(i)
		if current_click_index == i: continue
		
		if private_oop_has_life(i):
			
			num += 1
			
			xiaojians.select([i])
		
		if num >= max_num: break
		pass



func private_select_right():
	xiaojians.all_hide()
	
	if fight_local_map.has(str(current_click_index)) and current_click_index > 6:
		
		if fight_local_map[str(current_click_index)].entity_data["death"]: return
		if fight_local_map[str(current_click_index)].entity_data["escape"]: return
		if fight_local_map[str(current_click_index)].entity_data["snap"]: return
		var a = [current_click_index]
		
		if xiaojians != null: xiaojians.select(a)
	pass


func private_select_right_all():
	for ind in right_index_sort:
		if fight_local_map.has(str(ind)) and ind > 6:
			
			if fight_local_map[str(ind)].entity_data["death"]: continue
			if fight_local_map[str(ind)].entity_data["escape"]: continue
			if fight_local_map[str(ind)].entity_data["snap"]: continue
			var a = [ind]
			if xiaojians != null: xiaojians.select(a)
	emit_signal("auto_ok_select")


func private_select_right_die():
	
	if fight_local_map.has(str(current_click_index)):
		var data = fight_local_map[str(current_click_index)].entity_data
		if data["death"]:
			if xiaojians != null: xiaojians.select([current_click_index])


func private_select_right_self():
	var c_index = private_get_self_index()
	if xiaojians != null and c_index != - 1: xiaojians.select([c_index])
	emit_signal("auto_ok_select")
	pass


func private_select_right_teammate():
	var realese_index = private_get_self_index()
	if current_click_index == realese_index: return
	if xiaojians != null and current_click_index != - 1 and current_click_index > 6:
		xiaojians.select([current_click_index])
	pass





func private_oop_has_life(ind):
	if fight_local_map == null or fight_local_map.empty():
		fight_local_map = TBBattleManage.current_local_position_map
	
	if fight_local_map.has(str(ind)):
		
		if not is_instance_valid(fight_local_map[str(ind)]): return false
		
		var data = fight_local_map[str(ind)].entity_data
		if not data["death"] and not data["escape"] and not data["snap"]: return true
	return false
func private_self_has_life(ind):
	
	if fight_local_map.has(str(ind)) and ind > 6:
		var data = fight_local_map[str(ind)].entity_data
		if not data["death"] and not data["escape"] and not data["snap"]: return true
	return false

func private_get_oop_life_index():
	for i in left_index_sort:
		if private_oop_has_life(i): return i
	return - 1


func private_get_self_life_index(self_index):
	for i in right_index_sort:
		if private_oop_has_life(i) and self_index != i:
			return i
	return - 1


func private_get_self_index():
	
	var find_id = RoleInfoManage.get_role_id();
	var find_tyep = "role"
	if op_type != 0:
		find_tyep = "pet"
		find_id = PetInfoManage.get_fight_pet_id()
	
	for key in fight_local_map.keys():
		if fight_local_map[key].entity_data["id"] == find_id and fight_local_map[key].entity_data["type"] == find_tyep:
			return int(key)
	return - 1


func private_get_self_die():
	for ind in right_index_sort:
		if fight_local_map.has(str(ind)):
			var data = fight_local_map[str(ind)].entity_data
			if data["death"]:
				return ind
