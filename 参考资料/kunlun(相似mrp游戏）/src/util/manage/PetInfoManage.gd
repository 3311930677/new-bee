extends Node
class_name PetInfoManage

const prefix = "PetInfoManage->"

signal loaded_all_list_pets
signal reset_pet
signal fight_pet
signal pet_info
signal main_head_no_pet
signal pet_point_add_success
signal pet_change_name_success

signal pet_reload_show

signal pet_trader_reset_success
signal pet_trader_wash_point_success
signal pet_trader_release_success
signal pet_trader_refining_success

var ScreenUtils
var NetContext
var StaticGameData

var all_info
var list_all_pets = []
var fight_pet_id = 0 setget set_fight_id, get_fight_id

var fight_pet_details = {}

var temp_fight_id = - 1


var request_data_is_load_detail = true

func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	StaticGameData = Global.get("StaticGameData")
	NetContext.set_handler("upgrade", "pet", self, "_on_pet_upgrade_handle")
	
	NetContext.set_handler("PetRemote", "getPets", self, "_on_pet_data_result")
	
	NetContext.set_handler("PetRemote", "playPet", self, "_on_pet_fight_result")
	
	NetContext.set_handler("PetRemote", "rest", self, "_on_pet_reset_result")
	
	NetContext.set_handler("PetRemote", "addPoints", self, "_on_pet_add_points_result")
	
	NetContext.set_handler("PetRemote", "changeName", self, "_on_change_name_result")
	
	NetContext.set_handler("DataRemote", "getPetInfo", self, "_on_pet_details_result")
	
	NetContext.set_handler("PetTraderRemote", "resetPet", self, "_on_pet_trader_reset_result")
	
	NetContext.set_handler("PetTraderRemote", "washPoint", self, "_on_pet_trader_wash_point_result")
	
	NetContext.set_handler("PetTraderRemote", "releasePet", self, "_on_pet_trader_release_result")
	
	NetContext.set_handler("PetTraderRemote", "refiningPet", self, "_on_pet_trader_refining_result")
	


func request_data(wait = true, is_load_detail = true):
	request_data_is_load_detail = is_load_detail
	NetContext.request_service("PetRemote", "getPets", {}, wait)
	pass
	

var temp_pet_id_details
func request_pet_details(pet_hold_id, wait = true):
	if pet_hold_id == - 1:
		Global.log_info(str(prefix, "查看自己的出战宠物详细数据"))
		pet_hold_id = Global.get("RoleInfoManage").get_pet_fight_id()
		if pet_hold_id == 0:
			Global.log_info(str(prefix, "当前自身没有出战宠物"))
			return
		
		fight_pet_id = pet_hold_id
	temp_pet_id_details = pet_hold_id
	NetContext.request_service("DataRemote", "getPetInfo", {
		"hold_id": pet_hold_id
	}, wait)


func change_pet_name(hold_id, new_name):
	NetContext.request_service("PetRemote", "changeName", {
		"hold_id": hold_id, 
		"new_name": new_name
	}, true)
	pass


func set_fight_pet(pet_id):
	temp_fight_id = pet_id
	NetContext.request_service("PetRemote", "playPet", {
		"pet_id": pet_id
	}, true)

func reset_fight():
	NetContext.request_service("PetRemote", "rest", {}, true)

func discard_pet(hold_id):
	var dis_data = {
		"id": hold_id, 
		"item_type": 2, 
		"count": 1
	}
	var ind = 0
	for item in list_all_pets:
		if item["id"] == hold_id:
			list_all_pets.remove(ind)
			break
		ind += 1
	
	Global.get("BagInfoManage").discard_bag_art(dis_data, 1)

func add_pet_point(pet_id, data):
	data["hold_id"] = pet_id
	NetContext.request_service("PetRemote", "addPoints", data, true)
	pass

func get_fight_pet_id():
	return fight_pet_id

func get_fight_pet_info():
	for info in list_all_pets:
		if info["id"] == get_fight_pet_id():
			return info


func trader_pet_reset(hold_id):
	NetContext.request_service("PetTraderRemote", "resetPet", {
		"pet_hold_id": hold_id
	}, true)
	pass
	

func trader_pet_wash_point(hold_id):
	NetContext.request_service("PetTraderRemote", "washPoint", {
		"pet_hold_id": hold_id
	}, true)
	pass
	

func trader_pet_release(hold_id):
	NetContext.request_service("PetTraderRemote", "releasePet", {
		"pet_hold_id": hold_id
	}, true)
	pass

func trade_pet_refining(hold_id):
	NetContext.request_service("PetTraderRemote", "refiningPet", {
		"pet_hold_id": hold_id
	}, true)
	pass


func _on_pet_data_result(data):
	all_info = data["data"]
	list_all_pets = data["data"]
	fight_pet_id = Global.get("RoleInfoManage").get_pet_fight_id()
	Global.log_info(str(prefix, "宠物列表数据", data))
	emit_signal("loaded_all_list_pets")
	if fight_pet_id > 0 and request_data_is_load_detail:
		pass

	else:
		emit_signal("main_head_no_pet")
	


func _on_pet_fight_result(data):
	data = data["data"]
	Global.get("RoleInfoManage").hot_role_op["pet_atk"] = - 1
	Global.log_info(str(prefix, "宠物出战成功", data))
	ScreenUtils.show_message("宠物出战成功")
	
	fight_pet_id = temp_fight_id
	fight_pet_details = data
	Global.get("RoleInfoManage").set_pet_fight_id(fight_pet_id)
	
	request_pet_details(fight_pet_id, true)


func _on_pet_reset_result(data):
	Global.log_info(str(prefix, "宠物休息成功", data))
	ScreenUtils.show_message("宠物休息成功")
	temp_fight_id = - 1
	fight_pet_id = 0
	fight_pet_details = null
	Global.get("RoleInfoManage").set_pet_fight_id(fight_pet_id)
	emit_signal("reset_pet")
	emit_signal("main_head_no_pet")


func _on_pet_add_points_result(data):
	Global.log_info(str(prefix, "宠物加点成功", data))
	data = data["data"]
	fight_pet_details["petAddPoint"] = data
	emit_signal("pet_point_add_success")
	emit_signal("pet_info", temp_pet_id_details, fight_pet_details)


func _on_pet_details_result(data):
	Global.log_info(str(prefix, "宠物详细数据", data))

	
	if temp_pet_id_details == get_fight_pet_id():
		fight_pet_details = data["data"]
		emit_signal("pet_reload_show")
		emit_signal("fight_pet")
	
	emit_signal("pet_info", temp_pet_id_details, data["data"])


func _on_pet_upgrade_handle(data):
	data = parse_json(data["data"])














	

	pass


func _on_change_name_result(data):
	data = data["data"]
	for item in list_all_pets:
		if item.id == data.id:
			item.name = data.name
			break
	if data.id == fight_pet_details["petHold"].id:
		fight_pet_details["petHold"] = data
	ScreenUtils.show_message(str("宠物成功改名为：", data.name))
	emit_signal("pet_change_name_success", data)
	emit_signal("pet_info", temp_pet_id_details, fight_pet_details)



func _on_pet_trader_reset_result(data):
	Global.get("ScreenUtils").show_message("宠物重置成功")
	emit_signal("pet_trader_reset_success")
	pass

func _on_pet_trader_wash_point_result(data):
	Global.get("ScreenUtils").show_message("宠物洗点成功")
	emit_signal("pet_trader_wash_point_success")
	pass

func _on_pet_trader_release_result(data):
	Global.get("ScreenUtils").show_message("宠物已放生")
	emit_signal("pet_trader_release_success")
	pass

func _on_pet_trader_refining_result(data):
	Global.get("ScreenUtils").show_message("宠物成功被炼化")
	emit_signal("pet_trader_refining_success")
	pass


func flush_pet_bvo_info(basic_vo_info):
	fight_pet_id = basic_vo_info["id"]
	fight_pet_details["petHold"] = fight_pet_details.get("petHold", {})
	fight_pet_details["petHold"]["level"] = basic_vo_info["level"]
	fight_pet_details["petHold"]["pet_race_id"] = basic_vo_info["pet_race"]
	fight_pet_details["petHold"]["hp"] = basic_vo_info["hp"]
	fight_pet_details["petHold"]["mp"] = basic_vo_info["mp"]
	fight_pet_details["petHold"]["exp"] = basic_vo_info["exp"]
	
	pass


func get_fight_pet_name():
	return fight_pet_details.get("petHold", {"name": "宠物名称"}).get("name")

func get_fight_pet_details():
	return fight_pet_details


func set_pet_attr(args):
	if fight_pet_details == null or fight_pet_details.empty():
		Global.log_info(str(prefix, "有异常，前端没有详细数据，后端发来了变化的数据"))
		return
	if args.has("exp"):
		fight_pet_details["petHold"]["exp"] = args.get("exp", 0)
	if args.has("hp"):
		fight_pet_details["petHold"]["hp"] = args.get("hp", 0)
	if args.has("mp"):
		fight_pet_details["petHold"]["mp"] = args.get("mp", 0)
	if args.has("level"):
		fight_pet_details["petHold"]["level"] = args.get("level", 1)
	
	if args.has("cur_loyalty"):
		fight_pet_details["petHold"]["cur_loyalty"] = args.get("cur_loyalty", 0)
		pass
	
	if args.get("level_add", 0) > 0:
		fight_pet_details["petAddPoint"]["point"] += args.get("level_add") * 5
		if not fight_pet_details.has("skills"):
			fight_pet_details["skills"] = []
		var skills = args.get("skills", [])
		fight_pet_details["skills"].append_array(skills)
		
		var CalculationManage = Global.get("CalculationManage")
		var temp_hold = {
			"level": args.get("level_add", 0), 
			"growing_up": fight_pet_details["petHold"]["growing_up"]
		}
		var data = CalculationManage.get_pet_attribute(fight_pet_details["qual"], temp_hold, {})
		
		var bbcode_txt = Global.get("RoleInfoManage").show_attr(data)
		var bbcode = "[color=white]你的宠物等级提升到%d级[/color]\n" % (args.get("level", 0))
		
		if skills.size() > 0:
			bbcode = str(bbcode, "[color=white]领悟了以下新技能:[/color]\n")
			for sid in skills:
				var sk_info = StaticGameData.get_skill_data(sid)
				bbcode = str(bbcode, "[color=green]【%s】[/color]\n" % sk_info["name"])
				pass
			pass
		bbcode = str(bbcode, "[color=white]额外获得可用点数：[color=green]", int(args.get("level_add", 0) * 5), "[/color]\n")
		ScreenUtils.show_message_plus(str(bbcode, bbcode_txt))
		pass
	emit_signal("pet_reload_show")
	pass


func set_fight_id(id):
	fight_pet_id = id

func set_pet_exp(p_exp):
	if p_exp == 0: return
	fight_pet_details["petHold"]["exp"] += p_exp

func get_fight_id():
	return fight_pet_id

func get_pet_level():
	return fight_pet_details["petHold"]["level"]
	pass
func get_pet_exp():

	return fight_pet_details["petHold"]["exp"]
	pass
func get_pet_max_exp():
	return Global.get("CalculationManage").calculate_pet_level_exp(fight_pet_details["petHold"]["level"])

	pass
func get_pet_hp():

	return fight_pet_details["petHold"]["hp"]
	pass
func get_pet_max_hp():
	return Global.get("CalculationManage").caculate_pet(fight_pet_details)["normal"]["max_hp"]

	pass
func get_pet_mp():
	return fight_pet_details["petHold"]["mp"]
	pass
func get_pet_max_mp():
	return Global.get("CalculationManage").caculate_pet(fight_pet_details)["normal"]["max_mp"]

	pass
func get_pet_img_dir():
	if fight_pet_details.empty(): return null
	return StaticGameData.get_pet_data(fight_pet_details["petHold"]["pet_race_id"])["img_dir"]
