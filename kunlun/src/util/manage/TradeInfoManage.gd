extends Node
class_name TradeInfoManage

signal put_consignment_success
signal self_consignment_success
signal take_consignment_success
signal query_consignment_success
signal buy_consignment_success

var NetContext

func _init() -> void :
	NetContext = Global.get("NetContext")
	NetContext.set_handler("TradeConsignmentRemote", "putConsignment", self, "_on_put_consignment_success")
	NetContext.set_handler("TradeConsignmentRemote", "getSelfConsignment", self, "_on_self_consignment_success")
	NetContext.set_handler("TradeConsignmentRemote", "takeConsignment", self, "_on_take_consignment_success")
	NetContext.set_handler("TradeConsignmentRemote", "queryAllConsignment", self, "_on_query_consignment_success")
	NetContext.set_handler("TradeConsignmentRemote", "buyConsignment", self, "_on_buy_consignment_success")



func put_consignment(hold_id, item_type, num, coin_num, coin_type):
	NetContext.request_service("TradeConsignmentRemote", "putConsignment", {
		"hold_id": hold_id, 
		"item_type": item_type, 
		"num": num, 
		"coin_num": coin_num, 
		"coin_type": coin_type
	}, true)

func get_self_consignemnt():
	NetContext.request_service("TradeConsignmentRemote", "getSelfConsignment", {}, true)
	pass

func take_consignment(trade_id):
	NetContext.request_service("TradeConsignmentRemote", "takeConsignment", {
		"trade_id": trade_id
	}, true)
	pass

func query_consignment(page = 0, count = 10, param = null):
	NetContext.request_service("TradeConsignmentRemote", "queryAllConsignment", {
		"page": page, 
		"count": count, 
		"parameter": param
	}, true)
	pass

func byg_consignment(trade_id, num):
	NetContext.request_service("TradeConsignmentRemote", "buyConsignment", {
		"trade_id": trade_id, 
		"num": num
	}, true)
	pass



func _on_buy_consignment_success(data):
	emit_signal("buy_consignment_success")
	pass


func _on_self_consignment_success(data):
	data = data["data"]
	emit_signal("self_consignment_success", data)
func _on_take_consignment_success(data):
	emit_signal("take_consignment_success")
	pass



func _on_put_consignment_success(data):
	Global.log_info("寄卖成功")
	emit_signal("put_consignment_success")

func _on_query_consignment_success(data):
	Global.log_info("查询成功")
	data = data["data"]
	emit_signal("query_consignment_success", data)
