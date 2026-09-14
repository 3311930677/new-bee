extends Node
class_name BagInfoManage

const prefix = "BagInfoManage->"

signal _bag_all_data

signal _bag_data_num_change_
signal _bagpackdata_num_change_
signal _bag_data_update_

signal _consolidate_signal

signal _equ_detail_info
signal _repair_equ_signal
signal _punching_equ_signal
signal _counter_equ_signal
signal _bind_equ_signal
signal _inlaid_gem_equ_signal
signal _add_max_potential_equ_signal
signal _op_bag_store_coins_sinal

var ScreenUtils
var StaticGameData
var NetContext


var next_is_load_net_data = true
var bag_fac_load_num = 0
var art_dic_names = {"arts": 5, "equs": 3, "gems": 4}
var art_dic_names_revers = {"5": "arts", "3": "equs", "4": "gems"}


var temp_data
var temp_data_num
var temp_data_type

var map_all_bags = {}
var map_all_store_house = {}

var skip_equ_detail_info = false

var wear_hold_id = - 1
var wear_unload_node = null
var equ_gemstone_type = - 1


var equ_level_percent = [0.08, 0.11, 0.12, 0.13, 0.14, 0.14, 0.14, 0.15, 0.15, 0.15, 0.15, 0.16, 0.16, 0.16, 0.16]


func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	NetContext = Global.get("NetContext")
	
	
	NetContext.set_handler("BackpackRemote", "getAllArticle", self, "_on_all_bag_data_result")
	
	NetContext.set_handler("BackpackRemote", "getAllArticles", self, "_on_all_bag_data_result")
	NetContext.set_handler("BackpackRemote", "getRoleBackPackData", self, "_on_bagpack_data_result")
	
	NetContext.set_handler("StorehouseRemote", "getStoreHouseData", self, "_on_all_store_house_data_result")
	
	NetContext.set_handler("ArticleUseRemote", "useGiftPack", self, "_on_use_gift_pack_result")
	
	NetContext.set_handler("ArticleUseRemote", "useProp", self, "_on_use_prop_result")
	
	NetContext.set_handler("ArticleUseRemote", "useDrug", self, "_on_use_drug_result")
	
	NetContext.set_handler("BackpackRemote", "discard", self, "_on_discard_result")
	
	NetContext.set_handler("StorehouseRemote", "put", self, "_on_store_put_result")
	
	NetContext.set_handler("StorehouseRemote", "take", self, "_on_take_result")
	
	NetContext.set_handler("EquipmentRemote", "wearEquipment", self, "_on_wear_euqipment_result")
	
	NetContext.set_handler("EquipmentRemote", "unloadEquipment", self, "_on_unload_euqipment_result")
	
	NetContext.set_handler("EquipmentRemote", "getEquDetails", self, "_on_euqipment_details_result")
	
	NetContext.set_handler("EquipmentRemote", "consolidateEquipment", self, "_on_consolidate_equipment")
	
	NetContext.set_handler("EquipmentRemote", "repairEqu", self, "_on_repair_equipment")
	
	NetContext.set_handler("EquipmentRemote", "punchingEquipment", self, "_on_punching_equipment")
	
	NetContext.set_handler("EquipmentRemote", "counterEquipment", self, "_on_counter_equipment")
	
	NetContext.set_handler("EquipmentRemote", "bingEquipment", self, "_on_bind_equipment")
	
	NetContext.set_handler("EquipmentRemote", "setPotentialEquId", self, "_on_set_potential_equipment")
	
	NetContext.set_handler("EquipmentRemote", "addMaxPotential", self, "_on_add_max_potential_equipment")
	
	NetContext.set_handler("EquipmentRemote", "inlaidGem", self, "_on_inlaid_gem_equipment")
	
	
	
	NetContext.set_handler("StorehouseRemote", "putGoldCoin", self, "_on_put_gold_coin_result")
	
	NetContext.set_handler("StorehouseRemote", "takeGoldCoin", self, "_on_take_gold_coin_result")
	




