extends TextureRect

signal tab_click

export (String) var group_name = ""
export (String) var text = "tab"
export (int) var tab_index = 0
export (bool) var is_checked = false
var light_tes = null

var AssetsManage

func _ready() -> void :
	AssetsManage = Global.get("AssetsManage")
	light_tes = load(str(AssetsManage.get_prefix(), "assets/res/light.png"))
	$Label.text = text
	self.texture = null
	add_to_group(group_name)
	if is_checked: checked()

func checked():
	self.texture = light_tes
	emit_signal("tab_click", self)

func unchecked():
	self.texture = null

func _on_TextureButton_pressed() -> void :
	var arr_g = get_tree().get_nodes_in_group(group_name)
	for tab in arr_g:
		if tab != self:
			tab.unchecked()
	checked()
