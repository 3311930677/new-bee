extends TextureRect

signal item_click

var light_tex = null
var AssetsManage

func _init():
	AssetsManage = Global.get("AssetsManage")
	
	light_tex = AssetsManage.get_ligth_tex()

func _on_TextureButton_pressed() -> void :
	var arr_lib_labels = Global.get_nodes_in_group("lib_label_item")
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