func _on_all_bag_data_result(data):
	bag_fac_load_num += 1
	data = data["data"]
	Global.log_info(str(prefix, "背包所有数据", data))
	map_all_bags = data
	emit_signal("_bag_all_data", data)
	if bag_fac_load_num >= 2:
		next_is_load_net_data = false
		emit_signal("_bag_data_update_")

func _on_bagpack_data_result(data):
	data = data["data"]
	map_all_bags["roleBackpackData"] = data
	emit_signal("_bagpackdata_num_change_")


func _on_all_store_house_data_result(data):
	bag_fac_load_num += 1
	data = data["data"]
	Global.log_info(str(prefix, "仓库所有数据", data))
	map_all_store_house = data
	if bag_fac_load_num >= 2:
		next_is_load_net_data = false
		emit_signal("_bag_data_update_")

func _on_put_gold_coin_result(data):
	emit_signal("_op_bag_store_coins_sinal", 1)
	pass

func _on_take_gold_coin_result(data):
	emit_signal("_op_bag_store_coins_sinal", 2)
	pass


func _on_wear_euqipment_result(data):
	

	
	data = data["data"]
	Global.log_info(str(prefix, "穿戴装备返回的数据", data))

	if wear_hold_id <= 0: return
	
	var wear_stattic_data = - 1
	var wear_hold_data = null
	
	for item in map_all_bags["equs"]:
		
		if item.id == wear_hold_id:
			wear_hold_data = item
			break
	
	if wear_hold_data != null:
		
		var wear_index = StaticGameData.get_equi_data(wear_hold_data["equi_data_id"])["wear_index"]
		
		for item in map_all_bags["equs"]:
			var temp_wear_index = StaticGameData.get_equi_data(item["equi_data_id"])["wear_index"]
			if temp_wear_index == wear_index and item.is_wear == 1:
				item.is_wear = 0
			
		wear_hold_data.is_wear = 1
	
	Global.get("RoleInfoManage").common_wear_equipment(data)
	
	
	wear_hold_id = - 1

	emit_signal("_bag_data_update_")
	pass

func _on_unload_euqipment_result(data):
	
	
	for item in map_all_bags["equs"]:
		if item.id == wear_unload_node.equi_data.id:
			item.is_wear = 0
			Global.get("RoleInfoManage").common_unwear_equipment(item)
		
	if wear_unload_node != null:
		wear_unload_node.none()
		wear_unload_node = null

	Global.get("RoleInfoManage").reload_ui()
	Global.get("RoleInfoManage").update_role_info()
	Global.log_info(str(prefix, "卸下装备返回的数据", data))
	ScreenUtils.show_message("装备卸下成功")
	
	
	
	wear_hold_id = - 1
	emit_signal("_bag_data_update_")
	pass

func _on_euqipment_details_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "装备详细数据", data))
	if skip_equ_detail_info:
		emit_signal("_equ_detail_info", data)
	else: private_show_equi_details(data)


func _on_consolidate_equipment(data):
	data = data["data"]
	private_equipment_data_update(data)
	
	









	
	
	emit_signal("_consolidate_signal", data)
	pass

func _on_repair_equipment(data):
	data = data["data"]
	private_equipment_data_update(data)
	
	emit_signal("_repair_equ_signal", data)
	pass


func _on_punching_equipment(data):
	data = data["data"]
	private_equipment_data_update(data)
	emit_signal("_punching_equ_signal", data)
	pass

func _on_counter_equipment(data):
	data = data["data"]
	private_equipment_data_update(data)
	emit_signal("_counter_equ_signal", data)
	pass

func _on_bind_equipment(data):
	data = data["data"]
	private_equipment_data_update(data)
	emit_signal("_bind_equ_signal", data)
	pass

