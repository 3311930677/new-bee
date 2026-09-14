extends Control

const prefix = "AroundUi->"

onready var container = $Background / Background2 / ScrollContainer / VBoxContainer

var npc_item_res = preload("res://src/tscn/ui/map/around/AroundItem.tscn")
var player_item_res = preload("res://src/tscn/ui/common/player/PlayerLabelItem.tscn")
var check_node = null
var model = 0

var player_menu_data = {
	
}


var npc_menu_data = {
	"1": "自动寻路", 
	"2": "取消操作"
}


var ScreenUtils
var AroundRoleManage
var RoleInfoManage


func _ready() -> void :

	ScreenUtils = Global.get("ScreenUtils")
	AroundRoleManage = Global.get("AroundRoleManage")
	RoleInfoManage = Global.get("RoleInfoManage")
	AroundRoleManage.connect("around_role_loaded", self, "_load_around_rols")
	


func _on_Cancle_pressed() -> void :
	queue_free()
	pass




func _load_around_rols(data):
	clear_container()
	Global.log_info(str(prefix, data))
	for item in data.keys():
		var p = player_item_res.instance()
		p.connect("item_click", self, "_item_click")
		container.add_child(p)
		p.set_data(data[str(item)])
	show()
	pass


func _on_Players_tab_click(node) -> void :
	clear_container()
	
	
	if AroundRoleManage != null:
		_load_around_rols(AroundRoleManage.current_around_list_roles_)


func _on_Npcs_tab_click(node) -> void :
	clear_container()
	var arr_npc = Global.get_nodes_in_group("npcs")
	for npc in arr_npc:
		if npc.get_task_id() != 0: continue
		var item = npc_item_res.instance()
		item.connect("item_click", self, "_item_click")
		item.set_npc_data(npc)
		$Background / Background2 / ScrollContainer / VBoxContainer.add_child(item)
	pass


func _item_click(node):
	if check_node == node:
		
		_on_Ok_pressed()
		return
	check_node = node


func _on_Ok_pressed() -> void :
	if check_node == null: return
	if check_node.around_type == 0:
		
		if check_node.get_role_id() == RoleInfoManage.get_role_id():
			return
		Global.log_info(str(prefix, "显示操作玩家的菜单"))
		var menu = Global.get("PlayerOperate").menu_dic.duplicate(true)
		menu["13"] = "申请入队"




		
		Global.get("ScreenUtils").build_menu($Control / PopupMenu, menu)
		pass
	elif check_node.around_type == 1:
		Global.log_info(str(prefix, "显示操作npc的菜单"))
		Global.get("ScreenUtils").build_menu($Control / PopupMenu, npc_menu_data)
	$Control / PopupMenu.popup_centered()


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = $Control / PopupMenu.get_item_id(index)
	if check_node.around_type == 0:
		
		Global.get("PlayerOperate").current_player_info = check_node.data
		Global.get("PlayerOperate").role_id = check_node.data["id"]
		Global.get("PlayerOperate").team_name = check_node.data.get("team_name", null)
		Global.log_info(str(prefix, "玩家菜单被点击"))
		Global.get("PlayerOperate").menu_item_click(id)
		return
	if id == 1 and check_node.around_type == 1:
		Global.log_info(str(prefix, "自动前往npc所在地"))
		player_go_to_npc(check_node)
		
	$Control / PopupMenu.hide()

func player_go_to_npc(node):
	var npc = node.npc_node
	var player = Global.get_nodes_in_group("player")[0]
	player.set_target_points(npc.position)
	queue_free()
func clear_container():
	for item in $Background / Background2 / ScrollContainer / VBoxContainer.get_children():
		item.queue_free()
	check_node = null

func load_data(data_dic):
	hide()
	clear_container()
	AroundRoleManage.load_around_roles()
