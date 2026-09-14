extends "res://src/tscn/server_nodes/Form/Input.gd"

var item_tscn = preload("res://src/tscn/server_nodes/item/TextItem.tscn")


var light_res = load("res://src/tscn/ui/login/select_area/nine_patch_btn_pressed.tres")
var normal_res = load("res://src/tscn/ui/login/select_area/nine_patch_btn_normal.tres")


var NinePatchRect
var textButton

var checked: bool
var group: String
var text: String
var checked_data

var max_pressed
var cur_pressed = 0

func init_tscn():
	instance_tscn = item_tscn.instance()
	NinePatchRect = instance_tscn.find_node("NinePatchRect")
	NinePatchRect.texture = normal_res
	
	textButton = instance_tscn.find_node("textButton")
	textButton.connect("pressed", self, "_on_TextureButton_pressed")
	
	textButton.text = text
	
func init_after():
	NinePatchRect.rect_size = instance_tscn.rect_size
	textButton.rect_size = instance_tscn.rect_size
	
	textButton.rect_scale = instance_tscn.rect_scale
	textButton.rect_scale = instance_tscn.rect_scale
	
		
	
	
	
func init_data(data):
	.init_data(data)
	checked = data["checked"]
	group = data["group"]
	text = data["text"]
	checked_data = data["data"]
	max_pressed = data["max_pressed"]
	
	

func unchecked():
	NinePatchRect.texture = normal_res
	checked = false
	cur_pressed = 0
	pass
	

func checked():
	cur_pressed += 1
	checked = true
	NinePatchRect.texture = light_res
	

func click():
	pass

	
func _on_TextureButton_pressed() -> void :
	cur_pressed += 1
	
	var root = get_root()
	
	if form_name != "":
		for key in checked_data.keys():
			root.form_data[form_name][key] = checked_data[key]
	
	var list = root.search_node_by_type(type)
	
	
	if cur_pressed >= max_pressed:
		cur_pressed = 1
		click()
		
	for item in list:
		
		if group == item.group:
			item.unchecked()
	
	
	checked()

	


