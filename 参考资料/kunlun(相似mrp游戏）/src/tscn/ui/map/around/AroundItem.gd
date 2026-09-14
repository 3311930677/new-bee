extends TextureRect

signal item_click

var light_tex = null
var around_type = 1

var npc_node

func _ready() -> void :
	light_tex = Global.get("AssetsManage").get_ligth_tex()
	pass

func checked():
	self.texture = light_tex
	emit_signal("item_click", self)

func unchecked():
	self.texture = null
	


func _on_TextureButton_pressed() -> void :
	var items = Global.get_nodes_in_group("around_item")
	for item in items:
		if item != self:
			item.unchecked()
	checked()


func set_npc_data(node):
	npc_node = node
	$NpcItem / Label.text = node.get_name()
