extends Node
class_name ShopInfoManage

const prefix = "ShopInfoManage->"

signal buy_successed
signal sell_successed
signal loaded_data


var GOLD_COIN = 1
var SILVER_COIN = 2
var COUPONS = 3
var MERITORIOUS = 4


var EQU = 3
var GEM = 4
var ART = 5


var GOOD_EQUI_NORMAL = 1
var GOOD_PET_TYPE2 = 2
var GOOD_PET_EQUI = 3
var GOOD_ART_TYPE2 = 4
var GOOD_ART_TYPE1 = 5
var GOOD_GEM_NORMAL = 6
var GOOD_ART_TYPE3 = 7
var GOOD_ART_TIME = 8
var GOOD_EQUI_HEIGHT = 9


var ScreenUtils
var NetContext

var list_all_shop_data = []


var dealer_index = 1

var dealer_job_type = 0

var dealer_levels = [
	[], 
	[0, 30], 
	[30, 50], 
	[50, 60], 
	[60, 80], 
	[80, 100], 
]
var wuqi_buwei = [1]
var fangju_buwei = [2, 3, 4, 5, 6, 7]
var shiping_buwei = [8, 9]

func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	NetContext = Global.get("NetContext")
	
	
	NetContext.set_handler("SystemMallRemote", "getAll", self, "_on_all_mall_data_result")
	
	NetContext.set_handler("SystemMallRemote", "buy", self, "_on_buy_mall_data_result")
	
	NetContext.set_handler("SystemMallRemote", "sell", self, "_on_sell_mall_data_result")
	NetContext.set_handler("DataRemote", "giftBagExchange", self, "_on_gift_bag_exchange_result")

func request_data():



	list_all_shop_data = Global.get("StaticGameData").get_all_system_mall_data()
	emit_signal("loaded_data")


func _on_buy_mall_data_result(data):
	data = data["data"]
	Global.get("BagInfoManage").map_all_bags["roleBackpackData"] = data
	Global.log_info(str(prefix, "购买成功", data))
	ScreenUtils.show_message("购买成功")
	emit_signal("buy_successed")
	pass

func _on_all_mall_data_result(data):
	data = data["data"]
	list_all_shop_data = data
	emit_signal("loaded_data")
	pass


func _on_sell_mall_data_result(data):
	data = data["data"]
	Global.get("BagInfoManage").map_all_bags["roleBackpackData"] = data
	Global.log_info(str(prefix, "售卖成功", data))
	ScreenUtils.show_message("售卖出成功")
	emit_signal("sell_successed")
	pass

func _on_gift_bag_exchange_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "兑换成功", data))
	ScreenUtils.show_message("兑换成功")
	pass


func buy_art(id, num):
	NetContext.request_service("SystemMallRemote", "buy", {
		"id": id, 
		"num": num
	}, true)

func sell_art(art_type, id, num):
	NetContext.request_service("SystemMallRemote", "sell", {
		"article_type": art_type, 
		"id": id, 
		"num": num
	}, true)
	pass

func gift_bag_exchange(key):
	NetContext.request_service("DataRemote", "giftBagExchange", {
		"key": key
	}, true)
	

func get_all_coupons_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == COUPONS:
			result.append(mall)
	return result

func get_all_coupons_consume_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == COUPONS and mall["good_type"] == GOOD_ART_TYPE1:
			result.append(mall)
	return result

func get_all_coupons_gem_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == COUPONS and mall["good_type"] == GOOD_GEM_NORMAL:
			result.append(mall)
	return result


func get_all_coupns_pet_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == COUPONS and (mall["good_type"] == GOOD_PET_TYPE2 or mall["good_type"] == GOOD_PET_EQUI):
			result.append(mall)
	return result



func get_all_gold_coin_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == GOLD_COIN and (mall["good_type"] == GOOD_EQUI_HEIGHT or int(mall["good_data_type"]) != EQU):
			result.append(mall)
	return result



func get_all_silver_coin_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == SILVER_COIN:
			result.append(mall)
	return result


func get_all_wq_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == GOLD_COIN and int(mall["good_type"]) == GOOD_EQUI_NORMAL:
			
			var s_data = Global.get("StaticGameData").get_equi_data(int(mall["good_data_id"]))
			var index = int(s_data["wear_index"])
			if wuqi_buwei.find(index) != - 1:
				
				var s = int(int(s_data["entity_type"]) / 10)
				if s == 0 or s == int(dealer_job_type):
					
					var vmn = dealer_levels[int(dealer_index)]
					if s_data["level"] >= vmn[0] and s_data["level"] <= vmn[1]:
						result.append(mall)
	return result

func get_all_fangju_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == GOLD_COIN and int(mall["good_type"]) == GOOD_EQUI_NORMAL:
			
			var s_data = Global.get("StaticGameData").get_equi_data(int(mall["good_data_id"]))
			var index = int(s_data["wear_index"])
			if fangju_buwei.find(index) != - 1:
				
				var s = int(int(s_data["entity_type"]) / 10)
				if s == 0 or s == int(dealer_job_type):
					
					var vmn = dealer_levels[int(dealer_index)]
					if s_data["level"] >= vmn[0] and s_data["level"] <= vmn[1]:
						result.append(mall)
	return result

func get_all_shipin_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == GOLD_COIN and int(mall["good_type"]) == GOOD_EQUI_NORMAL:
			
			var s_data = Global.get("StaticGameData").get_equi_data(int(mall["good_data_id"]))
			var index = int(s_data["wear_index"])
			if shiping_buwei.find(index) != - 1:
				
				var s = int(int(s_data["entity_type"]) / 10)
				if s == 0 or s == int(dealer_job_type):
					var vmn = dealer_levels[int(dealer_index)]
					if s_data["level"] >= vmn[0] and s_data["level"] <= vmn[1]:
						result.append(mall)
	return result

func get_all_pet_data():
	var result = []
	return result
	pass


func get_meritorious_article_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == MERITORIOUS and mall["good_data_type"] == ART:
			result.append(mall)
	return result
	pass

func get_meritorious_gem_data():
	var result = []
	for mall in list_all_shop_data:
		if int(mall["mall_type"]) == MERITORIOUS and mall["good_data_type"] == GEM:
			result.append(mall)
	return result
	pass