func _on_set_potential_equipment(data):
	ScreenUtils.show_message("练潜装备设置成功!!")
	pass


func _on_add_max_potential_equipment(data):
	data = data["data"]
	private_equipment_data_update(data)
	emit_signal("_add_max_potential_equ_signal", data)
	pass

func _on_inlaid_gem_equipment(data):
	data = data["data"]
	private_equipment_data_update(data)
	emit_signal("_inlaid_gem_equ_signal", data)

func _on_use_prop_result(data):
	data = data["data"]
	
	temp_data["count"] = temp_data.get("count", 1) - temp_data_num
	ScreenUtils.show_message("道具使用成功")
	clear_zero_art()
	
	map_all_bags["roleBackpackData"]["gold_coin"] = data["gold_coin"]
	map_all_bags["roleBackpackData"]["silver_coin"] = data["silver_coin"]
	map_all_bags["roleBackpackData"]["coupons"] = data["coupons"]
	map_all_bags["roleBackpackData"]["cur_capacity"] = data["cur_capacity"]
	map_all_bags["roleBackpackData"]["storehouse_capacity"] = data["storehouse_capacity"]
	emit_signal("_bag_data_update_")
	pass

func _on_use_gift_pack_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "使用礼包返回的数据", data))
	
	temp_data["count"] = temp_data.get("count", 1) - temp_data_num
	
	

	
	
	add_articles(data["arts"])
	add_gems(data["gems"])
	add_equis(data["equs"])
	
	clear_zero_art()
	emit_signal("_bag_data_update_")
	


func _on_use_drug_result(data):
	data = data["data"]
	ScreenUtils.show_message("道具使用成功")
	Global.log_info(str(prefix, "使用回血蓝的道具返回的数据", data))
	
	temp_data["count"] = temp_data.get("count", 1) - temp_data_num
	clear_zero_art()
	emit_signal("_bag_data_num_change_")


func _on_discard_result(data):
	data = data["data"]
	map_all_bags["roleBackpackData"] = data
	ScreenUtils.show_message("丢弃成功")
	Global.log_info(str(prefix, "丢弃道具返回的数据", data))
	temp_data["count"] = temp_data.get("count", 1) - int(temp_data_num)
	clear_zero_art()
	emit_signal("_bag_data_num_change_")

func _on_store_put_result(data):
	data = data["data"]
	ScreenUtils.show_message("道具存放成功")
	
	temp_data["count"] = temp_data.get("count", 1) - temp_data_num
	
	if temp_data["count"] <= 0:
		map_all_bags["roleBackpackData"]["cur_capacity"] = map_all_bags["roleBackpackData"]["cur_capacity"] - 1
	
	var temp = null
	if data.has("type"):
		temp = private_find_data_in_store(data.get("data", null), art_dic_names_revers[str(data["type"])])
	else:
		temp = null
	
	if temp != null:
		
		temp["count"] = data["data"]["count"]
		clear_zero_art()
		emit_signal("_bag_data_num_change_")
	else:
		
		var dic_temp_data = temp_data.duplicate(true)
		dic_temp_data["count"] = temp_data_num
		if data.has("data"): dic_temp_data["id"] = data["data"]["id"]
		else: dic_temp_data["id"] = data["id"]
		
		map_all_store_house[str(art_dic_names_revers[str(data.get("type", "5"))])].append(dic_temp_data)
		clear_zero_art()
		emit_signal("_bag_data_update_")
		pass
	
	Global.log_info(str(prefix, "道具存放在仓库响应这里", data))
	


