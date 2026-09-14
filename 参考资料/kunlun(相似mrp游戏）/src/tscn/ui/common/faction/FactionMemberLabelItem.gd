extends Control
signal item_click

export (Color) var test_color = Color(0, 0, 0, 1)
export (int) var leader_type = - 1
onready var name_ = $ScrollContainer2 / HBoxContainer / Name
onready var time_left = $TimeLeft


var str_icon_template = ""
var light_tex = null

var StaticGameData

func _ready() -> void :
	
	StaticGameData = Global.get("StaticGameData")
	light_tex = Global.get("AssetsManage").get_ligth_tex()
	str_icon_template = str(Global.get("AssetsManage").get_prefix(), "assets/res/cd_bp0%d.png")
	
	set_all_color(test_color)
	var dic_data = get_meta("data")
	if dic_data == null: return
	
	leader_type = dic_data.get("member_type", 3)
	
	if leader_type == 0: $FactionIcon.texture = load(str_icon_template % 1)
	elif leader_type == 1: $FactionIcon.texture = load(str_icon_template % 2)
	elif leader_type == 2: $FactionIcon.texture = load(str_icon_template % 3)
	else: $FactionIcon.texture = null
	
	
	var role_name = dic_data.get("role", {}).get("role_name", "默认昵称")
	var role_level = dic_data["role"]["level"]
	var zhiye = StaticGameData.equi_job_name[str(dic_data["role"]["job_id"], dic_data["role"]["division_id"])]
	
	name_.text = str("[LV%d][%s]%s" % [role_level, zhiye, role_name])
	

func _on_TextureButton_pressed() -> void :
	var arr_skill_labels = Global.get_nodes_in_group("faction_member_label_item")
	for item in arr_skill_labels:
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

func set_all_color(color):
	name_["custom_colors/font_color"] = color
	time_left["custom_colors/font_color"] = color
	pass
