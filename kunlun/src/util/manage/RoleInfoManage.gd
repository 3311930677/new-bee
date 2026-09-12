extends Node

class_name RoleInfoManage




const prefix = "RoleInfoManage->"

signal bind_success
signal reload_head_ui
signal role_info_result
signal role_info_update
signal role_reload_display

signal role_bvo_info_loaded
signal role_pet_fight_id_loaded
signal role_deliver_loaded
signal role_condition_info_loaded
signal role_backpack_info_loaded
signal role_pet_show_reload

var sjrwtx_res = load("res://src/tscn/ui/common/SJRWTX.tscn")

var NetContext
var ScreenUtils
var StaticGameData


var user_vo_data = {}

var hot_role_op = {}

var role_info = {}


var role_all_info_data = {}


var cur_area_id = 1

var role_reload_display = false
var first_role_data_load = false
var show_pet_ui = false
func inspect_self_data():
	emit_signal("role_info_result", role_all_info_data)

func update_role_info():
	emit_signal("role_info_result", role_all_info_data)

	pass

func update_role_condition_info():
	NetContext.request_service("RoleOpRemote", "getRoleConditionInfo", {}, false)
	pass

func update_role_backpack_info():
	NetContext.request_service("RoleOpRemote", "getRoleBackpackInfo", {}, false)

func flush_role_bvo_info(r_id):
	if int(r_id) == - 1: r_id = get_role_id()
	NetContext.request_service("DataRemote", "getRoleBasicInfo", {
			"target_role_id": r_id
	}, false)


func request_role_data(role_id = - 1, wait = true):
	var id = role_id
	if id == - 1: id = get_role_id()
	NetContext.request_service("DataRemote", "getRoleInfo", {
			"id": id
		}, wait)

func request_role_skill_learn():
	NetContext.request_service("DataRemote", "getRoleSkillLearn", {}, false)
	pass


func op_role_state(state_index, op):
	Global.log_info(str("修改状态:", state_index, op))
	NetContext.request_service("ArticleUseRemote", "operatorRoleState", {
			"role_id": get_role_id(), 
			"type_index": state_index, 
			"op": op
		}, true)
	pass

func get_target_role_fight_pet_id(target_role_id, show_pet_ui_: bool = false):
	show_pet_ui = show_pet_ui_
	NetContext.request_service("PetRemote", "getRoleFightPet", {
			"target_role_id": target_role_id, 
	}, true)
	pass

func deliver_target_role(target_role_id, deliver_type):
	NetContext.request_service("RoleRemote", "deliverRole", {
			"target_role_id": target_role_id, 
			"deliver_type": deliver_type, 
	}, true)
	pass


func upgrade_role_level():
	NetContext.request_service("RoleOpRemote", "updateRoleLevel", {}, true)
	pass

func _init() -> void :
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	
	NetContext.set_handler("upgrade", "role", self, "_on_role_update_handler")
	NetContext.set_handler("Reward", "reward", self, "_on_role_reward_handler")
	
	NetContext.set_handler("LoginController", "selectRole", self, "_on_bind_role_result")
	NetContext.set_handler("LoginController", "roleOffline", self, "_on_unbind_role_result")
	
	NetContext.set_handler("DataRemote", "getRoleInfo", self, "_on_role_info_result")
	NetContext.set_handler("DataRemote", "getRoleSkillLearn", self, "_on_role_learn_skill_result")
	
	
	
	NetContext.set_handler("ArticleUseRemote", "operatorRoleState", self, "_on_role_state_result")
	
	
	NetContext.set_handler("DataRemote", "getRoleBasicInfo", self, "_on_role_basic_vo_info_result")
	
	NetContext.set_handler("PetRemote", "getRoleFightPet", self, "_on_role_fight_pet_result")
	
	
	NetContext.set_handler("RoleRemote", "deliverRole", self, "_on_role_deliver_info_result")
	
	
	NetContext.set_handler("RoleOpRemote", "getRoleConditionInfo", self, "_on_role_condition_info_result")
	
	NetContext.set_handler("RoleOpRemote", "getRoleBackpackInfo", self, "_on_role_backpack_info_result")
	
	NetContext.set_handler("RoleOpRemote", "updateRoleLevel", self, "_on_role_upgrade_result")





