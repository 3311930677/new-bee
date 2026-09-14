extends TextureRect

signal item_click

export (bool) var show_num = true


onready var level = $HBoxContainer / Level
onready var name_ = $HBoxContainer / ScrollContainer / HBoxContainer / Name
onready var num = $Num

var ScreenUtils
var BagInfoManage
var StaticGameData
var AssetsManage

var data
var static_data
var light_tex = null
var type = 5

func _ready() -> void :
	AssetsManage = Global.get("AssetsManage")
	
	light_tex = load(str(AssetsManage.get_prefix(), "assets/res/light.png"))
	
	ScreenUtils = Global.get("ScreenUtils")
	BagInfoManage = Global.get("BagInfoManage")
	StaticGameData = Global.get("StaticGameData")
	if not show_num: num.visible = false
	BagInfoManage.connect("_bag_data_num_change_", self, "_on_reload_data")
	set_all_color(Global.get("GameData").colors["purple"])


func _on_reload_data():
	var bind = StaticGameData.get_bind_text_format(data.get("bind", 0))
	var num_ = data.get("count", 1)
	var is_mar_bool = false
	if num_ <= 0:
		queue_free()
		return
	num.text = str("x", num_)
	
	if data.has("gemstone_id"):
		
		data["item_type"] = 4
		static_data = StaticGameData.get_gem_data(data["gemstone_id"])
		name_.text = str(bind, static_data["name"])
		pass
	elif data.has("equi_data_id"):
		data["item_type"] = 3
		static_data = StaticGameData.get_equi_data(data["equi_data_id"])
		var countermark = StaticGameData.get_countermark_text_format(data["countermark"])
		
		
		var consolidate_level = data["consolidate_level"]
		var con_level_text = ""
		if consolidate_level > 0: con_level_text = str("+", consolidate_level)
		
		var punch_num = data["punch"]
		var punch_text = ""
		if punch_num > 0:
			punch_text = str("[", punch_num, "]")
		
		
		
		var is_mar = ""
		if data["is_mar"] == 1:
			is_mar = str("[", "损坏", "]")
			is_mar_bool = true
		else:
			is_mar_bool = false
		
		var job_name = StaticGameData.get_euqi_job_text_format(data["equi_data_id"])
		
		if countermark.length() <= 1:
			name_.text = str(job_name, bind, static_data["name"], "  ", con_level_text, punch_text, is_mar)
		else:
			name_.text = str(job_name, countermark, static_data["name"], "  ", con_level_text, punch_text, is_mar)
		
		pass
	elif data.has("articles_data_id"):
		data["item_type"] = 5
		
		static_data = StaticGameData.get_article_data(data["articles_data_id"])
		name_.text = str(bind, static_data["name"])
		pass
	
	level.text = str("LV", static_data["level"])
	if is_mar_bool:
		set_all_color(Color(0.7, 0.7, 0.7, 1))
		pass
	else:
		set_all_color(Color(str("#", static_data["display_color"])))
	
	if data.get("count", 1) <= 0:
		queue_free()



func _on_TextureButton_pressed() -> void :
	var arr_props = Global.get_nodes_in_group("prop_label_item")
	for item in arr_props:
		if item != self:
			item.unckecked();
	checked()

func set_data(data):
	self.data = data
	_on_reload_data()

func checked():
	texture = light_tex
	emit_signal("item_click", self)

func set_all_color(color):
	name_["custom_colors/font_color"] = color
	level["custom_colors/font_color"] = color
	pass

func unckecked():
	texture = null


func get_type():
	if data.has("gemstone_id"):
		return 4
	elif data.has("equi_data_id"):
		return 3
	elif data.has("articles_data_id"):
		return 5
	return 0

func get_art_type():
	return int(static_data["type"])
func get_details():
	return static_data
func is_overlay():
	if data.get("count", 1) > 1: return true
	return static_data.get("overlay", 0) == 1
