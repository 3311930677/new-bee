extends Panel


var ScreenUtils
var RoleInfoManage
var StaticGameData
var CalculationManage
var source_data = null
func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	StaticGameData = Global.get("StaticGameData")
	CalculationManage = Global.get("CalculationManage")
	RoleInfoManage.connect("role_info_result", self, "_on_role_info_result")

func _on_role_info_result(data):
	source_data = data
	var box = $Background / Background2 / ScrollContainer / VBoxContainer
	
	
	var attribute = CalculationManage.calculate_role(data)
	
	var role_attribute = CalculationManage.get_role_rttribute(data["role"]["job_id"] * 10 + data["role"]["division_id"], data["role"]["level"])
	
	var equ_attribute = CalculationManage.get_equipment_attribute(data["equipment_holds"])
	
	var skill_attribute = CalculationManage.get_role_skill_attribute(data["skills"])
	var max_exp = CalculationManage.calculate_role_level_exp(data["role"]["level"])



	
	var equ_normal = CalculationManage.basic_attr_convert_normal_attr(equ_attribute["basic"])
	CalculationManage.normal_add_attr(equ_attribute["normal"], equ_normal)
	var skill_normal = CalculationManage.basic_attr_convert_normal_attr(skill_attribute["basic"])
	CalculationManage.normal_add_attr(skill_attribute["normal"], skill_normal)
	equ_normal = equ_attribute["normal"]
	skill_normal = skill_attribute["normal"]
	
	
	var index = 0
	var inspect_self = false
	var inspect_id = $"../../..".inspect_id
	if inspect_id == - 1:
		inspect_self = true
	else:
		hide_sj_btn()
	var basic_attribute = attribute["basic"]
	var normal_attribute = attribute["normal"]
	
	
	for k in attribute["basic"].keys():
		var rich_label = box.get_child(index)
		if rich_label == null: continue
		rich_label.clear()
		var num = basic_attribute[k]
		var pre = str("[color=black]%s:%d" % [StaticGameData.attr_name_data[k], round(num)])
		if inspect_self:
			var s_v = skill_attribute.get("basic", {}).get(k, 0)
			var e_v = equ_attribute.get("basic", {}).get(k, 0)
			if s_v > 0:
				pre = str(pre, "[color=green](+%d)" % round(s_v))
			if e_v > 0:
				pre = str(pre, "[color=#FFA500](+%d)" % round(e_v))
		rich_label.append_bbcode(pre)
		index += 1
	
	
	for k in attribute["normal"].keys():
		var rich_label = box.get_child(index)
		if rich_label == null: continue
		rich_label.clear()
		var num = normal_attribute[k]
		var pre = str("[color=black]%s:%d" % [StaticGameData.attr_name_data[k], round(num)])
		if inspect_self:
			var s_v = skill_normal.get(k, 0)
			var e_v = equ_normal.get(k, 0)
			if s_v > 0:
				pre = str(pre, "[color=green](+%d)" % round(s_v))
			if e_v > 0:
				pre = str(pre, "[color=#FFA500](+%d)" % round(e_v))
		index += 1
		rich_label.append_bbcode(pre)
	
	
	pass
	
	var hp_num = $"Panel2/HpC/Nums"
	var mp_num = $"Panel2/MpC/Nums"
	var exp_num = $"Panel2/ExpC/Nums"
	
	var hp_progress = $"Panel2/HpC/Hp"
	var mp_progress = $"Panel2/MpC/Mp"
	var exp_progress = $"Panel2/ExpC/Exp"
	
	
	hp_num.text = str(int(attribute["hp"]), "/", int(attribute["normal"]["max_hp"]))
	mp_num.text = str(int(attribute["mp"]), "/", int(attribute["normal"]["max_mp"]))
	exp_num.text = str(int(attribute["exp"]), "/", int(max_exp))
	
	hp_progress.value = int(attribute["hp"] * 1.0 / attribute["normal"]["max_hp"] * 100)
	mp_progress.value = int(attribute["mp"] * 1.0 / attribute["normal"]["max_mp"] * 100)
	exp_progress.value = int(attribute["exp"] * 1.0 / max_exp * 100)
	
	$"Panel2/Level".text = str("LV", data["role"]["level"])
	
	$Panel2 / DisplayRole.load_data(data["role"])
	
	if attribute["exp"] >= max_exp:
		$"Panel2/Button".disabled = false
	else:
		$"Panel2/Button".disabled = true


func hide_sj_btn():
	$"Panel2/Button".hide()


func _on_Button_pressed() -> void :
	
	if RoleInfoManage.get_role_division_id() != 0:
		RoleInfoManage.upgrade_role_level()
	else:
		ScreenUtils.show_message("你必须加入门派后才能继续升级")
