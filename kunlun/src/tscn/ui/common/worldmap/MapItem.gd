extends Control

signal item_click


export (String) var icon_name = "1A"
export (String) var map_name = "太虚之峰"
export (bool) var checked = false
export (bool) var current = false
export (int) var city_id = - 1

onready var name_ = $WorldName
onready var icon = $TextureRect
onready var current_tex = $CurrentMap

var str_icon_template = ""
var str_icon_black_template = ""

var checked_res
var unchecked_res

func _init():
	var AssetsManage = Global.get("AssetsManage")
	str_icon_template = str(AssetsManage.get_prefix(), "assets/res/mini/%s.png")
	str_icon_black_template = str(AssetsManage.get_prefix(), "assets/res/mini/%s_F.png")

func _ready() -> void :
	load_res()
	$AnimationPlayer.play("idel")
	
	if Global.get("MapInfoManage").get_current_map_city() == city_id:
		$CurrentMap.show()
		checked()
	else:
		$CurrentMap.hide()

func _on_TextureButton_pressed() -> void :
	var arr_world_item_labels = Global.get_nodes_in_group("world_map_label_item")
	for item in arr_world_item_labels:
		if item != self:
			item.unchecked()
	checked()


func checked():
	icon.texture = checked_res
	name_["custom_colors/font_color"] = Color(1, 0, 0, 1)
	emit_signal("item_click", self)

func unchecked():
	icon.texture = unchecked_res
	name_["custom_colors/font_color"] = Color(255 / 255.0, 224 / 255.0, 138 / 255.0, 1)

func load_res():
	checked_res = load(str_icon_template % icon_name)
	unchecked_res = load(str_icon_black_template % icon_name)
	name_.text = map_name
	if checked: icon.texture = checked_res
	else: icon.texture = unchecked_res
	if not current: current_tex.hide()
	else: current_tex.show()