func _on_role_update_handler(data):
	data = parse_json(data["data"])
	Global.log_info(str(prefix, "角色升级", data))
	
	update_role_info()
	
	
	
	

	var bbcode = "[color=white]恭喜！人物角色等级提升[/color]\n"
	ScreenUtils.show_message_plus(str(bbcode, show_attr(data)))
	


func _on_role_reward_handler(data):
	data = parse_json(data["data"])
	Global.log_info(str(prefix, "得到任务奖励", data))
	
	if data["arts"].size() < 1 and data["equs"].size() < 1 and data["gems"].size() < 1 and data["pets"].size() < 1:
		return
	show_reward(data)
	pass


func _on_bind_role_result(data):
	
	role_info = data["data"]
	role_all_info_data["role"] = role_info
	emit_signal("bind_success")
	

func _on_unbind_role_result(data):
	Global.log_info(str("角色解除绑定，跳转界面"))
	
	ScreenUtils.clear_ui()
	Global.get("ChatInfoManage").clear()
	Global.get("PetInfoManage").fight_pet_id = - 1
	Global.get("TBBattleManage").current_fighting = false
	Global.get("NTeamManage").disposse()
	
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/login/select_role/SelectRoleUi.tscn", "load_data", {"area_id": cur_area_id})
	ScreenUtils.clear_scence()
	
	first_role_data_load = false
	hot_role_op["auto_atk"] = false
	hot_role_op["role_atk"] = - 1
	hot_role_op["pet_atk"] = - 1
	pass


func _on_role_info_result(data):
	data = data["data"]
	
	
	
	if not first_role_data_load:
		first_role_data_load = true
	
	if int(data["role"]["id"]) == int(get_role_id()):
		role_all_info_data = data
		role_info = data["role"]
		
		if Global.get("FactionInfoManage").has_faction():
			Global.get("FactionInfoManage").get_faction_union_data(get_role_faction_id(), false)
			Global.get("FactionInfoManage").get_member_info(get_role_id(), false)
		
		if int(role_info["pet_id"]) > 0:
			Global.get("PetInfoManage").set_fight_id(int(role_info["pet_id"]))
			Global.get("PetInfoManage").request_pet_details(int(role_info["pet_id"]), true)
		emit_signal("reload_head_ui")
		if role_reload_display:
			role_reload_display = false
			emit_signal("role_reload_display", role_info)
	emit_signal("role_info_result", data)
	
	pass

func _on_role_learn_skill_result(data):
	data = data["data"]
	role_all_info_data["skills"] = data
	emit_signal("role_info_result", role_all_info_data)
	reload_ui()


func _on_role_state_result(data):
	data = data["data"]
	role_all_info_data["role_condition"] = data
	

func _on_role_basic_vo_info_result(data):
	data = data["data"]
	if data["id"] == get_role_id():
		
		role_info["hp"] = data["hp"]
		role_info["mp"] = data["mp"]
		role_info["exp"] = data["exp"]
		if not role_all_info_data.has("role"): role_all_info_data["role"] = {}
		role_all_info_data["role"]["faction_id"] = data.get("faction_id", 0)
		role_all_info_data["role"]["popularity"] = data.get("popularity", 0)
		Global.get("FactionInfoManage").current_fac_info["name"] = data.get("faction_name", "帮派昵称")
		role_info["level"] = data["level"]
		if data.has("pet_basic_vo") and data["pet_basic_vo"] != null and not data["pet_basic_vo"].empty():
			Global.get("PetInfoManage").flush_pet_bvo_info(data["pet_basic_vo"])
		reload_ui()
		pass
	emit_signal("role_bvo_info_loaded", data)


func _on_role_fight_pet_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "角色出战宠物id 返回：", data))
	if show_pet_ui:
		if data["pet_id"] <= 0:
			ScreenUtils.show_message("该玩家没有设置出战的宠物")
			return
		Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/pet/PetUi.tscn", "load_data", {"pet_type": 1, "id": data["pet_id"]})
	emit_signal("role_pet_fight_id_loaded", data)
	pass

