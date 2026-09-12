extends Control
const prefix = "SelectRole->"
onready var head = $"Background/Background2/Head"
onready var role_name = $"Background/Background2/RoleName"
onready var role_level = $"Background/Background2/RoleLevel"
onready var role_fentang = $"Background/Background2/RoleFenTang"
onready var role_zheng_ying = $"Background/Background2/TextureRect"

onready var pupup_menu = $Control / PopupMenu
onready var dipan = preload("res://src/tscn/ui/login/select_role/RoleDiPan.tscn")
onready var dipans = [
	$"Background/TextureRect/Dipan1", 
	$"Background/TextureRect/Dipan2", 
	$"Background/TextureRect/Dipan3", 
]

var menu_data1 = {
	"0": "创建角色", 
	"1": "进入游戏", 
	"2": "删除角色", 
	"3": "取消操作"
}
var menu_data2 = {
	"0": "创建角色", 
	"3": "取消操作"
}

var zy_res_str_template = "res://assets/res/zy_%d.png"


var cur_node_role_dipan

var ScreenUtils
var NetContext
var StaticGameData
var RoleInfoManage


var list_roles
var area_id

func load_data(data):
	area_id = data["area_id"]
	hide()
	NetContext.request_service("RoleRemote", "getAreaRoles", {"area_id": area_id}, true)
	
	

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	StaticGameData = Global.get("StaticGameData")
	RoleInfoManage = Global.get("RoleInfoManage")
	RoleInfoManage.connect("bind_success", self, "_on_bind_role_result")
	
	NetContext.set_handler("RoleRemote", "getAreaRoles", self, "_on_area_role_result")
	NetContext.set_handler("RoleRemote", "delRole", self, "_on_delete_role_result")
	head.set_display()

func _on_Cancle_pressed() -> void :
	ScreenUtils.change_ui("res://src/tscn/ui/login/select_area/SelectAreaUi.tscn")
	queue_free()


func build_menu():
	
	var dic_menu
	if cur_node_role_dipan == null:
		dic_menu = menu_data2
	else:
		dic_menu = menu_data1
	
	pupup_menu.clear()
	
	pupup_menu.rect_size.y = 0
	
	var arr_key = dic_menu.keys()
	for k in arr_key:
		pupup_menu.add_item(dic_menu[str(k)], int(k))
	pupup_menu.popup_centered()

func _dipan_click(node: Node):
	cur_node_role_dipan = node
	
	role_name.text = str("昵称：", node.data["role_name"])
	role_level.text = str("等级：", node.data["level"])
	role_zheng_ying.texture = load(zy_res_str_template % node.data["job_id"])
	head.set_show_index(node.data["race_id"])
	var n = StaticGameData.role_job_division_name[str(node.data["division_id"])]
	role_fentang.text = str("分堂：", n)


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = pupup_menu.get_item_id(index)
	match id:
		0:
			create_role()
			Global.log_info(str(prefix, "创建角色"))
		1:
			join_game()
			Global.log_info(str(prefix, "进入游戏"))
		2:
			delete_role()


func _on_Ok_pressed() -> void :
	build_menu()


func create_role():
	if list_roles.size() >= 3:
		ScreenUtils.show_message("角色数量已达上限")
		return
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/login/rerister_role/RegisterRoleUi.tscn", "load_data", {"area_id": area_id})
	queue_free()


func delete_role():
	ScreenUtils.show_message("删除角色为不可逆操作\n确定继续操作？", self, "delete_ok")

func delete_ok():
	Global.log_info(str(prefix, "删除角色"))
	NetContext.request_service("RoleRemote", "delRole", {
		"role_id": cur_node_role_dipan.data["id"], 
		"area_id": area_id
		}, true)

func _on_delete_role_result(data):
	ScreenUtils.show_message("角色删除成功")
	list_roles.remove(0)
	cur_node_role_dipan.queue_free()
	cur_node_role_dipan = null


func join_game():
	RoleInfoManage.bind_role(area_id, cur_node_role_dipan.data["id"])
	


func _on_bind_role_result():
	
	ScreenUtils.clear_ui()
	ScreenUtils.clear_scence()
	

	
	Global.get("RoleInfoManage").update_role_backpack_info()
	
	Global.get("RoleInfoManage").request_role_data( - 1)
	
	Global.get("MapInfoManage").current_map = Global.get("RoleInfoManage").get_role_current_map()
	
	Global.get("BagInfoManage").request_bag_data(false)

	
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/MainControlUi.tscn", "load_data", {})
	
	ScreenUtils.change_scence("res://src/tscn/scence/MapScence.tscn", "load_data", {})
	pass

func _on_area_role_result(data):
	list_roles = data.get("data", [])
	show()
	var ind = 0
	for role_data in list_roles:
		var d = dipan.instance()
		dipans[ind].add_child(d)
		d.set_data(role_data)
		d.connect("item_click", self, "_dipan_click")
		ind += 1
