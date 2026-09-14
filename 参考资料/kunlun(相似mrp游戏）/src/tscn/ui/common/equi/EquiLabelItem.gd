extends TextureRect

signal item_click

export (String) var equi_type = "药囊"
export (String) var test_name = "LV1 [绑定]无敌药囊"
export (Color) var test_color = Color(1, 0, 0, 1)
export (int) var wear_index = 0
export (NodePath) var call_node = null

onready var name_ = $ScrollContainer / HBoxContainer / Name

var AssetsManage

var light_tex = null

var RoleInfoManage
var StaticGameData
var equi_data
var static_data


var static_dic_data = {
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
	"12": "补给包"
}

func _ready() -> void :
	AssetsManage = Global.get("AssetsManage")
	light_tex = AssetsManage.get_ligth_tex()
	
	$ScrollContainer / HBoxContainer / EquiType.text = equi_type
	name_.text = test_name
	set_all_color(test_color)
	RoleInfoManage = Global.get("RoleInfoManage")
	StaticGameData = Global.get("StaticGameData")
	RoleInfoManage.connect("role_info_result", self, "_on_role_info_result")
	if static_dic_data.has(str(wear_index)):
		$ScrollContainer / HBoxContainer / EquiType.text = str(static_dic_data[str(wear_index)], ":")


func _on_TextureButton_pressed() -> void :
	var arr_equi_label = Global.get_nodes_in_group("equi_label_item")
	for item in arr_equi_label:
		if item != self:
			item.unchecked();
	checked()
	if call_node != null:
		get_node(call_node).other_click()


func other_click():
	var arr_equi_label = Global.get_nodes_in_group("equi_label_item")
	for item in arr_equi_label:
		if item != self:
			item.unchecked();
	checked()
	pass

func set_all_color(color):
	name_["custom_colors/font_color"] = color

func checked():
	self.texture = light_tex
	emit_signal("item_click", self)

func unchecked():
	self.texture = null
func has_wear(equs) -> bool:
	var flag = false
	for it in equs:
		static_data = StaticGameData.get_equi_data(it["equi_data_id"])
		if int(static_data["wear_index"]) == wear_index:
			equi_data = it
			return true
	return false
func _on_role_info_result(data):

	var equs = data.get("equipment_holds", [])
	
	if not has_wear(equs):
		none()
		return
	
	var str_name = "LV"
	
	var hex_color = static_data["display_color"]
	
	
	var menpai = Global.get("StaticGameData").get_euqi_job_all_text_format(equi_data["equi_data_id"])
	
	var bind = ""
	if equi_data["countermark"] > 0:
		bind = Global.get("StaticGameData").get_countermark_text_format(equi_data["countermark"])
	else:
		bind = Global.get("StaticGameData").get_bind_text_format(equi_data["bind"])
	
	
	var qianghua = ""
	if equi_data["consolidate_level"] > 0:
		qianghua = str("+", equi_data["consolidate_level"])
	
	var kong = ""
	if equi_data["punch"] > 0:
		kong = str("[", equi_data["punch"], "]")
	
	str_name = str(str_name, static_data["level"])
	str_name = str(str_name, bind, menpai, static_data["name"], " ", qianghua, kong)
	
	if call_node != null:
		var icon_node = get_node(call_node)
		icon_node.show_icon(hex_color)
	if data.role.potential_equ_id == equi_data.id:
		str_name = str(str_name, "[练潜]")
	name_.text = str_name
	set_all_color(Color(str("#", hex_color)))
	
	pass


func none():
	name_.text = "无"
	equi_data = null
	set_all_color(Color(0.7, 0.7, 0.7, 1))
	if call_node != null:
		var icon_node = get_node(call_node)
		icon_node.gray()
	pass
