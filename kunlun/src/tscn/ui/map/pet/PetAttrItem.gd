extends TextureRect

signal add_click
signal sub_click
signal item_checked

export (String) var name_ = "力量"
export (String) var key = "power"

var light_res = null

var base_attr

var add_point = {}

var point = 0
var checked = false
var AssetsManage
func _ready() -> void :
	$Name.text = name_
	AssetsManage = Global.get("AssetsManage")
	light_res = AssetsManage.get_ligth_tex()

func set_data(data, add_point_):
	base_attr = data
	point = 0
	add_point = add_point_
	$Number.text = str(round(base_attr[key]))
	pass

func _on_TextureButton_pressed() -> void :
	var arr_node = Global.get_nodes_in_group("pet_attr_item")
	for n in arr_node:
		if n != self:
			n.unchecked()
	checked()

func checked():
	checked = true
	texture = light_res
	emit_signal("item_checked", self)

func unchecked():
	checked = false
	texture = null

func _on_Add_pressed() -> void :
	if not checked: return
	if add_point.get("add_point", 0) <= 0: return
	
	point += 1
	add_point["add_point"] -= 1
	
	emit_signal("add_click", self)
	
	$Number.text = str(round(base_attr[key] + point))


func _on_Sub_pressed() -> void :
	if not checked: return
	if point <= 0: return
	
	point -= 1
	add_point["add_point"] += 1
	
	emit_signal("sub_click", self)
	$Number.text = str(round(base_attr[key] + point))



var all_delta = 0.0
var out_time = 1.5
var btn_add_time = 0.15
var btn_add_ = 0.1
var long_click = false
var long_click_enable = false

var add_sub = false

func _process(delta: float) -> void :
	if long_click_enable:
		if long_click:
			btn_add_ += delta
			if btn_add_ >= btn_add_time:
				btn_add_ = 0.0
				if not add_sub:
					_on_Add_pressed()
				else:
					_on_Sub_pressed()
				pass
			pass
		else:
			all_delta += delta
			if all_delta >= out_time:
				all_delta = 0.0
				long_click = true
		pass

func _on_Add_button_down() -> void :
	long_click_enable = true
	add_sub = false
	pass


func _on_Add_button_up() -> void :
	long_click_enable = false
	all_delta = 0.0
	pass




func _on_Sub_button_down() -> void :
	long_click_enable = true
	add_sub = true
	pass


func _on_Sub_button_up() -> void :
	long_click_enable = false
	all_delta = 0.0
	pass
