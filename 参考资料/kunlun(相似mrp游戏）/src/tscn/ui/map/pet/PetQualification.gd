extends Panel

var data
var static_data

func set_data(data):
	self.data = data
	static_data = Global.get("StaticGameData").get_pet_data(data["petHold"]["pet_race_id"])
	var qual = data["qual"]
	$"Background/Background2/ScrollContainer/VBoxContainer/Label1".text = str("生命资质：%d/%d" % [qual["hp_qual"], static_data["hp_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label2".text = str("魔法资质：%d/%d" % [qual["mp_qual"], static_data["mp_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label3".text = str("物攻资质：%d/%d" % [qual["p_atk_qual"], static_data["p_atk_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label4".text = str("法攻资质：%d/%d" % [qual["l_atk_qual"], static_data["l_atk_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label5".text = str("物防资质：%d/%d" % [qual["p_def_qual"], static_data["p_def_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label6".text = str("法防资质：%d/%d" % [qual["l_def_qual"], static_data["l_def_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label7".text = str("暴击资质：%d/%d" % [qual["crit_qual"], static_data["crit_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label8".text = str("闪避资质：%d/%d" % [qual["hedge_qual"], static_data["hedge_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label9".text = str("速度资质：%d/%d" % [qual["speed_qual"], static_data["speed_qual"]])
	$"Background/Background2/ScrollContainer/VBoxContainer/Label10".text = str("命中资质：%d/%d" % [qual["hit_qual"], static_data["hit_qual"]])
	pass
