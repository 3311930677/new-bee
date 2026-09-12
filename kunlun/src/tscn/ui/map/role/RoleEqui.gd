extends Panel

onready var popumenu = $"Control/PopupMenu"
onready var display_role = $"Top/Role/DisplayRole"
var ScreenUtils
var RoleInfoManage

var check_node
var is_inspect_self = false

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	RoleInfoManage.connect("role_info_result", self, "_on_role_info_result")
	for item in $"Background/Background2/ScrollContainer/VBoxContainer".get_children():
		item.connect("item_click", self, "item_click")
	

func _on_role_info_result(data):
	if RoleInfoManage.get_role_id() == data["role"]["id"]:
		is_inspect_self = true
		
	display_role.load_data(data["role"])
	pass


func _on_Ok_pressed() -> void :
	if check_node == null: return
	
	if check_node.equi_data == null:
		return
	
	if is_inspect_self:
		popumenu.popup_centered()
		pass
	else:
		inspect_equi(check_node.equi_data)
		pass
	pass



func item_click(node):
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node


func _on_PopupMenu_index_pressed(index: int) -> void :
	match index:
		0:
			Global.get("BagInfoManage").unload_equipment(check_node.wear_index, check_node)
			pass
		1:
			inspect_equi(check_node.equi_data)
			pass

func inspect_equi(data):

	Global.get("BagInfoManage").private_show_equi_details(data)
	pass
