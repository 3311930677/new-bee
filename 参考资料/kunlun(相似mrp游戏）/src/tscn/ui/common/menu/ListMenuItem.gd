extends TextureRect

signal sigle_click
signal double_click

var light_res = null
var checked = false
var attach_data
var clickable = true


func _ready() -> void :
	light_res = Global.get("AssetsManage").get_ligth_tex()
	pass


func unchecked():
	self.texture = null
	checked = false

func checked():
	checked = true
	self.texture = light_res
	emit_signal("sigle_click", self)

func _on_TextureButton_pressed() -> void :
	
	if not clickable: return
	
	if checked:
		emit_signal("double_click", self)
		return
	var arr_item = Global.get_nodes_in_group("skill_menu_item")
	for item in arr_item:
		item.unchecked()
	checked()

func get_data():
	return attach_data

func set_data(a_d):
	attach_data = a_d
func set_name(i_n):
	$Label.text = str(i_n)

func set_click(boo):
	clickable = boo
	
	if boo:
		$Label["custom_colors/font_color"] = Color(1, 1, 1, 1)
		pass
	else:
		$Label["custom_colors/font_color"] = Color(0.4, 0.4, 0.4, 1)
		pass
