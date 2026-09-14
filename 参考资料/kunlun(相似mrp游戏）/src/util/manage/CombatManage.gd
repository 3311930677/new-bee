extends Node
class_name CombatManage
const prefix = "CombatManage"

signal fight_round_line_
signal fight_round_end_
signal fight_round_state_
signal fight_start_
signal fight_continue_


signal hot_info_update

var NetContext
var ScreenUtils
var fighting = false
var fight_start_data

var pk_request_data
var local_mapping_map

var atk_type = 1


var room_type = - 1

func _init() -> void :
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	
	NetContext.set_handler("ServicePush", "fightPush", self, "_on_fight_message_handler")
	NetContext.set_handler("FightRemote", "generalAttack", self, "_on_general_attack_message_handler")
	NetContext.set_handler("FightRemote", "skill", self, "_on_general_attack_message_handler")
	NetContext.set_handler("FightRemote", "runAway", self, "_on_general_run_away_handler")
	NetContext.set_handler("FightRemote", "capture", self, "_on_general_run_away_handler")
	
	NetContext.set_handler("SneakAttackRemote", "sneakAttack", self, "_on_sneak_attack_handler")
	


func _on_fight_message_handler(data):
	var msg = parse_json(data["data"])
	if msg["type"] == 1:
		fighting = true
		atk_type = 1
		room_type = msg["room_type"]
		emit_signal("fight_start_")
		Global.log_info(str(prefix, "战斗来了：", msg))
		ScreenUtils.hide_please_wait()
		fight_start_data = msg
		forced_fight()
		emit_signal("fight_continue_", atk_type)
	elif msg["type"] == 2:
		Global.log_info(str(prefix, "回合数据来了：", msg))
		emit_signal("fight_round_line_", msg)
		
	elif msg["type"] == 3:
		Global.log_info(str(prefix, "pk申请来了：", msg))
		pk_request_data = msg
		ScreenUtils.show_message(str("玩家:", msg["role_name"], "请求与你切磋,是否接受？"), self, "agreeInvite_", "declineInvite_")
	elif msg["type"] == 4:
		Global.log_info(str(prefix, "拒绝pk消息", msg))
		ScreenUtils.show_message(str("玩家:", msg["role_name"], "玩家拒绝了你的pk申请"))
	elif msg["type"] == 5:
		Global.log_info(str(prefix, "有战斗实体准备好了", msg))
		emit_signal("fight_round_state_", msg)
		
	elif msg["type"] == 6:
		Global.log_info(str(prefix, "战斗结束了", msg))
		fighting = false
		emit_signal("fight_round_end_", msg)
		room_type = - 1
		




func _on_general_run_away_handler(data):
	_on_general_attack_message_handler(data)
	pass
func _on_general_attack_message_handler(data):
	
	var pet_f_id = Global.get("RoleInfoManage").get_pet_fight_id()
	
	if pet_f_id <= 0:
		return
	
	var entity = get_player_pet_info()
	if entity["death"]: return
	
	if atk_type == 1:
		atk_type += 1
		emit_signal("fight_continue_", atk_type)

func _on_sneak_attack_handler(data):

	Global.log_info(str("偷袭返回数据", data))
	pass


func agreeInvite_():
	agree_invitation(pk_request_data["inviter_id"])
	

func declineInvite_():
	decline_invitation(pk_request_data["inviter_id"])


func pk_Invitation(invitee_id):
	NetContext.request_fight("PKRemote", "pkInvitation", {"invitee_id": invitee_id})
	

func agree_invitation(inviter_id):
	NetContext.request_fight("PKRemote", "agreeInvitation", {"inviter_id": inviter_id})
	

func decline_invitation(inviter_id):
	NetContext.request_fight("PKRemote", "declineInvitation", {"inviter_id": inviter_id})


func raid_role(player_info):
	
	
	
	
	if Global.get("RoleInfoManage").get_role_level() < 55:
		ScreenUtils.show_message("你等级过低，无法偷袭！")
		return
	NetContext.request_service("SneakAttackRemote", "sneakAttack", {
		"attacked_id": player_info["id"]
		}, true)
	pass



func round_end():
	if get_player_info().get("death", true):
		atk_type = 2
	else:
		atk_type = 1
	if get_player_pet_info().get("death", true) and atk_type == 2:
		atk_type = 0
	emit_signal("fight_continue_", atk_type)


func normal_atk(local_arr_pos):
	var targets = get_target_position(local_arr_pos)
	
	if atk_type == 1: Global.get("RoleInfoManage").hot_role_op["role_atk"] = - 1
	else: Global.get("RoleInfoManage").hot_role_op["pet_atk"] = - 1
	emit_signal("hot_info_update")
	
	NetContext.request_fight("FightRemote", "generalAttack", {
		"type": atk_type, 
		"targets": targets
	}, false)

func skill_atk(local_arr_pos, skill_id):
	var targets = get_target_position(local_arr_pos)
	if atk_type == 1: Global.get("RoleInfoManage").hot_role_op["role_atk"] = skill_id
	else: Global.get("RoleInfoManage").hot_role_op["pet_atk"] = skill_id
	emit_signal("hot_info_update")
	
	NetContext.request_fight("FightRemote", "skill", {
		"type": atk_type, 
		"skill_id": skill_id, 
		"targets": targets
	}, false)


func run_away():
	NetContext.request_fight("FightRemote", "runAway", {}, false)
	pass

func catch_pet(local_arr_pos):
	var targets = get_target_position(local_arr_pos)
	NetContext.request_fight("FightRemote", "capture", {
		"targets": targets
	}, false)
	pass


func forced_fight():
	
	ScreenUtils.change_fight_scence()
	pass

func quit_fight():
	fighting = false
	ScreenUtils.change_main_scence()
	
	Global.get("TaskInfoManage").request_refresh_task()


func get_target_position(local_p):
	var targets = []
	for i in local_p:
		var info = local_mapping_map[str(i)]
		if info == null: continue

		targets.append(info["index"])
	return targets


func get_player_position(is_p: bool = true):
	for entity in fight_start_data["entities"]:
		if entity != null and entity["type"] == 1:
			
			if Global.get("RoleInfoManage").get_role_id() == entity["id"]:
				
				if entity["index"] >= 6:
					
					if is_p == true:

						return arr_limit(fight_start_data["entities"], 6, 11)
					else:
						return arr_limit(fight_start_data["entities"], 0, 5)

				else:
					if is_p:
						return arr_limit(fight_start_data["entities"], 0, 5)

					else:
						return arr_limit(fight_start_data["entities"], 6, 11)

					


func get_player_info():
	for i in 12:
		var info = local_mapping_map[str(i)]
		if info == null: continue
		if info["type"] == 1 and info["id"] == Global.get("RoleInfoManage").get_role_id():
			return local_mapping_map[str(i)]
	return {}

func get_player_local_index():
	for i in 12:
		var info = local_mapping_map[str(i)]
		if info == null: continue
		if info["type"] == 1 and info["id"] == Global.get("RoleInfoManage").get_role_id():
			return i
	return - 1

func get_pet_local_index():
	for i in 12:
		var info = local_mapping_map[str(i)]
		if info == null: continue
		if info["type"] == 2 and info["id"] == Global.get("RoleInfoManage").get_pet_fight_id():
			return i
	return - 1
	pass

func get_player_pet_info():
	for i in 12:
		var info = local_mapping_map[str(i)]
		if info == null: continue
		if info["type"] == 2 and info["id"] == Global.get("RoleInfoManage").get_pet_fight_id():
			return local_mapping_map[str(i)]
	return {}

func get_role_info():
	for i in fight_start_data["entities"]:
		if i == null: continue
		if i["type"] == 1 and i["id"] == Global.get("RoleInfoManage").get_role_id():
			return i
	return Global.get("RoleInfoManage").get_role_all_info()

func get_pet_info():
	for i in fight_start_data["entities"]:
		if i == null: continue
		if i["type"] == 2 and i["id"] == Global.get("PetInfoManage").get_fight_pet_id():
			return i
	return null
	pass
func get_fight_room_type():
	return room_type;
func check_boss_room():
	return room_type == 2

func arr_limit(arr, start, end):
	var res_arr = []
	for i in range(start, end + 1):
		res_arr.append(arr[i])
		pass
	return res_arr
