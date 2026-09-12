extends Node
class_name MailInfoManage

const prefix = "MailInfoManage->"

signal mail_send_successed
signal mail_item_state_update
signal mail_item_ui_update
signal mail_content_detailed
signal mail_delete_successed

var ScreenUtils
var StaticGameData
var BagInfoManage
var NetContext

var mail_is_load = true


var list_mails = []
var temp_data

func _init() -> void :
	ScreenUtils = Global.get("ScreenUtils")
	StaticGameData = Global.get("StaticGameData")
	BagInfoManage = Global.get("BagInfoManage")
	NetContext = Global.get("NetContext")
	
	
	NetContext.set_handler("ServicePush", "mailPush", self, "_on_server_push_mail_message")
	
	NetContext.set_handler("MailRemote", "getMails", self, "_on_mails_result")
	
	NetContext.set_handler("MailRemote", "extractAttach", self, "_on_extract_result")
	
	NetContext.set_handler("MailRemote", "getMainContent", self, "_on_mail_content_result")
	
	NetContext.set_handler("MailRemote", "del", self, "_on_del_mail_result")
	
	NetContext.set_handler("MailRemote", "delAll", self, "_on_del_mail_all_result")
	
	NetContext.set_handler("MailRemote", "goBack", self, "_on_back_mail_result")
	
	NetContext.set_handler("MailRemote", "sendMail", self, "_on_send_mail_result")
	
	
	pass



func _on_server_push_mail_message(data):
	data = parse_json(data["data"])
	if int(data["type"]) == 1:
		ScreenUtils.show_top_tips("[color=red]你有新邮件来了[/color]")
		Global.get_nodes_in_group("mail_icon")[0].start_glimmer()
		mail_is_load = true



func _on_mails_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "邮件数据：", data))
	list_mails = data
	emit_signal("mail_item_ui_update")
	pass

func _on_extract_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "提取数据：", data))
	temp_data["extract"] = 1
	temp_data["cost"] = 0
	ScreenUtils.show_message("邮件提取成功")
	Global.get("BagInfoManage").request()
	emit_signal("mail_item_state_update")
	pass
func _on_mail_content_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "邮件详情：", data))
	temp_data["state"] = 1
	emit_signal("mail_content_detailed", data)
	emit_signal("mail_item_state_update")
	pass
func _on_del_mail_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "邮件删除返回：", data))
	ScreenUtils.show_message("邮件删除成功")
	var index = 0
	list_mails.erase(temp_data)
	





	emit_signal("mail_item_ui_update")
	pass
func _on_del_mail_all_result(data):
	data = data["data"]
	Global.log_info(str(prefix, "全部邮件删除返回：", data))
	ScreenUtils.show_message("邮件删除成功")
	list_mails.clear()
	emit_signal("mail_item_ui_update")
	pass
func _on_back_mail_result(data):
	Global.log_info(str(prefix, "邮件回退返回：", data))
	ScreenUtils.show_message("邮件回退成功")
	
	var index = 0
	list_mails.erase(temp_data)




	emit_signal("mail_item_ui_update")

func _on_send_mail_result(data):
	Global.log_info(str(prefix, "邮件发送成功：", data))
	ScreenUtils.show_message("邮件发送成功")
	emit_signal("mail_send_successed")
	pass


func send_mail(request_data):
	NetContext.request_service("MailRemote", "sendMail", request_data, true)


func request_all_mails():
	if mail_is_load:
		NetContext.request_service("MailRemote", "getMails", {}, true)
	else:
		emit_signal("mail_item_ui_update")
	pass

func get_mails():
	return list_mails

func get_mail_content(mail_info):
	temp_data = mail_info
	NetContext.request_service("MailRemote", "getMainContent", {
		"mail_id": mail_info["mail_id"]
	}, true)
	pass

func delete_mail(mail_info):
	temp_data = mail_info
	NetContext.request_service("MailRemote", "del", {
		"mail_id": temp_data["mail_id"]
	}, true)
	emit_signal("mail_delete_successed")
	pass

func delete_all_mails(mail_info):
	temp_data = mail_info
	NetContext.request_service("MailRemote", "delAll", {}, true)
	emit_signal("mail_delete_successed")
	pass

func back_mail(mail_info):
	temp_data = mail_info
	NetContext.request_service("MailRemote", "goBack", {
		"mail_id": temp_data["mail_id"]
	}, true)

func take_mail(mail_info):
	temp_data = mail_info
	NetContext.request_service("MailRemote", "extractAttach", {
		"mail_id": temp_data["mail_id"]
	}, true)
	pass

func check_has_mail():
	NetContext.request_service("MailRemote", "isUnread", {}, false)
