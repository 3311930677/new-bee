extends Node
class_name TBBattleManage


signal operation_success

signal operation_ready_success

signal battle_round_data_success

signal battle_round_end

signal hot_info_update

var NetContext
var MapInfoManage
var ScreenUtils


var current_fighting = false

var current_fight_room = {}

var current_room_type = 0

var current_local_position_map = {}

func _init() -> void :
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	MapInfoManage = Global.get("MapInfoManage")
	
	NetContext.set_handler("ServicePush", "fight", self, "_on_fight_message_handler")

	
	NetContext.set_handler("TBFightRemote", "encounterMonster", self, "_on_encounter_monster_handler")
	NetContext.set_handler("TBFightPKRemote", "pkInvitation", self, "_on_encounter_monster_handler")
	
	
	NetContext.set_handler("TBFightSneakRemote", "sneakAttack", self, "_on_encounter_monster_handler")
	
	
	NetContext.set_handler("SneakAttackRemote", "sneakAttack", self, "_on_encounter_monster_handler")
	
	NetContext.set_handler("TBFightOperationRemote", "generateAtk", self, "_on_general_behavior_message_handler")
	NetContext.set_handler("TBFightOperationRemote", "skillAtk", self, "_on_general_behavior_message_handler")
	NetContext.set_handler("TBFightOperationRemote", "escape", self, "_on_general_behavior_message_handler")
	NetContext.set_handler("TBFightOperationRemote", "capture", self, "_on_general_behavior_message_handler")
	

	



func request_has_fight():
	NetContext.request_fight("TBFightRemote", "checkHasFighting", {}, true)
	pass


func generate_atk(op_type, arr_targets):
	
	if op_type == 0: Global.get("RoleInfoManage").hot_role_op["role_atk"] = - 1
	else: Global.get("RoleInfoManage").hot_role_op["pet_atk"] = - 1
	emit_signal("hot_info_update")
	
	NetContext.request_fight("TBFightOperationRemote", "generateAtk", {
		"op_type": op_type, 
		"targets": arr_targets
	}, false)
	pass

func skill_atk(op_type, skill_id, arr_targets):
	if op_type == 0: Global.get("RoleInfoManage").hot_role_op["role_atk"] = skill_id
	else: Global.get("RoleInfoManage").hot_role_op["pet_atk"] = skill_id
	emit_signal("hot_info_update")

	NetContext.request_fight("TBFightOperationRemote", "skillAtk", {
		"op_type": op_type, 
		"skill_id": skill_id, 
		"targets": arr_targets
	}, false)
	pass

func escape(op_type):
	NetContext.request_fight("TBFightOperationRemote", "escape", {
		"op_type": op_type
	}, false)
	pass

func capture(op_type, arr_targets):
	NetContext.request_fight("TBFightOperationRemote", "capture", {
		"op_type": op_type, 
		"targets": arr_targets
	}, false)
	pass





func request_monster_fight():
	if not current_fighting:
		NetContext.request_fight("TBFightRemote", "encounterMonster", {
			"en_type": 0, 
			"similar": true
		}, false)
	current_fighting = true



func request_monster_npc_fight(en_type):
	if not current_fighting:
		NetContext.request_fight("TBFightRemote", "encounterMonster", {
			"en_type": en_type, 
			"similar": true
		}, false)
	current_fighting = true
	pass


func request_pk(invite_id):
	if not current_fighting:
		NetContext.request_fight("TBFightPKRemote", "pkInvitation", {
			"invite_id": invite_id, 
		}, false)
	current_fighting = true
	Global.get("ScreenUtils").show_message("等待对方回应")
	pass

func request_sneak(invite_id):
	if Global.get("RoleInfoManage").get_role_level() < 55:
		ScreenUtils.show_message("你等级过低，无法偷袭！")
		return
	
	
	if not current_fighting:
		NetContext.request_fight("TBFightSneakRemote", "sneakAttack", {
			"target_id": invite_id, 
		}, false)
	current_fighting = true



func get_battle_round():
	return int(current_fight_room["round"])

func get_battle_room_type():
	return current_room_type;

func get_role_entity_data():
	var role_entity = null
	
	var k = ["left", "right"]
	
	for lr in k:
		if role_entity != null: break
		
		var lr_map = current_fight_room[lr]
		
		for item in lr_map.keys():
		
			var info = lr_map[item]
		
			if info["type"] == "role":
		
				if int(info["id"]) == Global.get("RoleInfoManage").get_role_id():
		
					role_entity = info
		
					break
	
	return role_entity

func get_pet_entity_data():
	var pet_entity = null
	
	var k = ["left", "right"]
	
	for lr in k:
		if pet_entity != null: break
		
		var lr_map = current_fight_room[lr]
		
		for item in lr_map.keys():
		
			var info = lr_map[item]
		
			if info["type"] == "pet":
		
				if int(info["id"]) == Global.get("PetInfoManage").get_fight_pet_id():
		
					pet_entity = info
		
					break
	
	return pet_entity

func get_role_camp():
	var k = get_role_camp_key()
	if k == null:
		return null
	else:
		return current_fight_room[k]


func get_role_camp_key():
	var k = ["left", "right"]
	for lr in k:
		
		var lr_map = current_fight_room[lr]
		
		for item in lr_map.keys():
		
			var info = lr_map[item]
		
			if info["type"] == "role":
		
				if int(info["id"]) == Global.get("RoleInfoManage").get_role_id():
					return lr
	return null


func _on_encounter_monster_handler(data):
	current_fighting = false
	pass


func _on_fight_message_handler(data):
	data = parse_json(data["data"])
	var type = data["type"]
	
	
	if type == "start":
		
		var arr = Global.get_nodes_in_group("tb_battle_scence")
		if arr.size() > 0:
			Global.log_info("当前处于一个战斗场景中，不在新建场景");
			return
		current_fighting = true
		current_fight_room = data["room"]
		current_room_type = current_fight_room["roomType"]
		Global.log_info("有新的战斗来了！");
		current_local_position_map.clear()
		
		
		
		ScreenUtils.change_new_fight_scence()
		pass
	elif type == "ready":
		Global.log_info("有实体准备好了");
		emit_signal("operation_ready_success", data["ready"])
	elif type == "round":
		Global.log_info(str("战斗回合数据", data))
		
		current_fight_room["round"] = int(current_fight_room.get("round", 0)) + 1
		emit_signal("battle_round_data_success", data)
		pass
	elif type == "end":
		current_fighting = false
		emit_signal("battle_round_end", data)
		pass



func _on_general_behavior_message_handler(data):
	emit_signal("operation_success")
	pass
