extends Control
const prefix = "ForgeEquiUi->"

onready var yinliang = $Panel2 / Coins / Label / HBoxContainer / YinLiang


onready var bag_num = $Panel2 / Panel3 / BagNum

onready var box = $Panel2 / Background / Background2 / ScrollContainer / VBoxContainer

onready var pop_menu = $Control / PopupMenu

var item_res = preload("res://src/tscn/ui/common/bag/ProLabelItem.tscn")

var BagInfoManage
var ScreenUtils
var StaticGameData

var check_node = null
var check_gemstone_type = - 1

var consume_coin = [100, 159, 286, 490, 652, 998, 1300, 1495, 1689, 2100, 2256, 2399, 2545, 2645, 2985]

var dic_menu = {
	"0": "使用初级锻造宝石(+10%)", 
	"1": "使用锻造宝石(+20%)", 
	"2": "使用精段宝石(+30%)", 
	"3": "使用锻皇宝石(+40%)", 
	"4": "使用圣锻皇宝石(+100%)"
}



func _ready() -> void :
	BagInfoManage = Global.get("BagInfoManage")
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	
	BagInfoManage.connect("_consolidate_signal", self, "_on_consolidate_handle")
	BagInfoManage.connect("_bag_all_data", self, "_on_bag_all_data_loaded")
	BagInfoManage.request_bag_data()
	hide()
	

	

func load_data():
	var arr_equ = BagInfoManage.get_equs()
	clear_container()
	
	yinliang.text = str(BagInfoManage.get_coins())
	var max_bag_num = BagInfoManage.get_bag_max_amount()
	var bag_num_ = BagInfoManage.get_bag_amount_local()
	
	bag_num.text = str("（", bag_num_, "/", max_bag_num, "）")
	
	for i in arr_equ:
		
		var static_data = StaticGameData.get_equi_data(i.equi_data_id)
		if static_data.wear_index == 12: continue
		
		var item = item_res.instance()
		item.connect("item_click", self, "_item_click")
		box.add_child(item)
		item.set_data(i)
		pass
	pass

func clear_container():
	for i in box.get_children():
		i.queue_free()

func _on_bag_all_data_loaded(data):
	load_data()
	show()
	pass

func _on_Cancle_pressed() -> void :
	queue_free()
	
func _item_click(node):
	if check_node == node:
		return _on_Ok_pressed()
	check_node = node
	pass


func _on_Ok_pressed() -> void :
	if check_node == null: return
	
	ScreenUtils.build_menu(pop_menu, dic_menu)
	pop_menu.popup_centered()
	Global.log_info(str(prefix, "选中项点击"))


func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = pop_menu.get_item_id(index)
	check_gemstone_type = id
	
	if check_node.data.is_mar:
		ScreenUtils.show_message("无法强化已损坏装备")
		return
	
	if check_node.data.consolidate_level >= 15:
		ScreenUtils.show_message("当前装备已到最大强化等级")
		return
	










	
	var money_consume = consume_coin[check_node.data.consolidate_level]
	
	if check_node.data.consolidate_level > 5:
		
		ScreenUtils.show_message_plus(str("当前装备锻造等级较高，大概率会锻造失败，确定[", dic_menu[str(id)], "]进行锻造装备？若锻造失败，装备将会损坏\n", "消耗：", money_consume, "银两"), self, "_press_ok_forge")
	else:
		ScreenUtils.show_message(str("确定[", dic_menu[str(id)], "]进行锻造装备？若锻造失败，装备将会损坏\n", "消耗：", money_consume, "金币"), self, "_press_ok_forge")
		
	pass


func _press_ok_forge():
	if (check_node == null or check_gemstone_type <= - 1): return
	
	BagInfoManage.consolidate_equ(check_node.data.id, check_gemstone_type)
	pass

func _on_consolidate_handle(data):
	check_gemstone_type = - 1
	
	if check_node.data.consolidate_level < data.consolidate_level:
		ScreenUtils.show_message("强化成功！！")
	else:
		ScreenUtils.show_message("强化失败，装备已损坏")
	
	var index = check_node.data.consolidate_level
	BagInfoManage.set_gold_coins(consume_coin[index])
	yinliang.text = str(BagInfoManage.get_coins())
	check_node.set_data(data)


