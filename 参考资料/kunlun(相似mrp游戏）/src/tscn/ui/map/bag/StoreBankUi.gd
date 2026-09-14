extends Control

onready var bag_gold_coin = $"Background/Background2/Bag/Coins/Label/HBoxContainer/YinLiang"
onready var bag_coupons = $"Background/Background2/Bag/Coins/Label2/HBoxContainer/YuanBao"
onready var bag_silver_coin = $"Background/Background2/Bag/Coins/Label3/HBoxContainer/YinPiao"

onready var store_gold_coin = $"Background/Background2/Store/Coins/Label/HBoxContainer/YinLiang"


var _load_data
var op_id
var op_num

var BagInfoManage
var ScreenUtils


func _ready() -> void :
	BagInfoManage = Global.get("BagInfoManage")
	BagInfoManage.connect("_op_bag_store_coins_sinal", self, "_op_bag_store_coins_result")
	ScreenUtils = Global.get("ScreenUtils")
	bag_gold_coin.text = "0"
	bag_coupons.text = "0"
	bag_silver_coin.text = "0"
	store_gold_coin.text = "0"
	pass


func load_data(data):
	_load_data = data
	reload()
	pass


func reload():
	bag_gold_coin.text = str(BagInfoManage.get_coins())
	bag_coupons.text = str(BagInfoManage.get_coupons())
	bag_silver_coin.text = str(BagInfoManage.get_silver_coins())
	
	
	store_gold_coin.text = str(BagInfoManage.get_store_coins())
	pass

func _op_bag_store_coins_result(op):
	if op == 1:
		
		BagInfoManage.set_gold_coins(op_num)
		BagInfoManage.set_store_gold_coins( - op_num)
		pass
	else:
		
		BagInfoManage.set_gold_coins( - op_num)
		BagInfoManage.set_store_gold_coins(op_num)
		pass
	reload()
	pass
func _popup_menu_edit_result(id, num_text):
	op_id = id
	op_num = int(num_text)
	if op_num <= 0 or op_num >= 999999999:
		ScreenUtils.show_message("输入的数量不合理")
		return
		pass
	if op_id == 1:
		if BagInfoManage.get_coins() < op_num:
			ScreenUtils.show_message("背包银两不足")
			return
		
		BagInfoManage.put_store_coin(op_num)
	else:
		if BagInfoManage.get_store_coins() < op_num:
			ScreenUtils.show_message("仓库银两不足")
			return
		
		BagInfoManage.take_store_coin(op_num)
	pass

func _on_Cancle_pressed() -> void :
	queue_free()


func _on_Add_pressed() -> void :
	ScreenUtils.show_popup_menu_edit(self, "_popup_menu_edit_result", 1, "请输入存入数量：")
	pass


func _on_Sub_pressed() -> void :
	ScreenUtils.show_popup_menu_edit(self, "_popup_menu_edit_result", 2, "请输入取出数量：")
	pass
