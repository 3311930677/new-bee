extends Control

onready var level = $TextureRect / HBoxContainer / Level
onready var name_ = $TextureRect / HBoxContainer / ScrollContainer / TitleContainer / Name
onready var num = $TextureRect / HBoxContainer / Num


onready var bg = $TextureRect


onready var coin_num = $TextureRect / HBoxContainer / ScrollContainer2 / Coins / YinLiang

onready var coin_tex = $TextureRect / HBoxContainer / ScrollContainer2 / Coins / TextureRect

signal item_click(node)

var light_tex = null

var coupons_res = load("res://src/tscn/ui/common/tres/yuanbao.tres")
var gold_coin_res = load("res://src/tscn/ui/common/tres/yinliang.tres")
var sliver_coin_res = load("res://src/tscn/ui/common/tres/yinpiao.tres")

var data
var static_data = null

func _init():
	light_tex = Global.get("AssetsManage").get_ligth_tex()


func set_data(data):
	self.data = data
	reload()
	if data["type"] == 4:
		static_data = Global.get("StaticGameData").get_gem_data(data["static_id"])
	elif data["type"] == 5:
		static_data = Global.get("StaticGameData").get_article_data(data["static_id"])
	

func reload():
	bg.texture = null
	name_.text = data.get("good_name", "").substr(1)
	num.text = str("x", data.get("num", 1))
	level.text = str("LV", data.get("level", 1))
	
	coin_num.text = str(data.get("coin_num", 0))
	match int(data.get("coin_type", 1)):
		1:
			coin_tex.texture = coupons_res
			pass
		2:
			coin_tex.texture = gold_coin_res
			pass
		3:
			coin_tex.texture = sliver_coin_res
			pass
		_:
			coin_tex.texture = coupons_res
	
	if int(data.get("num", 0)) == 0:
		queue_free()
	else:
		set_color(data.get("display_color", "ffffff"))

func set_color(hexColor = "FFFFFF"):
	level["custom_colors/font_color"] = Color(str("#", hexColor))
	name_["custom_colors/font_color"] = Color(str("#", hexColor))

	pass

func unckecked():
	if bg != null:
		bg.texture = null
	pass

func _on_TextureButton_pressed() -> void :
	var arr_props = Global.get_nodes_in_group("trade_item")
	for item in arr_props:
		if item != self:
			item.unckecked();
	bg.texture = light_tex
	emit_signal("item_click", self)
func get_details():
	return static_data