func _on_role_deliver_info_result(data):
	emit_signal("role_deliver_loaded")
	pass


func _on_role_condition_info_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "角色状态信息", data))
	role_all_info_data["role_condition"] = data
	emit_signal("role_condition_info_loaded")
	

func _on_role_backpack_info_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "背包的容量金币等数据", data))
	Global.get("BagInfoManage").map_all_bags["roleBackpackData"] = data
	emit_signal("role_backpack_info_loaded", data)
	pass

func _on_role_upgrade_result(data):
	ScreenUtils.show_message("操作成功!!!")


func bind_role(area_id, role_id):
	NetContext.request_gate("LoginController", "selectRole", {"area_id": area_id, "role_id": role_id}, true)

func unbind_role():
	NetContext.request_gate("LoginController", "roleOffline", {}, true)




func reload_ui():
	emit_signal("reload_head_ui")
	emit_signal("role_pet_show_reload")
	pass


func set_role_attr(args):
	
	if args.has("exp"): role_info["exp"] = args.get("exp", 0)
	if args.has("hp"): role_info["hp"] = args.get("hp", 0)
	if args.has("mp"): role_info["mp"] = args.get("mp", 0)
	if args.has("level"): role_info["level"] = args.get("level", 1)
	
	if args.has("potential_equ_id"): role_info["potential_equ_id"] = args.get("potential_equ_id", 0)
	
	if args.has("job_id"):
		role_info["job_id"] = args.get("job_id", 0)
		show_uplevel_special()
		emit_signal("role_reload_display", role_info)
	
	if args.has("division_id"):
		role_info["division_id"] = args.get("division_id", 0)
		show_uplevel_special()
		emit_signal("role_reload_display", role_info)
	
	if args.has("faction_id"):
		
		role_info["faction_id"] = args.get("faction_id", 0)
		if role_info["faction_id"] > 0:
			Global.get("FactionInfoManage").get_member_info(role_info["id"], false)
	
	if args.has("popularity"): role_info["popularity"] = args.get("popularity", 0)
	
	if args.has("vip_exp"): role_info["vip_exp"] = args.get("vip_exp", 0)
	
	if args.has("is_run_business"): role_info["is_run_business"] = args.get("is_run_business", 0)
	
	if args.has("title_id"): role_info["title_id"] = args.get("title_id", 0)
	
	if args.has("mute"): role_info["mute"] = args.get("mute", 0)
	
	if args.has("role_name"): role_info["role_name"] = args.get("role_name", "昵称加载中...")
	
	if args.has("role_condition_supply_pack"): role_all_info_data["role_condition"]["supply_pack"] = args.get("role_condition_supply_pack", 0)
	
	
	if args.has("equ_add_potential"):
		var hold = args["equ_add_potential"]
		for item in role_all_info_data["equipment_holds"]:
			if item.id == hold.id: item["usr_potentia"] = hold["usr_potential"]
	
	if args.get("level_add", 0) > 0:
		show_uplevel_special()
		var CalculationManage = Global.get("CalculationManage")
		
		var attribute = CalculationManage.get_role_rttribute(role_info["job_id"] * 10 + role_info["division_id"], args.get("level_add"))
		var bbcode_txt = show_attr(attribute)
		var bbcode = "[color=white]恭喜你！等级提升到%d级[/color]\n" % (args.get("level", 0))
		
		ScreenUtils.show_message_plus(str(bbcode, bbcode_txt))
		Global.log_info(str("角色发生等级变化，这里需要进行弹窗展示"))
		pass
	update_role_info()
	reload_ui()
	pass

func set_pet_fight_id(id):
	role_info["pet_id"] = id
	pass

func set_role_exp(r_exp):
	role_info["exp"] += r_exp


func get_role_position():
	return Vector2(role_info["x"], role_info["y"])
func set_role_position(v2):
	role_info["x"] = v2.x
	role_info["y"] = v2.y
	pass

