extends TextureRect


signal item_click

onready var level = $Level
onready var name_ = $ScrollContainer / HBoxContainer / Name
onready var cost = $ScrollContainer2 / HBoxContainer2 / Num
onready var tex = $"ScrollContainer2/HBoxContainer2/TextureRect"

var light_tex = null
var yinliang_res = load("res://src/tscn/ui/common/tres/yinliang.tres")
var yinpiao_res = load("res://src/tscn/ui/common/tres/yinpiao.tres")
var yuanbao_res = load("res://src/tscn/ui/common/tres/yuanbao.tres")
var meritorious_res = load("res://src/tscn/ui/common/tres/gongxun.tres")
var StaticGameData
var BagInfoManage
var ShopInfoManage
var AssetsManage

var static_data
var cosin_type
var data
var buy_num

func checked():
	texture = light_tex
	emit_signal("item_click", self)

func set_all_color_str(color_str):
	set_all_color(Color(str("#", color_str)))
func set_all_color(color):
	level["custom_colors/font_color"] = color
	name_["custom_colors/font_color"] = color
	pass

func unckecked():
	texture = null

func _ready() -> void :
	AssetsManage = Global.get("AssetsManage")
	StaticGameData = Global.get("StaticGameData")
	BagInfoManage = Global.get("BagInfoManage")
	ShopInfoManage = Global.get("ShopInfoManage")
	
	
	light_tex = AssetsManage.get_ligth_tex()
	
	set_all_color(Global.get("GameData").colors["purple"])


func _on_TextureButton_pressed() -> void :
	var arr_props = Global.get_nodes_in_group("shop_label_item")
	for item in arr_props:
		if item != self:
			item.unckecked();
		checked()

func set_data(data):
	self.data = data
	cost.text = str(data["cost"])
	set_cost_tex(data)
	var art_name = ""
	
	match int(data["good_data_type"]):
		3:
			static_data = StaticGameData.get_equi_data(data["good_data_id"])
			
			art_name = StaticGameData.get_euqi_job_text_format(static_data["id"])
			pass
		4:
			static_data = StaticGameData.get_gem_data(data["good_data_id"])
			pass
		5:
			static_data = StaticGameData.get_article_data(data["good_data_id"])
			pass
	var bind = StaticGameData.get_bind_text_format(data["bind"])
	level.text = str("LV", static_data.get("level", "1"))
	name_.text = str(bind, art_name, static_data.get("name", "物品名称"))
	set_all_color_str(static_data.get("display_color", "000000"))

func set_cost_tex(data):
	cosin_type = int(data["mall_type"])
	match cosin_type:
		1:
			tex.texture = yinliang_res
			pass
		2:
			tex.texture = yinpiao_res
		3:
			tex.texture = yuanbao_res
		4:
			tex.texture = meritorious_res

func get_details():
	return static_data

func is_overlay():
	
	if static_data.get("overlay", - 1) == 1: return true
	
	if data["good_data_type"] == ShopInfoManage.GEM: return true
	return false


func check_coins(num):
	buy_num = num
	var cost = int(data["cost"]) * num
	match cosin_type:
		1:
			return BagInfoManage.get_coins() >= cost
		2:
			return BagInfoManage.get_silver_coins() >= cost
		3:
			return BagInfoManage.get_coupons() >= cost
		4:
			return BagInfoManage.get_meritorious() >= cost
	return true

func buy_successed():
	pass







