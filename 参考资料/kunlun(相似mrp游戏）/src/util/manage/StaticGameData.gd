extends Node
class_name StaticGameData

const prefix = "StaticGameData->"
signal _loaded_complete

var NetContext
var ScreenUtils
var FileHelper

var page_size = 100
var current_page_cont = 0


var map_load_count = {
	"getBasicData": 1, 
	"getNpcData": 20, 
	"getPortalData": 5, 
	"getArticle": 4, 
	"getGem": 6, 
	"getEqui": 9, 

	"getPet": 6, 
	"getSystemMall": 6, 
	"getSkillDataTemp": 10, 
	"getRoleUpAttr": 1, 
	"getSkillBonusAttr": 7, 
	"end": 0
}


var attr_name_data = {
	"power": "力量", 
	"agile": "敏捷", 
	"intelligence": "智力", 
	"endurance": "耐力", 
	"spirit": "精神", 
	"physical_atk": "物攻", 
	"law_atk": "法攻", 
	"physical_def": "物防", 
	"law_def": "法防", 
	"hit": "命中", 
	"dodge": "闪避", 
	"crit": "暴击", 
	"bash": "暴击", 
	"shot_speed": "出手速度", 
	"max_hp": "生命", 
	"max_mp": "魔法", 
}
var pet_grade_data = {
	"1": "一品", 
	"2": "二品", 
	"3": "三品", 
	"4": "四品", 
	"5": "五品", 
}
var role_job_division_name = {
	"0": "无", 
	"1": "遁甲", 
	"2": "猛士", 
	"3": "天音", 
	"4": "琴魔", 
	"5": "幽冥", 
	"6": "罗刹", 
}
var equi_job_name = {
	"00": "无", 
	"0": "无", 
	"10": "墨", 
	"20": "道", 
	"30": "阴阳", 
	"11": "遁", 
	"12": "猛", 
	"23": "音", 
	"24": "琴", 
	"35": "冥", 
	"36": "刹", 
}
var equi_job_all_name = {
	"0": "无", 
	"10": "墨家", 
	"20": "道家", 
	"30": "阴阳家", 
	"11": "盾甲", 
	"12": "猛士", 
	"23": "天音", 
	"24": "琴魔", 
	"35": "幽冥", 
	"36": "罗刹", 
}

var euqi_location_name = {
	"1": "武器", 
	"2": "头部", 
	"3": "胸部", 
	"4": "腕部", 
	"5": "腰部", 
	"6": "腿部", 
	"7": "脚部", 
	"8": "颈部", 
	"9": "手部", 
	"10": "护符", 
	"11": "法宝", 
	"12": "补给包", 
}

var colors = {
	"black": Color(0, 0, 0, 1), 
	"red": Color(1, 0, 0, 1), 
	"green": Color(0, 1, 0, 1), 
	"blue": Color(0, 0, 1, 1), 
	"purple": Color(1, 0, 1, 1), 
	"grey": Color(0.5, 0.5, 0.5, 1), 
	"orange": Color(1, 165 / 255, 0, 1), 
	"grass_green": Color(42 / 255, 171 / 255, 42 / 255, 1), 
	"green_yellow": Color(173 / 255, 255 / 255, 47 / 255, 1), 
}
var all_static_data = {}


var version = 1.0

var file_name = "user://run_info_data.bin"

var file_key = "4*/*566run_info_data.bin,;123d"

func _init() -> void :
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	FileHelper = Global.get("FileHelper")
	
	NetContext.set_handler("GameBasicDataRemote", "checkVersion", self, "_on_check_version_data")
	
	NetContext.set_handler("GameBasicDataRemote", "getBasicData", self, "_on_role_basic_data")
	
	NetContext.set_handler("GameBasicDataRemote", "getNpcData", self, "_on_npc_data")
	
	NetContext.set_handler("GameBasicDataRemote", "getPortalData", self, "_on_map_protal_data")
	
	NetContext.set_handler("GameBasicDataRemote", "getArticle", self, "_on_article_data")
	
	NetContext.set_handler("GameBasicDataRemote", "getGem", self, "_on_gem_data")
	
	NetContext.set_handler("GameBasicDataRemote", "getEqui", self, "_on_equi_data")
	
	NetContext.set_handler("GameBasicDataRemote", "getSkillData", self, "_on_skill_data")
	NetContext.set_handler("GameBasicDataRemote", "getSkillDataTemp", self, "_on_skill_data_temp")
	
	NetContext.set_handler("GameBasicDataRemote", "getPet", self, "_on_pet_data")
	
	NetContext.set_handler("GameBasicDataRemote", "getSystemMall", self, "_on_all_mall_data_result")
	
	NetContext.set_handler("GameBasicDataRemote", "getRoleUpAttr", self, "_on_all_role_update_result")
	NetContext.set_handler("GameBasicDataRemote", "getSkillBonusAttr", self, "_on_all_skill_bonus_attr_result")
	
	load_local_data()
	
	version = all_static_data.get("version", "1.0")
	pass

func load_data():
	
	NetContext.request_service("GameBasicDataRemote", "checkVersion", {
		"version": version
	}, true)
	





	pass

func _on_check_version_data(data):
	data = data["data"]
	if data.get("update", false):
		Global.log_info(str(prefix, "静态资源需要更新"))
		load_network_data()
	else:
		Global.log_info(str(prefix, "使用本地资源"))
		emit_signal("_loaded_complete")
		pass
	pass


func load_network_data():
	current_page_cont = 0
	all_static_data.clear()
	
	
	NetContext.request_service("GameBasicDataRemote", "getBasicData", {}, true)
	pass


func load_local_data():
	all_static_data.clear()
	if not FileHelper.file_exits(file_name):
		load_network_data()
		return
	all_static_data = FileHelper.read_encrypted(file_name, file_key)
	pass


func network_data_loaded_save():
	FileHelper.save_encrypted(file_name, all_static_data, file_key)
	pass


func _on_role_basic_data(data):
	data = data["data"]
	current_page_cont += 1
	for key in data.keys():
		all_static_data[key] = data[key]
	_load_next_static_data("getBasicData")


func _on_npc_data(data):
	data = data["data"]
	current_page_cont += 1
	
	if all_static_data.has("npcs"):
		all_static_data["npcs"].append_array(data)
	else:
		all_static_data["npcs"] = data
	_load_next_static_data("getNpcData")


func _on_map_protal_data(data):
	data = data["data"]
	current_page_cont += 1
	
	
	if all_static_data.has("portals"):
		all_static_data["portals"].append_array(data)
	else:
		all_static_data["portals"] = data
	
	_load_next_static_data("getPortalData")


func _on_article_data(data):
	data = data["data"]
	current_page_cont += 1
	
	
	if not all_static_data.has("articles"):
		all_static_data["articles"] = {}
	
	for item in data:
		all_static_data["articles"][str(item["id"])] = item
	_load_next_static_data("getArticle")
	


func _on_gem_data(data):
	data = data["data"]
	current_page_cont += 1
	
	if not all_static_data.has("gems"):
		all_static_data["gems"] = {}
	for item in data:
		all_static_data["gems"][str(item["id"])] = item
	_load_next_static_data("getGem")
	


func _on_equi_data(data):
	data = data["data"]
	current_page_cont += 1
	if not all_static_data.has("equis"):
		all_static_data["equis"] = {}
		
	for item in data:
		all_static_data["equis"][str(item["id"])] = item
	_load_next_static_data("getEqui")


func _on_skill_data(data):
	data = data["data"]
	current_page_cont += 1
	if not all_static_data.has("skills"):
		all_static_data["skills"] = {}
	for item in data:
		all_static_data["skills"][str(item["id"])] = item
	_load_next_static_data("getSkillData")

func _on_skill_data_temp(data):
	data = data["data"]
	current_page_cont += 1
	if not all_static_data.has("skill_temp"):
		all_static_data["skill_temp"] = {}
	for item in data:
		all_static_data["skill_temp"][str(item["id"])] = item
	_load_next_static_data("getSkillDataTemp")


func _on_pet_data(data):
	data = data["data"]
	current_page_cont += 1
	if not all_static_data.has("pets"):
		all_static_data["pets"] = {}
	for item in data:
		all_static_data["pets"][str(item["id"])] = item
	_load_next_static_data("getPet")


func _on_all_mall_data_result(data):
	data = data["data"]
	current_page_cont += 1
	
	if all_static_data.has("mall"):
		all_static_data["mall"].append_array(data)
	else:
		all_static_data["mall"] = data
	_load_next_static_data("getSystemMall")
	pass

func _on_all_role_update_result(data):
	data = data["data"]
	current_page_cont += 1
	
	if all_static_data.has("role_update"):
		all_static_data["role_update"].append_array(data)
	else:
		all_static_data["role_update"] = data
	_load_next_static_data("getRoleUpAttr")
	pass

func _on_all_skill_bonus_attr_result(data):
	data = data["data"]
	current_page_cont += 1
	
	if all_static_data.has("skill_bonus"):
		all_static_data["skill_bonus"].append_array(data)
	else:
		all_static_data["skill_bonus"] = data
	_load_next_static_data("getSkillBonusAttr")
	pass


func _load_next_static_data(str_key):
	
	var max_page = map_load_count[str_key]
	
	if current_page_cont >= max_page:
		current_page_cont = 0
		var arr_key = map_load_count.keys()
		
		var nextkey = arr_key[arr_key.find(str_key) + 1]
		
		if nextkey == "end":
			
			version = all_static_data.get("version", "1.0")
			emit_signal("_loaded_complete")
			Global.log_info(str(prefix, "数据请求完毕！"))
			
			network_data_loaded_save()
			return
		else:
			NetContext.request_service("GameBasicDataRemote", nextkey, {
				"pageNum": current_page_cont + 1, 
				"pageSize": page_size
			}, true)
	else:
		
		NetContext.request_service("GameBasicDataRemote", str_key, {
			"pageNum": current_page_cont + 1, 
			"pageSize": page_size
		}, true)
	
	
	pass







func get_role_type(race_id, job_id, job_divison_id):
	var role_type = 10
	var sex = all_static_data["role_race"][int(race_id) - 1]["sex"]
	if int(job_id) == 0:
		if sex == 1: role_type = race_id - 3
		else: role_type = race_id
	else:
		
		if int(job_divison_id) == 0:
			role_type = Global.get("RoleUtils").role_type_arr_job[job_id - 1]
		else:
			role_type = Global.get("RoleUtils").role_type_arr_division[job_divison_id - 1]
	return {"role_type": role_type, "sex": sex}

func get_role_popularity_text(p, default_txt = "平民"):
	if p >= - 50 and p < 0:
		return "[歹徒]"
	elif p >= - 100 and p < - 50:
		return "[恶霸]"
	elif p <= - 100:
		return "[魔头]"
	elif p > 0 and p <= 50:
		return "[侠士]"
	elif p > 50 and p < 100:
		return "[勇士]"
	elif p >= 100:
		return "[英雄]"
	else:
		return default_txt
func get_role_popularity_color(p):
	if p >= - 50 and p < 0:
		return Color(210 / 255.0, 105 / 255.0, 30 / 255.0, 1);
	elif p >= - 100 and p < - 50:
		return Color(255 / 255.0, 69 / 255.0, 0 / 255.0, 1);
	elif p <= - 100:
		return Color(1, 0, 0, 1);
	elif p > 0 and p <= 50:
		return Color(144 / 255.0, 238 / 255.0, 144 / 255.0, 1);
	elif p > 50 and p < 100:
		return Color(0, 1, 0.5, 1);
	elif p >= 100:
		return Color(0, 1, 1, 1);
	else:
		return Color(0, 0, 0, 1);
	

func get_role_sex(race_id):
	var sex = all_static_data["role_race"][int(race_id) - 1]["sex"]
	return sex
func get_role_sex_text(race_id):
	var sex = get_role_sex(race_id)
	if sex == 0: return "男"
	else: return "女"


func get_role_job_text(job_id, job_division_id):
	if int(job_id) == 0: return "无";
	if int(job_division_id) == 0:
		return all_static_data["role_job"][job_id - 1]["job_name"]
	else:
		return all_static_data["role_job_division"][job_division_id - 1]["division_name"]

func get_role_job_text_format(job_id, job_division_id):
	return str("[", get_role_job_text(job_id, job_division_id), "]")


func get_bind_text(is_bing):
	if int(is_bing) == 0: return ""
	else: return "绑定"

func get_bind_text_format(is_bing):
	var txt = get_bind_text(is_bing)
	if txt != "": return str("[", txt, "]")
	return txt

func get_countermark_text(is_countermark):
	if int(is_countermark) == 0: return ""
	else: return "刻印"
func get_countermark_text_format(is_countermark):
	var txt = get_countermark_text(is_countermark)
	if txt != "": return str("[", txt, "]")
	return txt

func get_equi_job_txt(euqi_id):
	var temp_data = get_equi_data(euqi_id)
	return equi_job_name[str(temp_data["entity_type"])]

func get_euqi_job_text_format(euqi_id):
	var e_name = get_equi_job_txt(euqi_id)
	if e_name != "": return str("[", e_name, "]")
	return e_name

func get_equi_job_all_txt(euqi_id):
	var temp_data = get_equi_data(euqi_id)
	return equi_job_all_name[str(temp_data["entity_type"])]

func get_euqi_job_all_text_format(euqi_id):
	var e_name = get_equi_job_all_txt(euqi_id)
	if e_name != "": return str("[", e_name, "]")
	return e_name

func get_equ_all_name(hold_data):
	var data = hold_data
	var static_data = get_equi_data(data.equi_data_id)
	var level = data.get("level", 1)
	var bind = get_bind_text_format(data.get("bind", 0))
	var keyin = get_countermark_text_format(data.get("countermark", 0))
	if keyin.length() > 2: bind = keyin
	var zhiye = get_euqi_job_text_format(data.equi_data_id)
	var consolidate_level = data.get("consolidate_level", 0)
	if consolidate_level <= 0: consolidate_level = ""
	else: consolidate_level = str("+", consolidate_level)
	var punch = data.get("punch", 0)
	if punch <= 0: punch = ""
	else: punch = str("[%d]" % punch)
	var bbcode = str("LV%d %s%s%s %s%s" % [level, bind, zhiye, static_data["name"], consolidate_level, punch])
	return bbcode


func get_euqi_location(euqi_id):
	var temp_data = get_equi_data(euqi_id)
	return euqi_location_name[str(temp_data["wear_index"])]


func get_gem_data(gems_id):
	return all_static_data["gems"][str(gems_id)]

func get_equi_data(equi_id):
	return all_static_data["equis"][str(equi_id)]

func get_skill_data(skill_id):

	return get_skill_data_temp(skill_id)
func get_skill_data_temp(skill_id):
	if not all_static_data["skill_temp"].has(str(skill_id)):
		ScreenUtils.show_message("你的资源不完整，请重启再试")
	return all_static_data["skill_temp"][str(skill_id)]

func get_article_data(article_id):
	if not all_static_data["articles"].has(str(article_id)):
		ScreenUtils.show_message("你的资源不完整，请重启再试")
	return all_static_data["articles"][str(article_id)]
func get_pet_data(pet_race_id):
	if not all_static_data["pets"].has(str(pet_race_id)):
		ScreenUtils.show_message("你的资源不完整，请重启再试")
		return {}
	return all_static_data["pets"][str(pet_race_id)].duplicate(true)


func get_npc_data(id):
	for i in all_static_data.get("npcs", []):
		if i["id"] == id: return i

func get_npc_id_data(npc_id):
	for i in all_static_data.get("npcs", []):
		if i["npc_id"] == npc_id: return i


func get_all_system_mall_data():
	return all_static_data["mall"]

func get_pet_grade_text(grade):
	return pet_grade_data[str(grade)]

func get_article_data_txt(article_id):
	return get_article_data(article_id).get("name", "")
func get_article_data_txt_bbcode(article_id):
	var s = get_article_data(article_id)
	var bbstr = str("[color=#", s["display_color"], "]", s["name"], "[/color]")
	return bbstr


func get_bag_artic_data_info(bag_info):
	match get_articles_item_type(bag_info):
		2: return get_pet_data(bag_info["pet_race_id"])
		3: return get_equi_data(bag_info["equi_data_id"])
		4: return get_gem_data(bag_info["gemstone_id"])
		5: return get_article_data(bag_info["articles_data_id"])

func get_gem_data_txt(gemstone_id):
	return get_gem_data(gemstone_id).get("name", "")
func get_gem_data_txt_bbcode(gemstone_id):
	var s = get_gem_data(gemstone_id)
	var bbstr = str("[color=#", s["display_color"], "]", s["name"], "[/color]")
	return bbstr

func get_equi_data_txt(equi_id):
	return get_equi_data(equi_id).get("name", "")
func get_equi_data_txt_bbcode(equi_id):
	var s = get_equi_data(equi_id)
	var bbstr = str("[color=#", s["display_color"], "]", s["name"], "[/color]")
	return bbstr

func get_role_update_data(job_division_id):
	var res = {}
	for info in all_static_data["role_update"]:
		if info["id"] == job_division_id: return info
	return res

func get_skill_bonus_attr(skill_id: int) -> Array:
	var res = []
	for i in all_static_data.get("skill_bonus", []):
		if i.get("skill_id", 0) == skill_id:
			res.append(i)
		pass
	return res

func get_articles_item_type(bag_item_data):
	if bag_item_data.has("articles_data_id"):
		return 5
	if bag_item_data.has("pet_race_id"):
		return 2
	if bag_item_data.has("equi_data_id"):
		return 3
	if bag_item_data.has("gemstone_id"):
		return 4
	return 1
func get_popularity_color(p):
	if p >= - 50 and p < 0:
		return Color(210 / 255.0, 105 / 255.0, 30 / 255.0, 1);
	elif p >= - 100 and p < - 50:
		return Color(255 / 255.0, 69 / 255.0, 0 / 255.0, 1);
	elif p <= - 100:
		return Color(1, 0, 0, 1);
	elif p > 0 and p <= 50:
		return Color(144 / 255.0, 238 / 255.0, 144 / 255.0, 1);
	elif p > 50 and p < 100:
		return Color(0, 1, 0.5, 1);
	elif p >= 100:
		return Color(0, 1, 1, 1);
	else:
		return Color(1, 1, 1, 1);
	pass
func get_popularity_txt(p):
	if p >= - 50 and p < 0:
		return "[歹徒]"
	elif p >= - 100 and p < - 50:
		return "[恶霸]"
	elif p <= - 100:
		return "[魔头]"
	elif p > 0 and p <= 50:
		return "[侠士]"
	elif p > 50 and p < 100:
		return "[勇士]"
	elif p >= 100:
		return "[英雄]"
	else:
		return ""
	pass

func calculat_role_exp(lv):
	var d = 106.0 + 100 - lv
	var a = pow(1.1256, lv)
	return round(d * a)


func calculat_pet_exp(lv):
	var d = 106.0
	var a = pow(1.1146, lv)
	return round(a * d)



func articls_has_overlay(articles_id):
	return get_article_data(articles_id).get("overlay", 0) == 1

func get_prop_item_type(data):
	if data.has("gemstone_id"):
		return 4
	elif data.has("equi_data_id"):
		return 3
	elif data.has("articles_data_id"):
		return 5
	return 0

func show_art_data_info(static_data):
	if static_data == null: return
	var dis_color = static_data["display_color"]
	if dis_color == "000000": dis_color = "FFFFFF"
	var na = str("物品名称:[color=#%s]%s[/color]" % [dis_color, static_data["name"]], "\n")
	var lv = str("物品等级:LV%s" % static_data["level"], "\n")
	var desc = str("物品描述:\n[color=green]", static_data["desc"])
	Global.get("ScreenUtils").show_message_plus(str(na, lv, desc))