func _on_take_result(data):
	data = data["data"]
	ScreenUtils.show_message("道具取出成功")
	
	temp_data["count"] = temp_data.get("count", 1) - temp_data_num
	
	clear_zero_art()
	var temp = private_find_data_in_bag(data["data"], art_dic_names_revers[str(data["type"])])
	if temp != null:
		
		temp["count"] = data["data"]["count"]
		clear_zero_art()
		emit_signal("_bag_data_num_change_")
	else:
		
		var dic_temp_data = temp_data.duplicate(true)
		dic_temp_data["count"] = temp_data_num
		dic_temp_data["id"] = data["data"]["id"]
		map_all_bags[str(art_dic_names_revers[str(data["type"])])].append(dic_temp_data)
		
		map_all_bags["roleBackpackData"]["cur_capacity"] = map_all_bags["roleBackpackData"]["cur_capacity"] + 1
		clear_zero_art()
		emit_signal("_bag_data_update_")
	Global.log_info(str(prefix, "仓库道具取出到背包的操作", data))


func private_find_data_in_bag(data, item_type):
	if data == null: return null
	var arr_arts = map_all_bags[item_type]
	for art in arr_arts:
		if int(data["id"]) == int(art["id"]):
			if data.has("count"):
				if data["count"] <= 0: return null
			return art
	return null

func private_find_data_in_store(data, item_type):
	if data == null: return null
	var arr_arts = map_all_store_house[item_type]
	for art in arr_arts:
		if int(data["id"]) == int(art["id"]):
			if data["count"] <= 0: return null
			return art
	return null


func private_show_data(data):
	
	var bbcode = "恭喜你获得以下物品:\n"
	for artic in data["arts"]:
		var num = artic.get("change_count", - 1)
		if num == - 1: num = artic.get("count", 1)
		var bind = StaticGameData.get_bind_text_format(artic.get("bind", 0))
		bbcode = str(bbcode, bind, StaticGameData.get_article_data_txt_bbcode(artic["articles_data_id"]), "x", num, "\n")
		pass
	for gem in data["gems"]:
		var num = gem.get("change_count", - 1)
		if num == - 1: num = gem.get("count", 1)
		var bind = StaticGameData.get_bind_text_format(gem.get("bind", 0))
		bbcode = str(bbcode, bind, StaticGameData.get_gem_data_txt_bbcode(gem["gemstone_id"]), "x", num, "\n")
		pass
	for equ in data["equs"]:
		var num = equ.get("change_count", - 1)
		if num == - 1: num = equ.get("count", 1)
		var bind = StaticGameData.get_bind_text_format(equ.get("bind", 0))
		bbcode = str(bbcode, bind, StaticGameData.get_equi_data_txt_bbcode(equ["equi_data_id"]), "x", num, "\n")
		pass
	for pet in data["pets"]:
		bbcode = str(bbcode, pet["name"], "x1", "\n")
		
		
		
		
		
		
		
	ScreenUtils.show_message_plus(bbcode)


func private_equipment_data_update(data):
	
	var remove_index = 0
	for item in map_all_bags["equs"]:
		if item.id == data.id:
			break
		remove_index += 1
	map_all_bags["equs"].remove(remove_index)
	map_all_bags["equs"].append(data)
	pass

func request_all_data(wait = true):
	NetContext.request_service("BackpackRemote", "getAllArticles", {}, wait)
	pass

func request_bag_data(is_show_wait = true):
	NetContext.request_service("BackpackRemote", "getAllArticle", {}, is_show_wait)
	pass

func request_data():
	next_is_load_net_data = true
	if not next_is_load_net_data:
		emit_signal("_bag_data_update_")
	else:
		NetContext.request_service("StorehouseRemote", "getStoreHouseData", {}, true)
		NetContext.request_service("BackpackRemote", "getAllArticle", {}, true)
func request(wait = false):
	NetContext.request_service("BackpackRemote", "getAllArticle", {}, wait)
	pass

func get_equipment_details(hold_id, skip_tips: bool = false):
	skip_equ_detail_info = skip_tips
	NetContext.request_service("EquipmentRemote", "getEquDetails", {
		"hold_id": hold_id
	}, true)
	pass

