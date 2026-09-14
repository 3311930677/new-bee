extends Node
class_name FactionInfoManage

const prefix = "FactionInfoManage->"


signal faction_list_loaded

signal faction_member_info_loaded

signal faction_member_request_list_loaded

signal faction_membem_list_loaded

signal faction_union_data_loaded

signal kickout_quit_loaded

signal faction_delete_success

var NetContext
var ScreenUtils


var faction_list = []
var current_member_info = null
var current_fac_info = {}

var op_types = 0

func _init() -> void :
	NetContext = Global.get("NetContext")
	ScreenUtils = Global.get("ScreenUtils")
	
	NetContext.set_handler("FactionRemote", "creatFaction", self, "_on_create_faction_result")
	NetContext.set_handler("FactionRemote", "deleteFaction", self, "_on_delete_faction_result")
	NetContext.set_handler("FactionRemote", "getFactionUnionList", self, "_on_faction_list_result")
	NetContext.set_handler("FactionRemote", "joinFactionId", self, "_on_request_join_result")
	NetContext.set_handler("FactionRemote", "joinFactionRoleId", self, "_on_request_join_result")
	NetContext.set_handler("FactionRemote", "getFactionMemberInfo", self, "_on_role_member_info_result")
	NetContext.set_handler("FactionRemote", "getRequestList", self, "_on_member_request_list_result")
	NetContext.set_handler("FactionRemote", "agreeAndInjectFaction", self, "_on_faction_member_op_result")
	NetContext.set_handler("FactionRemote", "quitFaction", self, "_on_kikout_quit_op_result")
	NetContext.set_handler("FactionRemote", "getFactionMemberList", self, "_on_member_list_result")
	NetContext.set_handler("FactionRemote", "getFactionUnionDataInfo", self, "_on_faction_union_data_result")
	pass


func get_faction_list():
	NetContext.request_service("FactionRemote", "getFactionUnionList", {}, true)
	pass


func request_join_faction(fac_id):
	NetContext.request_service("FactionRemote", "joinFactionId", {
		"faction_id": fac_id
	}, true)
	pass


func request_join_faction_with_role(target_role_id):
	NetContext.request_service("FactionRemote", "joinFactionRoleId", {
		"target_role_id": target_role_id
	}, true)
	pass


func create_faction(fac_name):
	NetContext.request_service("FactionRemote", "creatFaction", {
		"faction_name": fac_name
	}, true)
	pass

func delete_faction(faction_id):
	NetContext.request_service("FactionRemote", "deleteFaction", {
		"faction_id": faction_id
	}, true)
	pass


func get_member_info(target_role_id, is_wait = true):
	NetContext.request_service("FactionRemote", "getFactionMemberInfo", {
		"target_role_id": target_role_id
	}, is_wait)
	pass


func get_requested_join():
	
	NetContext.request_service("FactionRemote", "getRequestList", {}, true)
	pass


func agree_and_inject_faction(request_faction_id, faction_id, ops):
	NetContext.request_service("FactionRemote", "agreeAndInjectFaction", {
		"request_faction_id": request_faction_id, 
		"faction_id": faction_id, 
		"ops": ops
	}, true)
	pass


func kikout_quit_faction(target_role_id, faction_id, types):
	op_types = types
	NetContext.request_service("FactionRemote", "quitFaction", {
		"target_role_id": target_role_id, 
		"faction_id": faction_id, 
		"types": types
	}, true)
	pass


func get_faction_member_list(faction_id):
	NetContext.request_service("FactionRemote", "getFactionMemberList", {}, true)
	pass

func get_faction_union_data(faction_id, is_wait = true):
	NetContext.request_service("FactionRemote", "getFactionUnionDataInfo", {
		"faction_id": faction_id
	}, is_wait)
	pass




func _on_create_faction_result(data):
	data = data["data"]
	ScreenUtils.show_message("帮派创建成功！")
	Global.get("RoleInfoManage").set_role_faction_id(int(data))
	pass

func _on_delete_faction_result(data):
	Global.get("RoleInfoManage").set_role_faction_id(0)
	emit_signal("faction_delete_success")
	pass


func _on_request_join_result(data):
	data = data["data"]
	ScreenUtils.show_message("已发出入帮请求,请等待同意")
	pass
	

func _on_faction_list_result(data):
	data = data["data"]
	emit_signal("faction_list_loaded", data)
	faction_list = data
	Global.log_info(str(prefix, "帮派列表", data))
	pass


func _on_role_member_info_result(data):
	data = data["data"]
	if int(data["role_id"]) == Global.get("RoleInfoManage").get_role_id():
		current_member_info = data
	else:
		emit_signal("faction_member_info_loaded", data)
	Global.log_info(str("成员的详细信息：", data))
	pass


func _on_member_request_list_result(data):
	data = data["data"]
	emit_signal("faction_member_request_list_loaded", data)
	pass


func _on_faction_member_op_result(data):
	ScreenUtils.show_message("操作成功！")
	pass


func _on_kikout_quit_op_result(data):
	if op_types == 0:
		ScreenUtils.show_message("退出帮派成功")
	else:
		ScreenUtils.show_message("操作成功")
	emit_signal("kickout_quit_loaded")


func _on_member_list_result(data):
	data = data["data"]
	emit_signal("faction_membem_list_loaded", data)
	pass

func _on_faction_union_data_result(data):
	data = data.get("data", {})
	emit_signal("faction_union_data_loaded", data)


func has_faction():
	var id = Global.get("RoleInfoManage").get_role_faction_id()
	if id <= 0: return false
	return true
