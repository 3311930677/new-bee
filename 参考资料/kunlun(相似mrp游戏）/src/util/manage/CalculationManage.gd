extends Node
class_name CalculationManage



var NetContext
var StaticGameData

var Config = {
	"hp": "hp", 
	"Mp": "mp", 
	"max_hp": "max_hp", 
	"max_mp": "max_mp", 
	"physical_atk": "physical_atk", 
	"law_atk": "law_atk", 
	"physical_def": "physical_def", 
	"law_def": "law_def", 
	"hit": "hit", 
	"dodge": "dodge", 
	"bash": "bash", 
	"crit": "crit", 
	"shot_speed": "shot_speed", 
	"power": "power", 
	"intelligence": "intelligence", 
	"agile": "agile", 
	"endurance": "endurance", 
	"spirit": "spirit", 
}

var GameConfig = {
	"pet_basic_exp": 106.0, 
	"pet_up_exp_percent": 1.1146, 
	"role_basic_exp": 106.0, 
	"role_up_exp_percent": 1.1256, 
}


var petConfig = {
	"p_atk_percent": 250.0, 
	"l_atk_percent": 250.0, 
	"max_hp_percent": 40.0, 
	"max_mp_percent": 85.0, 
	"p_def_percent": 360.0, 
	"l_def_percent": 360.0, 
	"cir_percent": 540.0, 
	"dodge_percent": 300.0, 
	"speed_percent": 165.0, 
	"hit_percent": 180.0, 
	"power": 280, 
	"intelligence": 280, 
	"agile": 165, 
	"endurance": 250, 
	"spirit": 250
}

var potentialConfig = {
	"max_hp": 30.0, 
	"max_mp": 5.4, 
	"hit": 8.1, 
	"physical_def": 10.0, 
	"law_def": 10.0, 
	"physical_atk": 5.5, 
	"law_atk": 5.5, 
	"dodge": 8.1, 
	"crit": 10.5, 
	"shot_speed": 14.2, 
}
var basics = ["power", "intelligence", "agile", "endurance", "spirit"]
var consolidate_percent = [0.08, 0.11, 0.12, 0.13, 0.14, 0.14, 0.14, 0.15, 0.15, 0.15, 0.15, 0.16, 0.16, 0.16, 0.16]
var counter_mark_percent = 1.3

func _init():
	NetContext = Global.get("NetContext")
	StaticGameData = Global.get("StaticGameData")

func calculate_role(role_all_data: Dictionary) -> Dictionary:
	
	var attribute = get_role_rttribute(role_all_data["role"]["job_id"] * 10 + role_all_data["role"]["division_id"], role_all_data["role"]["level"])
	var equ_attribute = get_equipment_attribute(role_all_data.get("equipment_holds", []))
	var skill_attribute = get_role_skill_attribute(role_all_data.get("skills", []))
	attr_add_attr(attribute, equ_attribute)
	attr_add_attr(attribute, skill_attribute)
	
	var normal = basic_attr_convert_normal_attr(attribute["basic"])
	normal_add_attr(attribute["normal"], normal)
	attribute["hp"] = role_all_data["role"]["hp"]
	attribute["mp"] = role_all_data["role"]["mp"]
	attribute["exp"] = role_all_data["role"]["exp"]
	return attribute


func caculate_pet(pet_details):
	var attribute = get_pet_attribute(pet_details["qual"], pet_details["petHold"], pet_details["petAddPoint"])
	var normal = basic_attr_convert_normal_attr(attribute["basic"])
	normal_add_attr(attribute["normal"], normal)
	attribute["hp"] = pet_details["petHold"]["hp"]
	attribute["mp"] = pet_details["petHold"]["mp"]
	attribute["exp"] = pet_details["petHold"]["exp"]
	return attribute


func calculate_pet_level_exp(level: int) -> int:
	var exp_ = GameConfig.pet_basic_exp
	var pow_ = pow(GameConfig.pet_up_exp_percent, level)
	return int(round((exp_ + 100 - level) * pow_))


func calculate_role_level_exp(level: int) -> int:
	var exp_ = GameConfig.role_basic_exp + 100 - level;
	var pow_ = pow(GameConfig.role_up_exp_percent, level);
	return int(exp_ * pow_)






func get_pet_attribute(pet_qualification: Dictionary, pet_hold: Dictionary, pet_add_point: Dictionary) -> Dictionary:
	
	var attribute = {
		"hp": pet_hold.get("hp", 0), 
		"mp": pet_hold.get("mp", 0)
	}
	var normal_attribute = {}
	var basic_attribute = {}
	var level = pet_hold.get("level", 0)
	var percent = pet_hold.get("growing_up", 0) / 1000.0 * pet_hold.get("level", 0)
	
	normal_attribute[Config.max_hp] = round(pet_qualification["hp_qual"] / petConfig.max_hp_percent * percent)
	normal_attribute[Config.max_mp] = round(pet_qualification["mp_qual"] / petConfig.max_mp_percent * percent)
	normal_attribute[Config.physical_atk] = round(pet_qualification["p_atk_qual"] / petConfig.p_atk_percent * percent)
	normal_attribute[Config.law_atk] = round(pet_qualification["l_atk_qual"] / petConfig.l_atk_percent * percent)
	normal_attribute[Config.physical_def] = round(pet_qualification["p_def_qual"] / petConfig.p_def_percent * percent)
	normal_attribute[Config.law_def] = round(pet_qualification["l_def_qual"] / petConfig.l_def_percent * percent)
	normal_attribute[Config.hit] = round(pet_qualification["hit_qual"] / petConfig.hit_percent * percent)
	normal_attribute[Config.dodge] = round(pet_qualification["hedge_qual"] / petConfig.dodge_percent * percent)
	normal_attribute[Config.bash] = round(pet_qualification["crit_qual"] / petConfig.cir_percent * percent)
	normal_attribute[Config.shot_speed] = round(pet_qualification["speed_qual"] / petConfig.speed_percent * percent)
	
	
	basic_attribute[Config.power] = round(pet_qualification["p_atk_qual"] / petConfig.power + level);
	basic_attribute[Config.intelligence] = round(pet_qualification["l_atk_qual"] / petConfig.intelligence + level);
	basic_attribute[Config.agile] = round(pet_qualification["speed_qual"] / petConfig.agile + level);
	basic_attribute[Config.endurance] = round(pet_qualification["hp_qual"] / petConfig.endurance + level);
	basic_attribute[Config.spirit] = round(pet_qualification["mp_qual"] / petConfig.spirit + level);
	
	attribute["normal"] = normal_attribute
	attribute["basic"] = basic_attribute
	
	
	basic_add_attr(basic_attribute, pet_add_point)
	
	return attribute


func get_role_rttribute(job_division_id: int, role_level: int) -> Dictionary:
	var attribute = {}
	var normal_attribute = {}
	var basic_attribute = {}
	
	var update_attribute_data = StaticGameData.get_role_update_data(job_division_id)
	
	basic_attribute[Config.power] = round(update_attribute_data[Config.power] * role_level)
	basic_attribute[Config.intelligence] = round(update_attribute_data[Config.intelligence] * role_level)
	basic_attribute[Config.agile] = round(update_attribute_data[Config.agile] * role_level)
	basic_attribute[Config.endurance] = round(update_attribute_data[Config.endurance] * role_level)
	basic_attribute[Config.spirit] = round(update_attribute_data[Config.spirit] * role_level)
	
	normal_attribute[Config.max_hp] = round(update_attribute_data[Config.max_hp] * role_level)
	normal_attribute[Config.max_mp] = round(update_attribute_data[Config.max_mp] * role_level)
	normal_attribute[Config.physical_atk] = round(update_attribute_data[Config.physical_atk] * role_level)
	normal_attribute[Config.law_atk] = round(update_attribute_data[Config.law_atk] * role_level)
	normal_attribute[Config.physical_def] = round(update_attribute_data[Config.physical_def] * role_level)
	normal_attribute[Config.law_def] = round(update_attribute_data[Config.law_def] * role_level)
	normal_attribute[Config.hit] = round(update_attribute_data[Config.hit] * role_level)
	normal_attribute[Config.dodge] = round(update_attribute_data[Config.dodge] * role_level)
	normal_attribute[Config.bash] = round(update_attribute_data[Config.crit] * role_level)
	normal_attribute[Config.shot_speed] = round(update_attribute_data[Config.shot_speed] * role_level)
	
	attribute["normal"] = normal_attribute
	attribute["basic"] = basic_attribute
	
	return attribute


func get_role_skill_attribute(list_skill_id: Array) -> Dictionary:
	var attribute = {}
	var normal_attribute = {}
	var basic_attribute = {}
	
	
	var skill_bonus_arr = []
	
	for sid in list_skill_id:
		skill_bonus_arr.append_array(StaticGameData.get_skill_bonus_attr(sid))
	for sba in skill_bonus_arr:
		basic_attribute[sba.attr_name] = basic_attribute.get(sba.attr_name, 0) + sba["fixed_value"]
		normal_attribute[sba.attr_name] = normal_attribute.get(sba.attr_name, 0) + sba["fixed_value"]
	attribute["normal"] = normal_attribute
	attribute["basic"] = basic_attribute
	return attribute


func get_equipment_attribute(list_equ_hold: Array) -> Dictionary:

	var attribute = {}
	var normal_attribute = {}
	var basic_attribute = {}
	attribute["normal"] = normal_attribute
	attribute["basic"] = basic_attribute
	for item in list_equ_hold:
		var temp_attribute = calculation_euqipment(item)
		attr_add_attr(attribute, temp_attribute)
	return attribute

func calculation_euqipment(equipment_hold) -> Dictionary:
	var equ_data = StaticGameData.get_equi_data(equipment_hold["equi_data_id"])
	
	
	var percent = 1.0
	
	if equipment_hold.get("countermark", 0) == 1:
		percent = 1.3
	if equipment_hold.get("consolidate_level", 0) > 0:
		for i in equipment_hold.get("consolidate_level", 0):
			percent += consolidate_percent[i]
	var attribute = {}
	var normal_attribute = {}
	var basic_attribute = {}
	attribute["normal"] = normal_attribute
	attribute["basic"] = basic_attribute
	
	
	normal_attribute[Config.max_hp] = round(equ_data[Config.max_hp] * percent)
	normal_attribute[Config.max_mp] = round(equ_data[Config.max_mp] * percent)
	normal_attribute[Config.physical_atk] = round(equ_data[Config.physical_atk] * percent)
	normal_attribute[Config.law_atk] = round(equ_data[Config.law_atk] * percent)
	normal_attribute[Config.physical_def] = round(equ_data[Config.physical_def] * percent)
	normal_attribute[Config.law_def] = round(equ_data[Config.law_def] * percent)
	normal_attribute[Config.hit] = round(equ_data[Config.hit] * percent)
	normal_attribute[Config.dodge] = round(equ_data[Config.dodge] * percent)
	normal_attribute[Config.bash] = round(equ_data[Config.crit] * percent)
	normal_attribute[Config.shot_speed] = round(equ_data[Config.shot_speed] * percent)
	
	
	for i in range(1, 6):
		var k = equipment_hold[str("additional_attr_", i)]
		if k != null and k.length() > 1:
			if basics.find(equipment_hold[str("additional_attr_", i)]) != - 1:
				basic_attribute[k] = equipment_hold[str("attr_value_", i)] + basic_attribute.get(k, 0)
			else:
				if equipment_hold[str("additional_attr_", i)] == "crit":
					equipment_hold[str("additional_attr_", i)] = "bash"
					pass
				normal_attribute[k] = equipment_hold[str("attr_value_", i)] + normal_attribute.get(k, 0)
	
	
	
	var gem_attrs = equipment_hold.get("equGemAttrs", [])
	var current_potential = equipment_hold.get("usr_potential", 0)
	
	if current_potential > 100:
		for gem_attr in gem_attrs:
			if current_potential <= 0: break
			
			gem_attr["cur_val"] = 0
			var p_v = potentialConfig.get(gem_attr["attr_name"], 1.0)
			var max_v = gem_attr["max_val"]
			var use_max = max_v / p_v * 100
			if current_potential >= use_max:
				gem_attr["cur_val"] = gem_attr["max_val"]
				current_potential -= use_max
			else:
				gem_attr["cur_val"] = current_potential / 100 * p_v
				current_potential = 0
			attr_add_name(attribute, gem_attr["attr_name"], int(gem_attr["cur_val"]))
			pass
	
	
	
	return attribute



func basic_attr_convert_normal_attr(basic: Dictionary) -> Dictionary:
	var normal_attribute = {}
	normal_attribute[Config.physical_atk] = round(basic.get(Config.power, 0) * 1.125)
	normal_attribute[Config.hit] = round(basic.get(Config.power, 0) * 1)
	
	normal_attribute[Config.law_atk] = round(basic.get(Config.intelligence, 0) * 1.125)
	normal_attribute[Config.bash] = round(basic.get(Config.intelligence, 0) * 1)
	
	normal_attribute[Config.shot_speed] = round(basic.get(Config.agile, 0) * 1.125)
	normal_attribute[Config.dodge] = round(basic.get(Config.agile, 0) * 0.5)
	
	normal_attribute[Config.max_hp] = round(basic.get(Config.endurance, 0) * 15)
	normal_attribute[Config.physical_def] = round(basic.get(Config.endurance, 0) * 1.125)
	normal_attribute[Config.law_def] = round(basic.get(Config.endurance, 0) * 1.125)
	
	normal_attribute[Config.max_hp] = round(basic.get(Config.spirit, 0) * 5 + normal_attribute.get(Config.max_hp, 0))
	normal_attribute[Config.max_mp] = round(basic.get(Config.spirit, 0) * 1.5)
	
	
	return normal_attribute


func basic_add_attr(dest: Dictionary, source: Dictionary) -> void :
	dest[Config.power] = source.get(Config.power, 0) + dest.get(Config.power, 0)
	dest[Config.intelligence] = source.get(Config.intelligence, 0) + dest.get(Config.intelligence, 0)
	dest[Config.agile] = source.get(Config.agile, 0) + dest.get(Config.agile, 0)
	dest[Config.endurance] = source.get(Config.endurance, 0) + dest.get(Config.endurance, 0)
	dest[Config.spirit] = source.get(Config.spirit, 0) + dest.get(Config.spirit, 0)
	pass

func normal_add_attr(dest: Dictionary, source: Dictionary) -> void :
	dest[Config.max_hp] = source.get(Config.max_hp, 0) + dest.get(Config.max_hp, 0)
	dest[Config.max_mp] = source.get(Config.max_mp, 0) + dest.get(Config.max_mp, 0)
	dest[Config.physical_atk] = source.get(Config.physical_atk, 0) + dest.get(Config.physical_atk, 0)
	dest[Config.law_atk] = source.get(Config.law_atk, 0) + dest.get(Config.law_atk, 0)
	dest[Config.physical_def] = source.get(Config.physical_def, 0) + dest.get(Config.physical_def, 0)
	dest[Config.law_def] = source.get(Config.law_def, 0) + dest.get(Config.law_def, 0)
	dest[Config.hit] = source.get(Config.hit, 0) + dest.get(Config.hit, 0)
	dest[Config.dodge] = source.get(Config.dodge, 0) + dest.get(Config.dodge, 0)
	dest[Config.bash] = source.get(Config.bash, 0) + dest.get(Config.bash, 0)
	dest[Config.shot_speed] = source.get(Config.shot_speed, 0) + dest.get(Config.shot_speed, 0)
	pass

func attr_add_attr(dest: Dictionary, source: Dictionary) -> void :
	basic_add_attr(dest.get("basic", {}), source.get("basic", {}))
	normal_add_attr(dest.get("normal", {}), source.get("normal", {}))
	pass

func attr_add_name(attribute: Dictionary, attr_name: String, attr_val: int):
	if attr_name == "crit": attr_name = "bash"
	if basics.find(attr_name) != - 1:
		var basic_attribute = attribute["basic"]
		basic_attribute[attr_name] = attr_val + basic_attribute.get(attr_name, 0)
	else:
		var normal_attribute = attribute["normal"]
		normal_attribute[attr_name] = attr_val + normal_attribute.get(attr_name, 0)
	pass