func wear_equipment(hold_id):
	wear_hold_id = hold_id
	NetContext.request_service("EquipmentRemote", "wearEquipment", {
		"equ_id": hold_id
	}, true)
	pass

func unload_equipment(hold_id, node_):
	wear_unload_node = node_
	wear_hold_id = hold_id
	NetContext.request_service("EquipmentRemote", "unloadEquipment", {
		"wear_index": hold_id
	}, true)
	pass

func consolidate_equ(hold_id, gemstone_type):
	equ_gemstone_type = gemstone_type
	NetContext.request_service("EquipmentRemote", "consolidateEquipment", {
		"equ_hold_id": hold_id, 
		"gemstone_type": gemstone_type, 
	}, true)


func repair_equ(hold_id):
	NetContext.request_service("EquipmentRemote", "repairEqu", {
		"equ_hold_id": hold_id, 
	}, true)
	pass


func punching_equipment(hold_id):
	NetContext.request_service("EquipmentRemote", "punchingEquipment", {
		"equ_hold_id": hold_id, 
	}, true)

func counter_equipment(hold_id):
	NetContext.request_service("EquipmentRemote", "counterEquipment", {
		"equ_hold_id": hold_id, 
	}, true)
	pass

func bind_equipment(hold_id):
	NetContext.request_service("EquipmentRemote", "bingEquipment", {
		"equ_hold_id": hold_id, 
	}, true)
	pass


func set_poemtial_equipment(hold_id):
	NetContext.request_service("EquipmentRemote", "setPotentialEquId", {
		"equ_hold_id": hold_id, 
	}, true)
	pass

func add_potential_equipment(hold_id):
	NetContext.request_service("EquipmentRemote", "addMaxPotential", {
		"equ_hold_id": hold_id, 
	}, true)
	pass

func inlaid_gem_equipment(hold_id, index, gem_id):
	NetContext.request_service("EquipmentRemote", "inlaidGem", {
		"equ_hold_id": hold_id, 
		"index": index, 
		"gem_hold_id": gem_id, 
	}, true)
	pass

func use_prop(data, number):
	if int(number) <= 0:
		ScreenUtils.showMessage("使用数量非法")
		return
	temp_data = data
	temp_data_num = number
	var dic = {
		"use_num": number, 
		"art_hold_id": data["id"]
	}
	NetContext.request_service("ArticleUseRemote", "useProp", dic, true)
	pass
func use_gifpack(data, number):
	if int(number) <= 0:
		ScreenUtils.showMessage("使用数量非法")
		return
	
	temp_data = data
	temp_data_num = number
	var dic = {
		"use_num": number, 
		"art_hold_id": data["id"]
	}
	NetContext.request_service("ArticleUseRemote", "useGiftPack", dic, true)
	pass


func use_drug_art(data, number, user_drug_type):
	temp_data = data
	temp_data_num = number
	temp_data_type = user_drug_type
	var dic = {
		"use_num": number, 
		"type": user_drug_type, 
		"art_hold_id": data["id"], 
	}
	NetContext.request_service("ArticleUseRemote", "useDrug", dic, true)
	pass


func move_bag_to_store_house(data, number, isCommand = false):
	if int(number) <= 0:
		ScreenUtils.showMessage("存入数量不合法")
		return
	temp_data = data
	temp_data_num = number
	var dic = {
		"hold_id": data["id"], 
		"num": number, 
		"type": data["item_type"], 
		"isCommand": isCommand
	}
	NetContext.request_service("StorehouseRemote", "put", dic, true)
	pass

func move_store_house_to_bag(data, number, isCommand = false):
	if int(number) <= 0:
		ScreenUtils.showMessage("取出数量不合法")
		return
	temp_data = data
	temp_data_num = number
	var dic = {
		"hold_id": data["id"], 
		"num": number, 
		"type": data["item_type"], 
		"isCommand": isCommand
	}
	NetContext.request_service("StorehouseRemote", "take", dic, true)
	pass


