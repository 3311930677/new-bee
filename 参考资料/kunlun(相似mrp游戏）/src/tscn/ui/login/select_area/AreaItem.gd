extends Control

onready var bg = $NinePatchRect
onready var s_name = $Name
onready var heads = [
	$Control / Head1, 
	$Control / Head2, 
	$Control / Head3, 
]
signal item_click

export (String) var server_name = "默认服务器"

var light_res = load("res://src/tscn/ui/login/select_area/nine_patch_btn_pressed.tres")
var normal_res = load("res://src/tscn/ui/login/select_area/nine_patch_btn_normal.tres")


var str_head_light_template = ""


var data

func _init():
	var AssetsManage = Global.get("AssetsManage")
	str_head_light_template = str(AssetsManage.get_prefix(), "assets/res/%d.png")

func _ready() -> void :
	s_name.text = server_name
	for i in heads:
		i.hide()

func _on_TextureButton_pressed() -> void :
	var arr_server = Global.get_nodes_in_group("server_items")
	for item in arr_server:
		item.unchecked()
	checked()

func checked():
	bg.texture = light_res
	emit_signal("item_click", self)

func unchecked():
	bg.texture = normal_res


func set_server_name(ns: String):
	s_name.text = ns

func show_head_count(count):
	for i in count:
		if i < heads.size():
			heads[i].show()
	pass

func set_data(data):
	self.data = data
	set_server_name(data["name"])
	pass
