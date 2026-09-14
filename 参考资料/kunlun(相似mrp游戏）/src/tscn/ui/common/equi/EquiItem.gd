extends Control

signal item_click

export (bool) var checked = false
export (int) var icon_index = 1
export (int) var wear_index = 1
export (NodePath) var call_node = null


var AssetsManage


var icon_str_template = ""
var icon_f_str_template = ""

var checked_res = null


func _ready() -> void :
	AssetsManage = Global.get("AssetsManage")
	
	icon_str_template = str(AssetsManage.get_prefix(), "assets/res/equi/%d.png")
	icon_f_str_template = str(AssetsManage.get_prefix(), "assets/res/equi/%d_f.png")
	checked_res = load(str(AssetsManage.get_prefix(), "assets/res/checked.png"))
	
	
	if not checked: $CheckedTex.texture = null
	$PropIcon.texture = load(icon_str_template % icon_index)
	

func checked():
	$CheckedTex.texture = checked_res
	emit_signal("item_click", self)
	

func unckecked():
	$CheckedTex.texture = null

func _on_TextureButton_pressed() -> void :
	var arr_icons = Global.get_nodes_in_group("equi_icon_item")
	for item in arr_icons:
		if item != self:
			item.unckecked()
	checked()
	
	if call_node != null:
		get_node(call_node).other_click()


func other_click():
	var arr_icons = Global.get_nodes_in_group("equi_icon_item")
	for item in arr_icons:
		if item != self:
			item.unckecked()
	checked()
	pass

func gray():
	$Bg.hide()
	$PropIcon.hide()
	pass


func show_icon(hex_color):
	if hex_color == "000000": hex_color = "778899"
	
	$Bg.color = Color(str("#", hex_color))
	$Bg.show()
	$PropIcon.show()
	
	pass