func discard_bag_art(data, number):
	if not data.has("count"):
		data["count"] = 1
	if int(number) > int(data["count"]):
		ScreenUtils.showMessage("物品丢弃数量超过持有数量")
		return
	var dic = {
		"hold_id": data["id"], 
		"num": int(number), 
		"type": data.item_type
	}
	temp_data_num = int(number)
	temp_data = data
	NetContext.request_service("BackpackRemote", "discard", dic, true)
	pass

func flush_backpack():
	NetContext.request_service("BackpackRemote", "getRoleBackPackData", {}, true)
	pass


func put_store_coin(num):
	NetContext.request_service("StorehouseRemote", "putGoldCoin", {
		"num": num, 
		"op_type": 1
	}, true)
	pass


func take_store_coin(num):
	NetContext.request_service("StorehouseRemote", "takeGoldCoin", {
		"num": num, 
		"op_type": 1
	}, true)
	pass










func get_all_bag_datas():
	var temp = []
	temp.append_array(get_arts())
	temp.append_array(get_equs())
	temp.append_array(get_gems())
	return temp
func get_all_store_datas():
	var temp = []
	temp.append_array(map_all_store_house["arts"])
	temp.append_array(map_all_store_house["equs"])
	temp.append_array(map_all_store_house["gems"])
	return temp

func get_arts():
	var temp_arr = []
	temp_arr.append_array(map_all_bags.get("arts", []))
	return temp_arr

func get_equs():
	var temp_arr = []
	
	for item in map_all_bags.get("equs", []):
		if item.get("is_wear", 0): continue
		temp_arr.append(item)
	return temp_arr

func get_all_equs():
	return map_all_bags.get("equs", [])

func get_gems():
	return map_all_bags.get("gems", [])

func get_tasks():
	var tasks = []
	for i in get_arts():
		var s_d = StaticGameData.get_article_data(i["articles_data_id"])
		if s_d["type"] == 4:
			tasks.append(i)
	return tasks

func get_pets():
	var pet_datas = []
	return pet_datas

func get_all_pets():
	var pets = []
	for i in map_all_bags.get("petHolds", []):
		if int(i["id"]) != Global.get("PetInfoManage").get_fight_pet_id():
			pets.append(i)
	return pets
func set_gold_coins(num):
	map_all_bags["roleBackpackData"]["gold_coin"] = get_coins() - int(num)
func set_silver_coins(num):
	map_all_bags["roleBackpackData"]["silver_coin"] = get_silver_coins() - int(num)
func set_coupons(num):
	map_all_bags["roleBackpackData"]["coupons"] = get_coupons() - int(num)
func set_store_gold_coins(num):
	map_all_bags["roleBackpackData"]["storehouse_gold_coin"] = get_store_coins() - int(num)
	pass
func set_bag_amount(reduce_num):
	map_all_bags["roleBackpackData"]["cur_capacity"] = map_all_bags["roleBackpackData"]["cur_capacity"] - reduce_num
func set_trade_amount(reduce_num):
	map_all_bags["roleBackpackData"]["trade_capacity"] = map_all_bags["roleBackpackData"]["trade_capacity"] - reduce_num

func get_coins():
	return int(map_all_bags["roleBackpackData"]["gold_coin"])

func get_silver_coins():
	return int(map_all_bags["roleBackpackData"]["silver_coin"])

func get_coupons():
	return int(map_all_bags["roleBackpackData"]["coupons"])
func get_meritorious():
	return int(map_all_bags["roleBackpackData"]["meritorious_service"])
func get_store_coins():
	return int(map_all_bags["roleBackpackData"].get("storehouse_gold_coin", 0))

func get_bag_amount():
	return int(map_all_bags["roleBackpackData"]["cur_capacity"])
func get_bag_max_amount():
	return int(map_all_bags["roleBackpackData"].get("max_capacity", 50))

