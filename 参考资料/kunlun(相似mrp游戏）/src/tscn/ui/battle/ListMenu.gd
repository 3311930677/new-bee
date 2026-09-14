extends Control

var call_obj
var call_method

func _ready() -> void :
	$PopupPanel / ListMenu.connect("double_click", self, "double_click")


func show_m(atk_type, call_obj, call_method):
	self.call_obj = call_obj
	self.call_method = call_method
	
	$PopupPanel / ListMenu.clear()
	$PopupPanel.rect_size = Vector2(0, 0)
	$PopupPanel / ListMenu.rect_size = Vector2(0, 0)
	var skill_ids = []
	if atk_type == 1:
		var p_info = Global.get("CombatManage").get_player_info()
		skill_ids.append_array(p_info["skill_ids"])
		pass
	if atk_type == 2:
		var p_info = Global.get("CombatManage").get_player_pet_info()
		skill_ids.append_array(p_info["skill_ids"])
	
	var c_role_mp = Global.get_nodes_in_group("main_head")[0].c_role_mp
	var c_pet_mp = Global.get_nodes_in_group("main_head")[0].c_pet_mp
	
	var c_round = $"..".round_num
	var cd_map = $"../Middle".skill_cd_map
	if skill_ids.size() > 0:
		var arr_info = []
		for i in skill_ids:
			var temp = {}
			var skill_info = Global.get("StaticGameData").get_skill_data(i)
			
			
			
			if skill_info["type"] == 0: continue
			
			
			if cd_map.has(str(skill_info["id"])):
				
				if cd_map[str(skill_info["id"])] + skill_info["cd"] > c_round:
					
					temp["cd"] = true
			
			var c_mp = 0
			
			if atk_type == 1:
				c_mp = c_role_mp
				pass
			elif atk_type == 2:
				c_mp = c_pet_mp
				pass
			if c_mp == 0:
				temp["cd"] = true
			elif c_mp < skill_info["mp_consume"]:
				temp["cd"] = true
			
			temp["name"] = skill_info["name"]
			temp["data"] = skill_info
			arr_info.append(temp)
		$PopupPanel / ListMenu.add_items(arr_info)
		private_show()
	else:
		Global.get("ScreenUtils").show_message("当前没有技能")
	


func show_w():
	
	pass


func _on_Cancle_pressed() -> void :
	hide()
	$PopupPanel.hide()


func _on_Ok_pressed() -> void :
	hide()
	$PopupPanel / ListMenu.clear()
	$PopupPanel.hide()
	var info = $PopupPanel / ListMenu.get_select()
	if call_obj != null:
		call_obj.call(call_method, info)


func double_click():
	_on_Ok_pressed()


func private_show():
	show()
	$PopupPanel.popup_centered_minsize()



func _on_PopupPanel_popup_hide() -> void :
	_on_Cancle_pressed()
	$PopupPanel / ListMenu.clear()
