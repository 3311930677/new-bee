extends Node
class_name MasterDataManage

signal master_list_loaded
signal master_register_list_loaded

var NetContext
var ScreenUtils

func _init():
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	
	NetContext.set_handler("MasterRemote", "getListMaster", self, "_on_master_list_data_success")
	NetContext.set_handler("MasterRemote", "listMasterRegister", self, "_on_list_master_register_data_success")
	NetContext.set_handler("MasterRemote", "requestMaster", self, "_on_request_master_data_success")
	NetContext.set_handler("MasterRemote", "requestApprentice", self, "_on_request_apprentice_data_success")


func getMasterListData():
	NetContext.request_service("MasterRemote", "getListMaster", {}, true)
	pass

func getMasterRegisterListData(register_type, page, count):
	NetContext.request_service("MasterRemote", "listMasterRegister", {
		"register_type": register_type, 
		"page": page, 
		"size": count
	}, true)
	pass

func request_master(target_id):
	NetContext.request_service("MasterRemote", "requestMaster", {
		"target_id": target_id
	}, true)
	
	pass

func request_apprentice(target_id):
	NetContext.request_service("MasterRemote", "requestApprentice", {
		"target_id": target_id
	}, true)
	

func _on_request_master_data_success(data):
	ScreenUtils.show_message("拜师请求发生成功，请等待对方回应")

func _on_request_apprentice_data_success(data):
	ScreenUtils.show_message("收徒请求发生成功，请等待对方回应")



func _on_master_list_data_success(data):
	data = data["data"]
	emit_signal("master_list_loaded", data)

func _on_list_master_register_data_success(data):
	data = data["data"]
	emit_signal("master_register_list_loaded", data)
	
