extends Control



var friend_item_res = preload("res://src/tscn/ui/common/friend/FriendLabelItem.tscn")


onready var frend_num = $"Head/Tabs/HBoxContainer/FriendTab/Num"
onready var black_list_num = $"Head/Tabs/HBoxContainer/BlackListTab/Num"
onready var foe_num = $"Head/Tabs/HBoxContainer/FoeTab/Num"
onready var popup_menu = $Control / PopupMenu

var init_load = true

var check_node = null

var load_mode_tab = 1

var ScreenUtils
var FriendInfoManage
var PlayerOperate

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	FriendInfoManage = Global.get("FriendInfoManage")
	PlayerOperate = Global.get("PlayerOperate")
	FriendInfoManage.connect("_friend_item_change", self, "_on_friend_item_change")
	
	hide()
	pass


func _item_click(node):
	PlayerOperate.current_player_info = node.data
	if check_node == node:
		_on_Ok_pressed()
		return
	check_node = node

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_FriendTab_tab_click(node) -> void :
	clear_container()
	load_mode_tab = 1
	if not init_load: _on_friend_item_change()


func _on_foeTab_tab_click(node) -> void :
	clear_container()
	load_mode_tab = 2
	if not init_load: _on_friend_item_change()


func _on_BlackListTab_tab_click(node) -> void :
	clear_container()
	load_mode_tab = 3
	if not init_load: _on_friend_item_change()

func _on_friend_item_change():
	init_load = false
	clear_container()
	show()
	
	frend_num.text = str("（", FriendInfoManage.get_friends().size(), "/50）")
	black_list_num.text = str("（", FriendInfoManage.get_black_list_friend().size(), "/50）")
	foe_num.text = str("（", FriendInfoManage.get_foe_friend().size(), "/50）")
	
	var load_list_item = []
	match load_mode_tab:
		1:
			load_list_item = FriendInfoManage.get_friends()
			pass
		2:
			load_list_item = FriendInfoManage.get_foe_friend()
			pass
		3:
			load_list_item = FriendInfoManage.get_black_list_friend()
	for i in load_list_item:
		var item = friend_item_res.instance()
		item.connect("item_click", self, "_item_click")
		$Background / Background2 / ScrollContainer / VBoxContainer.add_child(item)
		item.set_data(i)
	
func _on_Ok_pressed() -> void :
	if check_node == null:
		Global.get("ScreenUtils").build_menu($Control / PopupMenu, Global.get("PlayerOperate").friend_add_menu)
	elif load_mode_tab == 1:
		if check_node.is_online():
			var _dic = Global.get("PlayerOperate").menu_dic.duplicate()
			_dic.erase("4")
			_dic.erase("11")
			_dic.erase("12")
			_dic["26"] = "删除好友"
			_dic["25"] = "添加好友"
			Global.get("ScreenUtils").build_menu($Control / PopupMenu, _dic)
		else:
			Global.get("ScreenUtils").build_menu($Control / PopupMenu, Global.get("PlayerOperate").friend_no_onloine_menu)
		pass
	elif load_mode_tab == 3:
		Global.get("ScreenUtils").build_menu($Control / PopupMenu, Global.get("PlayerOperate").friend_black_list_menu)
		pass
	elif load_mode_tab == 2:
		Global.get("ScreenUtils").build_menu($Control / PopupMenu, Global.get("PlayerOperate").friend_feo_menu)
		pass
	$Control / PopupMenu.popup_centered()
	
	
	
	
	

func _on_add_friend(id, txt_name):
	Global.get("PlayerOperate")._on_add_friend(id, txt_name)

func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = $Control / PopupMenu.get_item_id(index)
	
	if id == 25:
		ScreenUtils.show_popup_menu_edit(self, "_on_add_friend", 1, "请输入角色名称:")
		pass
	else:
		Global.get("PlayerOperate").menu_item_click(id)



func clear_container():
	for item in $Background / Background2 / ScrollContainer / VBoxContainer.get_children():
		item.queue_free()
	check_node = null


func load_data(data):
	
	hide()
	var friend_type = data["friend_type"]
	if friend_type == 0:
		$Head / Tabs / HBoxContainer / FriendTab.checked()
		pass
	elif friend_type == 1:
		$Head / Tabs / HBoxContainer / BlackListTab.checked()
		pass
	elif friend_type == 2:
		$Head / Tabs / HBoxContainer / FoeTab.checked()
		pass
	FriendInfoManage.request_friends()
