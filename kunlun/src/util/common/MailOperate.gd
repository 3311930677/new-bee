extends Node
class_name MailOperate


var new_mail = {
	"4": "写新邮件"
}

var system_mail_no_attach = {
	"1": "阅读邮件", 
	"4": "新建邮件", 
	"3": "删除邮件", 
	"6": "删除全部", 
}

var system_mail_attach = {
	"1": "阅读邮件", 
	"2": "提取附件", 
	"4": "新建邮件", 
	"3": "删除邮件", 
	"6": "删除全部", 
}

var user_mail_no_attach = {
	"1": "阅读邮件", 
	"4": "新建邮件", 
	"5": "回复邮件", 
	"3": "删除邮件", 
	"6": "删除全部", 
}

var user_mail_attach = {
	"1": "阅读邮件", 
	"2": "提取附件", 
	"4": "新建邮件", 
	"5": "回复邮件", 
	"3": "删除邮件", 
	"6": "删除全部", 
}

var user_mail_attach_cost = {
	"1": "阅读邮件", 
	"2": "提取附件", 
	"4": "新建邮件", 
	"5": "回复邮件", 
	"3": "删除邮件", 
	"6": "删除全部", 
	"7": "退回邮件", 
}

var data

func get_menu_dic(mail_item):
	data = mail_item
	if mail_item == null: return new_mail
	
	if mail_item["role_id"] == 0:
		if mail_item["extract"] == 0:
			
			return system_mail_attach
		else:
			return system_mail_no_attach
	else:
		if mail_item["extract"] == 0:
			if mail_item["cost"] > 0:
				return user_mail_attach_cost
			return user_mail_attach
		else:
			return user_mail_no_attach

func menu_item_click(id):
	match id:
		1:
			Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/mail/ReadMailUi.tscn", "load_data", {"mail_data": data})
			pass
		2:
			if data["cost"] > 0:
				Global.get("ScreenUtils").show_message(str("确定花费:", data["cost"], "银两提取附件？"), self, "_ok_take_attache")
				pass
			else:
				_ok_take_attache()
				pass
		3:
			if data["cost"] > 0:
				Global.get("ScreenUtils").show_message(str("邮件中含有付费附件无法删除"))
				pass
			else:
				if data["extract"] == 0:
					Global.get("ScreenUtils").show_message(str("邮件中含有附件确定删除？"), self, "_ok_delete_mail")
				else:
					Global.get("ScreenUtils").show_message(str("确定删除邮件？"), self, "_ok_delete_mail")
			pass
		4:
			Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/mail/SendMailUi.tscn", "load_data", {})
			pass
		5:
			Global.get("ScreenUtils").chage_ui_and_args("res://src/tscn/ui/map/mail/SendMailUi.tscn", "load_data", {"name": data["role_name"]})
			pass
		6:
			if data["cost"] > 0:
				Global.get("ScreenUtils").show_message(str("部分邮件中含有付费附件无法删除"))
				pass
			else:
				if data["extract"] == 0:
					Global.get("ScreenUtils").show_message(str("部分邮件中含有附件确定删除？"), self, "_ok_delete_mail_all")
				else:
					Global.get("ScreenUtils").show_message(str("确定删除邮件？"), self, "_ok_delete_mail_all")
			pass
		7:
			Global.get("ScreenUtils").show_message(str("确定退回当前邮件？"), self, "_ok_back_mail")
			pass


func _ok_take_attache():
	Global.get("MailInfoManage").take_mail(data)
	data = null
	pass
func _ok_delete_mail():
	Global.get("MailInfoManage").delete_mail(data)
	data = null
	pass
func _ok_delete_mail_all():
	Global.get("MailInfoManage").delete_all_mails(data)
	data = null
	pass
func _ok_back_mail():
	Global.get("MailInfoManage").back_mail(data)
	data = null
