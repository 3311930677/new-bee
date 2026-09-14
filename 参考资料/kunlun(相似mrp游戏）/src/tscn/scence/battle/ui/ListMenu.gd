extends Control


signal item_click_

onready var menu = $PopupPanel / ListMenu
onready var popup = $PopupPanel

var TBBattleManage
var StaticGameData
var ScreenUtils


var skill_cd_map = {
	
}

func _ready() -> void :
	TBBattleManage = Global.get("TBBattleManage")
	StaticGameData = Global.get("StaticGameData")
	ScreenUtils = Global.get("ScreenUtils")
	
	menu.connect("double_click", self, "_item_click")
	pass

func _item_click():
	
	var data = menu.get_select()
	
	emit_signal("item_click_", data)
	popup.hide()
	pass


func release_skill(skill_id):
	skill_cd_map[str(skill_id)] = TBBattleManage.get_battle_round()
	pass


func show_skill(op_type):
	menu.clear()
	var skil_ids = []
	var current_mp = 0
	if op_type == 0:
		skil_ids = TBBattleManage.get_role_entity_data()["otherData"]["skill"]
		current_mp = TBBattleManage.get_role_entity_data()["otherData"]["mp"]
	else:
		skil_ids = TBBattleManage.get_pet_entity_data()["otherData"]["skill"]
		current_mp = TBBattleManage.get_pet_entity_data()["otherData"]["mp"]
	
	
	
	var arr_map_sk_id = []
	
	
	for sid in skil_ids:
		if sid <= 0: continue
		var sk_st_data = StaticGameData.get_skill_data_temp(sid)
		if sk_st_data == null or sk_st_data.empty(): continue
		
		if sk_st_data["type"] == 0: continue
		if int(sk_st_data["id"]) == 100000: continue
		
		var sk_mp = {"name": sk_st_data["name"], "data": sk_st_data, "cd": false, "id": int(sk_st_data["id"])}
		arr_map_sk_id.append(sk_mp)
		
		
		if skill_cd_map.has(str(sid)):
			
			
			var end_round = skill_cd_map[str(sid)] + sk_st_data["cd"]
			if end_round >= TBBattleManage.get_battle_round():
				sk_mp["cd"] = true
		
		if current_mp < sk_st_data["mp_consume"]:
			sk_mp["cd"] = true
	
	var catch_skill = {
		"name": "捕捉", 
		"data": {"id": 99999999}, 
		"cd": false, 
		"id": 99999999
	}
	
	if op_type == 0: arr_map_sk_id.append(catch_skill)
	if arr_map_sk_id.size() <= 0:
		ScreenUtils.show_message("当前没有可用技能")
		return
	
	arr_map_sk_id.sort_custom(MyCustomSorter, "sort_ascending")
	
	menu.add_items(arr_map_sk_id)
	popup.rect_size.y = 0
	menu.rect_size.y = 0
	popup.popup_centered(Vector2.ZERO)


class MyCustomSorter:
	static func sort_ascending(a, b):
		if a["id"] < b["id"]:
			return true
		return false