func get_role_current_map():
	
	if not first_role_data_load:
		return role_info["map_id"]
	return Global.get("MapInfoManage").current_map

func set_role_current_map(map_id):
	role_info["map_id"] = int(map_id)
func get_role_info():
	return role_info
func get_role_all_info():
	return role_all_info_data

func get_role_id():
	return role_info["id"]
func get_role_name():
	return role_info["role_name"]
func get_role_race_id():
	return role_info["race_id"]
func get_role_level():
	return role_info["level"]
func get_pet_fight_id():
	return role_info["pet_id"]
func get_role_division_id():
	return role_info["division_id"]
func get_role_exp():
	return role_info.get("exp", 0)
	pass

func get_role_max_exp():
	return Global.get("CalculationManage").calculate_role_level_exp(get_role_level())


	pass
func get_role_hp():
	return role_info.get("hp", 1)
	pass
func get_role_max_hp():
	return Global.get("CalculationManage").calculate_role(role_all_info_data)["normal"]["max_hp"]


	pass
func get_role_mp():
	return role_info.get("mp", 1)

	pass
func get_role_max_mp():
	return Global.get("CalculationManage").calculate_role(role_all_info_data)["normal"]["max_mp"]


	pass

func get_role_wear_euqi_ids():
	var temp_arr = []
	for item in role_all_info_data["equipment_holds"]:
		temp_arr.append(item["id"])
	return temp_arr



func get_role_has_state_enemy():
	if not role_all_info_data.has("role_condition"):
		return false
	var enem = role_all_info_data["role_condition"]["enemy_magic_card"]
	var enem_start = role_all_info_data["role_condition"]["start_enemy_magic_card"]
	if enem == 0: return false
	if enem_start == 0: return false
	
	var s = OS.get_system_time_msecs() - enem_start
	
	if s >= enem:
		
		role_all_info_data["role_condition"]["enemy_magic_card"] = 0
		role_all_info_data["role_condition"]["start_enemy_magic_card"] = 0
		return false
	else: return true

func get_role_has_exorcism():
	if not role_all_info_data.has("role_condition"):
		return false
	var exo = role_all_info_data["role_condition"]["exorcism_card"]
	var exo_start = role_all_info_data["role_condition"]["start_exorcism_card"]
	if exo == 0: return false
	if exo_start == 0: return false
	
	var s = OS.get_system_time_msecs() - exo_start
	if s >= exo:
		role_all_info_data["role_condition"]["exorcism_card"] = 0
		role_all_info_data["role_condition"]["start_exorcism_card"] = 0
		return false
	else: return true

func get_role_faction_id():
	return role_info["faction_id"]
func set_role_faction_id(id):
	role_info["faction_id"] = id
func get_self_user_indetity():
	return user_vo_data.get("identity", 0)


func common_wear_equipment(equ_hold):
	var static_data = Global.get("StaticGameData").get_equi_data(equ_hold["equi_data_id"])
	var i = 0
	for item in role_all_info_data["equipment_holds"]:
		var temp_data = Global.get("StaticGameData").get_equi_data(item["equi_data_id"])
		if temp_data["wear_index"] == static_data["wear_index"]:
			break
		i += 1
	role_all_info_data["equipment_holds"].remove(i)
	role_all_info_data["equipment_holds"].append(equ_hold)
	reload_ui()
	pass

func common_unwear_equipment(equ_hold):
	var static_data = Global.get("StaticGameData").get_equi_data(equ_hold["equi_data_id"])
	var i = 0
	for item in role_all_info_data["equipment_holds"]:
		var temp_data = Global.get("StaticGameData").get_equi_data(item["equi_data_id"])
		if temp_data["wear_index"] == static_data["wear_index"]:
			break
		i += 1
	role_all_info_data["equipment_holds"].remove(i)
	reload_ui()
	pass

