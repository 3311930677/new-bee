extends Control

onready var title = $Head / XQTitle
onready var cash_tab = $Tabs / Cash
onready var yinliang_tab = $Tabs / YinLiang
onready var meritorious_tab = $Tabs / Meritorious
onready var equi_tab = $Tabs / Equi
onready var vip_tab = $Tabs / Vip
onready var popup_menu = $Control / PopupMenu
onready var container = $"Background/Background2/ScrollContainer/VBoxContainer"
onready var item_res = preload("res://src/tscn/ui/map/shop/ShoppingItem.tscn")

onready var coins_num = $"Tabs/Coins/Label/HBoxContainer/YinLiang"

onready var yuanbao_num = $"Tabs/Coins/Label2/HBoxContainer/YuanBao"

onready var yinpiao_num = $"Tabs/Coins/Label3/HBoxContainer/YinPiao"

onready var meritorious_num = $"Tabs/Coins/Label4/HBoxContainer/Meritorious"

onready var bag_num = $"Tabs/Panel3/BagNum"

var dic_menu = {
	"1": "购买道具", 
	"2": "查看详情"
}


var ScreenUtils
var ShopInfoManage
var BagInfoManage
var StaticGameData

var data = []
var init_data
var checked_node
var current_tab
var buy_num

func _ready() -> void :
	ShopInfoManage = Global.get("ShopInfoManage")
	BagInfoManage = Global.get("BagInfoManage")
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	
	
	Global.get("RoleInfoManage").update_role_backpack_info()
	
	ShopInfoManage.connect("buy_successed", self, "_on_buy_successed")
	ShopInfoManage.connect("loaded_data", self, "_on_loaded_data")

func _item_click(node):
	checked_node = node


func _on_Cancle_pressed() -> void :
	queue_free()
	pass


func _on_Ok_pressed() -> void :
	if checked_node == null:
		return
	ScreenUtils.build_menu(popup_menu, dic_menu)
	popup_menu.popup_centered()



func _on_buy_successed():
	checked_node.buy_successed()
	
	coins_num.text = str(BagInfoManage.get_coins())
	yuanbao_num.text = str(BagInfoManage.get_coupons())
	yinpiao_num.text = str(BagInfoManage.get_silver_coins())
	meritorious_num.text = str(BagInfoManage.get_meritorious())
	
	bag_num.text = str("（%d/%d）" % [BagInfoManage.get_bag_amount_local(), BagInfoManage.get_bag_max_amount()])
	
	pass

func _on_loaded_data():
	show()
	current_tab.checked()

func reload():
	clear_container()
	for item_data in data:
		var item = item_res.instance()
		item.connect("item_click", self, "_item_click")
		container.add_child(item)
		item.set_data(item_data)
		pass
	pass

func load_data(data):
	self.init_data = data
	if init_data == null: return
	hide()
	ShopInfoManage.request_data()
	
	hide_all_tab()
	if init_data.shop_type == 0:
		cash_tab.visible = true
		title.set_title("元宝商城")
		$"Tabs/Cash/HBoxContainer/AllTab".checked()
	if init_data.shop_type == 1:
		yinliang_tab.visible = true
		title.set_title("银两商城")
		$"Tabs/YinLiang/HBoxContainer/YinLiangTab".checked()
	if init_data.shop_type == 3:
		vip_tab.visible = true
		title.set_title("VIP商城")
		$"Tabs/Vip/HBoxContainer/AllTab".checked()
	if init_data.shop_type == 4:
		equi_tab.visible = true
		title.set_title("装备商城")
		$"Tabs/Equi/HBoxContainer/WuQiTab".checked()
	if init_data.shop_type == 5:
		meritorious_tab.visible = true
		title.set_title("功勋商城")
		$"Tabs/Meritorious/HBoxContainer/MArticleTab".checked()
		
		$"Tabs/Coins/Label3".visible = false
		$"Tabs/Coins/Label4".visible = true
		
	
	
	coins_num.text = str(BagInfoManage.get_coins())
	yuanbao_num.text = str(BagInfoManage.get_coupons())
	yinpiao_num.text = str(BagInfoManage.get_silver_coins())
	meritorious_num.text = str(BagInfoManage.get_meritorious())
	
	bag_num.text = str("（%d/%d）" % [BagInfoManage.get_bag_amount_local(), BagInfoManage.get_bag_max_amount()])


func hide_all_tab():
	cash_tab.visible = false
	yinliang_tab.visible = false
	equi_tab.visible = false
	vip_tab.visible = false

func clear_container():
	for i in $Background / Background2 / ScrollContainer / VBoxContainer.get_children():
		i.queue_free()


func _on_AllTab_coupons_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_coupons_data()
	reload()

func _on_ConsumeTab_coupons_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_coupons_consume_data()
	reload()

func _on_GemTab_coupons_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_coupons_gem_data()
	reload()

func _on_PetTab_coupons_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_coupns_pet_data()
	reload()

func _on_YinLiangTab_tab_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_gold_coin_data()
	reload()

func _on_YinPiaoTab_tab_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_silver_coin_data()
	reload()
func _popup_buy_ok():
	ShopInfoManage.buy_art(checked_node.data["id"], buy_num)
	pass
func _on_popup_edit(id, txt_num):
	var num = int(txt_num)
	if num <= 0:
		ScreenUtils.show_message("购买数量有误")
		return
	
	if not checked_node.check_coins(num): return
	
	var static_data = checked_node.get_details()
	buy_num = num
	ScreenUtils.show_message(str("确定购买%d件该道具？" % buy_num, static_data.get("name", "")), self, "_popup_buy_ok")

func _on_PopupMenu_index_pressed(index: int) -> void :
	var id = popup_menu.get_item_id(index)
	match id:
		1:
			
			if checked_node.is_overlay():
				ScreenUtils.show_popup_menu_edit(self, "_on_popup_edit", 0, "请输入购买数量：")
			else:
				_on_popup_edit(0, 1)
			
			pass
		2:
			
			var stat = checked_node.get_details()
			StaticGameData.show_art_data_info(stat)

			pass


func _on_WuQiTab_tab_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_wq_data()
	reload()
	pass


func _on_FangJuTab_tab_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_fangju_data()
	reload()
	pass


func _on_ShiPinTab_tab_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_shipin_data()
	reload()
	pass


func _on_PetTab_tab_click(node) -> void :
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_all_pet_data()
	reload()
	pass


func _on_MArticleTab_tab_click(node):
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_meritorious_article_data()
	reload()
	pass


func _on_MAGemTab_tab_click(node):
	current_tab = node
	if ShopInfoManage == null: return
	data = ShopInfoManage.get_meritorious_gem_data()
	reload()
	pass