func get_bag_amount_local():
	return get_bag_amount()


func get_store_amount():
	return int(map_all_bags["roleBackpackData"]["storehouse_capacity"])
func get_store_max_amount():

	return int(map_all_bags["roleBackpackData"].get("storehouse_max_capacity", 120))

func get_store_amount_local():
	return int(map_all_store_house["equs"].size() + map_all_store_house["gems"].size() + map_all_store_house["arts"].size())


func get_trade_capacity():
	return int(map_all_bags["roleBackpackData"].get("trade_capacity", 0))
	pass

func get_trade_max_capacity():
	return int(map_all_bags["roleBackpackData"].get("trade_max_capacity", 5))
	pass

func set_next_reload():
	next_is_load_net_data = true

func get_item_type_name(item_type):
	for n in art_dic_names.keys():
		if int(item_type) == int(art_dic_names[n]):
			return n
	return null


func add_articles(arr_articles_hold) -> bool:
	for item in arr_articles_hold:
		var temp = private_find_data_in_bag(item, "arts")
		if temp == null:
			
			map_all_bags["arts"].append(item)
			pass
		else:
			temp["change_count"] = temp["count"] - item.get("count", 1)
			temp["count"] = item.get("count", 1)
		pass
	return true


func add_gems(arr_gems_data) -> bool:
	for item in arr_gems_data:
		var temp = private_find_data_in_bag(item, "gems")
		if temp == null:
			
			map_all_bags["gems"].append(item)
			pass
		else:
			temp["change_count"] = temp["count"] - item.get("count", 1)
			
			temp["count"] = item.get("count", 1)
		pass
	return true


func add_equis(arr_equis) -> bool:
	for item in arr_equis:
		var temp = private_find_data_in_bag(item, "equs")
		if temp == null:
			
			map_all_bags["equs"].append(item)
			pass
		else:
			temp["change_count"] = temp["count"] - item.get("count", 1)
			
			temp["count"] = item.get("count", 1)
		pass
	return true

func sub_data(data_info, num):
	match data_info["item_type"]:
		1:
			pass
		2:
			pass
		3:
			var data = private_find_data_in_bag(data_info, "equs")
			data["count"] = data.get("count", 1) - num
			pass
		4:
			var data = private_find_data_in_bag(data_info, "gems")
			data["count"] = data.get("count", 1) - num
			pass
		5:
			var data = private_find_data_in_bag(data_info, "arts")
			data["count"] = data.get("count", 1) - num
			pass
	
	clear_zero_art()
	emit_signal("_bag_data_num_change_")


func clear_zero_art():
	var keys = art_dic_names.keys()
	for i in keys:
		var index = 0
		for item in map_all_bags.get(str(i), []):
			if item.get("count", 1) == 0:
				map_all_bags[str(i)].remove(index)
			else:
				index = index + 1
	
	for i in keys:
		var index = 0
		for item in map_all_store_house.get(str(i), []):
			if item.get("count", 1) == 0:
				map_all_store_house[str(i)].remove(index)
			else:
				index = index + 1
		pass
	pass


