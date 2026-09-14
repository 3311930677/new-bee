extends TextureRect

signal item_click

onready var txt = $Label
var light_tex = null
var checked = false
var current_index = 0
var current_txt = ""

func _ready():
	light_tex = Global.get("AssetsManage").get_ligth_tex()

func set_text(txt, index):
	self.txt.text = txt
	current_index = index
	current_txt = txt


func _on_TextureButton_pressed() -> void :
	
	var arr_node = get_tree().get_nodes_in_group("menu_item")
	for no in arr_node:
		if no != self:
			no.unchecked()
	checked()
	emit_signal("item_click", self)

func checked():
	checked = true
	texture = light_tex
	

func unchecked():
	checked = false
	texture = null
