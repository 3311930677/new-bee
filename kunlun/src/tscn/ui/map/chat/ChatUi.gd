extends Control


onready var chat_show_label = $"Background"
onready var scroll_container = $"Background/Background2/ScrollContainer"
onready var popup_menu = $"Control/PopupMenu"

var ScreenUtils
var PlayerOperate
var RoleInfoManage
var ChatInfoManage
var StaticGameData

var menu = {
	"1": "查看信息", 
	"2": "查看宠物", 
	"3": "邀请组队", 
	"13": "申请入队", 
	"4": "添加好友", 
	"5": "发起私聊", 
	"6": "发送邮件", 



	"10": "申请入会", 
	"27": "加入黑名单", 
}


var checked_dic

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	PlayerOperate = Global.get("PlayerOperate")
	RoleInfoManage = Global.get("RoleInfoManage")
	ChatInfoManage = Global.get("ChatInfoManage")
	StaticGameData = Global.get("StaticGameData")
	ChatInfoManage.connect("chat_single_info", self, "_on_max_scroll")

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_ZongTab_tab_click(node) -> void :
	chat_show_label.reload_msg(0)
	$Timer.start()
	pass


func _on_QuTab_tab_click(node) -> void :
	chat_show_label.reload_msg(2)
	$Timer.start()


func _on_DuiTab_tab_click(node) -> void :
	chat_show_label.reload_msg(4)
	$Timer.start()


func _on_MiTab_tab_click(node) -> void :
	chat_show_label.reload_msg(3)
	$Timer.start()


func _on_BangTab_tab_click(node) -> void :
	chat_show_label.reload_msg(5)
	$Timer.start()


func _on_ZhanTab_tab_click(node) -> void :
	chat_show_label.reload_msg(6)
	$Timer.start()


func load_data(data):
	$Head / Tabs / HBoxContainer / ZongTab.checked()
	pass


func clear_container():
	$Background / Background2 / ScrollContainer / VBoxContainer / RichTextLabel.clear()

func _on_max_scroll(data):
	var bar = scroll_container.get_v_scrollbar()
	
	if bar.max_value - 339 == bar.value:
		$Timer.start()


func _on_SendMessage_pressed() -> void :
	ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/chat/SendMessageUi.tscn", "load_data", {})










func _on_RichTextLabel_meta_clicked(meta) -> void :
	var dic = parse_json(meta)
	checked_dic = dic
	
	if dic.get("chat_type") == 0 and dic.get("id", 0) != 0:
		PlayerOperate.current_player_info = dic
		show_role_dic_menu()
	else:
		show_prop_dic_menu()
	pass



func show_role_dic_menu():
	if RoleInfoManage.get_role_id() == checked_dic["id"]:
		return
	ScreenUtils.build_menu(popup_menu, menu)
	popup_menu.popup_centered()



func show_prop_dic_menu():
	var stat = StaticGameData.get_bag_artic_data_info(checked_dic)
	var type = StaticGameData.get_articles_item_type(checked_dic)
	if type == 2 or type == 3:
		if type == 2:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/pet/PetUi.tscn", "load_data", {"pet_type": 1, "id": checked_dic["id"]})
			pass
		else:
			Global.get("BagInfoManage").get_equipment_details(checked_dic["id"])
		pass
	else:
		StaticGameData.show_art_data_info(stat)
	pass


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = popup_menu.get_item_id(index)
	PlayerOperate.menu_item_click(id)


func _on_Timer_timeout() -> void :
	scroll_container.set_v_scroll(scroll_container.get_v_scrollbar().max_value)
	pass