func private_show_equi_details(data):
	
	var attr = Global.get("CalculationManage").calculation_euqipment(data)
	
	var static_data = Global.get("StaticGameData").get_equi_data(data["equi_data_id"])
	var hex_color = static_data["display_color"]
	if hex_color == "000000": hex_color = "ffffff"
	
	
	var bind_txt = ""
	if data["countermark"] == 1:
		bind_txt = Global.get("StaticGameData").get_countermark_text_format(data["countermark"])
	else:
		bind_txt = Global.get("StaticGameData").get_bind_text_format(data["bind"])
	var bbcode = ""
	
	var division_txt = Global.get("StaticGameData").get_euqi_job_text_format(data["equi_data_id"])
	
	var equi_name = Global.get("StaticGameData").get_equi_data_txt(data["equi_data_id"])
	
	var qianghua_ = ""
	if data["consolidate_level"] > 0:
		qianghua_ = str("+", data["consolidate_level"])
	var kong_num = ""
	if data["punch"] > 0:
		kong_num = str("(", data["punch"], ")")
	
	
	bbcode = str("[color=#", hex_color, "]", bind_txt, division_txt, equi_name, qianghua_, kong_num, "[/color]\n")
	
	bbcode = str(bbcode, "[color=white]装备等级:", static_data["level"], "\n")
	bbcode = str(bbcode, "职业:", Global.get("StaticGameData").get_equi_job_all_txt(data["equi_data_id"]), "\n")
	bbcode = str(bbcode, "部位:", Global.get("StaticGameData").get_euqi_location(data["equi_data_id"]), "\n")
	
	for key in Global.get("StaticGameData").attr_name_data.keys():
		if static_data.has(key) and static_data[key] > 0:
			var attr_name = Global.get("StaticGameData").attr_name_data[key]
			
			
			var add_value = calculate_percent(data["consolidate_level"])
			var add_values = 0
			if data["countermark"] > 0:
				add_values = int(floor(static_data[key] * 1.3 * add_value))
			else:
				add_values = int(floor(static_data[key] * add_value))
			
			if add_values <= 0: add_values = "";
			else: add_values = str("[color=green](+", add_values, ")[/color]")
			bbcode = str(bbcode, attr_name, "+", static_data[key], add_values, "\n")
		pass
	
	var is_mar = "否"
	if data.get("is_mar", 0) == 1: is_mar = "是"
	bbcode = str(bbcode, "装备是否损坏:", is_mar, "\n")
	
	var punch = data["punch"]
	var use_punch = data["use_inlay"]
	if punch > 0:
		bbcode = str(bbcode, "宝石镶嵌:", use_punch, "/", punch, "\n")
		
		for gem_item_info in data.get("equGemAttrs", []):
			var gem_p_n = Global.get("StaticGameData").attr_name_data[gem_item_info.attr_name]
			var gemm_n = str(gem_p_n, ":", "%d/%d" % [gem_item_info["cur_val"], gem_item_info["max_val"]])
			bbcode = str(bbcode, "[color=blue]%s[/color]\n" % gemm_n)
			pass
	
	bbcode = str(bbcode, "装备潜力:已用%d,总共%d" % [data["usr_potential"], data["max_potential"]], "\n")
	
	bbcode = str(bbcode, "[color=#%s]品质附加属性:\n" % hex_color)
	for i in 6:
		if i == 0: continue
		var at_name = str(data["additional_attr_%d" % i])
		if at_name == null or at_name.length() < 2: continue
		var at_txt_name = Global.get("StaticGameData").attr_name_data[at_name]
		var at_txt_num = data["attr_value_%d" % i]
		bbcode = str(bbcode, at_txt_name, "+", at_txt_num, "\n")
	bbcode = str(bbcode, "[color=white]出售价格:%d 银票\n" % static_data.get("sell_price", 100))
	bbcode = str(bbcode, "描述：", static_data["desc"], "\n")
	
	Global.get("ScreenUtils").show_message_plus(bbcode)

func private_show_equ_attr_change(data):
	var bbcode = ""
	bbcode = "[center]属性变化[/center]\n"
	for key in data.keys():
		if typeof(data[key]) != TYPE_ARRAY and int(data[key]) != 0:
			var n_m = StaticGameData.attr_name_data[key]
			var colors = "00ff00"
			if int(data[key]) < 0:
				colors = "ff0000"
			bbcode = str(bbcode, "%s:[color=#%s]%d[/color]\n" % [n_m, colors, int(round(data[key]))])
			pass
	Global.get("ScreenUtils").show_message_plus(bbcode)


func calculate_percent(level):
	var per = 0.0
	for i in level:
		per += equ_level_percent[i]
	return per
