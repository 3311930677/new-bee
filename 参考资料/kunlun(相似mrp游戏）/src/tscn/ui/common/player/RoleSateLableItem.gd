extends TextureRect

signal item_click


var light_tex = null
var AssetsManage


var _key_values
var _data
var open_switch = false

var static_key = {
	"supply_pack": 1, 
	"enemy_magic_card": 2, 
	"exorcism_card": 3, 
	"thyme_magic_weed": 4, 
	"magic_bell_magic_grass": 5, 
	"double_experience_potion": 6, 
}

func _init():
	AssetsManage = Global.get("AssetsManage")
	light_tex = AssetsManage.get_ligth_tex()

func set_data(key_value, data):
	_key_values = key_value
	_data = data
	var long_time = data[_key_values["key"]]
	var ss_tr = str(_key_values["value"], ":")
	
	if long_time <= 0:
		$Label2.text = ""
		if _key_values["key"] == "supply_pack":
			if (long_time <= - 1):
				ss_tr = str(ss_tr, "未开启")
				open_switch = false
				set_color_gay()
			else:
				ss_tr = str(ss_tr, _data["supply_pack"])
				if _data["supply_pack_switch"]:
					open()
					pass
				else:
					close()
					pass
		else:
			ss_tr = str(ss_tr, "未开启")
			open_switch = false
			set_color_gay()
	else:
		
		if _key_values["key"] != "supply_pack":
			var start_time = data[str("start_", _key_values["key"])]
			var fen = int(long_time / 1000 / 60)
			if start_time <= 0:
				close()
				pass
			else:
				open()
				
				var end_time = OS.get_system_time_msecs()
				var small_time = end_time - start_time
				fen -= small_time / 1000 / 60
				pass
			if fen <= 0:
				ss_tr = str(ss_tr, "未开启")
				open_switch = false
				set_color_gay()
			else:
				ss_tr = str(ss_tr, int(fen), "分钟")
		else:
			ss_tr = str(ss_tr, _data["supply_pack"])
			if _data["supply_pack_switch"]:
				open()
				pass
			else:
				close()
				pass
	$Label.text = ss_tr
	pass


func set_color_gay():
	$Label["custom_colors/font_color"] = Color(0.5, 0.5, 0.5, 1.0)
	pass

func set_color_switch_red():
	$Label2["custom_colors/font_color"] = Color(1.0, 0, 0, 1.0)
	pass

func set_color_Switch_green():
	$Label2["custom_colors/font_color"] = Color(0, 1.0, 0, 1.0)
	pass

func _on_TextureButton_pressed() -> void :
	var arr_lib_labels = Global.get_nodes_in_group("role_stat_lable_item")
	for item in arr_lib_labels:
		if item != self:
			item.unchecked()
	checked()


func checked():
	self.texture = light_tex
	emit_signal("item_click", self)
	pass

func unchecked():
	self.texture = null
	pass


func open(init = false):
	$Label2.text = "(开)"
	open_switch = true
	set_color_Switch_green()
	if init: Global.get("RoleInfoManage").op_role_state(static_key[_key_values["key"]], open_switch)
	pass


func close(init = false):
	$Label2.text = "(关)"
	open_switch = false
	set_color_switch_red()
	if init: Global.get("RoleInfoManage").op_role_state(static_key[_key_values["key"]], open_switch)
	pass
