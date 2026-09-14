extends Control

onready var box = $"Background/Background2/ScrollContainer/VBoxContainer"

var ScreenUtils
var RoleInfoManage
var FactionInfoManage
var PlayerOperate

var item_res = preload("res://src/tscn/ui/common/faction/FactionMemberLabelItem.tscn")


var checke_node

func load_data(data):
	if not FactionInfoManage.has_faction():
		ScreenUtils.show_message("请先加入或创建一个帮派")
		return
	hide()
	FactionInfoManage.get_faction_member_list(RoleInfoManage.get_role_faction_id())


func clear_container():
	for i in box.get_children():
		i.queue_free()
	pass

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	FactionInfoManage = Global.get("FactionInfoManage")
	PlayerOperate = Global.get("PlayerOperate")
	
	
	FactionInfoManage.connect("faction_membem_list_loaded", self, "_on_faction_membem_list_loaded")
	FactionInfoManage.connect("kickout_quit_loaded", self, "_on_kickout_quit_loaded")
	FactionInfoManage.connect("faction_delete_success", self, "_on_faction_delete_success_loaded")
	pass

func _item_click(node):
	if checke_node == node:
		_on_Ok_pressed()
		return
	checke_node = node
	pass

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_Ok_pressed() -> void :
	if checke_node == null: return
	var dic_data = checke_node.get_meta("data")
	
	
	if RoleInfoManage.get_role_id() == dic_data["role"]["id"]:
		if dic_data.get("member_type", 3) == 0:
			ScreenUtils.build_menu($Control / PopupMenu, {"31": "解散帮派"})
		else:
			ScreenUtils.build_menu($Control / PopupMenu, {"32": "退出帮派"})
	else:
		



		var self_member_type = FactionInfoManage.current_member_info.get("member_type", 3)
		
		var temp_data = PlayerOperate.faction_menu_dic.duplicate()
		if self_member_type == 0:
			temp_data["28"] = "分配职权"
			temp_data["29"] = "帮派转让"
			temp_data["30"] = "移除成员"
			pass
		elif self_member_type == 1:
			temp_data["28"] = "分配职权"
			temp_data["30"] = "移除成员"
			pass
		elif self_member_type == 2:
			temp_data["30"] = "移除成员"
		ScreenUtils.build_menu($Control / PopupMenu, temp_data)
	
	$Control / PopupMenu.popup_centered()


func _on_faction_membem_list_loaded(list_member):
	clear_container()
	for i in list_member:
		var item = item_res.instance()
		item.set_meta("data", i)
		item.connect("item_click", self, "_item_click")
		box.add_child(item)
		pass
	show()


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = $Control / PopupMenu.get_item_id(index)



	PlayerOperate.current_player_info = checke_node.get_meta("data")["role"]
	
	if id == 28:
		
		ScreenUtils.show_message("功能暂时不可用")
		pass
	elif id == 29:
		
		ScreenUtils.show_message("功能暂时不可用")
		pass
	elif id == 30:
		
		ScreenUtils.show_message("确定移除此成员？", self, "_ok_kikout_faction")
		pass
	elif id == 31:
		
		ScreenUtils.show_message("确定解散帮派？操作不可回退", self, "_ok_delete_faction")
		pass
	elif id == 32:
		
		ScreenUtils.show_message("确定退出当前帮派？", self, "_ok_quit_faction")
		pass
	else:
		PlayerOperate.menu_item_click(id)


func _ok_delete_faction():
	var data = checke_node.get_meta("data")
	FactionInfoManage.delete_faction(data["faction_u_id"])
	pass


func _ok_quit_faction():
	var data = checke_node.get_meta("data")
	FactionInfoManage.kikout_quit_faction(data["role"]["id"], data["faction_u_id"], 0)
	pass

func _ok_kikout_faction():
	var data = checke_node.get_meta("data")
	FactionInfoManage.kikout_quit_faction(data["role"]["id"], data["faction_u_id"], 1)
	pass


func _on_kickout_quit_loaded():
	checke_node.queue_free()
	checke_node = null
	pass

func _on_faction_delete_success_loaded():
	clear_container()
	checke_node = null