func show_reward(data):
	
	var bbcode = "[center][color=green]恭喜你获得![/color][center]\n"
	
	for item in data["arts"]:
		var s_a_data = StaticGameData.get_article_data(item["articles_data_id"])
		var bind = StaticGameData.get_bind_text_format(item["bind"])
		var c_color = s_a_data["display_color"]
		if c_color == "000000":
			c_color = "ffffff"
		bbcode = str(bbcode, "[color=#", c_color, "]")
		bbcode = str(bbcode, "LV", s_a_data["level"], " ", bind, s_a_data["name"])
		bbcode = str(bbcode, "x", item.get("count", 1), "[/color]\n")
		pass
	
	for item in data["equs"]:
		var s_a_data = StaticGameData.get_equi_data(item["equi_data_id"])
		
		var bind = StaticGameData.get_bind_text_format(item["bind"])
		
		var zhiye = StaticGameData.get_euqi_job_all_text_format(item["equi_data_id"])
		
		var c_color = s_a_data["display_color"]
		if c_color == "000000":
			c_color = "ffffff"
		bbcode = str(bbcode, "[color=#", c_color, "]")
		
		bbcode = str(bbcode, "LV", s_a_data["level"], " ", bind, zhiye, s_a_data["name"])
		
		bbcode = str(bbcode, "x", item.get("count", 1), "[/color]\n")
		pass
	
	for item in data["gems"]:
		var s_a_data = StaticGameData.get_gem_data(item["gemstone_id"])
		var bind = StaticGameData.get_bind_text_format(item["bind"])
		var c_color = s_a_data["display_color"]
		if c_color == "000000":
			c_color = "ffffff"
		bbcode = str(bbcode, "[color=#", c_color, "]")
		bbcode = str(bbcode, "LV", s_a_data["level"], " ", bind, s_a_data["name"])
		bbcode = str(bbcode, "x", item.get("count", 1), "[/color]\n")
		pass
	
	for item in data["pets"]:
		var pinji = Global.get("StaticGameData").get_pet_grade_text(item["grade"])
		bbcode = str(bbcode, "[color=white]", pinji, "  ", item["name"], "x1", "[/color]\n")
		pass
	
	ScreenUtils.show_message_plus(bbcode)


func show_attr(data):
	
	var bbcode = ""
	var basic = data["basic"]
	var normal = data["normal"]
	bbcode = str(bbcode, "生命:[color=green]+", int(normal.get("max_hp", 0)), "[/color],")
	bbcode = str(bbcode, "魔法:[color=green]+", int(normal.get("max_mp", 0)), "[/color]\n")
	bbcode = str(bbcode, "力量:[color=green]+", int(basic.get("power", 0)), "[/color],")
	bbcode = str(bbcode, "智力:[color=green]+", int(basic.get("intelligence", 0)), "[/color]\n")
	bbcode = str(bbcode, "敏捷:[color=green]+", int(basic.get("agile", 0)), "[/color],")
	bbcode = str(bbcode, "耐力:[color=green]+", int(basic.get("endurance", 0)), "[/color]\n")
	bbcode = str(bbcode, "精神:[color=green]+", int(basic.get("spirit", 0)), "[/color],")
	bbcode = str(bbcode, "物攻:[color=green]+", int(normal.get("physical_atk", 0)), "[/color]\n")
	bbcode = str(bbcode, "法攻:[color=green]+", int(normal.get("law_atk", 0)), "[/color],")
	bbcode = str(bbcode, "物防:[color=green]+", int(normal.get("physical_def", 0)), "[/color]\n")
	bbcode = str(bbcode, "法防:[color=green]+", int(normal.get("law_def", 0)), "[/color],")
	bbcode = str(bbcode, "命中:[color=green]+", int(normal.get("hit", 0)), "[/color]\n")
	bbcode = str(bbcode, "闪避:[color=green]+", int(normal.get("dodge", 0)), "[/color],")
	bbcode = str(bbcode, "暴击:[color=green]+", int(normal.get("bash", 0)), "[/color]\n")
	return bbcode


func show_uplevel_special():
	var container = Global.get("ScreenUtils").get_map_container()
	if container != null:
		var sjtx = sjrwtx_res.instance()
		container.add_child(sjtx)
		sjtx.play_anim("sj_tx")
		
		sjtx._set_position(container.player_entity.position)
	pass
