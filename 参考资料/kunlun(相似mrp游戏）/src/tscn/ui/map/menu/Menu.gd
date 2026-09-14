extends Control


var menu1 = [
	"任务", "宠物", "物品", 
	"社交", "主角", "商城", 
	"周围", "帮派", "地图", 
	"邮件", "系统", "备忘"
	]



var menu_wp = [
	"背包", "仓库"
]

var menu_sj = [
	"组队", "聊天", 
	"好友", "仇人", 
	"黑名单", "邮件"
]

var menu_sc = [
	"点券商城", "银两商城", 


]

var menu_gh = [
	"成员名册", "帮派信息", 

	"帮派列表", "入帮审批"
]







var menu_xt = [
	"重选角色", "更新公告", 
	"礼包兑换", "退出游戏"
	]
var menu_two_dic = {
	"2": menu_wp, 
	"3": menu_sj, 
	"5": menu_sc, 
	"7": menu_gh, 
	"10": menu_xt
}

onready var gridContainer1 = $Container / GridContainer


onready var control2 = $Container2
onready var gridContainer2 = $Container2 / GridContainer
onready var title = $Title / Label

var model_change_index = [2, 3, 5, 7, 10]
var model_one_index = 0
var model_one_node_click = null
var model_two_node_click = null
var item_menu_ = preload("res://src/tscn/ui/map/menu/MenuItem.tscn")
var popup_edit_menu = preload("res://src/tscn/ui/common/dialog/PopupPanel.tscn")


var temp_select_level = 1

var ScreenUtils
var RoleInfoManage

func _ready() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	RoleInfoManage = Global.get("RoleInfoManage")
	control2.hide()
	var index = 0
	for m in menu1:
		var i = item_menu_.instance()
		gridContainer1.add_child(i)
		i.set_text(m, index)
		i.connect("item_click", self, "menu_item_click")
		index += 1
	pass

func model_one_click(click_index):
	match click_index:
		0:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/task/TaskUi.tscn", "load_data", {})
			
			pass
		1:
			
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/pet/PetUi.tscn", "load_data", {"pet_type": 0})
			pass
		4:
			
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/role/RoleUi.tscn", "load_data", {"role_type": 0})
			pass
		6:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/around/AroundUi.tscn", "load_data", {})
			
			pass
		8:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/worldmap/WorldMap.tscn", "load_data", {})
			
			pass
		9:
			
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/mail/MailUi.tscn", "load_data", {})
			pass
		11:
			
			ScreenUtils.change_ui("res://src/tscn/ui/map/memo/memoUi.tscn")
			pass
	
	queue_free()
	


func model_two_bag_click(item: Node):
	match item.current_index:
		0:
			
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/bag/BagUi.tscn", "load_data", {"type": 0})
			pass
		1:
			
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/bag/BagUi.tscn", "load_data", {"type": 1})
			pass
	pass




func model_two_sj_click(item: Node):
	match item.current_index:
		0:
			ScreenUtils.change_ui("res://src/tscn/ui/map/team/NewTeamUi.tscn")

			pass
		1:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/chat/ChatUi.tscn", "load_data", {})
			pass
		2:
			
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/friend/FriendUi.tscn", "load_data", {"friend_type": 0})
		3:
			
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/friend/FriendUi.tscn", "load_data", {"friend_type": 2})
		4:
			
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/friend/FriendUi.tscn", "load_data", {"friend_type": 1})
		5:
			pass
	pass




func model_two_sc_click(item: Node):
	match item.current_index:
		0:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/shop/CashShopping.tscn", "load_data", {"shop_type": 0})
			pass
		1:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/shop/CashShopping.tscn", "load_data", {"shop_type": 1})
			pass
		2:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/shop/CashShopping.tscn", "load_data", {"shop_type": 3})
			pass
		3:
			pass
	pass




func model_two_gh_click(item: Node):
	match item.current_index:
		0:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/faction/Faction.tscn", "load_data", {})
			pass
		1:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/faction/FactionInfo.tscn", "_on_faction_union_data_loaded", {})
			pass
		2:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/faction/FactionList.tscn", "load_data", {})
		3:
			ScreenUtils.chage_ui_and_args("res://src/tscn/ui/map/faction/FactionRequest.tscn", "load_data", {})
	pass










func model_two_xt_click(item: Node):
	match item.current_index:
		0:
			RoleInfoManage.unbind_role()
			
			pass
		1:
			ScreenUtils.show_message_plus(Global.get("LocalInfo").get_notice())
			
			pass
		2:
			
			ScreenUtils.show_popup_menu_edit(self, "_on_menu_edit_result", 0, "请输入兑换码:")
			pass
		3:
			
			ScreenUtils.show_message("确定退出游戏？", Global.get("ScreenUtils"), "quit_")
			pass
	pass


func menu2_item_click(item: Node):
	model_two_node_click = item
	
	print("二级菜单", item.current_index, item.current_txt)
	match model_one_index:
		2:
			model_two_bag_click(item)
			pass
		3:
			model_two_sj_click(item)
			pass
		5:
			model_two_sc_click(item)
			pass
		7:
			model_two_gh_click(item)
			pass
		10:
			model_two_xt_click(item)
			pass
	
	if model_one_index != 10:
		queue_free()
	pass
func menu_item_click(item: Node):
	
	print("一级菜单", item.current_index, item.current_txt)
	if temp_select_level == 1:
		if model_change_index.find(item.current_index) != - 1:
			
			model_one_index = item.current_index
			temp_select_level = 2
			model_one_node_click = item
			
			title.text = item.current_txt
			clearTwoContainer()
			control2.show()
			
			loadTwoCpntainer(menu_two_dic[str(item.current_index)])
			pass
		else:
			model_one_click(item.current_index)


func _on_Cancel_pressed() -> void :
	if temp_select_level == 1:
		queue_free()
	else:
		
		control2.hide()
		
		clearTwoContainer()
		
		temp_select_level = 1
		
		model_one_node_click.checked()
		title.text = "主菜单"
		pass


func clearTwoContainer():
	for item in gridContainer2.get_children():
		item.queue_free()
	pass

func loadTwoCpntainer(arr):
	var index = 0
	for txt in arr:
		var i = item_menu_.instance()
		gridContainer2.add_child(i)
		i.rect_min_size = Vector2(90, i.rect_min_size.y)
		i.set_text(txt, index)
		i.connect("item_click", self, "menu2_item_click")
		index += 1
	pass

func _on_Ok_pressed() -> void :
	if temp_select_level == 1:
		if model_one_node_click == null: return
		model_one_node_click._on_TextureButton_pressed()
	else:
		if model_two_node_click == null: return
		model_two_node_click._on_TextureButton_pressed()

func _on_Cancle_pressed() -> void :
	if temp_select_level == 1:
		queue_free()
	else:
		
		control2.hide()
		
		clearTwoContainer()
		
		temp_select_level = 1
		
		model_one_node_click.checked()
		title.text = "主菜单"


func _on_menu_edit_result(id, txt):
	Global.log_info(txt)
	Global.get("ShopInfoManage").gift_bag_exchange(txt)
	queue_free()
